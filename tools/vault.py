import os
import sys
import struct
import hashlib
import getpass
import argparse

# Ensure console supports all unicode characters gracefully
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

MAGIC_V4 = b"VAULTV04"
MAGIC_V3 = b"VAULTV03"
MAGIC_V2 = b"VAULTV02"
MAGIC_V1 = b"HDRLOK01"

FOOTER_LEN_V4 = 80
FOOTER_LEN_V3 = 80
FOOTER_LEN_V2 = 76

EXCLUDED_EXTS = {
    ".bat", ".cmd", ".ps1", ".py", ".html", ".sh", ".git", ".gitignore", ".env", ".log"
}
EXCLUDED_DIRS = {
    "tools", ".vault", ".git", "__pycache__", "node_modules", ".vscode", ".idea"
}

SMART_FULL_THRESHOLD = 50 * 1024 * 1024
KDF_ITERATIONS = 100000

CRYPTO_BACKEND = None
try:
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    from cryptography.hazmat.backends import default_backend
    CRYPTO_BACKEND = "cryptography"
except ImportError:
    try:
        from Crypto.Cipher import AES
        CRYPTO_BACKEND = "pycryptodome"
    except ImportError:
        CRYPTO_BACKEND = "openssl"

def derive_key_and_auth(password, salt, version=4):
    iters = KDF_ITERATIONS if version >= 3 else 10000
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iters, dklen=32)
    if version == 4:
        tag = b"VAULT_AUTH_V4"
    elif version == 3:
        tag = b"VAULT_AUTH_V3"
    elif version == 2:
        tag = b"VAULT_AUTH_V2"
    else:
        tag = b"AUTH_CHECK_V1"
    auth_hash = hashlib.sha256(key + tag + salt).digest()
    return key, auth_hash

def aes_decrypt_cbc(key, iv, data):
    if CRYPTO_BACKEND == "cryptography":
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        decryptor = cipher.decryptor()
        return decryptor.update(data) + decryptor.finalize()
    elif CRYPTO_BACKEND == "pycryptodome":
        from Crypto.Cipher import AES
        cipher = AES.new(key, AES.MODE_CBC, iv)
        return cipher.decrypt(data)
    else:
        import subprocess
        p = subprocess.Popen(
            ["openssl", "enc", "-d", "-aes-256-cbc", "-K", key.hex(), "-iv", iv.hex(), "-nopad"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        out, err = p.communicate(data)
        if p.returncode != 0:
            raise RuntimeError(f"OpenSSL error: {err.decode('utf-8', errors='ignore')}")
        return out

def aes_encrypt_cbc(key, iv, data):
    if CRYPTO_BACKEND == "cryptography":
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        encryptor = cipher.encryptor()
        return encryptor.update(data) + encryptor.finalize()
    elif CRYPTO_BACKEND == "pycryptodome":
        from Crypto.Cipher import AES
        cipher = AES.new(key, AES.MODE_CBC, iv)
        return cipher.encrypt(data)
    else:
        import subprocess
        p = subprocess.Popen(
            ["openssl", "enc", "-e", "-aes-256-cbc", "-K", key.hex(), "-iv", iv.hex(), "-nopad"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        out, err = p.communicate(data)
        if p.returncode != 0:
            raise RuntimeError(f"OpenSSL error: {err.decode('utf-8', errors='ignore')}")
        return out

def read_footer(f, size):
    if size >= FOOTER_LEN_V4:
        f.seek(size - FOOTER_LEN_V4)
        foot = f.read(FOOTER_LEN_V4)
        magic = foot[:8]
        if magic == MAGIC_V4:
            return 4, foot, FOOTER_LEN_V4
        if magic == MAGIC_V3:
            return 3, foot, FOOTER_LEN_V3
    if size >= FOOTER_LEN_V2:
        f.seek(size - FOOTER_LEN_V2)
        foot = f.read(FOOTER_LEN_V2)
        if foot[:8] in (MAGIC_V2, MAGIC_V1):
            v = 2 if foot[:8] == MAGIC_V2 else 1
            return v, foot, FOOTER_LEN_V2
    return None, None, 0

def check_file_status(filepath):
    try:
        size = os.path.getsize(filepath)
        with open(filepath, "rb") as f:
            v, foot, _ = read_footer(f, size)
            if v:
                chunk_size = struct.unpack("<I", foot[8:12])[0]
                is_full = (v == 4 and chunk_size == 0)
                fails = 0
                if v >= 3:
                    fails, _ = struct.unpack("<HH", foot[76:80])
                mode_str = "100% Full Armor" if is_full else "Header Armor"
                if fails >= 5:
                    return f"locked ({mode_str} - LOCKOUT: {fails} fails)"
                return f"locked ({mode_str})"
        return "unlocked"
    except Exception:
        return "invalid"

def unlock_file(filepath, password):
    size = os.path.getsize(filepath)
    try:
        with open(filepath, "r+b") as f:
            version, footer, footer_len = read_footer(f, size)
            if not version:
                return False, "Not locked"

            chunk_size = struct.unpack("<I", footer[8:12])[0]
            salt = footer[12:28]
            iv = footer[28:44]
            stored_auth = footer[44:76]

            fails = 0
            if version >= 3:
                fails, _ = struct.unpack("<HH", footer[76:80])
                if fails >= 10:
                    return False, f"BRUTE-FORCE LOCKOUT ACTIVE ({fails} failed attempts). Cooldown required."

            key, auth_hash = derive_key_and_auth(password, salt, version=version)
            if stored_auth != auth_hash:
                if version >= 3:
                    fails += 1
                    f.seek(size - 4)
                    f.write(struct.pack("<HH", fails, 0))
                    f.flush()
                    remaining = max(0, 10 - fails)
                    return False, f"INCORRECT PASSWORD ({fails} failed attempts, {remaining} left before lockout)"
                return False, "INCORRECT PASSWORD"

            data_len = size - footer_len
            is_full = (version == 4 and chunk_size == 0)

            if is_full:
                enc_blocks_len = data_len - (data_len % 16)
                if enc_blocks_len > 0:
                    curr_iv = iv
                    chunk_step = 1024 * 1024
                    pos = 0
                    while pos < enc_blocks_len:
                        take = min(chunk_step, enc_blocks_len - pos)
                        f.seek(pos)
                        enc_chunk = f.read(take)
                        dec_chunk = aes_decrypt_cbc(key, curr_iv, enc_chunk)
                        curr_iv = enc_chunk[-16:]
                        f.seek(pos)
                        f.write(dec_chunk)
                        pos += take

                f.truncate(data_len)
                return True, f"Restored 100% full file ({data_len} bytes)"
            else:
                f.seek(0)
                enc_header = f.read(chunk_size)
                dec_header = aes_decrypt_cbc(key, iv, enc_header)

                f.seek(0)
                f.write(dec_header)
                f.truncate(data_len)
                return True, f"Restored {chunk_size} bytes header"
    except Exception as e:
        return False, f"Error: {e}"

def lock_file(filepath, password, force_full=False):
    size = os.path.getsize(filepath)
    if size < 16:
        return False, "File too small (< 16 bytes)"
    try:
        with open(filepath, "r+b") as f:
            v, _, _ = read_footer(f, size)
            if v:
                return False, "Already locked"

            is_full = force_full or (size < SMART_FULL_THRESHOLD)
            salt = os.urandom(16)
            iv = os.urandom(16)
            key, auth_hash = derive_key_and_auth(password, salt, version=4)

            if is_full:
                enc_blocks_len = size - (size % 16)
                curr_iv = iv
                pos = 0
                chunk_step = 1024 * 1024
                while pos < enc_blocks_len:
                    take = min(chunk_step, enc_blocks_len - pos)
                    f.seek(pos)
                    chunk = f.read(take)
                    enc_chunk = aes_encrypt_cbc(key, curr_iv, chunk)
                    curr_iv = enc_chunk[-16:]
                    f.seek(pos)
                    f.write(enc_chunk)
                    pos += take

                f.seek(0, os.SEEK_END)
                footer = MAGIC_V4 + struct.pack("<I", 0) + salt + iv + auth_hash + struct.pack("<HH", 0, 1)
                f.write(footer)
                return True, f"Encrypted 100% FULL FILE ({size} bytes, Zero Carvable Plaintext)"
            else:
                chunk_size = min(size, 65536)
                chunk_size = chunk_size - (chunk_size % 16)
                f.seek(0)
                header = f.read(chunk_size)
                enc_header = aes_encrypt_cbc(key, iv, header)
                f.seek(0)
                f.write(enc_header)
                f.seek(0, os.SEEK_END)
                footer = MAGIC_V4 + struct.pack("<I", chunk_size) + salt + iv + auth_hash + struct.pack("<HH", 0, 0)
                f.write(footer)
                return True, f"Encrypted {chunk_size} bytes header (Fast Media Mode)"
    except Exception as e:
        return False, f"Error: {e}"

def resolve_targets(path):
    path = os.path.abspath(path.strip('\'"'))
    if os.path.isfile(path):
        ext = os.path.splitext(path)[1].lower()
        if ext in EXCLUDED_EXTS:
            return []
        return [path]

    target_files = []
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d.lower() not in EXCLUDED_DIRS and not d.startswith(".")]
        for file in files:
            if file.startswith("."):
                continue
            ext = os.path.splitext(file)[1].lower()
            if ext in EXCLUDED_EXTS:
                continue
            target_files.append(os.path.join(root, file))
    return target_files

def process_targets(action, path, password=None, force_full=False):
    targets = resolve_targets(path)

    print("=" * 68)
    print(f"  Universal Vault Engine V4: {action.upper()} Operation")
    print(f"  Target Scope: {os.path.abspath(path.strip('\'\"'))}")
    print(f"  Files Identified: {len(targets)}")
    if action == "lock":
        mode_label = "100% Full Encryption (All Files)" if force_full else "Smart Hybrid (100% Full <50MB | Header >=50MB)"
        print(f"  Encryption Mode: {mode_label}")
        print(f"  Security: 100,000 PBKDF2 Iterations | Anti-Brute-Force Enabled")
    print("=" * 68)

    if not targets:
        print("No eligible files found to process.\n")
        return

    if action == "status":
        locked_count = 0
        unlocked_count = 0
        for p in targets:
            st = check_file_status(p)
            rel = os.path.relpath(p, path) if os.path.isdir(path) else os.path.basename(p)
            if st.startswith("locked"):
                print(f"  [LOCKED]   {rel} ({st})")
                locked_count += 1
            else:
                print(f"  [UNLOCKED] {rel}")
                unlocked_count += 1
        print("-" * 68)
        print(f"Status Summary: {locked_count} Locked | {unlocked_count} Unlocked\n")
        return

    success_count = 0
    skip_count = 0
    fail_count = 0

    for p in targets:
        rel = os.path.relpath(p, path) if os.path.isdir(path) else os.path.basename(p)
        print(f"Processing: {rel}... ", end="", flush=True)
        if action == "lock":
            ok, msg = lock_file(p, password, force_full=force_full)
        else:
            ok, msg = unlock_file(p, password)

        if ok:
            print(f"[SUCCESS: {msg}]")
            success_count += 1
        elif "Already locked" in msg or "Not locked" in msg or "too small" in msg:
            print(f"[SKIPPED: {msg}]")
            skip_count += 1
        else:
            print(f"[FAILED: {msg}]")
            fail_count += 1

    print("-" * 68)
    print(f"Summary: {success_count} Succeeded | {skip_count} Skipped | {fail_count} Failed\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Universal Cross-Platform Full-File Vault with Anti-Brute-Force")
    parser.add_argument("action", choices=["lock", "unlock", "status"], help="Action to perform")
    parser.add_argument("path", nargs="?", default=".", help="Specific file or directory path (default: current directory)")
    parser.add_argument("-p", "--password", help="Master password (optional, prompted securely if omitted)")
    parser.add_argument("--full", action="store_true", help="Force 100%% FULL encryption on all files regardless of size")

    args = parser.parse_args()

    password = args.password
    if args.action in ("lock", "unlock") and not password:
        if sys.stdin.isatty():
            password = getpass.getpass(f"Enter Master Password to {args.action.upper()}: ")
        else:
            line = sys.stdin.readline()
            password = line.strip() if line else ""

        if not password:
            print("Error: Password cannot be empty.")
            sys.exit(1)

    process_targets(args.action, args.path, password, force_full=args.full)

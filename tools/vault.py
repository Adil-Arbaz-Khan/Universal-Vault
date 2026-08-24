import os
import sys
import struct
import hashlib
import hmac
import getpass
import argparse

# Reconfigure stdout/stderr for full Unicode support
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

MAGIC_V5 = b"VAULTV05"
MAGIC_V4 = b"VAULTV04"
MAGIC_V3 = b"VAULTV03"
MAGIC_V2 = b"VAULTV02"
MAGIC_V1 = b"HDRLOK01"

FOOTER_LEN_V5 = 96
FOOTER_LEN_V4 = 80
FOOTER_LEN_V3 = 80
FOOTER_LEN_V2 = 76

CHUNK_SIZE_V5 = 64 * 1024  # 64 KB streaming blocks
KDF_ITERS_V5 = 600000     # OWASP 2026 Gold Standard (600,000 rounds)

EXCLUDED_EXTS = {
    ".bat", ".cmd", ".ps1", ".py", ".html", ".sh", ".git", ".gitignore", ".env", ".log"
}
EXCLUDED_DIRS = {
    "tools", ".vault", ".git", "__pycache__", "node_modules", ".vscode", ".idea"
}

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

def derive_keys_v5(password, salt):
    """
    Derives a 64-byte key material using PBKDF2-HMAC-SHA256 (600,000 iterations - OWASP Standard).
    Splits into:
    - 32-byte AES-256 Encryption Key
    - 32-byte HMAC-SHA256 Authentication Key
    """
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, KDF_ITERS_V5, dklen=64)
    enc_key = dk[:32]
    mac_key = dk[32:64]
    auth_tag = hmac.new(mac_key, b"VAULT_AUTH_V5" + salt, hashlib.sha256).digest()[:16]
    return enc_key, mac_key, auth_tag

def derive_legacy_key(password, salt, version=4):
    iters = 100000 if version >= 3 else 10000
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iters, dklen=32)
    tag = b"VAULT_AUTH_V4" if version == 4 else (b"VAULT_AUTH_V3" if version == 3 else (b"VAULT_AUTH_V2" if version == 2 else b"AUTH_CHECK_V1"))
    auth_hash = hashlib.sha256(key + tag + salt).digest()
    return key, auth_hash

def aes_ctr_process(key, nonce, data, initial_counter=0):
    """
    AES-256-CTR block streaming cipher.
    Encrypt and Decrypt are symmetric operations.
    """
    if CRYPTO_BACKEND == "cryptography":
        # Increment counter based on initial block offset
        counter_int = int.from_bytes(nonce, "big") + initial_counter
        curr_nonce = counter_int.to_bytes(16, "big")
        cipher = Cipher(algorithms.AES(key), modes.CTR(curr_nonce), backend=default_backend())
        enc = cipher.encryptor()
        return enc.update(data) + enc.finalize()
    elif CRYPTO_BACKEND == "pycryptodome":
        from Crypto.Cipher import AES
        from Crypto.Util import Counter
        ctr_val = (int.from_bytes(nonce, "big") + initial_counter) % (2**128)
        ctr = Counter.new(128, initial_value=ctr_val)
        cipher = AES.new(key, AES.MODE_CTR, counter=ctr)
        return cipher.encrypt(data)
    else:
        # Fallback to OpenSSL CLI
        import subprocess
        counter_int = int.from_bytes(nonce, "big") + initial_counter
        curr_iv = counter_int.to_bytes(16, "big").hex()
        p = subprocess.Popen(
            ["openssl", "enc", "-aes-256-ctr", "-K", key.hex(), "-iv", curr_iv, "-nopad"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        out, err = p.communicate(data)
        if p.returncode != 0:
            raise RuntimeError(f"OpenSSL error: {err.decode('utf-8', errors='ignore')}")
        return out

def aes_cbc_process(key, iv, data, decrypt=False):
    if CRYPTO_BACKEND == "cryptography":
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        ctx = cipher.decryptor() if decrypt else cipher.encryptor()
        return ctx.update(data) + ctx.finalize()
    elif CRYPTO_BACKEND == "pycryptodome":
        from Crypto.Cipher import AES
        cipher = AES.new(key, AES.MODE_CBC, iv)
        return cipher.decrypt(data) if decrypt else cipher.encrypt(data)
    else:
        import subprocess
        mode = "-d" if decrypt else "-e"
        p = subprocess.Popen(
            ["openssl", "enc", mode, "-aes-256-cbc", "-K", key.hex(), "-iv", iv.hex(), "-nopad"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        out, err = p.communicate(data)
        if p.returncode != 0:
            raise RuntimeError(f"OpenSSL error: {err.decode('utf-8', errors='ignore')}")
        return out

def read_footer(f, size):
    if size >= FOOTER_LEN_V5:
        f.seek(size - FOOTER_LEN_V5)
        foot = f.read(FOOTER_LEN_V5)
        if foot[:8] == MAGIC_V5:
            return 5, foot, FOOTER_LEN_V5
    if size >= FOOTER_LEN_V4:
        f.seek(size - FOOTER_LEN_V4)
        foot = f.read(FOOTER_LEN_V4)
        if foot[:8] == MAGIC_V4:
            return 4, foot, FOOTER_LEN_V4
        if foot[:8] == MAGIC_V3:
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
                if v == 5:
                    fails, _ = struct.unpack("<HH", foot[92:96])
                    status_lbl = "V5 Authenticated AEAD (100% Full-File)"
                    if fails >= 5:
                        return f"locked ({status_lbl} - LOCKOUT: {fails} fails)"
                    return f"locked ({status_lbl})"
                elif v == 4:
                    chunk_size = struct.unpack("<I", foot[8:12])[0]
                    fails, _ = struct.unpack("<HH", foot[76:80])
                    mode_str = "V4 Full Armor" if chunk_size == 0 else "V4 Header Armor"
                    if fails >= 5:
                        return f"locked ({mode_str} - LOCKOUT: {fails} fails)"
                    return f"locked ({mode_str})"
                else:
                    return f"locked (Legacy V{v})"
        return "unlocked"
    except Exception:
        return "invalid"

def lock_file_v5(filepath, password):
    size = os.path.getsize(filepath)
    if size < 1:
        return False, "File is empty (0 bytes)"
    try:
        with open(filepath, "r+b") as f:
            v, _, _ = read_footer(f, size)
            if v:
                return False, "Already locked"

            salt = os.urandom(16)
            nonce = os.urandom(16)
            enc_key, mac_key, auth_tag = derive_keys_v5(password, salt)

            hmac_calc = hmac.new(mac_key, digestmod=hashlib.sha256)

            pos = 0
            block_idx = 0
            while pos < size:
                take = min(CHUNK_SIZE_V5, size - pos)
                f.seek(pos)
                plaintext_chunk = f.read(take)
                
                # Encrypt chunk in-place using AES-256-CTR
                initial_block = block_idx * (CHUNK_SIZE_V5 // 16)
                cipher_chunk = aes_ctr_process(enc_key, nonce, plaintext_chunk, initial_counter=initial_block)

                # Feed ciphertext to master HMAC
                hmac_calc.update(cipher_chunk)

                f.seek(pos)
                f.write(cipher_chunk)

                pos += take
                block_idx += 1

            master_mac = hmac_calc.digest()

            # Append V5 Authenticated Footer (96 bytes)
            footer = (
                MAGIC_V5 +
                struct.pack("<I", CHUNK_SIZE_V5) +
                salt +
                nonce +
                master_mac +
                auth_tag +
                struct.pack("<HH", 0, 1)  # fails=0, mode=1 (Full AEAD)
            )
            f.seek(0, os.SEEK_END)
            f.write(footer)
            f.flush()

            return True, f"100% Full-File AEAD Armor ({size} bytes, Authenticated EtM + 600k PBKDF2)"
    except Exception as e:
        return False, f"Error: {e}"

def unlock_file_v5(filepath, password):
    size = os.path.getsize(filepath)
    try:
        with open(filepath, "r+b") as f:
            version, footer, footer_len = read_footer(f, size)
            if not version:
                return False, "Not locked"

            data_len = size - footer_len

            if version == 5:
                # V5 Authenticated Encrypt-then-MAC Engine
                salt = footer[12:28]
                nonce = footer[28:44]
                stored_mac = footer[44:76]
                stored_auth_tag = footer[76:92]
                fails, _ = struct.unpack("<HH", footer[92:96])

                if fails >= 10:
                    return False, f"BRUTE-FORCE LOCKOUT ACTIVE ({fails} failed attempts). Cooldown required."

                enc_key, mac_key, computed_auth_tag = derive_keys_v5(password, salt)

                # Constant-time password tag verification
                if not hmac.compare_digest(stored_auth_tag, computed_auth_tag):
                    fails += 1
                    f.seek(size - 4)
                    f.write(struct.pack("<HH", fails, 1))
                    f.flush()
                    rem = max(0, 10 - fails)
                    return False, f"INCORRECT PASSWORD ({fails} failed attempts, {rem} left before lockout)"

                # Full Ciphertext Integrity Verification (Anti-Tampering)
                f.seek(0)
                hmac_verify = hmac.new(mac_key, digestmod=hashlib.sha256)
                pos = 0
                while pos < data_len:
                    take = min(CHUNK_SIZE_V5, data_len - pos)
                    chunk = f.read(take)
                    hmac_verify.update(chunk)
                    pos += take

                computed_mac = hmac_verify.digest()
                if not hmac.compare_digest(stored_mac, computed_mac):
                    return False, "INTEGRITY ERROR: Ciphertext has been modified or corrupted! Decryption halted."

                # Authenticated Stream Decryption (In-Place)
                pos = 0
                block_idx = 0
                while pos < data_len:
                    take = min(CHUNK_SIZE_V5, data_len - pos)
                    f.seek(pos)
                    cipher_chunk = f.read(take)

                    initial_block = block_idx * (CHUNK_SIZE_V5 // 16)
                    plain_chunk = aes_ctr_process(enc_key, nonce, cipher_chunk, initial_counter=initial_block)

                    f.seek(pos)
                    f.write(plain_chunk)

                    pos += take
                    block_idx += 1

                f.truncate(data_len)
                f.flush()
                return True, f"Verified & Restored 100% full file ({data_len} bytes)"

            elif version == 4:
                # Legacy V4 Engine Support
                chunk_size = struct.unpack("<I", footer[8:12])[0]
                salt = footer[12:28]
                iv = footer[28:44]
                stored_auth = footer[44:76]
                fails, _ = struct.unpack("<HH", footer[76:80])

                if fails >= 10:
                    return False, f"BRUTE-FORCE LOCKOUT ACTIVE ({fails} failed attempts)."

                key, auth_hash = derive_legacy_key(password, salt, version=4)
                if not hmac.compare_digest(stored_auth, auth_hash):
                    fails += 1
                    f.seek(size - 4)
                    f.write(struct.pack("<HH", fails, 0))
                    f.flush()
                    return False, "INCORRECT PASSWORD"

                is_full = (chunk_size == 0)
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
                            dec_chunk = aes_cbc_process(key, curr_iv, enc_chunk, decrypt=True)
                            curr_iv = enc_chunk[-16:]
                            f.seek(pos)
                            f.write(dec_chunk)
                            pos += take
                    f.truncate(data_len)
                    return True, f"Restored V4 full file ({data_len} bytes) - [MIGRATION ADVISORY: Legacy format without HMAC integrity. Re-lock with V5]"
                else:
                    f.seek(0)
                    enc_header = f.read(chunk_size)
                    dec_header = aes_cbc_process(key, iv, enc_header, decrypt=True)
                    f.seek(0)
                    f.write(dec_header)
                    f.truncate(data_len)
                    return True, f"Restored V4 header ({chunk_size} bytes) - [MIGRATION ADVISORY: Legacy format. Re-lock with V5]"

            else:
                # Legacy V3/V2/V1 Support
                chunk_size = struct.unpack("<I", footer[8:12])[0]
                salt = footer[12:28]
                iv = footer[28:44]
                stored_auth = footer[44:76]

                key, auth_hash = derive_legacy_key(password, salt, version=version)
                if not hmac.compare_digest(stored_auth, auth_hash):
                    return False, "INCORRECT PASSWORD"

                f.seek(0)
                enc_header = f.read(chunk_size)
                dec_header = aes_cbc_process(key, iv, enc_header, decrypt=True)
                f.seek(0)
                f.write(dec_header)
                f.truncate(data_len)
                return True, f"Restored legacy V{version} header ({chunk_size} bytes) - [MIGRATION ADVISORY: Legacy format. Re-lock with V5]"

    except Exception as e:
        return False, f"Error: {e}"

def resolve_targets(path):
    path = os.path.abspath(path.strip('\'"'))
    if os.path.islink(path):
        return []
    if os.path.isfile(path):
        ext = os.path.splitext(path)[1].lower()
        if ext in EXCLUDED_EXTS:
            return []
        return [path]

    target_files = []
    for root, dirs, files in os.walk(path, followlinks=False):
        dirs[:] = [d for d in dirs if d.lower() not in EXCLUDED_DIRS and not d.startswith(".") and not os.path.islink(os.path.join(root, d))]
        for file in files:
            full_file_path = os.path.join(root, file)
            if file.startswith(".") or os.path.islink(full_file_path):
                continue
            ext = os.path.splitext(file)[1].lower()
            if ext in EXCLUDED_EXTS:
                continue
            target_files.append(full_file_path)
    return target_files

def process_targets(action, path, password=None):
    targets = resolve_targets(path)

    print("=" * 70)
    print(f"  Universal Vault V5 (Enterprise Grade): {action.upper()} Operation")
    print(f"  Target Scope: {os.path.abspath(path.strip('\'\"'))}")
    print(f"  Files Identified: {len(targets)}")
    if action == "lock":
        print(f"  Armor Mode: 100% Full-File AEAD (Stream Encrypt-then-MAC)")
        print(f"  Security: 600,000 PBKDF2-SHA256 Rounds | Anti-Tampering HMAC-SHA256")
    print("=" * 70)

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
        print("-" * 70)
        print(f"Status Summary: {locked_count} Locked | {unlocked_count} Unlocked\n")
        return

    success_count = 0
    skip_count = 0
    fail_count = 0

    for p in targets:
        rel = os.path.relpath(p, path) if os.path.isdir(path) else os.path.basename(p)
        print(f"Processing: {rel}... ", end="", flush=True)
        if action == "lock":
            ok, msg = lock_file_v5(p, password)
        else:
            ok, msg = unlock_file_v5(p, password)

        if ok:
            print(f"[SUCCESS: {msg}]")
            success_count += 1
        elif "Already locked" in msg or "Not locked" in msg or "empty" in msg:
            print(f"[SKIPPED: {msg}]")
            skip_count += 1
        else:
            print(f"[FAILED: {msg}]")
            fail_count += 1

    print("-" * 70)
    print(f"Summary: {success_count} Succeeded | {skip_count} Skipped | {fail_count} Failed\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Universal Vault V5: Authenticated Full-File In-Place Encryption Suite")
    parser.add_argument("action", choices=["lock", "unlock", "status"], help="Action to perform")
    parser.add_argument("path", nargs="?", default=".", help="Specific file or directory path (default: current directory)")
    parser.add_argument("-p", "--password", help="Master password (optional, prompted securely if omitted)")

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

    process_targets(args.action, args.path, password)

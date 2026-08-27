import os
import zipfile
import shutil

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT_DIR, "releases_v5.5.1")

if os.path.exists(OUT_DIR):
    shutil.rmtree(OUT_DIR)
os.makedirs(OUT_DIR, exist_ok=True)

# -------------------------------------------------------------
# Custom README Templates
# -------------------------------------------------------------

README_WINDOWS = """# 🛡️ Universal Vault v5.5.1 (Windows Edition)

**Enterprise-Grade In-Place Authenticated Encryption Suite (AEAD)**  
*Zero Installation • 100% Full-File AEAD • 600,000 PBKDF2 Iterations • Crash-Safe Checkpointed • Real-Time Progress Bar*

---

## 🚀 Simple Step-by-Step Instructions

### Method 1: 1-Click Batch Launchers (Recommended)
1. **To Lock / Encrypt**:
   * Double-click **`Lock.bat`**.
   * Choose option `[1]` to lock the entire folder, or choose `[2]` and drag-and-drop any specific file/folder into the terminal window.
   * Enter your master password.
2. **To Unlock / Decrypt**:
   * Double-click **`Unlock.bat`**.
   * Enter your master password. Universal Vault verifies HMAC-SHA256 integrity and restores your files in-place.
3. **To Check File Status**:
   * Double-click **`Status.bat`** to see which files are locked, unlocked, or interrupted.

---

### Method 2: Offline Web App & RAM Streamer (Zero Disk Writes)
1. Double-click **`Vault_App.html`** to open it in Chrome, Edge, Brave, or Firefox.
2. Drag and drop any encrypted video, audio, or document.
3. Enter your password to view PDFs or play 4K videos **directly in volatile RAM** with zero temporary files written to your hard drive.

---

## 🧯 What to Do If Interrupted (Crash Recovery)

Did your PC lose power, terminal close, or USB drive get unplugged midway? **Do not worry — your files are safe!**

* **If interrupted while Locking**:
  * Run **`Lock.bat`** $\\to$ Vault resumes from the exact byte where it stopped and finishes locking.
  * *Or* run **`Unlock.bat`** $\\to$ Vault automatically decrypts the partially locked part back to **100% original plaintext**.
* **If interrupted while Unlocking**:
  * Run **`Unlock.bat`** $\\to$ Vault automatically resumes from the last saved safe checkpoint.
* **To check progress**:
  * Run **`Status.bat`** to inspect the exact byte state of your files.

---
**Author**: [Adil Arbaz Khan](https://github.com/Adil-Arbaz-Khan) | **License**: MIT
"""

README_LINUX = """# 🛡️ Universal Vault v5.5.1 (Linux Edition)

**Enterprise-Grade In-Place Authenticated Encryption Suite (AEAD)**  
*Zero Installation • 100% Full-File AEAD • 600,000 PBKDF2 Iterations • Crash-Safe Checkpointed • Real-Time Progress Bar*

---

## 🚀 Simple Step-by-Step Instructions

### 1. Make Scripts Executable
Open your terminal in this directory and run:
```bash
chmod +x lock.sh unlock.sh status.sh
```

### 2. Lock Files / Folders
```bash
# Lock current directory tree:
./lock.sh

# Or lock a specific file or folder:
./lock.sh /path/to/my_folder
./lock.sh /path/to/secret.pdf
```

### 3. Unlock Files / Folders
```bash
# Unlock current directory tree:
./unlock.sh

# Or unlock a specific file or folder:
./unlock.sh /path/to/my_folder
```

### 4. Check Lock Status
```bash
./status.sh /path/to/my_folder
```

---

### 5. Offline Web App & RAM Streamer
Open **`Vault_App.html`** in Firefox, Chrome, or Brave:
* Streams 4K video, audio, and documents **in volatile RAM** with zero disk writes.
* 100% offline, client-side WebCrypto encryption.

---

## 🧯 What to Do If Interrupted (Crash Recovery)

* **Interrupted during Lock**:
  * Run `./lock.sh` to resume and complete encryption.
  * Run `./unlock.sh` to roll back to **100% original plaintext**.
* **Interrupted during Unlock**:
  * Run `./unlock.sh` to automatically resume decryption from the last checkpoint.
* **Check status**:
  * Run `./status.sh` to see the exact byte progress of any interrupted file.

---
**Author**: [Adil Arbaz Khan](https://github.com/Adil-Arbaz-Khan) | **License**: MIT
"""

README_MACOS = """# 🛡️ Universal Vault v5.5.1 (macOS Edition)

**Enterprise-Grade In-Place Authenticated Encryption Suite (AEAD)**  
*Zero Installation • 100% Full-File AEAD • 600,000 PBKDF2 Iterations • Crash-Safe Checkpointed • Real-Time Progress Bar*

---

## 🚀 Simple Step-by-Step Instructions

### Method 1: Terminal Shell Scripts
1. Open **Terminal.app** and navigate to this folder:
   ```bash
   chmod +x lock.sh unlock.sh status.sh
   ```
2. **To Lock**:
   ```bash
   ./lock.sh /path/to/your/folder
   # Tip: Type ./lock.sh and drag-and-drop any folder from Finder into Terminal!
   ```
3. **To Unlock**:
   ```bash
   ./unlock.sh /path/to/your/folder
   ```
4. **To Check Status**:
   ```bash
   ./status.sh /path/to/your/folder
   ```

---

### Method 2: Offline Web App & RAM Streamer (Safari / Chrome)
1. Double-click **`Vault_App.html`** to open in Safari, Chrome, or Brave.
2. Select or drop any file to encrypt/decrypt client-side.
3. Play videos or view documents **directly in memory** with zero disk footprint.

---

## 🧯 What to Do If Interrupted (Crash Recovery)

* **Interrupted during Lock**:
  * Run `./lock.sh` to resume and finish locking.
  * Run `./unlock.sh` to roll back to **100% original plaintext**.
* **Interrupted during Unlock**:
  * Run `./unlock.sh` to automatically resume decryption.
* **Check state**:
  * Run `./status.sh` to see byte progress.

---
**Author**: [Adil Arbaz Khan](https://github.com/Adil-Arbaz-Khan) | **License**: MIT
"""

README_ANDROID = """# 🛡️ Universal Vault v5.5.1 (Android Edition)

**Enterprise-Grade In-Place Authenticated Encryption Suite (AEAD)**  
*100% Full-File AEAD • Zero Install Web App • Termux CLI • Crash-Safe Checkpointed • Real-Time Progress Bar*

---

## 🚀 Simple Step-by-Step Instructions

### Option 1: 1-Click Mobile Web App (No Installation Needed)
1. Open **`Vault_App.html`** in **Chrome**, **Brave**, or **Firefox** on your Android phone/tablet.
2. Tap **Select File** and pick any video, photo, or document from your device.
3. Enter your password to:
   * **Lock / Unlock** files in-place with a live progress bar.
   * **Stream 4K videos or view PDFs** directly in RAM without leaving unencrypted files on your phone.
4. *Tip*: Tap Chrome's menu (3 dots) $\\to$ **"Add to Home screen"** to install it as an offline app icon!

---

### Option 2: Termux Command-Line (Power Users)
If you downloaded and extracted this zip into your Android **Downloads** folder:
1. Open **Termux** and grant storage permission (one-time setup):
   ```bash
   termux-setup-storage
   pkg install python -y
   ```
2. Navigate to where you extracted the tool:
   ```bash
   cd ~/storage/downloads/Universal-Vault-v5.5.1-Android
   # (or: cd /storage/emulated/0/Download/Universal-Vault-v5.5.1-Android)
   ```
3. Lock, Unlock, or Check Status of any file or folder on your device:
   ```bash
   # Lock a specific file or folder in your phone storage:
   python tools/vault.py lock /storage/emulated/0/Download/secret_file.pdf
   python tools/vault.py lock /storage/emulated/0/DCIM/Camera

   # Unlock:
   python tools/vault.py unlock /storage/emulated/0/Download/secret_file.pdf

   # Check Status:
   python tools/vault.py status /storage/emulated/0/Download/secret_file.pdf

   # Or lock everything in the current vault folder:
   python tools/vault.py lock .
   python tools/vault.py unlock .
   ```

---

## 🧯 Crash Recovery
* If Termux or browser closes midway:
  * Running **`lock`** resumes encryption to completion.
  * Running **`unlock`** rolls back a partial lock to 100% original plaintext.

---
**Author**: [Adil Arbaz Khan](https://github.com/Adil-Arbaz-Khan) | **License**: MIT
"""

README_IOS = """# 🛡️ Universal Vault v5.5.1 (iOS Edition: iPhone & iPad)

**Enterprise-Grade In-Place Authenticated Encryption Suite (AEAD)**  
*100% Standalone Offline Web App • Zero Disk Traces • Volatile RAM Streamer • Real-Time Progress Bar*

---

## 🚀 Simple Step-by-Step Instructions for iPhone & iPad

### 1. Open Offline App in Safari
1. Transfer or save **`Vault_App.html`** to your **Files** app on your iPhone or iPad.
2. Tap **`Vault_App.html`** to open it in **Safari**.
3. *Recommended*: Tap the **Share** button $\\to$ **"Add to Home Screen"**. This installs Universal Vault as a full-screen, standalone offline app on your home screen!

---

### 2. How to Encrypt & Decrypt on iOS
1. Open **Universal Vault** on your iPhone/iPad.
2. Tap **Browse / Select File** and select any document, photo, or video from your **Files** app or iCloud Drive.
3. Enter your master password:
   * Tap **Lock** to encrypt the file with AES-256-CTR + HMAC-SHA256 (600,000 PBKDF2 rounds) with live progress.
   * Tap **Unlock** to restore the file.
   * Tap **Stream / Preview** to watch encrypted videos or view PDFs **purely in RAM** with zero temp file storage leaks!

---

### 3. Security Highlights
* **100% Client-Side**: No internet connection required. All cryptography runs locally inside Safari's native WebCrypto engine.
* **RAM Auto-Wipe**: Ephemeral keys and memory buffers are automatically wiped after 3 minutes of inactivity.

---
**Author**: [Adil Arbaz Khan](https://github.com/Adil-Arbaz-Khan) | **License**: MIT
"""

SECURITY_IOS = """# Security Policy & Cryptographic Threat Model (iOS Edition)

## 🛡️ Architecture Overview: Standalone WebCrypto Appliance

On **iOS (iPhone & iPad)**, Universal Vault operates exclusively through the standalone client-side Progressive Web App (`Vault_App.html`). Due to Apple's strict operating system sandboxing, iOS does not provide native command-line shell access, background script daemons, or direct arbitrary filesystem block manipulation.

Instead, Universal Vault delivers **zero-disk-footprint, volatile RAM security** powered natively by the W3C Web Cryptography API (`crypto.subtle`) inside Safari's isolated WebKit engine.

---

## 🔒 Cryptographic Specifications (`Vault_App.html`)

Universal Vault on iOS adheres to the exact same enterprise-grade cryptographic standards as the desktop suite:

### 1. Symmetric Cipher
* **Algorithm**: `AES-256-CTR` (NIST SP 800-38A) executed via `crypto.subtle.encrypt` / `crypto.subtle.decrypt`.
* **Full-Payload Coverage**: 100% of the file data is transformed; no unencrypted plaintext headers or carvable payloads remain.
* **Nonce / Counter**: 16 bytes of cryptographically secure pseudo-random entropy generated per file via `crypto.getRandomValues()`.

### 2. Authenticity & Anti-Tampering (Integrity)
* **Master MAC**: `HMAC-SHA256` computed over the entire ciphertext payload (Encrypt-then-MAC / EtM architecture).
* **Malleability Immunity**: The engine enforces constant-time validation of the 16-byte `AuthTag` and full `MasterMAC` before releasing or rendering decrypted content. Any bit-flipping or payload tampering causes immediate rejection.

### 3. Key Derivation & Master Key Splitting
* **Algorithm**: `PBKDF2-HMAC-SHA256` (NIST SP 800-132).
* **Iterations**: **600,000 rounds** (OWASP 2026 Gold Standard) with a unique 16-byte random salt per file.
* **512-Bit Key Separation**:
  * 256-bit Encryption Key (`encKeyBytes`) $\\to$ AES-256-CTR
  * 256-bit Integrity Key (`macKeyBytes`) $\\to$ HMAC-SHA256

---

## 🧠 Volatile RAM Security & Zero Disk Traces

The primary security advantage of the iOS architecture is the **complete elimination of unencrypted temporary disk traces**:

1. **Zero Temporary Disk Files**:
   * Decrypted media (4K video, audio, PDFs, photos, and documents) is loaded directly into volatile browser RAM via ephemeral in-memory Blobs (`URL.createObjectURL`).
   * Plaintext data is never written to iPhone/iPad flash storage during streaming or previewing.
2. **Explicit Memory Zeroing**:
   * Raw typed arrays holding cryptographic keys (`encKeyBytes`, `macKeyBytes`) are explicitly overwritten with zeroes via `.fill(0)` immediately upon completion of cryptographic routines.
3. **Automated 3-Minute RAM Purge**:
   * An active session timer automatically revokes in-memory object URLs and clears buffers after 3 minutes of inactivity.
   * An instant **"Wipe RAM"** panic button allows immediate, one-tap memory purging.
4. **Offline Isolation & Content Security Policy (CSP)**:
   * `Vault_App.html` enforces a strict CSP (`default-src 'none'`). It operates 100% offline with zero external network calls, zero analytics, zero CDNs, and zero third-party dependencies.

---

## 🔍 iOS Operational Scope & Platform Boundaries

1. **Sandboxed File Handling**:
   * Because iOS prohibits background filesystem hooks, encrypted files are processed in memory and saved back to the **Files** app or iCloud Drive via standard iOS browser downloads or the iOS Share Sheet.
2. **Session-Based Rate Limiting**:
   * `Vault_App.html` implements progressive exponential rate limiting (3s $\\to$ 10s $\\to$ 60s cooldowns) on failed password attempts within the active browser session. Offline brute-force resistance against exported files is enforced by the **600,000 PBKDF2 iterations**.
3. **Interruption Behavior**:
   * Since processing occurs in memory before exporting, closing the Safari tab midway simply cancels the in-flight operation with zero partial file corruption on disk.

---

## 🛑 Reporting a Vulnerability

If you discover a potential cryptographic vulnerability, please send a disclosure report to:
* **Maintainer**: Adil Arbaz Khan
* **GitHub Profile**: [@Adil-Arbaz-Khan](https://github.com/Adil-Arbaz-Khan)
* **License**: [MIT License](LICENSE)
"""

# -------------------------------------------------------------
# Helper to write files into zip
# -------------------------------------------------------------

def make_zip(zip_name, file_map, custom_readme_content=None, custom_security_content=None):
    zip_path = os.path.join(OUT_DIR, zip_name)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for src_path, arc_name in file_map:
            if os.path.isfile(src_path):
                z.write(src_path, arc_name)
        if custom_readme_content:
            z.writestr("README.md", custom_readme_content)
        if custom_security_content:
            z.writestr("SECURITY.md", custom_security_content)
    size_mb = os.path.getsize(zip_path) / (1024 * 1024)
    print(f"Created: {zip_name} ({size_mb:.2f} MB)")

# 1. Windows ZIP
make_zip(
    "Universal-Vault-v5.5.1-Windows.zip",
    [
        (os.path.join(ROOT_DIR, "Lock.bat"), "Lock.bat"),
        (os.path.join(ROOT_DIR, "Unlock.bat"), "Unlock.bat"),
        (os.path.join(ROOT_DIR, "Status.bat"), "Status.bat"),
        (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
        (os.path.join(ROOT_DIR, "tools", "header_vault.ps1"), "tools/header_vault.ps1"),
        (os.path.join(ROOT_DIR, "tools", "vault.py"), "tools/vault.py"),
        (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
        (os.path.join(ROOT_DIR, "SECURITY.md"), "SECURITY.md"),
    ],
    custom_readme_content=README_WINDOWS
)

# 2. Linux ZIP
make_zip(
    "Universal-Vault-v5.5.1-Linux.zip",
    [
        (os.path.join(ROOT_DIR, "lock.sh"), "lock.sh"),
        (os.path.join(ROOT_DIR, "unlock.sh"), "unlock.sh"),
        (os.path.join(ROOT_DIR, "status.sh"), "status.sh"),
        (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
        (os.path.join(ROOT_DIR, "tools", "vault.py"), "tools/vault.py"),
        (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
        (os.path.join(ROOT_DIR, "SECURITY.md"), "SECURITY.md"),
    ],
    custom_readme_content=README_LINUX
)

# 3. macOS ZIP
make_zip(
    "Universal-Vault-v5.5.1-macOS.zip",
    [
        (os.path.join(ROOT_DIR, "lock.sh"), "lock.sh"),
        (os.path.join(ROOT_DIR, "unlock.sh"), "unlock.sh"),
        (os.path.join(ROOT_DIR, "status.sh"), "status.sh"),
        (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
        (os.path.join(ROOT_DIR, "tools", "vault.py"), "tools/vault.py"),
        (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
        (os.path.join(ROOT_DIR, "SECURITY.md"), "SECURITY.md"),
    ],
    custom_readme_content=README_MACOS
)

# 4. Android ZIP
make_zip(
    "Universal-Vault-v5.5.1-Android.zip",
    [
        (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
        (os.path.join(ROOT_DIR, "lock.sh"), "lock.sh"),
        (os.path.join(ROOT_DIR, "unlock.sh"), "unlock.sh"),
        (os.path.join(ROOT_DIR, "status.sh"), "status.sh"),
        (os.path.join(ROOT_DIR, "tools", "vault.py"), "tools/vault.py"),
        (os.path.join(ROOT_DIR, "tools", "setup_termux.sh"), "tools/setup_termux.sh"),
        (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
        (os.path.join(ROOT_DIR, "SECURITY.md"), "SECURITY.md"),
    ],
    custom_readme_content=README_ANDROID
)

# 5. iOS ZIP
make_zip(
    "Universal-Vault-v5.5.1-iOS.zip",
    [
        (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
        (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
    ],
    custom_readme_content=README_IOS,
    custom_security_content=SECURITY_IOS
)

# 6. Universal Multi-Platform ZIP (Full Package)
universal_files = [
    (os.path.join(ROOT_DIR, "Lock.bat"), "Lock.bat"),
    (os.path.join(ROOT_DIR, "Unlock.bat"), "Unlock.bat"),
    (os.path.join(ROOT_DIR, "Status.bat"), "Status.bat"),
    (os.path.join(ROOT_DIR, "lock.sh"), "lock.sh"),
    (os.path.join(ROOT_DIR, "unlock.sh"), "unlock.sh"),
    (os.path.join(ROOT_DIR, "status.sh"), "status.sh"),
    (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
    (os.path.join(ROOT_DIR, "README.md"), "README.md"),
    (os.path.join(ROOT_DIR, "SECURITY.md"), "SECURITY.md"),
    (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
    (os.path.join(ROOT_DIR, "CONTRIBUTING.md"), "CONTRIBUTING.md"),
    (os.path.join(ROOT_DIR, "tools", "vault.py"), "tools/vault.py"),
    (os.path.join(ROOT_DIR, "tools", "header_vault.ps1"), "tools/header_vault.ps1"),
    (os.path.join(ROOT_DIR, "tools", "setup_termux.sh"), "tools/setup_termux.sh"),
]

# Include Test Samples in Universal package
test_dir = os.path.join(ROOT_DIR, "Test_Samples")
if os.path.exists(test_dir):
    for root, dirs, files in os.walk(test_dir):
        for f in files:
            full_p = os.path.join(root, f)
            rel_p = os.path.relpath(full_p, ROOT_DIR)
            universal_files.append((full_p, rel_p))

make_zip("Universal-Vault-v5.5.1-Universal.zip", universal_files)

print("\nALL 6 PACKAGES CREATED SUCCESSFULLY IN:", OUT_DIR)

<div align="center">

<img src="assets/logo.png" alt="Universal Vault Logo" width="160" style="border-radius: 28px; box-shadow: 0 10px 30px rgba(0,0,0,0.6);" />

# 🛡️ Universal Vault V5.5.21

**Lightweight Sovereign Authenticated Encryption Suite (AEAD)**  
*Ultra-Lightweight (<3 MB) • Global Terminal-First CLI • 100% In-Place Streaming • Portable by Design*

[![Website: universal-vault.pages.dev](https://img.shields.io/badge/Website-universal--vault.pages.dev-0070f3.svg?style=for-the-badge)](https://universal-vault.pages.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![Security: AES-256-CTR + HMAC-SHA256](https://img.shields.io/badge/Security-AES--256--CTR%20%2B%20HMAC--SHA256-10b981.svg?style=for-the-badge)](SECURITY.md)
[![KDF: OWASP 600k](https://img.shields.io/badge/KDF-PBKDF2--600k%20Iters%20(OWASP)-38bdf8.svg?style=for-the-badge)](SECURITY.md)
[![Platforms: Windows | Linux | macOS | Android | iOS](https://img.shields.io/badge/Platforms-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Android%20%7C%20iOS-818cf8.svg?style=for-the-badge)](#-installation--setup-primary)
[![Author](https://img.shields.io/badge/Author-Adil%20Arbaz%20Khan-f43f5e.svg?style=for-the-badge)](https://github.com/Adil-Arbaz-Khan)

> **Official Website & Live WebApp:** [https://universal-vault.pages.dev/](https://universal-vault.pages.dev/)  
> **The Universal Vault Motto:**  
> **Featherweight footprint. High-performance terminal CLI as primary. 100% portable when you need it.**

</div>

---

## 🌟 Overview

**Universal Vault** is a lightweight, sovereign encryption suite engineered for fast, authenticated protection of files and directories across **Windows**, **Linux**, and **macOS**.

Built to eliminate the bloated containers, slow archives, and heavy background daemons of traditional encryption tools:
* 🪶 **Featherweight**: Statically compiled native binary under **3 MB** with **zero runtime dependencies** (no Python, no Node, no C++ runtime, no administrator privileges required).
* 🖥️ **Global CLI First**: Install with a single click or script $\to$ use `vault lock` / `vault unlock` / `vault status` from any terminal in any directory.
* 📦 **100% Portable Alternative**: Don't want to install? Run the standalone binary directly from a USB stick, launch the portable 1-click batch/shell scripts, or open the single-file offline WebApp (`Vault_App.html`).
* ⚡ **True In-Place Transformation (0% Storage Overhead)**: Encrypt a 20 GB database on a disk with only 5 MB of remaining space. No temporary container files, no temp folder disk leaks.
* 🔒 **Anti-Tamper AEAD (Encrypt-then-MAC)**: Employs master **HMAC-SHA256** authentication over the entire ciphertext payload. Any bit-flipping is detected and rejected before releasing plaintext.
* 🧯 **Crash-Safe Checkpointing**: Interrupted mid-operation by a power cut, dead laptop battery, or disconnected drive? Vault's 104-byte resumable footer tracks progress on disk so you can resume forward or roll back to your original file with zero data loss.
* 📊 **Multi-Phase Live Progress Bar**: Clear real-time visibility showing current phase (`Key Deriv`, `Verifying`, `Decrypting`, `Encrypting`), processed megabytes, live transfer speed, and accurate countdown ETA.

```
                    TARGET FILE OR RECURSIVE FOLDER
                                   │
                                   ▼
                   [ 100% IN-PLACE STREAMING AEAD ]
               Every byte transformed in-place on disk
                 Zero temporary disk copies created
                                   │
                  ┌────────────────┴────────────────┐
                  ▼                                 ▼
        [ AES-256-CTR Stream ]           [ Master HMAC-SHA256 ]
       Confidentiality (0% bloat)        Integrity (Anti-Tamper)
```

---

## 🚀 Installation & Setup (Primary / Recommended)

Universal Vault installs in seconds to your user environment with **no admin/root privileges required** and zero background services.

### 1. Windows (1-Click Installer)
1. Download or extract the repository.
2. Open [`installers/windows/`](installers/windows/) and double-click **`install.bat`**.
3. Open a **new** Command Prompt, PowerShell, or Windows Terminal window:
   ```cmd
   vault version
   ```

### 2. Linux (One-Liner)
```bash
cd installers/linux
chmod +x install.sh
./install.sh
```
*(Or `sudo ./install.sh` for system-wide installation to `/usr/local/bin`)*

### 3. macOS (Apple Silicon & Intel)
```bash
cd installers/macos
chmod +x install.sh
./install.sh
```
*(Automatically detects native Apple Silicon M1/M2/M3/M4 or Intel, clears Gatekeeper quarantine flags, and registers `~/.local/bin` in `~/.zprofile` and `~/.zshrc`)*
### 4. Android (Native App & Complete Suite)
* **Option A: Standalone APK (Recommended)**:
  1. Download **`UniversalVault-v5.5.21.apk`** from [Releases](https://github.com/Adil-Arbaz-Khan/Universal-Vault/releases/tag/v5.5.21) or [universal-vault.pages.dev](https://universal-vault.pages.dev/).
  2. Tap to install on your device (Android 8.0+ / API 26+ up to Android 15+).
  3. Enjoy 100% in-place SAF streaming, hardware write barriers (`Os.fsync`), crash-safe resumption, real-time password strength meter, and custom cybernetic dark obsidian theme.
* **Option B: Merged Android Bundle**:
  * Download **`Universal-Vault-v5.5.21-Android.zip`** for a complete all-in-one archive containing the native APK, the portable offline web viewer (`Vault_App.html`), and Termux CLI scripts (`setup_termux.sh`, `lock.sh`, `unlock.sh`).

---

## 🧳 Portable Edition (Zero-Install Alternative)

If you prefer a zero-footprint workflow without adding anything to your system PATH:

* **Portable CLI Binaries**: Drop `vault.exe` (Windows), `vault_linux_amd64` (Linux), or `vault_darwin_arm64` (macOS) onto a USB drive and run directly:
  ```bash
  ./vault lock /path/to/my_data
  ./vault unlock /path/to/my_data
  ```
* **Portable 1-Click Launchers (Windows)**:
  * Double-click **`Lock.bat`** to encrypt files/folders in-place.
  * Double-click **`Unlock.bat`** to decrypt and verify integrity.
  * Double-click **`Status.bat`** to inspect the lock state of your files.
* **Portable Shell Scripts (Linux & macOS)**:
  ```bash
  ./lock.sh /path/to/files
  ./unlock.sh /path/to/files
  ./status.sh /path/to/files
  ```
* **Offline Browser App (`Vault_App.html`)**:
  * Double-click **`Vault_App.html`** in any modern web browser (Chrome, Brave, Safari, Edge, Firefox) on desktop or mobile.
  * Also accessible online at [https://universal-vault.pages.dev/app/](https://universal-vault.pages.dev/app/).
  * Encrypt, decrypt, or stream 4K videos/audio **directly in volatile RAM** with zero disk writes.

---

## 🌐 Air-Gapped Web Application Architecture (How `Vault_App.html` Works)

Universal Vault features a standalone, fully self-contained single-file Web Application — **`Vault_App.html`** (hosted live at [https://universal-vault.pages.dev/app/](https://universal-vault.pages.dev/app/)).

Designed for environments where software installation is restricted or zero-trace operations are mandatory, it brings the cryptographic power of the native CLI to any browser:

### 1. 100% Client-Side WebCrypto Engine (Zero Server Interactions)
* Operates strictly within the client browser using the W3C **Web Cryptography API** (`window.crypto.subtle`).
* **Zero Server Dependency**: No passwords, keys, or file bytes are ever uploaded to any server or cloud API. All operations execute locally inside your browser's execution thread.
* **Air-Gapped & Offline Ready**: Save the HTML file to a USB drive and open it on an air-gapped machine with no internet connection — it works completely offline without degrading functionality.

### 2. Strict Content Security Policy (Zero Data Exfiltration)
* Hardened with a zero-trust Content Security Policy (CSP):
  ```http
  default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data: blob:; media-src blob:; frame-src blob:; object-src blob:;
  ```
* Bards any external HTTP/HTTPS network calls, web sockets, beacons, or third-party analytics. Zero telemetry, zero CDNs, zero tracking. All styling, SVG icons, and scripts are 100% embedded in a single file.

### 3. Bit-for-Bit Format Parity with Native CLI (`VAULTV05`)
* **Key Derivation (KDF)**: Derives 512 bits using `PBKDF2-HMAC-SHA256` with **600,000 iterations** (OWASP 2026 Recommended Work Factor) and unique 16-byte random salts.
* **Key Separation**: Splits derived bits into a 32-byte `EncKey` (AES) and a 32-byte `MacKey` (HMAC).
* **Pre-Flight Authentication**: Computes and validates a 16-byte `AuthTag` in constant time before proceeding with heavy payload decoding.
* **Encrypt-then-MAC (EtM)**: Verifies the full-file 32-byte `MasterMAC` (HMAC-SHA256) over 100% of the ciphertext before emitting any decrypted data.
* **Symmetric Cipher**: In-memory chunked streaming (4 MB RAM chunks) using `AES-256-CTR` preserving exact byte lengths (0% storage overhead).

### 4. Volatile RAM Streaming Player (Zero Disk Forensics)
* **Ephemeral In-Memory Playback**: Decrypted videos (including 4K MP4/WebM), audio files (MP3/WAV/FLAC), PDFs, high-resolution images, and text notes are converted into memory-resident `Blob` objects.
* **No Temporary Disk Footprint**: Bypasses the filesystem entirely using transient in-memory Object URLs (`URL.createObjectURL(blob)`). No unencrypted fragments ever touch the operating system's temporary directory or swap disk.
* **Explicit Memory Sanitization**: Derived keys and working typed arrays are actively zeroized in memory via `.fill(0)`. A dedicated **"Wipe RAM"** button allows users to immediately purge memory buffers and revoke Object URLs.

### 5. Real-Time Shannon Password Entropy Meter
* Evaluates password strength dynamically as the user types using mathematical Shannon entropy based on charset pool size ($N$) and password length ($L$): $E = L \log_2(N)$.
* Instant visual feedback:
  * 🔴 **Weak** (<40 bits) — Red indicator
  * 🟡 **Moderate** (40–60 bits) — Amber indicator
  * 🔵 **Strong** (60–80 bits) — Blue indicator
  * 🟢 **High-Assurance** (80+ bits) — Emerald indicator

### 6. Modern Cybernetic UI, Themes & Mobile Optimization
* **Dark / Light Mode**: Cybernetic dark obsidian (`#06090f`) and clean light mode (`#fafafa`), with toggle persisted to `localStorage` and synchronized with OS preferences.
* **Responsive Mobile Experience**: Dedicated mobile touch targets, optimized keyboard handling, and responsive compact footer tailored for smartphone screens.

---

## 💻 CLI Command Reference

Once installed, the `vault` command is globally available across all terminals.

### 1. `vault lock` — Encrypt Files & Folders
Transforms targets into 100% Full-File Authenticated AEAD Ciphertext in-place.

```bash
# Interactive prompt (Silent masked password typing -- zero shoulder surfing):
vault lock "Confidential.pdf"

# Lock an entire directory recursively:
vault lock "/data/projects/secret_repo"

# Lock current directory:
vault lock .

# Inline password (for automated scripts / CI):
vault lock "backup.tar" -p "MyMasterPassword123"
```

### 2. `vault unlock` — Decrypt & Verify Files
Verifies master HMAC authenticity and restores files back to their exact original plaintext in-place.

```bash
# Unlock a single file or directory:
vault unlock "Confidential.pdf"
vault unlock "/data/projects/secret_repo"

# Inline password:
vault unlock "backup.tar" -p "MyMasterPassword123"
```

### 3. `vault status` — Inspect Lock State
Scans files without modifying them to inspect encryption state:

```bash
vault status .
```

*Example Output:*
```text
======================================================================
  Universal Vault v5.5.21 (CLI Native): STATUS Operation
  Target Scope   : /data/projects
  Files Located  : 3
======================================================================
  [LOCKED]   Financial_Report.xlsx (locked (V5 Authenticated AEAD (100% Full-File)))
  [LOCKED]   Backup_Archive.zip (locked (V5 Authenticated AEAD (100% Full-File)))
  [UNLOCKED] Notes.txt
----------------------------------------------------------------------
Status Summary: 2 Locked | 1 Unlocked
```

### 4. `vault version`
Displays active CLI version and target architecture:
```bash
vault version
```

---

## 📊 Feature Comparison Matrix

| Feature | **Universal Vault CLI** | **BitLocker** (Win Pro) | **VeraCrypt** | **7-Zip / WinRAR** |
| :--- | :--- | :--- | :--- | :--- |
| **Footprint / Binary Size** | 🟢 **< 3 MB (Zero Dependencies)** | 🟢 Built-in | 🔴 Heavy Drivers (>50 MB) | 🟡 App Install (~15 MB) |
| **Installation Model** | 🟢 **1-Click Global CLI + Portable** | 🟢 Built-in | 🔴 Kernel Driver Install | 🟡 Desktop App |
| **In-Place Transformation** | 🟢 **Instant (0% Extra Storage)** | 🔴 Whole Drive Only | 🔴 Fixed Container File | 🔴 Creates Duplicates |
| **Temp File Disk Leaks** | 🛡️ **Zero Disk Leaks (RAM Streaming)** | 🛡️ None | 🛡️ None | ⚠️ **Severe (`AppData\Temp`)** |
| **Integrity / Anti-Tamper** | 🛡️ **Master HMAC-SHA256 (EtM)** | 🛡️ BitLocker MAC | 🛡️ XTS Authenticity | ⚠️ CRC32 / Partial |
| **Crash-Safe Resumability** | 🛡️ **Built-in Checkpoints** | 🛡️ Journaled | 🛡️ Journaled | ❌ Re-extract from scratch |
| **Symlink Traversal Guard** | 🛡️ **Pre-Order Pruning** | N/A | N/A | ⚠️ Client Dependent |
| **KDF Work Factor** | 🛡️ **600,000 PBKDF2-SHA256 (OWASP)** | 🛡️ TPM / PIN | 🛡️ Multiplier | 🔴 None / Low |

---

## 🧯 Crash Recovery Guide

If your computer shut down, laptop battery died, terminal was killed, or external drive was unplugged mid-operation: **Your data is safe and deterministic.**

Universal Vault maintains a 104-byte resumable footer with hardware write barriers (`FlushFileBuffers` / `fsync`):

* **If interrupted while LOCKING**:
  * **To finish encryption**: Run `vault lock <path>` $\to$ Resumes encrypting forward from the exact byte where it was stopped.
  * **To cancel and recover original file**: Run `vault unlock <path>` $\to$ Rolls back the partially locked portion and restores your **100% original unencrypted file**.
* **If interrupted while UNLOCKING**:
  * Run `vault unlock <path>` $\to$ Automatically resumes decrypting forward from the last safe checkpoint.
* **To check progress**:
  * Run `vault status <path>` $\to$ Reports interrupted state and exact byte offset.

---

## 🗑️ Clean Uninstallation

If you ever wish to remove Universal Vault CLI from your machine:
* **Windows**: Run [`installers/windows/uninstall.bat`](installers/windows/uninstall.bat) $\to$ Cleans `%LocalAppData%\UniversalVault` and removes PATH entry.
* **Linux**: Run `installers/linux/uninstall.sh` (or `sudo ./uninstall.sh`).
* **macOS**: Run `installers/macos/uninstall.sh` (or `sudo ./uninstall.sh`).

Leaves zero background services, zero registry clutter, and zero hidden files.

---

## 🔒 Official Cryptographic Checksums (SHA-256)

Verify binary integrity against published provenance hashes:

| Platform | Binary / Asset | SHA-256 Checksum |
| :--- | :--- | :--- |
| **Windows x86_64** | `vault.exe` | `b4ce2d3da7f6834d96bb8a3ea35389ccc8cd8b4bc0afdf515cb51b1230c00801` |
| **Linux x86_64** | `vault_linux_amd64` | `b5831310c678003df21a71701dfeb5c2f125c1fd0f160c4c3da28cfb5efa218f` |
| **Linux ARM64** | `vault_linux_arm64` | `d9edca2c9fa7ad31c9e72da24c4e9ffc3eb6672a8f932167ab44809bcb2a8321` |
| **macOS Apple Silicon** | `vault_darwin_arm64` | `3fd7358e6b6dd80087e2325f102bbdf902c30d11f10c6ff8f77b5f6d38e8ce80` |
| **macOS Intel** | `vault_darwin_amd64` | `a2923a5069ec3eebc439d87e4cc056f82f13400cc2cd8f3a44b74cd64456d84c` |
| **Android Native APK** | `UniversalVault-v5.5.21.apk` | `a491cfb5208668351562afdcd0493e991f03c3fa1ecbdaeafc8ffdcd68d26ff9` |

*Full verification guide and release history: [RELEASE_NOTES_v5.5.21.md](RELEASE_NOTES_v5.5.21.md)*

---

## 👤 Author

**Adil Arbaz Khan**  
GitHub: [@Adil-Arbaz-Khan](https://github.com/Adil-Arbaz-Khan)

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

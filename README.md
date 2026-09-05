<div align="center">

# 🛡️ Universal Vault V5.5.1

**Lightweight Sovereign Authenticated Encryption Suite (AEAD)**  
*Ultra-Lightweight (<3 MB) • Global Terminal-First CLI • 100% In-Place Streaming • Portable by Design*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![Security: AES-256-CTR + HMAC-SHA256](https://img.shields.io/badge/Security-AES--256--CTR%20%2B%20HMAC--SHA256-10b981.svg?style=for-the-badge)](SECURITY.md)
[![KDF: OWASP 600k](https://img.shields.io/badge/KDF-PBKDF2--600k%20Iters%20(OWASP)-38bdf8.svg?style=for-the-badge)](SECURITY.md)
[![Platforms: Windows | Linux | macOS](https://img.shields.io/badge/Platforms-Windows%20%7C%20Linux%20%7C%20macOS-818cf8.svg?style=for-the-badge)](#-installation--setup-primary)
[![Author](https://img.shields.io/badge/Author-Adil%20Arbaz%20Khan-f43f5e.svg?style=for-the-badge)](https://github.com/Adil-Arbaz-Khan)

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
  * Double-click **`Vault_App.html`** in any browser (Chrome, Brave, Safari, Edge, Firefox) on desktop or mobile.
  * Encrypt, decrypt, or stream 4K videos/audio **directly in volatile RAM** with zero disk writes.

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
  Universal Vault v5.5.1 (CLI Native): STATUS Operation
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

| Platform | Binary | SHA-256 Checksum |
| :--- | :--- | :--- |
| **Windows x86_64** | `vault.exe` | `dd55fb4af68e8ffed0c634416153cd67c9629691e3e4a08430cfe4ec0d755fa3` |
| **Linux x86_64** | `vault_linux_amd64` | `999e93e8e98d51c7d80131e2abea80bc0d82193c336769f262c309528fa19f38` |
| **Linux ARM64** | `vault_linux_arm64` | `a57dcf73e4afa19c9879d003527b042045687fecb9627e635af0a2e798686eb9` |
| **macOS Apple Silicon** | `vault_darwin_arm64` | `498a12064c7823e4f9b067633a9e1aaa0148b619711af38e50ab29a4dd921eb1` |
| **macOS Intel** | `vault_darwin_amd64` | `528466b7ef448d2f8e9907ff68c6d62fbca391bfeba4f5c7aca9cf6512549846` |

*Full verification guide and release history: [RELEASE_NOTES_v5.5.1_CLI.md](RELEASE_NOTES_v5.5.1_CLI.md)*

---

## 👤 Author

**Adil Arbaz Khan**  
GitHub: [@Adil-Arbaz-Khan](https://github.com/Adil-Arbaz-Khan)

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

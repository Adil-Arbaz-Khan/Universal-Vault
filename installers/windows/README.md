# 🛡️ Universal Vault CLI (Windows Edition)

**Enterprise-Grade In-Place Authenticated Encryption Suite (AEAD)**  
*Terminal-First Native CLI • Zero-Install Footprint • 100% In-Place Streaming • Crash-Safe Checkpointed*

---

## 📖 Table of Contents
1. [System Requirements](#-system-requirements)
2. [Quick Installation](#-1-click-installation)
3. [Command Reference & Usage](#-command-reference--usage)
   * [`vault lock`](#1-vault-lock---encrypt-filesfolders)
   * [`vault unlock`](#2-vault-unlock---decrypt-filesfolders)
   * [`vault status`](#3-vault-status---inspect-encryption-state)
   * [`vault version`](#4-vault-version)
4. [Crash Recovery (What to Do If Interrupted)](#-crash-recovery-guide)
5. [Uninstallation](#-clean-uninstallation)
6. [Security & Verification](#-security--verification)

---

## 💻 System Requirements

Universal Vault CLI is a lightweight, self-contained native Windows binary with **zero external software dependencies**:

* **Operating System**: Windows 11, Windows 10, Windows 8.1, or Windows Server 2012+ (64-bit x86_64).
* **Dependencies**: **None** (No Python, No .NET SDK, No Java, No Visual C++ Redistributable, No external DLLs required).
* **Privileges**: Standard User Account (Administrator rights / UAC elevation **not** required).
* **Storage Footprint**: Less than **3 MB** of total disk space.
* **Supported Shells**: Windows Terminal, Command Prompt (`cmd.exe`), PowerShell (5.1 & Core 7+), Git Bash, MSYS2, Cmder.

---

## 🚀 1-Click Installation

Universal Vault CLI installs as a standalone global terminal command usable from any directory in Command Prompt (`cmd.exe`), PowerShell, or Windows Terminal without requiring administrator privileges or manual PATH configuration.

### How to Install:
1. Double-click **`install.bat`**.
2. The installer will automatically:
   * Verify the cryptographic SHA-256 integrity of `vault.exe`.
   * Copy `vault.exe` to `%LocalAppData%\UniversalVault\bin\`.
   * Register the folder in your persistent User `PATH`.
3. Open a **new** Command Prompt or PowerShell window and verify:
   ```cmd
   vault version
   ```
   *Output:*
   ```text
   Universal Vault CLI v5.5.1 (Go Native Architecture)
   ```

---

## 💻 Command Reference & Usage

The `vault` command can be executed from **any directory** on your system against single files or entire directory trees.

### 1. `vault lock` — Encrypt Files/Folders
Transforms target files into 100% Full-File Authenticated AEAD Ciphertext in-place with 0% extra storage overhead.

* **Interactive Password Prompt (Recommended)**:
  ```cmd
  vault lock "C:\Users\YourName\Documents\Confidential.pdf"
  ```
  *You will be prompted to enter your master password securely.*

* **Lock an Entire Directory (Recursive)**:
  ```cmd
  vault lock "D:\Projects\SecretProject"
  ```

* **Lock Current Folder**:
  ```cmd
  vault lock .
  ```

* **Inline Password (Optional / Scripting)**:
  ```cmd
  vault lock "D:\Data" -p "MyStrongMasterPassword123"
  ```

---

### 2. `vault unlock` — Decrypt Files/Folders
Verifies HMAC-SHA256 authenticity and restores files back to their exact original plaintext in-place.

* **Unlock a File or Directory**:
  ```cmd
  vault unlock "C:\Users\YourName\Documents\Confidential.pdf"
  ```

* **Unlock Entire Directory**:
  ```cmd
  vault unlock "D:\Projects\SecretProject"
  ```

* **Unlock with Inline Password**:
  ```cmd
  vault unlock "D:\Data" -p "MyStrongMasterPassword123"
  ```

---

### 3. `vault status` — Inspect Encryption State
Scans files and displays whether they are unlocked, locked with V5 AEAD armor, locked with legacy formats, or interrupted mid-operation.

```cmd
vault status "D:\Projects\SecretProject"
```

*Example Output:*
```text
======================================================================
  Universal Vault v5.5.1 (CLI Native): STATUS Operation
  Target Scope   : D:\Projects\SecretProject
  Files Located  : 3
======================================================================
  [LOCKED]   Financials.xlsx (locked (V5 Authenticated AEAD (100% Full-File)))
  [LOCKED]   Design_Draft.psd (locked (V5 Authenticated AEAD (100% Full-File)))
  [UNLOCKED] Notes.txt
----------------------------------------------------------------------
Status Summary: 2 Locked | 1 Unlocked
```

---

### 4. `vault version`
Displays the active CLI version and architecture.
```cmd
vault version
```

---

## 🧯 Crash Recovery Guide

Did your PC lose power, laptop battery die, terminal window close, or USB flash drive get unplugged midway through locking or unlocking? **Your data is safe and deterministic.**

Universal Vault uses a 104-byte resumable binary footer that tracks physical byte checkpoints on disk:

* **If interrupted while LOCKING**:
  * **To complete encryption**: Run `vault lock <path>` $\to$ Vault reads the checkpoint and resumes encrypting forward from the exact byte where it stopped.
  * **To cancel and recover your original file**: Run `vault unlock <path>` $\to$ Vault detects the partially locked region, rolls back the ciphertext blocks back to plaintext, and restores your **100% original unencrypted file**.
* **If interrupted while UNLOCKING**:
  * Run `vault unlock <path>` $\to$ Vault automatically resumes decrypting forward from the last saved safe checkpoint.
* **To check progress of interrupted files**:
  * Run `vault status <path>` $\to$ Displays: `locked (V5 RESUMABLE LOCK INTERRUPTED at 250.00 MB)`.

---

## 🗑️ Clean Uninstallation

If you ever wish to remove Universal Vault CLI from your system:

1. Double-click **`uninstall.bat`**.
2. The uninstaller will:
   * Delete `%LocalAppData%\UniversalVault\bin\vault.exe`.
   * Cleanly remove the directory from your persistent User `PATH`.
   * Leave zero background services, zero registry leftovers, and zero junk on your system.

---

## 🔒 Security, Integrity & Checksum Verification

### 1. Cryptographic Provenance (Verify Binary Hash)
To guarantee your `vault.exe` binary has not been tampered with in transit, verify its SHA-256 hash before running:
```powershell
Get-FileHash .\vault.exe -Algorithm SHA256
```
Compare the output with the official checksum published in the GitHub Release notes.

### 2. Silent Terminal Password Masking
When prompted for a master password during interactive `vault lock` or `vault unlock`, the terminal disables console echo (`ENABLE_ECHO_INPUT` turned off). No characters, asterisks, or cursor movements are shown on screen, protecting against shoulder-surfing and screen recording leaks.

### 3. Cryptographic Suite Summary
* **Cipher**: AES-256-CTR (NIST SP 800-38A).
* **Integrity**: Encrypt-then-MAC (HMAC-SHA256) master payload authentication.
* **Work Factor**: 600,000 PBKDF2-HMAC-SHA256 rounds (OWASP 2026 Gold Standard).
* **Symlink Traversal**: Pre-order directory junction and symlink pruning prevents directory escaping attacks.
* **Flash Storage Safe**: Enforces hardware write flushes (`fsync` / Win32 `FlushFileBuffers`) before advancing progress pointers.

---
**Author**: [Adil Arbaz Khan](https://github.com/Adil-Arbaz-Khan)  
**License**: [MIT License](https://github.com/Adil-Arbaz-Khan/Universal-Vault/blob/main/LICENSE)

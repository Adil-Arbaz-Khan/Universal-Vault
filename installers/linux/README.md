# 🛡️ Universal Vault CLI (Linux Edition)

**Enterprise-Grade In-Place Authenticated Encryption Suite (AEAD)**  
*Terminal-First Native CLI • Zero-Install Footprint • 100% In-Place Streaming • Crash-Safe Checkpointed*

---

## 📖 Table of Contents
1. [System Requirements](#-system-requirements)
2. [Quick Installation](#-quick-installation)
3. [Command Reference & Usage](#-command-reference--usage)
   * [`vault lock`](#1-vault-lock---encrypt-filesfolders)
   * [`vault unlock`](#2-vault-unlock---decrypt-filesfolders)
   * [`vault status`](#3-vault-status---inspect-encryption-state)
   * [`vault version`](#4-vault-version)
4. [Crash Recovery (What to Do If Interrupted)](#-crash-recovery-guide)
5. [Uninstallation](#-clean-uninstallation)
6. [Security & Checksum Verification](#-security--checksum-verification)

---

## 💻 System Requirements

Universal Vault CLI is a lightweight, statically linked native ELF binary with **zero external dependencies**:

* **Operating System**: Any modern Linux distribution (Ubuntu, Debian, Fedora, Arch Linux, Alpine, CentOS, RHEL, Rocky Linux, openSUSE, Kali Linux, Raspberry Pi OS, Termux).
* **Architectures**:
  * `x86_64` / `amd64` (Standard 64-bit PC / Server)
  * `aarch64` / `arm64` (Raspberry Pi 3/4/5, Apple Silicon VMs, ARM64 Cloud VPS)
* **Dependencies**: **None** (No Python, No glibc dynamic runtime requirement, No C++ runtime needed).
* **Permissions**: Standard user (`$HOME/.local/bin`) or system-wide (`/usr/local/bin` via `sudo`).
* **Storage Footprint**: Less than **3 MB** total disk space.
* **Supported Shells**: `bash`, `zsh`, `fish`, `sh`, `dash`.

---

## 🚀 Quick Installation

Universal Vault CLI installs as a standalone global terminal command usable from any directory:

### How to Install:
1. Open your terminal in this extracted folder.
2. Run the installer:
   ```bash
   ./install.sh
   ```
   *(Or for global system-wide install: `sudo ./install.sh`)*
3. The installer will automatically:
   * Detect your hardware architecture (`x86_64` vs `arm64`).
   * Verify the cryptographic SHA-256 integrity of the binary before copying.
   * Deploy `vault` to `~/.local/bin` (or `/usr/local/bin` if root).
   * Ensure `~/.local/bin` is configured in your shell profile (`~/.bashrc`, `~/.zshrc`, `~/.profile`).
4. Open a **new** terminal tab or run `source ~/.bashrc` and verify:
   ```bash
   vault version
   ```
   *Output:*
   ```text
   Universal Vault CLI v5.5.1 (Go Native Architecture)
   ```

---

## 💻 Command Reference & Usage

The `vault` command can be executed from **any directory** on your system against single files or recursive directory trees.

### 1. `vault lock` — Encrypt Files/Folders
Transforms target files into 100% Full-File Authenticated AEAD Ciphertext in-place with 0% extra storage overhead.

* **Interactive Password Prompt (Recommended)**:
  ```bash
  vault lock "/home/user/Documents/Confidential.pdf"
  ```
  *Typed password is fully masked (silent input via `stty -echo`) to prevent shoulder surfing.*

* **Lock an Entire Directory (Recursive)**:
  ```bash
  vault lock "/data/projects/secret_repo"
  ```

* **Lock Current Folder**:
  ```bash
  vault lock .
  ```

* **Inline Password (Optional / Scripting)**:
  ```bash
  vault lock "/data/backup" -p "MyStrongMasterPassword123"
  ```

---

### 2. `vault unlock` — Decrypt Files/Folders
Verifies HMAC-SHA256 authenticity and restores files back to their exact original plaintext in-place.

* **Unlock a File or Directory**:
  ```bash
  vault unlock "/home/user/Documents/Confidential.pdf"
  ```

* **Unlock Entire Directory**:
  ```bash
  vault unlock "/data/projects/secret_repo"
  ```

* **Unlock with Inline Password**:
  ```bash
  vault unlock "/data/backup" -p "MyStrongMasterPassword123"
  ```

---

### 3. `vault status` — Inspect Encryption State
Scans files and displays whether they are unlocked, locked with V5 AEAD armor, locked with legacy formats, or interrupted mid-operation.

```bash
vault status "/data/projects/secret_repo"
```

*Example Output:*
```text
======================================================================
  Universal Vault v5.5.1 (CLI Native): STATUS Operation
  Target Scope   : /data/projects/secret_repo
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
```bash
vault version
```

---

## 🧯 Crash Recovery Guide

Did your server lose power, laptop battery die, terminal session disconnect (`SSH` dropped), or external drive get unplugged midway through locking or unlocking? **Your data is safe and deterministic.**

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

1. Run the uninstaller:
   ```bash
   ./uninstall.sh
   ```
   *(Or `sudo ./uninstall.sh` if installed system-wide)*
2. The uninstaller will:
   * Delete the binary from `~/.local/bin/vault` (or `/usr/local/bin/vault`).
   * Leave zero background daemons and zero system clutter.

---

## 🔒 Security & Checksum Verification

### 1. Cryptographic Provenance (Verify Binary Hash)
To guarantee your binary has not been tampered with or corrupted in transit, verify its SHA-256 checksum before executing:

```bash
sha256sum vault_linux_amd64
# Or for ARM64:
sha256sum vault_linux_arm64
```
Compare the output hash against [`SHA256SUMS.txt`](file:///D:/VS_code/Universal-Vault/installers/linux/SHA256SUMS.txt) or the official GitHub Release notes.

### 2. Silent Terminal Password Masking
Interactive password prompts use POSIX terminal control (`stty -echo`) with an automated exit trap (`trap 'stty echo' EXIT INT TERM`). No keystrokes or character counts are leaked on screen.

### 3. Cryptographic Suite Summary
* **Cipher**: AES-256-CTR (NIST SP 800-38A).
* **Integrity**: Encrypt-then-MAC (HMAC-SHA256) master payload authentication.
* **Work Factor**: 600,000 PBKDF2-HMAC-SHA256 rounds (OWASP 2026 Gold Standard).
* **Symlink Traversal**: Pre-order symbolic link pruning prevents directory escaping attacks.
* **Flash Storage Safe**: Enforces physical storage write barriers (`fsync()`) before advancing progress pointers.

---
**Author**: [Adil Arbaz Khan](https://github.com/Adil-Arbaz-Khan)  
**License**: [MIT License](https://github.com/Adil-Arbaz-Khan/Universal-Vault/blob/main/LICENSE)

<div align="center">

# 🛡️ Universal Vault V5.5

**Enterprise-Grade In-Place Authenticated Encryption Suite (AEAD)**  
*Zero Installation • 100% Full-File AEAD • RAM Streaming • Anti-Tampering HMAC-SHA256 • Crash-Safe Checkpointed*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![Security: AES-256-CTR + HMAC-SHA256](https://img.shields.io/badge/Security-AES--256--CTR%20%2B%20HMAC--SHA256-10b981.svg?style=for-the-badge)](SECURITY.md)
[![KDF: OWASP 600k](https://img.shields.io/badge/KDF-PBKDF2--600k%20Iters%20(OWASP)-38bdf8.svg?style=for-the-badge)](SECURITY.md)
[![Platforms: Universal](https://img.shields.io/badge/Platforms-Win%20%7C%20Mac%20%7C%20Linux%20%7C%20iOS%20%7C%20Android%20%7C%20Web-818cf8.svg?style=for-the-badge)](#-quickstart-guide)
[![Author](https://img.shields.io/badge/Author-Adil%20Arbaz%20Khan-f43f5e.svg?style=for-the-badge)](https://github.com/Adil-Arbaz-Khan)

</div>

---

## 🌟 Overview

**Universal Vault V5.5** is a sovereign, zero-dependency cryptographic appliance designed to provide **100% Full-File Authenticated Encryption (AEAD)** for individual files and complete directory trees across all operating systems.

Built specifically to solve the physical constraints of storage-limited drives (e.g., encrypting a 10 GB file with only 200 MB free space), Universal Vault encrypts data **in-place** with **0% storage overhead**, eliminates bit-flipping malleability with **Encrypt-then-MAC (EtM)** integrity verification, provides **crash-safe resumability** against sudden power loss, and enables **zero-copy RAM streaming** for multi-gigabyte media without writing temporary decrypted files to disk.

```
                              INCOMING TARGET
                                     │
                                     ▼
                   [ 100% FULL-FILE STREAMING AEAD ]
                     Every single byte encrypted in-place
                  Zero unencrypted headers or payload blocks
                                     │
                     ┌───────────────┴───────────────┐
                     ▼                               ▼
          [ AES-256-CTR Stream ]          [ Master HMAC-SHA256 ]
        Confidentiality (0% bloat)       Integrity (Anti-Tamper)
```

---

## ✨ Key Features (V5.5 Specification)

* 🛡️ **100% Full-File AEAD Across ALL File Sizes**:
  * Every byte of every file (from 1 KB documents to 50 GB videos) is fully encrypted using **AES-256-CTR block streaming** with zero unencrypted headers or carvable payloads remaining.
* 🧯 **Crash-Safe Resumable Operations**:
  * If a lock or unlock is interrupted — closed terminal, crash, power loss — your file is never left in a corrupted state. Resume forward or roll back to the original on your next attempt with zero data loss.
* 🛑 **Symlink-Safe Traversal**:
  * Pre-order junction & symlink pruning protects against directory escaping attacks during recursive folder operations.
* 🔒 **Anti-Tampering Encrypt-then-MAC (EtM) Integrity**:
  * Employs a master **HMAC-SHA256 tag** computed over the entire ciphertext payload. Any unauthorized bit-flipping or byte modification causes the decryption engine to reject the file immediately before executing any plaintext transforms.
* ⚡ **OWASP 2026 Gold Standard: 600,000 PBKDF2 Iterations**:
  * Exceeds standard defaults with **600,000 rounds of PBKDF2-SHA256** and unique 16-byte random salts per file, drastically throttling offline GPU dictionary attacks and rendering rainbow tables useless (strong passphrases recommended).
* ⚡ **Hardware Accelerated Throughput**:
  * The Windows PowerShell engine dynamically JIT-compiles a native C# stream processor at launch (**200+ MB/s**), while `Lock.bat`/`Unlock.bat` automatically detect and prioritize native C OpenSSL Python (**2.5+ GB/s**) when available.
* 🎬 **Zero-Copy In-Memory RAM Streamer (`Vault_App.html`)**:
  * Standalone client-side PWA that streams 4K video, audio, and documents **directly in volatile RAM** with **zero disk writes** and automated 3-minute memory auto-wiping.
* 🌐 **True In-Place Transformation (0% Extra Storage)**:
  * Encrypt a 10 GB file on a drive with 5 MB of free space. No temporary container files, no archive duplication.

---

## 📊 Comparison Matrix

| Feature | **Universal Vault (V5.5)** | **BitLocker** (Win Pro) | **VeraCrypt** | **7-Zip / WinRAR** |
| :--- | :--- | :--- | :--- | :--- |
| **Windows Home Support** | 🟢 **100% Native** | 🔴 Blocked (Pro only) | 🟡 Supported (Needs Admin) | 🟢 Supported |
| **Crash-Safe In-Place Resume** | 🛡️ **Yes (Footer Checkpoints)** | 🛡️ Journaled | 🛡️ Journaled | ❌ Re-extract from scratch |
| **Symlink Traversal Protection** | 🛡️ **Pre-Order Pruning** | N/A | N/A | ⚠️ Depends on client |
| **Payload Coverage** | 🛡️ **100% Full-File AEAD** | 🛡️ Whole Drive | 🛡️ Container Volume | ⚠️ Whole File (creates copy) |
| **Integrity / Anti-Tamper** | 🛡️ **Master HMAC-SHA256** | 🛡️ BitLocker MAC | 🛡️ XTS Integrity | ⚠️ CRC32 / Authenticated |
| **Install Footprint** | 🟢 **Zero Install** | 🟢 Built-in | 🔴 Heavy Kernel Drivers | 🟡 App Installation |
| **In-Place File Encryption** | 🟢 **Instant (0 extra bytes)** | 🔴 Whole Drive Only | 🔴 Fixed Container File | 🔴 Extracts to Temp Disk |
| **Temp File Disk Leaks** | 🛡️ **Zero Disk Leaks (RAM)** | 🛡️ None | 🛡️ None | ⚠️ **Severe (`AppData\Temp`)** |
| **KDF Iterations** | 🛡️ **600,000 PBKDF2-SHA256 (OWASP)** | 🛡️ TPM / PIN | 🛡️ Multiplier | 🔴 None / Low |

---

## 🚀 Quickstart Guide

### 1. Web & Mobile App (Offline PWA)
Simply double-click `Vault_App.html` in any modern web browser (Chrome, Brave, Edge, Safari, Firefox) on Windows, macOS, Linux, iOS, or Android:
* Encrypt & decrypt files client-side using native **WebCrypto SubtleCrypto**.
* Play encrypted videos and view encrypted PDFs directly in volatile memory with zero disk writes.

---

### 2. Windows 1-Click Launchers
* Double-click **`Lock.bat`** to lock files/folders with 100% Full-File AEAD and physical write barriers.
* Double-click **`Unlock.bat`** to verify HMAC integrity and restore files.
* Double-click **`Status.bat`** to inspect the lock state of your directory tree.

---

### 3. Linux & macOS (Universal Shell Scripts)
```bash
chmod +x lock.sh unlock.sh status.sh

# Lock
./lock.sh /path/to/my_folder

# Unlock
./unlock.sh /path/to/my_folder

# Status Audit
./status.sh /path/to/my_folder
```

---

### 4. Android (Mobile Web & Termux)
* **Method 1 (Instant 1-Click)**: Open `Vault_App.html` in Chrome or Brave on Android to lock, unlock, or stream 4K videos in RAM with zero install.
* **Method 2 (Termux Power Users)**:
  ```bash
  # 1. Grant storage permission & install python (one-time setup):
  termux-setup-storage
  pkg install python -y

  # 2. Navigate to where you extracted the tool:
  cd ~/storage/downloads/Universal-Vault-v5.5-Android

  # 3. Lock/Unlock any file or folder on your device:
  python tools/vault.py lock /storage/emulated/0/Download/secret_file.pdf
  python tools/vault.py unlock /storage/emulated/0/Download/secret_file.pdf
  ```

---

## 🧯 What to Do If Interrupted (Crash Recovery Guide)

Did your terminal accidentally close, laptop battery die, or USB drive get unplugged while locking or unlocking? **Do not worry — your files are safe!** Universal Vault V5.5 is designed with built-in checkpoint crash safety.

Here is how to solve it in seconds:

### Scenario 1: Interrupted While LOCKING
If encryption was stopped midway (e.g. at 40% of a large video or folder):
* **To finish locking**: Run **`Lock.bat`** (or `./lock.sh`) and enter your password. The vault will pick up from the exact byte where it stopped and seal the rest of the file.
* **To cancel and get your original unencrypted file back**: Run **`Unlock.bat`** (or `./unlock.sh`) and enter your password. The vault will detect that encryption was interrupted, automatically decrypt the partially locked portion back to plaintext, and restore your **100% original file**.

### Scenario 2: Interrupted While UNLOCKING
If decryption was stopped midway:
* Run **`Unlock.bat`** (or `./unlock.sh`) and enter your password. The vault will automatically resume decrypting from the last saved safe checkpoint and restore your file.

### Checking the Current State of Your Files
* Run **`Status.bat`** (or `./status.sh`). The tool will inspect your files and display if any file has an interrupted operation, showing the exact byte progress (e.g. `locked (V5 RESUMABLE UNLOCK INTERRUPTED at 250.00 MB)`).

---

## 🔒 Binary Specifications (`VAULTV05`)

Universal Vault V5.5 supports two footer variants:

### A. Resumable Checkpoint Layout (104 Bytes - Used In-Progress & Crash Recovery)
```
┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬─────────────┬─────────────┐
│  Magic (8B)  │ChunkSize (4B)│  Salt (16B)  │  Nonce (16B) │MasterMAC(32B)│ AuthTag(16B) │Checkpoint(8B)│ Fails (2B)  │StateFlag(2B)│
│  "VAULTV05"  │  uint32 LE   │ Random Bytes │ Random Bytes │ HMAC-SHA256  │ HMAC-SHA256  │  uint64 LE   │  uint16 LE  │  uint16 LE  │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴─────────────┴─────────────┘
```

### B. Sealed Base Layout (96 Bytes - Static Final Sealed Vaults)
```
┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬─────────────┬─────────────┐
│  Magic (8B)  │ChunkSize (4B)│  Salt (16B)  │  Nonce (16B) │MasterMAC(32B)│ AuthTag(16B) │ Fails (2B)  │ModeFlag (2B)│
│  "VAULTV05"  │  uint32 LE   │ Random Bytes │ Random Bytes │ HMAC-SHA256  │ HMAC-SHA256  │  uint16 LE  │  uint16 LE  │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴─────────────┴─────────────┘
```

* **Two-Key Splitting**: $DK = \text{PBKDF2-SHA256}(\text{Password}, \text{Salt}, 600000, 64)$
  * $\text{EncKey} = DK[0..31]$ (AES-256-CTR)
  * $\text{MacKey} = DK[32..63]$ (HMAC-SHA256)
* **MasterMAC**: $HMAC(\text{MacKey}, \text{Ciphertext})$ computed across the full file payload.
* **AuthTag**: $HMAC(\text{MacKey}, \text{"VAULT\_AUTH\_V5"} \parallel \text{Salt})[0..15]$ (Constant-time password verification).
* **Local UI Tripwire**: The on-disk failed attempt counter provides casual tamper-evidence for shared workstations (offline security is enforced by the 600,000 PBKDF2 computational cost).

---

## 👤 Author

**Adil Arbaz Khan**  
* GitHub: [@Adil-Arbaz-Khan](https://github.com/Adil-Arbaz-Khan)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

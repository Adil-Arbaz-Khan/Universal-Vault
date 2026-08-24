<div align="center">

# 🛡️ Universal Vault V5

**Enterprise-Grade In-Place Authenticated Encryption Suite (AEAD)**  
*Zero Installation • 100% Full-File AEAD • RAM Streaming • Anti-Tampering HMAC-SHA256*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![Security: AES-256-CTR + HMAC-SHA256](https://img.shields.io/badge/Security-AES--256--CTR%20%2B%20HMAC--SHA256-10b981.svg?style=for-the-badge)](SECURITY.md)
[![KDF: PBKDF2 250k](https://img.shields.io/badge/KDF-PBKDF2--250k%20Iters-38bdf8.svg?style=for-the-badge)](SECURITY.md)
[![Platforms: Universal](https://img.shields.io/badge/Platforms-Win%20%7C%20Mac%20%7C%20Linux%20%7C%20iOS%20%7C%20Android%20%7C%20Web-818cf8.svg?style=for-the-badge)](#-quickstart-guide)
[![Author](https://img.shields.io/badge/Author-Adil%20Arbaz%20Khan-f43f5e.svg?style=for-the-badge)](https://github.com/Adil-Arbaz-Khan)

</div>

---

## 🌟 Overview

**Universal Vault V5** is a sovereign, zero-dependency cryptographic appliance designed to provide **100% Full-File Authenticated Encryption (AEAD)** for individual files and complete directory trees across all operating systems.

Built specifically to solve the physical constraints of storage-limited drives (e.g., encrypting a 10 GB file with only 200 MB free space), Universal Vault encrypts data **in-place** with **0% storage overhead**, eliminates bit-flipping malleability with **Encrypt-then-MAC (EtM)** integrity verification, and enables **zero-copy RAM streaming** for multi-gigabyte media without writing temporary decrypted files to disk.

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

## ✨ Key Features (V5 Specification)

* 🛡️ **100% Full-File AEAD Across ALL File Sizes**:
  * Every byte of every file (from 1 KB documents to 50 GB videos) is fully encrypted using **AES-256-CTR block streaming** with zero unencrypted headers or carvable payloads remaining.
* 🔒 **Anti-Tampering Encrypt-then-MAC (EtM) Integrity**:
  * Employs a master **HMAC-SHA256 tag** computed over the entire ciphertext payload. Any unauthorized bit-flipping or byte modification causes the decryption engine to reject the file immediately before executing any plaintext transforms.
* ⚡ **NIST-Hardened 250,000 PBKDF2 Iterations**:
  * NIST SP 800-132 hardened KDF with a unique 16-byte random salt per file, rendering offline GPU dictionary and rainbow table attacks computationally intractable.
* 🎬 **Zero-Copy In-Memory RAM Streamer (`Vault_App.html`)**:
  * Standalone client-side PWA that streams 4K video, audio, and documents **directly in volatile RAM** with **zero disk writes** and automated 3-minute memory auto-wiping.
* 🌐 **True In-Place Transformation (0% Extra Storage)**:
  * Encrypt a 10 GB file on a drive with 5 MB of free space. No temporary container files, no archive duplication.

---

## 📊 Comparison Matrix

| Feature | **Universal Vault (V5)** | **BitLocker** (Win Pro) | **VeraCrypt** | **7-Zip / WinRAR** |
| :--- | :--- | :--- | :--- | :--- |
| **Windows Home Support** | 🟢 **100% Native** | 🔴 Blocked (Pro only) | 🟡 Supported (Needs Admin) | 🟢 Supported |
| **Payload Coverage** | 🛡️ **100% Full-File AEAD** | 🛡️ Whole Drive | 🛡️ Container Volume | ⚠️ Whole File (creates copy) |
| **Integrity / Anti-Tamper** | 🛡️ **Master HMAC-SHA256** | 🛡️ BitLocker MAC | 🛡️ XTS Integrity | ⚠️ CRC32 / Authenticated |
| **Install Footprint** | 🟢 **Zero Install** | 🟢 Built-in | 🔴 Heavy Kernel Drivers | 🟡 App Installation |
| **In-Place File Encryption** | 🟢 **Instant (0 extra bytes)** | 🔴 Whole Drive Only | 🔴 Fixed Container File | 🔴 Extracts to Temp Disk |
| **Temp File Disk Leaks** | 🛡️ **Zero Disk Leaks (RAM)** | 🛡️ None | 🛡️ None | ⚠️ **Severe (`AppData\Temp`)** |
| **KDF Iterations** | 🛡️ **250,000 PBKDF2-SHA256** | 🛡️ TPM / PIN | 🛡️ Multiplier | 🔴 None / Low |
| **Pricing / License** | 🟢 **100% Free & Open Source** | 🔴 $99–$199 OS Upgrade | 🟢 Open Source | 🟢 Free / Shareware |

---

## 📁 Repository Structure

```
Universal-Vault/
│
├── 📜 Lock.bat                ← Windows 1-Click Authenticated AEAD Locker
├── 📜 Unlock.bat              ← Windows 1-Click Authenticated AEAD Unlocker
├── 📜 Status.bat              ← Windows 1-Click Vault Security Auditor
├── 🌐 Vault_App.html          ← Standalone Web & Mobile RAM Streamer / PWA
├── 🐧 lock.sh                 ← Linux / macOS / Android Termux Locker
├── 🐧 unlock.sh               ← Linux / macOS / Android Termux Unlocker
├── 🐧 status.sh               ← Linux / macOS / Android Termux Auditor
│
├── 📂 tools/
│   ├── vault.py               ← Universal Python 3 Core Engine (AES-256 + HMAC + 250k PBKDF2)
│   ├── header_vault.ps1       ← Universal PowerShell 7+ .NET Core Engine
│   └── setup_termux.sh        ← Android Termux 1-Click Setup Script
│
├── 📂 Test_Samples/           ← 100% Authentic Sample Files for Live Verification
│   ├── 📂 Documents/          ← Genuine PDF, Excel XLSX, Word DOCX, CSV, TXT
│   ├── 📂 Images/             ← Genuine PNG, JPEG, SVG
│   ├── 📂 Media/              ← Genuine MP4 Video, WAV Audio
│   └── 📂 Code_And_Data/      ← Python, JSON, ZIP Archive
│
├── 📜 LICENSE                 ← MIT Open Source License
├── 📜 SECURITY.md             ← Cryptographic Threat Model & Specifications
└── 📜 CONTRIBUTING.md         ← Developer & Community Guidelines
```

---

## 🚀 Quickstart Guide

### 1. Windows (Zero-Install Batch & PowerShell)
* **To Lock Everything**: Double-click **`Lock.bat`** $\rightarrow$ Enter password.
* **To Lock a Single File / Folder**: Drag-and-drop any file directly onto **`Lock.bat`**.
* **To Unlock**: Double-click or drag onto **`Unlock.bat`** $\rightarrow$ Verifies HMAC and restores bit-for-bit.
* **To Audit Security**: Double-click **`Status.bat`**.

```cmd
# Or via PowerShell CLI:
powershell -ExecutionPolicy Bypass -File tools\header_vault.ps1 -Action Lock -Path "D:\SecretFolder"
powershell -ExecutionPolicy Bypass -File tools\header_vault.ps1 -Action Unlock -Path "D:\SecretFolder"
```

---

### 2. Web, iPhone & Android Mobile (`Vault_App.html`)
1. Open **`Vault_App.html`** in any web browser.
2. Select any encrypted file $\rightarrow$ Enter password $\rightarrow$ Click **Stream & Preview in RAM**.
3. Streams media and documents in browser memory with **zero disk writes** and auto-wipes after 3 minutes.

---

### 3. Linux & macOS (Shell & Python)
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

### 4. Android (via Termux)
```bash
pkg install python git -y
git clone https://github.com/Adil-Arbaz-Khan/Universal-Vault.git
cd Universal-Vault
bash tools/setup_termux.sh

# Lock/Unlock any file on storage:
./lock.sh /sdcard/Download/Private_Document.pdf
./unlock.sh /sdcard/Download/Private_Document.pdf
```

---

## 🔒 Binary Specification (`VAULTV05` - 96 Bytes)

Universal Vault V5 appends a 96-byte authenticated cryptographic trailer at the end of each protected file:

```
┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬─────────────┬─────────────┐
│  Magic (8B)  │ChunkSize (4B)│  Salt (16B)  │  Nonce (16B) │MasterMAC(32B)│ AuthTag(16B) │ Fails (2B)  │ModeFlag (2B)│
│  "VAULTV05"  │  uint32 LE   │ Random Bytes │ Random Bytes │ HMAC-SHA256  │ HMAC-SHA256  │  uint16 LE  │  uint16 LE  │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴─────────────┴─────────────┘
```

* **Two-Key Splitting**: $DK = \text{PBKDF2-SHA256}(\text{Password}, \text{Salt}, 250000, 64)$
  * $\text{EncKey} = DK[0..31]$ (AES-256-CTR)
  * $\text{MacKey} = DK[32..63]$ (HMAC-SHA256)
* **MasterMAC**: $HMAC(\text{MacKey}, \text{Ciphertext})$ computed across the full file payload.
* **AuthTag**: $HMAC(\text{MacKey}, \text{"VAULT\_AUTH\_V5"} \parallel \text{Salt})[0..15]$ (Constant-time password verification).

---

## 👤 Author

**Adil Arbaz Khan**  
* GitHub: [@Adil-Arbaz-Khan](https://github.com/Adil-Arbaz-Khan)

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

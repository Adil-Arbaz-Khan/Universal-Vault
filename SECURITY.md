# Security Policy & Cryptographic Threat Model (V5)

## 🛡️ Supported Versions

| Version | Status | Key Derivation (KDF) | Integrity / Authenticity | Payload Coverage |
| :--- | :--- | :--- | :--- | :--- |
| **V5.x** | 🟢 **Active / Recommended** | PBKDF2-HMAC-SHA256 (600,000 iters) | 🛡️ **Master HMAC-SHA256 (AEAD EtM)** | 🛡️ **100% Full-File AEAD (All Sizes)** |
| **V4.x** | 🟡 Deprecated (Migration Only) | PBKDF2-HMAC-SHA256 (100,000 iters) | ⚠️ Password AuthHash only (No payload MAC) | ⚠️ Hybrid (Full <50MB / Header) |
| **V3.x - V1.x** | 🔴 End-of-Life | PBKDF2-HMAC-SHA256 (10k-100k iters) | ❌ None | ⚠️ Header-Only (64 KB) |

> [!NOTE]
> **Threat Model & Lockout Scope**: The on-disk failed attempt counter functions as a **local UI tripwire** for shared workstations and casual tampering. Offline brute-force resistance against raw copied files is governed solely by the computational work factor of **600,000 PBKDF2-SHA256 iterations** with unique per-file random salts (high-entropy passphrases recommended).

> [!WARNING]
> **Legacy V4 Migration Notice**: While Universal Vault V5 supports unlocking legacy V4/V3 files for backward compatibility, V4 files only authenticated the encryption key, not the underlying ciphertext payload. Users holding legacy V4 vaults are strongly advised to unlock and re-lock their files using **V5 Authenticated AEAD** to obtain full ciphertext integrity protection.

---

## 🔒 Cryptographic Specifications (V5 Specification)

Universal Vault V5 implements an **Authenticated Encryption with Associated Data (AEAD)** construction following the formal **Encrypt-then-MAC (EtM)** standard (ISO/IEC 18033-4):

### 1. Symmetric Cipher
* **Algorithm**: `AES-256-CTR` (NIST SP 800-38A).
* **Streaming Block Architecture**: 64 KB block streaming preserves exact byte lengths, enabling 100% in-place transformation with **0% extra disk space**.
* **Nonce / Counter**: 16 bytes of cryptographically secure pseudo-random entropy per file.

### 2. Authenticity & Anti-Tampering (Integrity)
* **Master MAC**: `HMAC-SHA256` computed over the entire ciphertext payload.
* **Malleability Immunity**: Bit-flipping and chosen-ciphertext attacks are mathematically neutralized; the decryption engine verifies the master HMAC tag before executing any plaintext transforms.

### 3. Key Derivation & Master Splitting
* **Standard**: NIST SP 800-132 `PBKDF2-HMAC-SHA256`.
* **Iterations**: `600,000 rounds` (OWASP 2026 Gold Standard) with unique 16-byte random salt per file.
* **Key Separation**:
  * 32-byte Encryption Key (`EncKey`)
  * 32-byte MAC Key (`MacKey`)

### 4. Binary Footer Layout (`VAULTV05` - 96 Bytes)

```
┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬─────────────┬─────────────┐
│  Magic (8B)  │ChunkSize (4B)│  Salt (16B)  │  Nonce (16B) │MasterMAC(32B)│ AuthTag(16B) │ Fails (2B)  │ModeFlag (2B)│
│  "VAULTV05"  │  uint32 LE   │ Random Bytes │ Random Bytes │ HMAC-SHA256  │ HMAC-SHA256  │  uint16 LE  │  uint16 LE  │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴─────────────┴─────────────┘
```

---

## 🔍 Known Operational Boundaries & Security Assumptions

1. **Password Entropy**: The 600,000 PBKDF2 iterations substantially raise the computational cost for offline GPU attackers, but cannot protect against trivially guessable passwords. High-entropy passphrases (14+ characters) remain essential.
2. **Browser Garbage Collection & RAM**: In `Vault_App.html`, typed arrays containing key bytes are immediately overwritten with zeros via `.fill(0)`. However, JavaScript engine garbage collectors (V8/SpiderMonkey) manage low-level heap memory dynamically. For high-security environments, close browser tabs after session completion or use the "Wipe RAM" button.
3. **Filesystem Metadata**: The Encrypt-then-MAC tag authenticates 100% of the ciphertext file content. External filesystem metadata (e.g. filename, file modification timestamps) are managed by the host OS filesystem.
4. **Endpoint Security**: The cryptographic suite assumes the host endpoint is free from active hardware keyloggers or compromised memory-scraping malware.

---

## 🛑 Reporting a Vulnerability

If you discover a potential cryptographic vulnerability within Universal Vault, please send a disclosure report to:
* **Maintainer**: Adil Arbaz Khan
* **GitHub Profile**: [@Adil-Arbaz-Khan](https://github.com/Adil-Arbaz-Khan)

# Security Policy & Cryptographic Threat Model (V5)

## 🛡️ Supported Versions

| Version | Status | Key Derivation (KDF) | Integrity / Authenticity | Payload Coverage |
| :--- | :--- | :--- | :--- | :--- |
| **V5.x** | 🟢 **Active / Recommended** | PBKDF2-HMAC-SHA256 (250,000 iters) | 🛡️ **Master HMAC-SHA256 (AEAD EtM)** | 🛡️ **100% Full-File AEAD (All Sizes)** |
| **V4.x** | 🟡 Supported (Legacy) | PBKDF2-HMAC-SHA256 (100,000 iters) | ⚠️ Password AuthHash only | ⚠️ Hybrid (Full <50MB / Header) |
| **V3.x - V1.x** | 🔴 Deprecated | PBKDF2-HMAC-SHA256 (10k-100k iters) | ❌ None | ⚠️ Header-Only (64 KB) |

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
* **Iterations**: `250,000 rounds` with unique 16-byte random salt per file.
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

## 🛑 Reporting a Vulnerability

If you discover a potential cryptographic vulnerability within Universal Vault, please send a disclosure report to:
* **Maintainer**: Adil Arbaz Khan
* **GitHub Profile**: [@Adil-Arbaz-Khan](https://github.com/Adil-Arbaz-Khan)

# Security Policy & Cryptographic Threat Model

## 🛡️ Supported Versions

| Version | Status | Key Derivation (KDF) | Anti-Brute-Force Armor | Carving Resistance |
| :--- | :--- | :--- | :--- | :--- |
| **V4.x** | 🟢 **Active / Recommended** | PBKDF2-HMAC-SHA256 (100,000 iters) | ✅ On-Disk Counter + Web Lockout | 🛡️ **100% Full-File Armor (0 Carvable Plaintext)** |
| **V3.x** | 🟡 Supported (Legacy) | PBKDF2-HMAC-SHA256 (100,000 iters) | ✅ On-Disk Counter | ⚠️ Partial Header Armor (64 KB) |
| **V2.x / V1.x** | 🔴 Deprecated | PBKDF2-HMAC-SHA256 (10,000 iters) | ❌ None | ⚠️ Partial Header Armor |

---

## 🔒 Cryptographic Specifications

Universal Vault is designed according to **Kerckhoffs's Principle**: the security of the vault rests entirely upon the secrecy and entropy of the user's master password, not the obscurity of the algorithms.

### 1. Symmetric Cipher
* **Algorithm**: `AES-256-CBC` (Advanced Encryption Standard with 256-bit key length and Cipher Block Chaining mode).
* **Initialization Vector (IV)**: 16 bytes of cryptographically secure pseudo-random entropy generated per file via `os.urandom()` (Python), `RNGCryptoServiceProvider` (.NET), or `crypto.getRandomValues()` (Web).

### 2. Key Derivation Function (KDF)
* **Standard**: NIST SP 800-132 compliant `PBKDF2-HMAC-SHA256`.
* **Iterations**: `100,000 rounds` to mitigate offline high-performance GPU dictionary and brute-force attacks.
* **Salt**: 16 bytes unique random salt per file, completely neutralizing precomputed rainbow tables.

### 3. Binary Footer Layout (`VAULTV04` - 80 Bytes)

```
┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐
│  Magic (8B)  │ChunkSize (4B)│  Salt (16B)  │   IV (16B)   │AuthHash (32B)│  Fails (2B)  │ModeFlag (2B) │
│  "VAULTV04"  │  uint32 LE   │ Random Bytes │ Random Bytes │ SHA256 Hash  │  uint16 LE   │  uint16 LE   │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘
```

* **Authentication Tag**: $\text{AuthHash} = \text{SHA256}(\text{Key} \parallel \text{"VAULT\_AUTH\_V4"} \parallel \text{Salt})$
* **Constant-Time Verification**: Prevents micro-timing side-channel analysis during authentication.

---

## 🛑 Reporting a Vulnerability

If you discover a potential security flaw or cryptographic vulnerability within Universal Vault, please do **not** open a public issue on GitHub.

Instead, please send a detailed disclosure report to:
* **Maintainer**: Adil Arbaz Khan
* **GitHub Profile**: [@Adil-Arbaz-Khan](https://github.com/Adil-Arbaz-Khan)

Please include steps to reproduce, the targeted file type, and your environment specifications. We appreciate your efforts in responsible disclosure.

# Security Policy & Cryptographic Threat Model (V5.5.4)

> **Official Website & Live WebApp**: [https://universal-vault.pages.dev/](https://universal-vault.pages.dev/)

## 🛡️ Supported Versions

| Version | Status | Key Derivation (KDF) | Integrity / Authenticity | Payload Coverage | Fault Tolerance & Footer Format |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **V5.5.4 / V5.5+ (Native CLI, Android & WebApp)** | 🟢 **Active / Recommended** | PBKDF2-HMAC-SHA256 (600,000 iters) | 🛡️ **Master HMAC-SHA256 (AEAD EtM)** | 🛡️ **100% Full-File AEAD (All Sizes)** | ⚡ **Crash-Safe Checkpointed (104-byte Resumable / Two-Way Rollback)** |
| **V5.0** | 🟢 Supported | PBKDF2-HMAC-SHA256 (600,000 iters) | 🛡️ **Master HMAC-SHA256 (AEAD EtM)** | 🛡️ **100% Full-File AEAD (All Sizes)** | ⚠️ Static Sealed (96-byte Non-Resumable Footer) |
| **V4.x** | 🟡 Deprecated (Migration Only) | PBKDF2-HMAC-SHA256 (100,000 iters) | ⚠️ Password AuthHash only (No payload MAC) | ⚠️ Hybrid (Full <50MB / Header) | ❌ Non-Resumable |
| **V3.x - V1.x** | 🔴 End-of-Life | PBKDF2-HMAC-SHA256 (10k-100k iters) | ❌ None | ⚠️ Header-Only (64 KB) | ❌ Non-Resumable |

> [!NOTE]
> **Threat Model & Lockout Scope**: The on-disk failed attempt counter functions as a **local UI tripwire** for shared workstations and casual tampering. Offline brute-force resistance against raw copied files is governed solely by the computational work factor of **600,000 PBKDF2-SHA256 iterations** with unique per-file random salts (high-entropy passphrases recommended).

> [!WARNING]
> **Legacy V4 Migration Notice**: While Universal Vault V5/V5.5 supports unlocking legacy V4/V3 files for backward compatibility, V4 files only authenticated the encryption key, not the underlying ciphertext payload. Users holding legacy V4 vaults are strongly advised to unlock and re-lock their files using **V5.5 Authenticated AEAD** to obtain full ciphertext integrity protection.

---

## 🔒 Cryptographic Specifications (V5.5.4 Architecture)

Universal Vault V5.5.4 implements an **Authenticated Encryption with Associated Data (AEAD)** construction following the formal **Encrypt-then-MAC (EtM)** standard (ISO/IEC 18033-4):

### 1. Zero-Dependency Native Core (Supply-Chain Immunity)
* The primary CLI engine (`cmd/vault`) is built entirely using the **Go Standard Library** (`crypto/aes`, `crypto/cipher`, `crypto/hmac`, `crypto/sha256`, `crypto/rand`, `crypto/subtle`).
* **Zero External Dependencies**: Statically compiled without third-party libraries, eliminating open-source supply chain attack vectors and dependency confusion risks.

### 2. Symmetric Cipher
* **Algorithm**: `AES-256-CTR` (NIST SP 800-38A).
* **Streaming Block Architecture**: 64 KB block streaming preserves exact byte lengths, enabling 100% in-place transformation with **0% extra disk space**.
* **Nonce / Counter**: 16 bytes of cryptographically secure pseudo-random entropy generated via OS CSPRNG (`crypto/rand` invoking Win32 `BCryptGenRandom` or Unix `getrandom(2)`/`getentropy(2)`).

### 3. Authenticity & Anti-Tampering (Integrity)
* **Master MAC**: `HMAC-SHA256` computed over 100% of the ciphertext payload.
* **Malleability Immunity**: Bit-flipping and chosen-ciphertext attacks are mathematically neutralized; the decryption engine verifies the master HMAC tag before executing any plaintext transforms.

### 4. Key Derivation & Master Splitting
* **Standard**: NIST SP 800-132 `PBKDF2-HMAC-SHA256`.
* **Iterations**: `600,000 rounds` (OWASP 2026 Gold Standard) with unique 16-byte random salt per file.
* **Key Separation**: 512 derived bits split into:
  * 32-byte Encryption Key (`EncKey` for AES-CTR)
  * 32-byte MAC Key (`MacKey` for HMAC-SHA256)
* **Pre-Flight Authentication (`AuthTag`)**: $HMAC(\text{MacKey}, \text{"VAULT\_AUTH\_V5"} \parallel \text{Salt})[0..15]$ verified in constant-time (`crypto/subtle`) before beginning ciphertext reads.

### 5. Fault-Tolerant Checkpointed Streaming (Crash Safety)
* **Periodic Checkpoints**: In-place progress is atomically flushed to a 64-bit progress offset in the footer during transformation.
* **Hardware Write Barriers**: Flushes transformed blocks directly to physical NAND flash (`FlushFileBuffers` on Windows, `fsync(2)` on POSIX) before advancing checkpoint pointers.
* **Automated Interruption Recovery**: If power fails or a user abruptly closes the process midway through a large multi-gigabyte file, the engine on next launch detects the exact byte offset and seamlessly resumes transformation from the safe checkpoint rather than leaving corrupted data.

### 6. Silent Terminal Password Masking (Shoulder-Surfing Defense)
* **Windows**: Directly queries Win32 Console API (`GetConsoleMode` / `SetConsoleMode`) and disables `ENABLE_ECHO_INPUT` (`0x0004`) during master password input.
* **Linux / macOS**: Direct POSIX terminal mode (`stty -echo`) with signal exit traps (`EXIT`, `INT`, `TERM`) guarantees password keystrokes are never echoed to the terminal or leaked in command history.

### 7. Binary Footer Layouts (`VAULTV05`)

#### A. Resumable Checkpoint Layout (104 Bytes - Used In-Progress and Crash Recovery)
```text
┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬─────────────┬─────────────┐
│  Magic (8B)  │ChunkSize (4B)│  Salt (16B)  │  Nonce (16B) │MasterMAC(32B)│ AuthTag(16B) │Checkpoint(8B)│ Fails (2B)  │StateFlag(2B)│
│  "VAULTV05"  │  uint32 LE   │ Random Bytes │ Random Bytes │ HMAC-SHA256  │ HMAC-SHA256  │  uint64 LE   │  uint16 LE  │  uint16 LE  │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴─────────────┴─────────────┘
```

#### B. Sealed Base Layout (96 Bytes - Static Final Sealed Vaults)
```text
┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬─────────────┬─────────────┐
│  Magic (8B)  │ChunkSize (4B)│  Salt (16B)  │  Nonce (16B) │MasterMAC(32B)│ AuthTag(16B) │ Fails (2B)  │ModeFlag (2B)│
│  "VAULTV05"  │  uint32 LE   │ Random Bytes │ Random Bytes │ HMAC-SHA256  │ HMAC-SHA256  │  uint16 LE  │  uint16 LE  │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴─────────────┴─────────────┘
```

#### C. Gibberish Filename Masking Specification (`FlagGibberishName = 0x0004`)
When filename masking is enabled (`-g` / `--gibberish` in CLI, toggle switch in WebApp & Android):
* **Filesystem Obfuscation**: The vault is renamed to a randomized 16-hexadecimal hash with `.vault` extension (e.g. `7f8a1c9e4b2d3f0a.vault`), disguising original file identities, extensions, and metadata from directory listings.
* **Encrypted Metadata Header**: The original filename is encoded as UTF-8 and stored immediately after the encrypted payload at byte offset `dataLen`:
  ```text
  [dataLen .. dataLen + 2]       : uint16 LE (length of original filename, in bytes)
  [dataLen + 2 .. dataLen + 2 + N]: Encrypted UTF-8 filename (AES-256-CTR)
  ```
* **Keystream Alignment**: Filename encryption utilizes the continuous AES-256-CTR keystream starting at counter block `(dataLen + 15) / 16`.
* **Authenticated Encrypt-then-MAC (EtM)**: The 32-byte Master HMAC-SHA256 signature covers all bytes from index `0` up to `dataLen + metaLen`. Decryption verifies HMAC integrity across both the payload and filename metadata before any decryption or restoration occurs.
* **State Flag Isolation**: Bit 2 (`0x0004`) is set in `StateFlags` (footer bytes 102..104), while crash-safe interruption detection strictly isolates bits 0 and 1 (`stateFlags & 3`), preserving flawless checkpoint recovery.
* **Deterministic Restoration**: Unlocking automatically detects `FlagGibberishName`, decrypts the original filename, and renames the file back to its exact original plaintext name.

### 8. WebCrypto Air-Gapped Engine Architecture (`Vault_App.html`)

Universal Vault provides an air-gapped, zero-dependency browser implementation in `Vault_App.html` (hosted at [https://universal-vault.pages.dev/app/](https://universal-vault.pages.dev/app/)):

* **Client-Side Isolated Execution**: Built entirely upon the W3C Web Cryptography API (`window.crypto.subtle`). Cryptographic transformations execute within the local browser sandbox; no keys, credentials, or file bytes are ever transmitted over the network.
* **Strict Content Security Policy (Anti-Exfiltration Guard)**:
  `default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data: blob:; media-src blob:; frame-src blob:; object-src blob:;`
  Guarantees zero outbound network connections, zero external script loading, and zero telemetry beacons.
* **Cryptographic & Format Parity with Native CLI**:
  * **KDF**: 600,000 iterations of PBKDF2-HMAC-SHA256 deriving 512 bits (split into 32-byte AES-CTR `EncKey` and 32-byte HMAC-SHA256 `MacKey`).
  * **Pre-Flight Authentication**: Verifies the 16-byte `AuthTag` ($HMAC(\text{MacKey}, \text{"VAULT\_AUTH\_V5"} \parallel \text{Salt})[0..15]$) in constant time before parsing payload ciphertext.
  * **Anti-Tamper Master MAC (EtM)**: Verifies the 32-byte HMAC-SHA256 signature across 100% of ciphertext blocks prior to emitting plaintext.
  * **Streaming Transformation**: Processes files in 4 MB RAM chunks via AES-256-CTR, preserving exact file size with zero disk bloat.
* **In-Memory RAM Streaming & Zero-Disk Forensics**:
  * Decrypts videos (up to 4K), audio streams, PDFs, and documents directly into volatile memory as `Blob` objects.
  * Streams media directly using transient Object URLs (`URL.createObjectURL(blob)`), leaving zero temporary file fragments in disk caches or `%Temp%` folders.
* **RAM Sanitization & Zeroization**:
  * Key buffers and working typed arrays are overwritten with zeros via `.fill(0)`.
  * A dedicated **"Wipe RAM"** button revokes all active Object URLs and releases memory buffers immediately.
* **Shannon Password Entropy Validation**:
  * Dynamically assesses password entropy in real-time ($E = L \log_2(N)$) to prevent users from encrypting vaults with guessable passwords. Visual tiers classify entropy from Weak (<40 bits) to High-Assurance (80+ bits).

### 9. Volatile RAM Streaming & Anti-Forensic Inspection Protocol (Zero-Disk Footprint)

Universal Vault V5.5.4 introduces unified ephemeral inspection across all native environments (`vault view` / `vault stream` in CLI, `decryptToMemory` in Android, and WebCrypto in `Vault_App.html`), eliminating disk forensics:

* **Zero Plaintext Disk Writes**: Plaintext bytes are never written to physical flash storage, swap containers, or `%Temp%` / `/tmp` staging folders.
* **CLI Ephemeral Loopback Server**:
  * Decrypts ciphertext chunks strictly into volatile memory (`[]byte`).
  * If the target is text/source code, it is rendered directly to terminal stdout, and the memory buffer is zeroized immediately.
  * For rich media (PDF, images, video, audio), the CLI binds a transient HTTP server strictly to `127.0.0.1` on a dynamic port assigned by the OS kernel.
  * **Route Isolation**: The endpoint is gated by a 16-hexadecimal cryptographically random token (`http://127.0.0.1:<port>/<token>/<filename>`), preventing local port scanning or cross-process loopback snooping.
  * **RFC 7233 Range Support**: Handles HTTP 206 partial content requests, allowing smooth scrubbing of high-bitrate audio and 4K video files directly inside standard web browsers.
  * **Anti-Caching Directives**: Transmits `Cache-Control: no-store, no-cache, must-revalidate, private` and `Pragma: no-cache` headers to prevent browser rendering engines from caching decoded bytes to disk.
  * **Graceful Termination & Memory Zeroization**: Intercepts `os.Interrupt` / `SIGINT` / `SIGTERM` signals, shuts down the listener socket, and explicitly clears plaintext byte slices (`for i := range plaintext { plaintext[i] = 0 }`).
* **Android In-App Jetpack Compose RAM Previewer**:
  * **Heap Safety Barrier**: Evaluates `Runtime.getRuntime().maxMemory() - totalMemory + freeMemory` and enforces a strict 150 MB heap safety threshold prior to memory allocation, preventing `OutOfMemoryError` aborts.
  * **In-Memory Rendering**: Plaintext documents and decoded `Bitmap` streams are rendered strictly within Jetpack Compose state layers without utilizing `context.cacheDir` or temporary disk storage.
  * **Active Zeroization (`DisposableEffect`)**: When the preview dialog leaves the composition or is dismissed, `DisposableEffect` executes `bytes.fill(0)` to overwrite all raw decrypted byte buffers in memory.
  * **Automated Panic Wipe Protocol**: The RAM viewer initiates an active 180-second countdown timer. If left unattended, memory is automatically wiped and the modal closed. A manual "PANIC WIPE" action permits immediate operator-initiated purge.

---

## 🔍 Known Operational Boundaries & Security Assumptions

1. **Password Entropy**: The 600,000 PBKDF2 iterations substantially raise the computational cost for offline GPU attackers, but cannot protect against trivially guessable passwords. High-entropy passphrases (14+ characters) remain essential.
2. **Browser Garbage Collection & RAM**: In `Vault_App.html`, typed arrays containing key bytes are immediately overwritten with zeros via `.fill(0)`. However, JavaScript engine garbage collectors (V8/SpiderMonkey) manage low-level heap memory dynamically. For high-security environments, close browser tabs after session completion or use the "Wipe RAM" button.
3. **Filesystem Metadata & Filename Confidentiality**: The Encrypt-then-MAC tag authenticates 100% of the ciphertext file content. When standard in-place locking is used, external filenames remain visible. When **Gibberish Filename Masking** (`-g` / `--gibberish`) is engaged, the filename is encrypted and disguised as a random 16-hex hash, eliminating filename metadata leakage.
4. **Endpoint Security**: The cryptographic suite assumes the host endpoint is free from active hardware keyloggers or compromised memory-scraping malware.
5. **iOS (iPhone & iPad) Execution Model**: Unlike desktop and Android environments that support native command-line batch streaming, iOS enforces strict app sandboxing without terminal/shell access. On iOS, Universal Vault operates exclusively through the standalone client-side WebCrypto PWA (`Vault_App.html` hosted at [https://universal-vault.pages.dev/app/](https://universal-vault.pages.dev/app/)) in Safari, executing entirely in volatile browser RAM with zero terminal dependencies or background filesystem hooks.

---

## 🛠️ Security & Hardening Highlights

* **Symlink Traversal Immunity**: Recursive folder traversal checks directory entry metadata and skips symbolic links (`os.ModeSymlink`) *before* descending, preventing drive-by directory escape attacks.
* **Hardware Flash Synchronization**: Two-phase write barriers ensure that data blocks are physically committed to flash before advancing the checkpoint pointer, eliminating write-reordering data loss on USB flash drives.
* **Idempotent Status Auditing**: Diagnostic `status` operations are strictly read-only and never mutate files or execute truncations on damaged media.
* **Out-of-Band Provenance Verification**: Every released binary is accompanied by official cryptographic SHA-256 hashes published in `SHA256SUMS.txt` and GitHub Release Notes.

---

## 🛑 Reporting a Vulnerability

If you discover a potential cryptographic vulnerability within Universal Vault, please send a disclosure report to:
* **Maintainer**: Adil Arbaz Khan
* **GitHub Profile**: [@Adil-Arbaz-Khan](https://github.com/Adil-Arbaz-Khan)

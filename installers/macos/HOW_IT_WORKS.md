# ⚙️ How It Works & Architecture Guide (macOS Edition)

**Universal Vault CLI (macOS Engine)**  
*Under-the-Hood Architecture, Installer Internals, Safety Analysis & Cryptographic Deep Dive*

---

## 📖 Table of Contents
1. [macOS Installer Internals & Safety Analysis](#1-macos-installer-internals--safety-analysis)
   * [User-Space vs System-Wide Installation](#user-space-vs-system-wide-installation)
   * [Architecture Detection & Rosetta 2 Awareness](#architecture-detection--rosetta-2-awareness)
   * [Gatekeeper & Quarantine Handling](#gatekeeper--quarantine-handling)
   * [Is the Installer Safe? (Safety Audit)](#is-the-installer-safe-safety-audit)
   * [How Clean Uninstallation Works](#how-clean-uninstallation-works)
2. [Core CLI Engine Architecture](#2-core-cli-engine-architecture)
   * [In-Place Streaming (0% Extra Storage Overhead)](#in-place-streaming-0-extra-storage-overhead)
   * [Cryptographic Pipeline (600k PBKDF2 + AES-CTR + Master MAC)](#cryptographic-pipeline)
   * [104-Byte Resumable Checkpoint Architecture](#104-byte-resumable-checkpoint-architecture)
   * [Hardware Flash Memory Write Barriers (APFS fsync)](#hardware-flash-memory-write-barriers)
   * [Symlink Pruning & Path Safety](#symlink-pruning--path-safety)
3. [Format Compatibility Matrix](#3-format-compatibility-matrix)

---

## 1. macOS Installer Internals & Safety Analysis

### User-Space vs System-Wide Installation
The installer dynamically adapts to privileges:
* **Standard User (Default / Non-Root)**:
  * Deploys to `$HOME/.local/bin/vault`.
  * **Zero Root/Sudo Privileges Required**: Completely contained within the user's home directory.
  * Configures modern macOS login shells: automatically appends `$HOME/.local/bin` to `~/.zprofile` (evaluated by macOS `Terminal.app` login shells) as well as `~/.zshrc` and `~/.bash_profile`.
* **System Administrator (`sudo ./install.sh`)**:
  * Deploys to standard system binary path `/usr/local/bin/vault`.
  * Automatically accessible globally for all accounts on the Mac via standard macOS `/etc/paths`.

---

### Architecture Detection & Rosetta 2 Awareness
`install.sh` inspects the machine hardware architecture via `uname -m`:
* `arm64` $\to$ Deploys native 64-bit Apple Silicon binary (`vault_darwin_arm64`).
* `x86_64` $\to$ Evaluates `sysctl -in sysctl.proc_translated`:
  * If `1`: Terminal is running under Rosetta 2 emulation on an Apple Silicon Mac $\to$ Deploys native `vault_darwin_arm64` to maximize speed and efficiency on the native M-series cores.
  * If `0`: Mac is genuine Intel x86_64 $\to$ Deploys `vault_darwin_amd64`.

---

### Gatekeeper & Quarantine Handling
When files are downloaded via web browsers (Safari, Chrome) or chat tools on macOS, the kernel attaches an extended attribute (`com.apple.quarantine`). If present on an unsigned binary, Gatekeeper may display a warning dialog.
`install.sh` safely strips this attribute from the destination binary via:
```bash
xattr -d com.apple.quarantine "$DEST_EXE" 2>/dev/null || true
xattr -c "$DEST_EXE" 2>/dev/null || true
```
This enables seamless terminal execution without friction.

---

### Is the Installer Safe? (Safety Audit)

| Safety Property | Assessment | Technical Implementation |
| :--- | :--- | :--- |
| **Open Source & Transparent** | 🟢 **100% Transparent** | `install.sh` is a clean, standard 85-line POSIX Bash script with `set -euo pipefail`. |
| **Integrity & Copy Validation** | 🟢 **Checksum Gated** | Computes the SHA-256 hash before and after copying (`shasum -a 256`), ensuring bit-perfect file copy before declaring success. |
| **No Background Daemons** | 🟢 **Zero LaunchDaemons** | No `launchd` plist services, background daemons, or telemetry agents are installed. |
| **No Internet Connection** | 🟢 **100% Offline** | Runs entirely locally with zero network requests. |
| **Statically Linked** | 🟢 **Zero Runtime Dependencies** | Compiled with `CGO_ENABLED=0` — runs out of the box without Xcode Command Line Tools or Homebrew. |
| **Silent Password Entry** | 🟢 **Shoulder-Surfing Safe** | Direct POSIX terminal mode (`stty -echo`) with signal traps ensures passwords never echo to the screen. |

---

### How Clean Uninstallation Works
Running `uninstall.sh` (or `sudo ./uninstall.sh`):
1. Deletes `vault` from `$HOME/.local/bin/` or `/usr/local/bin/`.
2. Leaves zero background daemons, zero configuration detritus, and zero system clutter.

---

## 2. Core CLI Engine Architecture

```
                    INPUT FILE (100 MB Video / Document)
                                    │
                                    ▼
       ┌─────────────────────────────────────────────────────────┐
       │ 1. KEY DERIVATION & MASTER SPLITTING                    │
       │    PBKDF2-HMAC-SHA256 (600,000 rounds, 16B Salt)        │
       │    ├── 256-bit AES Encryption Key (EncKey)              │
       │    └── 256-bit HMAC Integrity Key (MacKey)              │
       └────────────────────────────┬────────────────────────────┘
                                    │
                                    ▼
       ┌─────────────────────────────────────────────────────────┐
       │ 2. IN-PLACE 64 KB STREAM TRANSFORMATION                 │
       │    Transform 64 KB blocks directly on disk via AES-CTR  │
       │    0% extra disk space, zero temp file leakage          │
       └────────────────────────────┬────────────────────────────┘
                                    │
                                    ▼
       ┌─────────────────────────────────────────────────────────┐
       │ 3. HARDWARE WRITE BARRIER & CHECKPOINTING               │
       │    Flush transformed data to APFS / NVMe (fsync)        │
       │    Write 104-byte footer checkpoint & flush             │
       └────────────────────────────┬────────────────────────────┘
                                    │
                                    ▼
       ┌─────────────────────────────────────────────────────────┐
       │ 4. INTEGRITY SEALING (ENCRYPT-THEN-MAC)                 │
       │    Compute Master HMAC-SHA256 across entire ciphertext  │
       │    Seal footer with STATE_NORMAL_LOCKED                 │
       └─────────────────────────────────────────────────────────┘
```

---

### In-Place Streaming (0% Extra Storage Overhead)
Unlike standard archiving tools that extract contents to `/tmp`, Universal Vault operates **strictly in-place**:
* Reads a 64 KB block from disk $\to$ Encrypts or Decrypts via `AES-256-CTR` in RAM $\to$ Overwrites the transformed block to the **exact same disk sector**.
* **Zero temporary disk files**: Enables securing a 100 GB folder on an internal SSD with only 5 MB of free remaining space.

---

### Cryptographic Pipeline

1. **Key Derivation (KDF)**:
   * **Standard**: NIST SP 800-132 `PBKDF2-HMAC-SHA256`.
   * **Work Factor**: **600,000 iterations** (OWASP 2026 Gold Standard).
   * **Salt**: 16 cryptographically secure pseudo-random bytes generated via the Darwin kernel CSPRNG (`/dev/urandom` / `getentropy(2)`).
   * **Key Separation**: 512 derived bits split into 256-bit `EncKey` (AES-CTR) and 256-bit `MacKey` (HMAC-SHA256).

2. **Symmetric Encryption**:
   * `AES-256-CTR` (NIST SP 800-38A) streaming block cipher.
   * Every block receives a deterministic big-endian counter increment: $\text{Counter}_i = \text{Nonce} + i$.

3. **Authenticity & Anti-Tampering (Integrity)**:
   * Master `HMAC-SHA256` computed over 100% of the ciphertext payload (Encrypt-then-MAC / EtM standard).
   * Decryption verifies the master HMAC tag **before releasing or restoring plaintext**.

---

### 104-Byte Resumable Checkpoint Architecture

During active in-progress operations and crash recovery, Universal Vault appends a 104-byte binary trailer:

```text
┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬──────────────┬─────────────┬─────────────┐
│  Magic (8B)  │ChunkSize (4B)│  Salt (16B)  │  Nonce (16B) │MasterMAC(32B)│ AuthTag(16B) │Checkpoint(8B)│ Fails (2B)  │StateFlag(2B)│
│  "VAULTV05"  │  uint32 LE   │ Random Bytes │ Random Bytes │ HMAC-SHA256  │ HMAC-SHA256  │  uint64 LE   │  uint16 LE  │  uint16 LE  │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴──────────────┴─────────────┴─────────────┘
```

#### Two-Way Interruption Recovery Logic:
* **State 1 (`STATE_LOCK_IN_PROGRESS`)**:
  * If a lock operation is interrupted midway:
    * Running **`vault lock`**: Reads `Checkpoint`, derives the keystream counter, and resumes encrypting forward from where it stopped.
    * Running **`vault unlock`**: Detects the partially locked region, rolls back the ciphertext blocks back to plaintext, and restores your **100% original unencrypted file**.
* **State 2 (`STATE_UNLOCK_IN_PROGRESS`)**:
  * If an unlock operation is interrupted:
    * Running **`vault unlock`**: Automatically resumes decrypting forward from the last saved safe checkpoint.

---

### Hardware Flash Memory Write Barriers (APFS fsync)
On macOS APFS filesystems and NVMe flash drives, Universal Vault enforces a **two-phase hardware flush barrier**:
1. Writes transformed data chunk to disk.
2. Invokes POSIX `fsync(2)` to commit data blocks to physical flash.
3. Updates `CheckpointOffset` in the 104-byte footer and invokes `fsync(2)` on the metadata.
4. Physical syncs are throttled to 1 MB intervals to maximize throughput while bounding worst-case resume redos to $\le 1\text{ MB}$.

---

### Symlink Pruning & Path Safety
* **Protection**: Symbolic links pointing outside the target directory (e.g. to `/Applications`, `/Library`, or external volumes) are inspected with `os.Lstat()`. If `os.ModeSymlink` is detected, the engine **skips and prunes the link**, guaranteeing encryption never escapes the intended boundary.

---

## 3. Format Compatibility Matrix

Universal Vault CLI is **100% byte-compatible** with all platforms and formats:

| Format Version | Cipher & Mode | PBKDF2 Iterations | Trailer Length | Coverage | CLI Compatibility |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **V5.5.1 / V5.5** | `AES-256-CTR` + `HMAC-SHA256` | 600,000 iters | 104 Bytes | 100% Full-File AEAD | 🟢 **Native Lock, Unlock & Status** |
| **V5.0 Base** | `AES-256-CTR` + `HMAC-SHA256` | 600,000 iters | 96 Bytes | 100% Full-File AEAD | 🟢 **Native Unlock & Status** |
| **V4.x Legacy** | `AES-256-CBC` (Key Auth) | 100,000 iters | 80 Bytes | Hybrid (<50MB Full/Header) | 🟡 **Unlock via Python Engine** |
| **V1–V3 Legacy**| `AES-256-CBC` (Header) | 10,000–100,000 iters | 76–80 Bytes | Header-Only (64 KB) | 🟡 **Unlock via Python Engine** |

---
**Author**: [Adil Arbaz Khan](https://github.com/Adil-Arbaz-Khan)  
**License**: [MIT License](https://github.com/Adil-Arbaz-Khan/Universal-Vault/blob/main/LICENSE)

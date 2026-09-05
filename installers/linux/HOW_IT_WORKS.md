# ⚙️ How It Works & Architecture Guide (Linux Edition)

**Universal Vault CLI (Linux Engine)**  
*Under-the-Hood Architecture, Installer Internals, Safety Analysis & Cryptographic Deep Dive*

---

## 📖 Table of Contents
1. [Linux Installer Internals & Safety Analysis](#1-linux-installer-internals--safety-analysis)
   * [User-Space vs System-Wide Installation](#user-space-vs-system-wide-installation)
   * [Architecture Detection & Binary Selection](#architecture-detection--binary-selection)
   * [Is the Installer Safe? (Safety Audit)](#is-the-installer-safe-safety-audit)
   * [How Clean Uninstallation Works](#how-clean-uninstallation-works)
2. [Core CLI Engine Architecture](#2-core-cli-engine-architecture)
   * [In-Place Streaming (0% Extra Storage Overhead)](#in-place-streaming-0-extra-storage-overhead)
   * [Cryptographic Pipeline (600k PBKDF2 + AES-CTR + Master MAC)](#cryptographic-pipeline)
   * [104-Byte Resumable Checkpoint Architecture](#104-byte-resumable-checkpoint-architecture)
   * [Hardware Flash Memory Write Barriers (POSIX fsync)](#hardware-flash-memory-write-barriers)
   * [Symlink Pruning & Path Safety](#symlink-pruning--path-safety)
3. [Format Compatibility Matrix](#3-format-compatibility-matrix)

---

## 1. Linux Installer Internals & Safety Analysis

### User-Space vs System-Wide Installation
The installer dynamically adapts to privileges:
* **Standard User (Default / Non-Root)**:
  * Deploys to `$HOME/.local/bin/vault`.
  * **Zero Root/Sudo Privileges Required**: Completely contained inside the user's home directory.
  * Checks shell startup files (`~/.bashrc`, `~/.zshrc`, `~/.profile`) and safely appends `$HOME/.local/bin` to `$PATH` if missing.
* **System Administrator (`sudo ./install.sh`)**:
  * Deploys to standard system binary path `/usr/local/bin/vault`.
  * Automatically accessible globally for all user accounts on the machine.

---

### Architecture Detection & Binary Selection
`install.sh` queries the kernel machine hardware name via `uname -m`:
* `x86_64` / `amd64` $\to$ Deploys 64-bit AMD64 binary (`vault_linux_amd64`).
* `aarch64` / `arm64` $\to$ Deploys 64-bit ARM64 binary (`vault_linux_arm64`).

---

### Is the Installer Safe? (Safety Audit)

| Safety Property | Assessment | Technical Implementation |
| :--- | :--- | :--- |
| **Open Source & Transparent** | 🟢 **100% Transparent** | `install.sh` is a clean, standard 75-line POSIX Bash script with `set -euo pipefail`. |
| **Integrity & Copy Validation** | 🟢 **Checksum Gated** | Computes the SHA-256 hash before and after copying (`sha256sum`), ensuring bit-perfect file copy before declaring success. |
| **No Background Daemons** | 🟢 **Zero Background Tasks** | No `systemd` services, cron jobs, background processes, or telemetry agents are created. |
| **No Internet Connection** | 🟢 **100% Offline** | The installation process runs entirely offline and makes zero network requests. |
| **No Dynamic Runtime Glitches** | 🟢 **Statically Linked** | Compiled with `CGO_ENABLED=0`, meaning it runs seamlessly across glibc and musl (Alpine) systems without missing `.so` library errors. |
| **Non-Destructive** | 🟢 **Safe Isolation** | Installs exclusively to `~/.local/bin/vault` or `/usr/local/bin/vault`; never overwrites third-party packages. |
| **Silent Password Entry** | 🟢 **Shoulder-Surfing Safe** | Direct POSIX terminal mode (`stty -echo`) with signal traps ensures passwords never echo to the terminal. |

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
       │    Flush transformed data to NAND flash (POSIX fsync)   │
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
Unlike standard archiving tools (tar, 7z) that extract contents to `/tmp`, Universal Vault operates **strictly in-place**:
* Reads a 64 KB block from disk $\to$ Encrypts or Decrypts via `AES-256-CTR` in RAM $\to$ Overwrites the transformed block to the **exact same disk sector**.
* **Zero temporary disk files**: Allows securing a 100 GB database on a disk with only 5 MB of free remaining space.

---

### Cryptographic Pipeline

1. **Key Derivation (KDF)**:
   * **Standard**: NIST SP 800-132 `PBKDF2-HMAC-SHA256`.
   * **Work Factor**: **600,000 iterations** (OWASP 2026 Gold Standard).
   * **Salt**: 16 cryptographically secure pseudo-random bytes generated via Linux kernel CSPRNG (`/dev/urandom` / `getrandom(2)`).
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

| Magic (8B) | ChunkSize (4B) | Salt (16B) | Nonce (16B) | MasterMAC (32B) | AuthTag (16B) | Checkpoint (8B) | Fails (2B) | StateFlag (2B) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `"VAULTV05"` | `uint32` LE | Random Bytes | Random Bytes | HMAC-SHA256 | HMAC-SHA256 | `uint64` LE | `uint16` LE | `uint16` LE |

#### Two-Way Interruption Recovery Logic:
* **State 1 (`STATE_LOCK_IN_PROGRESS`)**:
  * If a lock operation is killed at 200 MB of a 500 MB file:
    * Running **`vault lock`**: Reads `Checkpoint=200MB`, derives keystream counter for block index $200\text{MB}/64\text{KB}$, and resumes encrypting forward from $200\text{MB} \to 500\text{MB}$.
    * Running **`vault unlock`**: Detects that only $0\dots200\text{MB}$ is ciphertext, decrypts $0\dots200\text{MB}$ back to plaintext, leaves $200\dots500\text{MB}$ untouched, truncates the footer, and restores the **100% original unencrypted file**.
* **State 2 (`STATE_UNLOCK_IN_PROGRESS`)**:
  * If an unlock operation is killed midway:
    * Running **`vault unlock`**: Resumes decrypting from the last checkpoint to completion.

---

### Hardware Flash Memory Write Barriers (POSIX fsync)
On external USB storage and server SSDs, write buffering could reorder writes. Universal Vault enforces a **two-phase hardware flush barrier**:
1. Writes transformed data chunk to disk.
2. Invokes POSIX `fsync(2)` to commit data blocks to physical flash.
3. Updates `CheckpointOffset` in the 104-byte footer and invokes `fsync(2)` on the metadata.
4. Physical syncs are throttled to 1 MB intervals to maximize throughput while bounding worst-case resume redos to $\le 1\text{ MB}$.

---

### Symlink Pruning & Path Safety
* **Protection**: Symbolic links pointing outside the target directory (e.g. to `/etc`, `/var`, or external mounts) are inspected with `os.Lstat()`. If `os.ModeSymlink` is detected, the engine **skips and prunes the link**, guaranteeing encryption never escapes the intended boundary.

---

## 3. Format Compatibility Matrix

Universal Vault CLI is **100% byte-compatible** with all platforms and formats:

| Format Version | Cipher & Mode | PBKDF2 Iterations | Trailer Length | Coverage | CLI Compatibility |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **V5.5.2 / V5.5+** | `AES-256-CTR` + `HMAC-SHA256` | 600,000 iters | 104 Bytes | 100% Full-File AEAD | 🟢 **Native Lock, Unlock & Status** |
| **V5.0 Base** | `AES-256-CTR` + `HMAC-SHA256` | 600,000 iters | 96 Bytes | 100% Full-File AEAD | 🟢 **Native Unlock & Status** |
| **V4.x Legacy** | `AES-256-CBC` (Key Auth) | 100,000 iters | 80 Bytes | Hybrid (<50MB Full/Header) | 🟡 **Unlock via Python Engine** |
| **V1–V3 Legacy**| `AES-256-CBC` (Header) | 10,000–100,000 iters | 76–80 Bytes | Header-Only (64 KB) | 🟡 **Unlock via Python Engine** |

---
**Author**: [Adil Arbaz Khan](https://github.com/Adil-Arbaz-Khan)  
**License**: [MIT License](https://github.com/Adil-Arbaz-Khan/Universal-Vault/blob/main/LICENSE)

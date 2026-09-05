# Universal Vault CLI v5.5.1 — Release Notes & Cryptographic Checksums

**Universal Vault** has evolved into a standalone, native, terminal-first CLI suite (`vault`) engineered in Go with zero external dependencies and 100% byte-perfect compatibility with existing Universal Vault files.

---

## 🔒 Cryptographic Provenance & Official Checksums (SHA-256)

To guarantee that your downloaded binary has not been tampered with or corrupted in transit, verify its SHA-256 checksum against this published reference:

### Windows (x86_64) — Phase 1 (Verified):
```text
dd55fb4af68e8ffed0c634416153cd67c9629691e3e4a08430cfe4ec0d755fa3  vault.exe
```
*Verification:* `Get-FileHash .\vault.exe -Algorithm SHA256`

### Linux (x86_64 & ARM64) — Phase 2 (Verified):
```text
999e93e8e98d51c7d80131e2abea80bc0d82193c336769f262c309528fa19f38  vault_linux_amd64
a57dcf73e4afa19c9879d003527b042045687fecb9627e635af0a2e798686eb9  vault_linux_arm64
```
*Verification (x86_64):* `sha256sum vault_linux_amd64`  
*Verification (ARM64):* `sha256sum vault_linux_arm64`

### macOS (Apple Silicon & Intel) — Phase 3 (Verified):
```text
498a12064c7823e4f9b067633a9e1aaa0148b619711af38e50ab29a4dd921eb1  vault_darwin_arm64
528466b7ef448d2f8e9907ff68c6d62fbca391bfeba4f5c7aca9cf6512549846  vault_darwin_amd64
```
*Verification (Apple Silicon):* `shasum -a 256 vault_darwin_arm64`  
*Verification (Intel Mac):* `shasum -a 256 vault_darwin_amd64`

*(Checksums for Android Native APK will be published sequentially upon completion of Phase 4.)*

---

## 🚀 Architectural Highlights

1. **Global Terminal Command (`vault`)**:
   * Windows 1-click installer (`install.bat`) automatically deploys `vault.exe` to `%LocalAppData%\UniversalVault\bin` and configures User `%PATH%`.
   * Usable from any directory across Command Prompt, PowerShell, Windows Terminal, and Git Bash without admin privileges.
2. **Silent Password Input (Zero Echo)**:
   * Interactive password prompts completely hide typed characters via Win32 Console mode (`ENABLE_ECHO_INPUT` disabled) and Unix `stty -echo`.
3. **100% In-Place Streaming (0% Extra Disk Space)**:
   * Transforms files directly in place via `AES-256-CTR` in 64 KB chunks. Zero unencrypted temporary file leakage.
4. **Crash-Safe Checkpointed Resumption**:
   * 104-byte resumable binary footer (`VAULTV05`) tracks physical progress pointers with hardware flash synchronization barriers (`FlushFileBuffers` / `fsync`).
5. **Authenticity & Integrity**:
   * Encrypt-then-MAC (`HMAC-SHA256`) master verification and 600,000 PBKDF2-SHA256 rounds (OWASP 2026 Gold Standard).

---
**Repository**: [https://github.com/Adil-Arbaz-Khan/Universal-Vault](https://github.com/Adil-Arbaz-Khan/Universal-Vault)  
**Author**: Adil Arbaz Khan

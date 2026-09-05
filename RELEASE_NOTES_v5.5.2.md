# Universal Vault v5.5.2 — Release Notes & Cryptographic Checksums

> **"Featherweight footprint. High-performance terminal CLI as primary. 100% portable when you need it."**

Universal Vault **v5.5.2** delivers our first **Native Android APK**, introducing zero-footprint sovereign encryption directly to mobile devices alongside our lightweight terminal-first CLI suite across **Windows**, **Linux**, and **macOS**.

---

## 🌟 What's New in v5.5.2

### 1. 📱 Native Android Application (`UniversalVault-v5.5.2.apk`)
* **Pure Kotlin Cryptographic Engine**: Bit-for-bit parity with desktop `VAULTV05` format — `AES-256-CTR` in 64 KB streaming blocks, 600,000 PBKDF2-HMAC-SHA256 iterations (OWASP Gold Standard), and full-file master `HMAC-SHA256` Encrypt-then-MAC authentication.
* **Storage Access Framework (SAF) In-Place Streaming**: Interacts directly with Android's storage provider via low-level `FileDescriptor` NIO channels (`FileDescriptorVaultChannel`), achieving **0% temporary disk overhead** and zero unencrypted data leakage into cache or temp folders.
* **Hardware Write Synchronization**: Employs POSIX `Os.fsync(fd)` barriers flushed on every 1 MB checkpoint, ensuring complete resilience against app termination or dead batteries with 104-byte resumable binary footer checkpoints.
* **Live Telemetry & UI**: Glassmorphic dark obsidian theme (`#06090F`), electric cyan accents (`#38BDF8`), and real-time telemetry tracking PBKDF2 computation, HMAC validation, throughput (MB/s), and countdown ETA.

### 2. 🎨 Custom Cybernetic Branding & Adaptive Icon Suite
* **Bespoke Logo**: High-resolution neon-cyan and electric-blue shield with an illuminated lock and circuit accents set against deep obsidian.
* **Adaptive Android Icons**: Full mipmap density suite (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`) with adaptive foregrounds and `#06090F` background.

### 3. 📦 Merged Android Release Bundle (`Universal-Vault-v5.5.2-Android.zip`)
* Combines the native Android APK (`UniversalVault-v5.5.2.apk`), the zero-install offline web viewer (`Vault_App.html`), and Termux CLI scripts into a single complete mobile package.
* Also offers standalone `UniversalVault-v5.5.2.apk` for 1-tap installation.

### 4. 🖥️ Global Terminal-First CLI Suite (v5.5.2)
* Version string bumped to `5.5.2` across Windows, Linux, and macOS native Go binaries.
* Statically compiled under 3 MB with **zero external dependencies**.
* Multi-phase progress bar with clean line erasure leaving no visual artifacts.

---

## 🔒 Official Cryptographic Checksums (SHA-256)

### Extracted Native CLI Binaries:
```text
b4ce2d3da7f6834d96bb8a3ea35389ccc8cd8b4bc0afdf515cb51b1230c00801  vault.exe (Windows x86_64)
b5831310c678003df21a71701dfeb5c2f125c1fd0f160c4c3da28cfb5efa218f  vault_linux_amd64 (Linux x86_64)
d9edca2c9fa7ad31c9e72da24c4e9ffc3eb6672a8f932167ab44809bcb2a8321  vault_linux_arm64 (Linux ARM64)
3fd7358e6b6dd80087e2325f102bbdf902c30d11f10c6ff8f77b5f6d38e8ce80  vault_darwin_arm64 (macOS Apple Silicon)
a2923a5069ec3eebc439d87e4cc056f82f13400cc2cd8f3a44b74cd64456d84c  vault_darwin_amd64 (macOS Intel)
```

### Standalone Android APK:
```text
6aa2ff6fea9d2b0982c5e7442f9892fe08177e3fcbe00f0cd27fc29c0f213d10  UniversalVault-v5.5.2.apk
```

---
**Repository**: [https://github.com/Adil-Arbaz-Khan/Universal-Vault](https://github.com/Adil-Arbaz-Khan/Universal-Vault)  
**Author**: Adil Arbaz Khan

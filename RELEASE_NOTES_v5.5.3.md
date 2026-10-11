# Universal Vault v5.5.3 — Release Notes & Cryptographic Checksums

> **Official Website & Live WebApp**: [https://universal-vault.pages.dev/](https://universal-vault.pages.dev/)  
> **"Featherweight footprint. High-performance terminal CLI as primary. 100% portable when you need it."**

Universal Vault **v5.5.3** delivers full cross-platform filename masking (**Gibberish File Name Formatting**), disguising encrypted filenames to randomized 16-hex hashes across all platforms (Go Native CLI, Python Engine, PowerShell Engine, WebApp, and Native Android App), coupled with synchronized **v5.5.3** terminal banners and application badges across all operating systems.

---

## 🌟 What's New in v5.5.3

### 1. 🔀 Gibberish Filename Masking Across All Platforms
* **Zero-Leakage Filename Masking**: Encrypted files can now be disguised to randomized 16-hex lowercase strings with `.vault` extension (e.g. `e4f1a08b9c2d3e4f.vault`), preventing metadata disclosure, extension profiling, or shoulder-surfing.
* **104-Byte Binary Footer Integration**: Original filenames are safely preserved inside the 104-byte cryptographic footer using bitflag `FlagGibberishName = 4`, authenticated under master `HMAC-SHA256` AEAD.
* **Seamless In-Place Restoration**: Upon valid password entry during unlock, the engine automatically restores the file's original plaintext name and extension in-place.
* **CLI & Interactive Flags**:
  * Native CLI: `vault lock <path> -g` or `vault lock <path> --gibberish`
  * Python Engine: `python tools/vault.py lock <path> -g`
  * PowerShell Engine: `.\tools\header_vault.ps1 -Action Lock -Path <path> -Gibberish`
  * Launchers: Interactive option in `Lock.bat` and CLI flag in `lock.sh`
  * WebApp: Interactive Gibberish toggle in `Vault_App.html`
  * Android App: In-app gibberish toggle in `VaultScreen.kt`

### 2. 📱 Synchronized Universal Version Display (v5.5.3)
* **Android Application**: Bumped to `versionName "5.5.3"` and `versionCode 5530`, with `v5.5.3` version pill badge in the brand header.
* **Native CLI Binaries**: Go architecture updated to `v5.5.3` across Windows, Linux, and macOS.
* **Python & PowerShell Engines**: Banners and `--version` / `version` CLI flags updated to `v5.5.3`.
* **Platform Launchers**: `Lock.bat`, `Unlock.bat`, `Status.bat`, `lock.sh`, `unlock.sh`, `status.sh` synchronized to display `V5.5.3`.
* **Air-Gapped WebApp**: `Vault_App.html` header pill updated to `v5.5.3`.

### 3. 📦 Official Release Bundles (`releases_v5.5.3`)
* Complete standalone package archives for Windows, Linux, macOS, Android, iOS, and Universal.
* Standalone `UniversalVault-v5.5.3.apk` ready for direct mobile installation.

---

## 🔒 Official Cryptographic Checksums (SHA-256)

### Release Package Archives (ZIP):
```text
03a0b97d616c8e4034c8b8b62909a7c74f4f586ca93e7b990fa0b422b988e872  Universal-Vault-v5.5.3-Windows.zip
d063ae0ce7b32e4d6e2ef72fa1fc3632a9efff02ac1fda96ecfad7030bf20ad5  Universal-Vault-v5.5.3-Linux.zip
9a7181bc2d70b8f1759e43dacfc1c0eef154e5d0d9cc873147c63fcae878140d  Universal-Vault-v5.5.3-macOS.zip
bcc16edbe85eb3843543c05db1b04ef75b364ba24d0045862b5b91ccdffd0f24  Universal-Vault-v5.5.3-Android.zip
180911e3a8e4fa19d5477345eacb5a243aa4b2f9e3da316be3583d58ace64435  Universal-Vault-v5.5.3-iOS.zip
9a68a3b42a8f5406a413bd81729f5a37fc813f8bad1ac82bfafb089f364dcb7e  Universal-Vault-v5.5.3-Universal.zip
```

### Standalone Android APK:
```text
6f106c7d69ebfd8202e066c71904debfe9fe4090923310a542416d38de9a8065  UniversalVault-v5.5.3.apk
```

### Native CLI Binaries:
```text
eac39193ede2aabfa91a293ac9a97936828ce7a842a351cfbe184e8281af7960  vault.exe (Windows x86_64)
60e5966eb8175c092d55d7cd1e521f78ce797bef27d99744510e799c07380ab1  vault_linux_amd64 (Linux x86_64)
799ffeb11c2bc1a68499468a83098481b42298adbeef6c2318b63dd4faf73e77  vault_linux_arm64 (Linux ARM64)
eaf90f2b28acd879796ed618e5d8c82a569ee38e9794943bf5298df97f3325f0  vault_darwin_arm64 (macOS Apple Silicon)
94c10f41a670268fdbe048278b3f5dba091f0c89fb2e8420778a30efd21fe7b9  vault_darwin_amd64 (macOS Intel)
```

---
**Repository**: [https://github.com/Adil-Arbaz-Khan/Universal-Vault](https://github.com/Adil-Arbaz-Khan/Universal-Vault)  
**Website**: [https://universal-vault.pages.dev/](https://universal-vault.pages.dev/)  
**Author**: Adil Arbaz Khan

# Universal Vault v5.5.21 — Release Notes & Cryptographic Checksums

> **Official Website & Live WebApp**: [https://universal-vault.pages.dev/](https://universal-vault.pages.dev/)  
> **"Featherweight footprint. High-performance terminal CLI as primary. 100% portable when you need it."**

Universal Vault **v5.5.21** brings major enhancements across both mobile and web ecosystems, introducing a real-time mathematical Shannon password entropy meter, dark/light theme switching, mobile-optimized responsive layouts, and the updated Native Android Release APK.

---

## 🌟 What's New in v5.5.21

### 1. 📱 Native Android APK (`UniversalVault-v5.5.21.apk`)
* **Real-Time Password Strength Meter**: Integrates dynamic entropy calculation giving instant visual feedback on password complexity.
* **Dark / Light Mode**: Adds theme preferences with instant switching, perfectly complementing system light and dark environments.
* **Updated Build**: Bumped to `versionName "5.5.21"` and `versionCode 5521`.
* **100% SAF In-Place Streaming**: Pure Kotlin cryptographic engine running `AES-256-CTR` with 600,000 PBKDF2 rounds (OWASP Gold Standard), master `HMAC-SHA256` AEAD (EtM), and POSIX `Os.fsync` hardware write barriers.

### 2. 🌐 Modernized Air-Gapped WebApp (`Vault_App.html`)
* **Live Deployment & Offline Portability**: Hosted at [universal-vault.pages.dev/app/](https://universal-vault.pages.dev/app/) and packaged as a standalone offline HTML application.
* **Shannon Password Entropy Meter**: Evaluates character-space variety ($N$) and length ($L$) in real time ($E = L \log_2(N)$) with color-coded classification:
  * 🔴 Weak (<40 bits)
  * 🟡 Moderate (40–60 bits)
  * 🔵 Strong (60–80 bits)
  * 🟢 High-Assurance (80+ bits)
* **Dark / Light Mode Toggle**: Obsidian cybernetic dark mode and crisp light mode, synced with OS preferences and saved in `localStorage`.
* **Mobile-Optimized Responsive Layout**: Redesigned compact mobile footer, optimized viewports, and clean touch targets for smartphone and tablet browsers.
* **Air-Gapped Zero-Trust CSP**: Strict Content Security Policy (`default-src 'none'`) ensuring zero network requests, zero telemetry, and zero data leakage.
* **Volatile RAM Streaming Player**: Playback of 4K video, audio, PDFs, and images completely in browser memory via transient Object URLs with zero unencrypted disk footprint.

### 3. 📦 Platform Release Bundles (v5.5.21)
* Updated all platform archives (`Android`, `iOS`, `Linux`, `macOS`, `Universal`, `Windows`) with the new `Vault_App.html`, updated release documentation, official website links, and the v5.5.21 Android APK.

---

## 🔒 Official Cryptographic Checksums (SHA-256)

### Native Android APK:
```text
a491cfb5208668351562afdcd0493e991f03c3fa1ecbdaeafc8ffdcd68d26ff9  UniversalVault-v5.5.21.apk
```

### Native CLI Binaries:
```text
b4ce2d3da7f6834d96bb8a3ea35389ccc8cd8b4bc0afdf515cb51b1230c00801  vault.exe (Windows x86_64)
b5831310c678003df21a71701dfeb5c2f125c1fd0f160c4c3da28cfb5efa218f  vault_linux_amd64 (Linux x86_64)
d9edca2c9fa7ad31c9e72da24c4e9ffc3eb6672a8f932167ab44809bcb2a8321  vault_linux_arm64 (Linux ARM64)
3fd7358e6b6dd80087e2325f102bbdf902c30d11f10c6ff8f77b5f6d38e8ce80  vault_darwin_arm64 (macOS Apple Silicon)
a2923a5069ec3eebc439d87e4cc056f82f13400cc2cd8f3a44b74cd64456d84c  vault_darwin_amd64 (macOS Intel)
```

---
**Repository**: [https://github.com/Adil-Arbaz-Khan/Universal-Vault](https://github.com/Adil-Arbaz-Khan/Universal-Vault)  
**Website**: [https://universal-vault.pages.dev/](https://universal-vault.pages.dev/)  
**Author**: Adil Arbaz Khan

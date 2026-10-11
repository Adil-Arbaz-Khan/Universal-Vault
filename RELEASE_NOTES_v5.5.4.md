# Universal Vault v5.5.4 — Lightweight Sovereign Encryption & Native Suite

> **Official Website & Live WebApp**: [https://universal-vault.pages.dev/](https://universal-vault.pages.dev/)  
Universal Vault **v5.5.4** introduces **Volatile RAM Streaming (`vault view` / Stream in RAM)** across both the native Terminal CLIs and the Android application, enabling users to inspect and preview encrypted documents, code, images, audio, and video directly from volatile memory with **absolute zero plaintext writes to physical disk**.

---

## 🌟 What's New in v5.5.4

### 1. ⚡ Volatile RAM Streaming & Zero-Disk Forensics (`vault view`)
* **Terminal Native Streamer**: Inspect encrypted files without modifying or extracting plaintext to physical disk.
  * **Text & Code Files**: Displayed directly in terminal stdout with immediate heap zeroization upon completion.
  * **Rich Media & Documents (Images, 4K Video, Audio, PDF)**: CLI automatically spawns an ephemeral loopback HTTP server (`http://127.0.0.1:<port>/<token>/<filename>`) with dynamic OS port allocation and an unguessable 16-hex session token. Launches the system default browser with full HTTP 206 Partial Content (range requests) for seamless video seeking. RAM is securely purged and zeroized upon pressing Enter or closing the session.
  * **Disguised Filename Resolution**: Automatically recovers the original filename and MIME type from the 104-byte footer when streaming files masked with gibberish names.
  * **Commands**: `vault view <path>` (Go Native CLI), `python tools/vault.py view <path>`, `View.bat` (Windows), and `view.sh` (Linux/macOS/Termux).

### 2. 📱 Android Volatile RAM Streamer & Hardware-Accelerated External Playback
* **Hardware-Accelerated External Streaming**: Seamlessly stream decrypted rich media (videos, audio, PDFs) to external apps (VLC, MX Player, Photos, Chrome, Acrobat) via Android's secure `FileProvider` with exact MIME detection and decrypted original title restoration.
* **Expanded Memory Capacity & Large Heap**: Enabled `android:largeHeap="true"`, allowing up to 1 GB volatile streaming on modern devices.
* **RAM Overload & OOM Safeguards**: Dynamic heap capacity analysis and allocation error guards that politely notify the user when device memory is constrained rather than crashing.
* **Volatile Stream Session Manager**: In-app text viewer with live search and lines inspection; 180s auto-wipe countdown timer and instant red 'PANIC WIPE' button that zeroes buffers (`bytes.fill(0)`) and shreds temporary cache files with zeroed blocks.

### 3. 🛡️ WebApp Gibberish Resumability Fix (`Vault_App.html`)
* **State Bitmask Separation**: Resolved an issue where files locked with `-g` (`FlagGibberishName = 4`) were mistakenly flagged as interrupted operations during web decryption. The check now isolates operational state bits (`opState & 3`), enabling flawless 100% roundtrip decryption and streaming in WebCrypto.

### 4. 📱 Synchronized Universal Version Display (v5.5.4)
* **Android Application**: Synchronized to `versionName "5.5.4"` and `versionCode 5540`, with `v5.5.4` badge in the header.
* **Native CLI Binaries**: Go architecture updated to `v5.5.4` across Windows, Linux, and macOS.
* **Python & PowerShell Engines**: Banners and `--version` / `version` flags updated to `v5.5.4`.
* **Platform Launchers**: `Lock.bat`, `Unlock.bat`, `Status.bat`, `View.bat`, `lock.sh`, `unlock.sh`, `status.sh`, `view.sh` synchronized to display `V5.5.4`.
* **Air-Gapped WebApp**: `Vault_App.html` header pill updated to `v5.5.4`.

### 5. 📦 Official Release Bundles (`releases_v5.5.4`)
* Standalone `UniversalVault-v5.5.4.apk` ready for direct mobile installation.
* All platform archives (`Android`, `iOS`, `Linux`, `macOS`, `Universal`, `Windows`) updated with the new streaming utilities, `View.bat`, `view.sh`, and documentation.

---

## 🔒 Official Cryptographic Checksums (SHA-256)

### Release Package Archives (ZIP):
```text
d5797a0ac5eaf990d86e329de0b2a08a4d439c28fa6f4cae614864984a0f7ec5  Universal-Vault-v5.5.4-Windows.zip
6fe4f1d1d7bf0aa6556ab92a141bbb4f55a1114a46de858e9ff21be8eb089bac  Universal-Vault-v5.5.4-Linux.zip
46a7640ad293ae58f2afddaf4f6df8e2f0b8e35058ba6b05f7ba8e927895131b  Universal-Vault-v5.5.4-macOS.zip
e9429dc0cb652490542132fbcca984eaeeff3967d799c4c739181cabdc72e46a  Universal-Vault-v5.5.4-Android.zip
dbe9b9a314fe24c5dcbdeb596ecaec0d0632669693dad12a6e8cc93d9df15efd  Universal-Vault-v5.5.4-iOS.zip
1e60596b77f60e741993ee93fb20ea65640efc225eec2f6c9f0af1cbc68cd978  Universal-Vault-v5.5.4-Universal.zip
```

### Standalone Android APK:
```text
c5be129cb27784c97d546c8d1826f17cb2aba9490a23028cd8bf8a78f06cb4f0  UniversalVault-v5.5.4.apk
```

### Extracted Native CLI Binaries:
```text
3aa674d54d8fcb37828e9920dfa558b76198036edf1aad39711e6dd69839753f  vault.exe (Windows x86_64)
8a3b1fb7ffda088f0e0dc53de83e654f7042552553a915f0d3ba468321ec06be  vault_linux_amd64 (Linux x86_64)
1724b5df89e3c872e5ecd4c25ace4532266fba10b24b6324731f8ba292d698b6  vault_linux_arm64 (Linux ARM64)
6487fcfaa84989fb4921b92bfeb722aa058e99db1d86486e2ad28f8ad1d68e34  vault_darwin_arm64 (macOS Apple Silicon)
465f775e8dfd42aa0a82ebe0edb0e8e58d3281a86802d6154d6164f229339110  vault_darwin_amd64 (macOS Intel)
```

---

## 🚀 Quick Download & Install

* **Windows Users**: Download **`Universal-Vault-v5.5.4-Windows.zip`**, extract, and double-click **`install.bat`**.
* **Linux Users**: Download **`Universal-Vault-v5.5.4-Linux.zip`**, extract, and run `./install.sh`.
* **macOS Users**: Download **`Universal-Vault-v5.5.4-macOS.zip`**, extract, and run `./install.sh`.
* **Android Users**: Download and install **`UniversalVault-v5.5.4.apk`** (or download **`Universal-Vault-v5.5.4-Android.zip`** which bundles the APK + portable web viewer + Termux scripts).
* **iOS / Browser Users**: Download **`Universal-Vault-v5.5.4-iOS.zip`** or open [https://universal-vault.pages.dev/app/](https://universal-vault.pages.dev/app/).

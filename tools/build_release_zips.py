#!/usr/bin/env python3
"""
Universal Vault v5.5.3 Release Packager
Generates official release zip archives for Windows, Linux, macOS, Android, iOS, and Universal.
Also emits SHA256SUMS.txt and GITHUB_RELEASE_TEMPLATE.md inside releases_v5.5.3.
"""

import os
import zipfile
import shutil
import hashlib

VERSION = "5.5.4"
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT_DIR, f"releases_v{VERSION}")

if os.path.exists(OUT_DIR):
    shutil.rmtree(OUT_DIR)
os.makedirs(OUT_DIR, exist_ok=True)

def sha256_file(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def make_zip(zip_name, file_map, custom_files=None):
    zip_path = os.path.join(OUT_DIR, zip_name)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for src_path, arc_name in file_map:
            if os.path.isfile(src_path):
                # Ensure POSIX permissions are preserved for shell scripts and executables
                z_info = zipfile.ZipInfo.from_file(src_path, arc_name)
                if arc_name.endswith((".sh", "vault", "vault_linux_amd64", "vault_linux_arm64", "vault_darwin_amd64", "vault_darwin_arm64")):
                    z_info.external_attr = 0o755 << 16
                with open(src_path, "rb") as f:
                    z.writestr(z_info, f.read())
        if custom_files:
            for arc_name, content in custom_files.items():
                z.writestr(arc_name, content)
    
    size_mb = os.path.getsize(zip_path) / (1024 * 1024)
    file_hash = sha256_file(zip_path)
    print(f"[+] Created: {zip_name:<40} ({size_mb:5.2f} MB) | SHA256: {file_hash[:16]}...")
    return zip_name, file_hash

print("======================================================================")
print(f"  Packaging Universal Vault v{VERSION} Official Release Archives")
print("======================================================================")

packages = []

# 1. Windows Package
win_files = [
    (os.path.join(ROOT_DIR, "installers", "windows", "install.bat"), "install.bat"),
    (os.path.join(ROOT_DIR, "installers", "windows", "uninstall.bat"), "uninstall.bat"),
    (os.path.join(ROOT_DIR, "installers", "windows", "vault.exe"), "vault.exe"),
    (os.path.join(ROOT_DIR, "installers", "windows", "README.md"), "README.md"),
    (os.path.join(ROOT_DIR, "installers", "windows", "HOW_IT_WORKS.md"), "HOW_IT_WORKS.md"),
    (os.path.join(ROOT_DIR, "installers", "windows", "SHA256SUMS.txt"), "SHA256SUMS.txt"),
    (os.path.join(ROOT_DIR, "Lock.bat"), "portable/Lock.bat"),
    (os.path.join(ROOT_DIR, "Unlock.bat"), "portable/Unlock.bat"),
    (os.path.join(ROOT_DIR, "Status.bat"), "portable/Status.bat"),
    (os.path.join(ROOT_DIR, "View.bat"), "portable/View.bat"),
    (os.path.join(ROOT_DIR, "Vault_App.html"), "portable/Vault_App.html"),
    (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
]
packages.append(make_zip(f"Universal-Vault-v{VERSION}-Windows.zip", win_files))

# 2. Linux Package
linux_files = [
    (os.path.join(ROOT_DIR, "installers", "linux", "install.sh"), "install.sh"),
    (os.path.join(ROOT_DIR, "installers", "linux", "uninstall.sh"), "uninstall.sh"),
    (os.path.join(ROOT_DIR, "installers", "linux", "vault_linux_amd64"), "vault_linux_amd64"),
    (os.path.join(ROOT_DIR, "installers", "linux", "vault_linux_arm64"), "vault_linux_arm64"),
    (os.path.join(ROOT_DIR, "installers", "linux", "README.md"), "README.md"),
    (os.path.join(ROOT_DIR, "installers", "linux", "HOW_IT_WORKS.md"), "HOW_IT_WORKS.md"),
    (os.path.join(ROOT_DIR, "installers", "linux", "SHA256SUMS.txt"), "SHA256SUMS.txt"),
    (os.path.join(ROOT_DIR, "lock.sh"), "portable/lock.sh"),
    (os.path.join(ROOT_DIR, "unlock.sh"), "portable/unlock.sh"),
    (os.path.join(ROOT_DIR, "status.sh"), "portable/status.sh"),
    (os.path.join(ROOT_DIR, "view.sh"), "portable/view.sh"),
    (os.path.join(ROOT_DIR, "Vault_App.html"), "portable/Vault_App.html"),
    (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
]
packages.append(make_zip(f"Universal-Vault-v{VERSION}-Linux.zip", linux_files))

# 3. macOS Package
macos_files = [
    (os.path.join(ROOT_DIR, "installers", "macos", "install.sh"), "install.sh"),
    (os.path.join(ROOT_DIR, "installers", "macos", "uninstall.sh"), "uninstall.sh"),
    (os.path.join(ROOT_DIR, "installers", "macos", "vault_darwin_arm64"), "vault_darwin_arm64"),
    (os.path.join(ROOT_DIR, "installers", "macos", "vault_darwin_amd64"), "vault_darwin_amd64"),
    (os.path.join(ROOT_DIR, "installers", "macos", "README.md"), "README.md"),
    (os.path.join(ROOT_DIR, "installers", "macos", "HOW_IT_WORKS.md"), "HOW_IT_WORKS.md"),
    (os.path.join(ROOT_DIR, "installers", "macos", "SHA256SUMS.txt"), "SHA256SUMS.txt"),
    (os.path.join(ROOT_DIR, "lock.sh"), "portable/lock.sh"),
    (os.path.join(ROOT_DIR, "unlock.sh"), "portable/unlock.sh"),
    (os.path.join(ROOT_DIR, "status.sh"), "portable/status.sh"),
    (os.path.join(ROOT_DIR, "view.sh"), "portable/view.sh"),
    (os.path.join(ROOT_DIR, "Vault_App.html"), "portable/Vault_App.html"),
    (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
]
packages.append(make_zip(f"Universal-Vault-v{VERSION}-macOS.zip", macos_files))

# 4. Android Package (Native APK + Web PWA + Termux CLI)
android_readme = (
    f"Universal Vault v{VERSION} — Android Release\n"
    "=========================================\n\n"
    "1. NATIVE ANDROID APPLICATION (Recommended)\n"
    f"   File: UniversalVault-v{VERSION}.apk\n"
    "   - Install: Open this APK directly on your Android phone to install.\n"
    "   - 100% in-place sovereign encryption via Storage Access Framework (SAF).\n"
    "   - Volatile RAM Streamer: View images & documents directly in RAM with zero disk writes.\n"
    "   - 600,000 PBKDF2-HMAC-SHA256 iterations (OWASP Gold Standard).\n"
    "   - Filename Gibberish Masking (-g / --gibberish) toggle built-in.\n"
    "   - Hardware write barrier synchronization (Os.fsync) & crash resumption.\n"
    "   - Live telemetry: speed (MB/s) and ETA countdown.\n\n"
    "2. PORTABLE OFFLINE WEB APPLICATION\n"
    "   File: Vault_App.html\n"
    "   - Open in Chrome, Brave, Firefox, or Edge.\n"
    "   - Stream encrypted 4K video, audio, and documents in RAM with zero disk writes.\n\n"
    "3. TERMUX CLI SCRIPTS (Advanced)\n"
    "   Run ./tools/setup_termux.sh, then lock.sh / unlock.sh / view.sh / status.sh.\n"
)

android_files = [
    (os.path.join(ROOT_DIR, "bin", "android", f"UniversalVault-v{VERSION}.apk"), f"UniversalVault-v{VERSION}.apk"),
    (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
    (os.path.join(ROOT_DIR, "lock.sh"), "lock.sh"),
    (os.path.join(ROOT_DIR, "unlock.sh"), "unlock.sh"),
    (os.path.join(ROOT_DIR, "status.sh"), "status.sh"),
    (os.path.join(ROOT_DIR, "view.sh"), "view.sh"),
    (os.path.join(ROOT_DIR, "tools", "vault.py"), "tools/vault.py"),
    (os.path.join(ROOT_DIR, "tools", "setup_termux.sh"), "tools/setup_termux.sh"),
    (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
    (os.path.join(ROOT_DIR, "SECURITY.md"), "SECURITY.md"),
]
packages.append(make_zip(f"Universal-Vault-v{VERSION}-Android.zip", android_files, custom_files={"README.txt": android_readme}))

# 5. iOS Package (PWA)
ios_files = [
    (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
    (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
]
packages.append(make_zip(f"Universal-Vault-v{VERSION}-iOS.zip", ios_files))

# 6. Universal All-Platforms Package
universal_files = [
    (os.path.join(ROOT_DIR, "README.md"), "README.md"),
    (os.path.join(ROOT_DIR, "SECURITY.md"), "SECURITY.md"),
    (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
    (os.path.join(ROOT_DIR, "CONTRIBUTING.md"), "CONTRIBUTING.md"),
    (os.path.join(ROOT_DIR, f"RELEASE_NOTES_v{VERSION}.md"), f"RELEASE_NOTES_v{VERSION}.md"),
    (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
    (os.path.join(ROOT_DIR, "Lock.bat"), "Lock.bat"),
    (os.path.join(ROOT_DIR, "Unlock.bat"), "Unlock.bat"),
    (os.path.join(ROOT_DIR, "Status.bat"), "Status.bat"),
    (os.path.join(ROOT_DIR, "View.bat"), "View.bat"),
    (os.path.join(ROOT_DIR, "lock.sh"), "lock.sh"),
    (os.path.join(ROOT_DIR, "unlock.sh"), "unlock.sh"),
    (os.path.join(ROOT_DIR, "status.sh"), "status.sh"),
    (os.path.join(ROOT_DIR, "view.sh"), "view.sh"),
    (os.path.join(ROOT_DIR, "tools", "vault.py"), "tools/vault.py"),
    (os.path.join(ROOT_DIR, "tools", "header_vault.ps1"), "tools/header_vault.ps1"),
    (os.path.join(ROOT_DIR, "tools", "setup_termux.sh"), "tools/setup_termux.sh"),
]

for folder in ["cmd", "bin", "installers", "Test_Samples"]:
    folder_p = os.path.join(ROOT_DIR, folder)
    if os.path.exists(folder_p):
        for root, dirs, files in os.walk(folder_p):
            for f in files:
                # In bin/android, only include current version APK to prevent archive bloat
                if "bin" in root and "android" in root and f.startswith("UniversalVault-") and f != f"UniversalVault-v{VERSION}.apk":
                    continue
                full_p = os.path.join(root, f)
                rel_p = os.path.relpath(full_p, ROOT_DIR)
                universal_files.append((full_p, rel_p))

packages.append(make_zip(f"Universal-Vault-v{VERSION}-Universal.zip", universal_files))

# Copy standalone Android APK to release directory
apk_src = os.path.join(ROOT_DIR, "bin", "android", f"UniversalVault-v{VERSION}.apk")
apk_dst = os.path.join(OUT_DIR, f"UniversalVault-v{VERSION}.apk")
apk_hash = None
if os.path.exists(apk_src):
    shutil.copy2(apk_src, apk_dst)
    apk_hash = sha256_file(apk_dst)
    print(f"[+] Copied Standalone APK: UniversalVault-v{VERSION}.apk | SHA256: {apk_hash[:16]}...")

# Write SHA256SUMS.txt for the release packages
sums_path = os.path.join(OUT_DIR, "SHA256SUMS.txt")
with open(sums_path, "w", encoding="utf-8") as f:
    for name, h in packages:
        f.write(f"{h}  {name}\n")
    if apk_hash:
        f.write(f"{apk_hash}  UniversalVault-v{VERSION}.apk\n")

print("\n[+] Wrote release checksums to:", sums_path)

# Query native CLI hashes from installers/
cli_hashes = {}
for plat, fname in [
    ("Windows x86_64", os.path.join(ROOT_DIR, "installers", "windows", "vault.exe")),
    ("Linux x86_64", os.path.join(ROOT_DIR, "installers", "linux", "vault_linux_amd64")),
    ("Linux ARM64", os.path.join(ROOT_DIR, "installers", "linux", "vault_linux_arm64")),
    ("macOS Apple Silicon", os.path.join(ROOT_DIR, "installers", "macos", "vault_darwin_arm64")),
    ("macOS Intel", os.path.join(ROOT_DIR, "installers", "macos", "vault_darwin_amd64")),
]:
    if os.path.exists(fname):
        cli_hashes[os.path.basename(fname)] = (plat, sha256_file(fname))

# Write GITHUB_RELEASE_TEMPLATE.md
template_path = os.path.join(OUT_DIR, "GITHUB_RELEASE_TEMPLATE.md")
with open(template_path, "w", encoding="utf-8") as f:
    f.write(f"# Universal Vault v{VERSION} — Lightweight Sovereign Encryption & Native Suite\n\n")
    f.write("> **Official Website & Live WebApp**: [https://universal-vault.pages.dev/](https://universal-vault.pages.dev/)  \n")
    f.write(f"Universal Vault **v{VERSION}** introduces **Volatile RAM Streaming (`vault view` / Stream in RAM)** across both the native Terminal CLIs and the Android application, enabling users to inspect and preview encrypted documents, code, images, audio, and video directly from volatile memory with **absolute zero plaintext writes to physical disk**.\n\n")
    f.write("---\n\n")
    f.write(f"## 🌟 What's New in v{VERSION}\n\n")
    f.write("### 1. ⚡ Volatile RAM Streaming & Zero-Disk Forensics (`vault view`)\n")
    f.write("* **Terminal Native Streamer**: Inspect encrypted files without modifying or extracting plaintext to physical disk.\n")
    f.write("  * **Text & Code Files**: Displayed directly in terminal stdout with immediate heap zeroization upon completion.\n")
    f.write("  * **Rich Media & Documents (Images, 4K Video, Audio, PDF)**: CLI automatically spawns an ephemeral loopback HTTP server (`http://127.0.0.1:<port>/<token>/<filename>`) with dynamic OS port allocation and an unguessable 16-hex session token. Launches the system default browser with full HTTP 206 Partial Content (range requests) for seamless video seeking. RAM is securely purged and zeroized upon pressing Enter or closing the session.\n")
    f.write("  * **Disguised Filename Resolution**: Automatically recovers the original filename and MIME type from the 104-byte footer when streaming files masked with gibberish names.\n")
    f.write("  * **Commands**: `vault view <path>` (Go Native CLI), `python tools/vault.py view <path>`, `View.bat` (Windows), and `view.sh` (Linux/macOS/Termux).\n\n")
    f.write("### 2. 📱 Android In-App RAM Streamer & Auto-Wipe Panic Protocol\n")
    f.write("* **In-App RAM Previewer**: Added **'STREAM IN RAM'** action in the native Jetpack Compose UI.\n")
    f.write("* **Supported Formats**: Direct in-memory rendering of images (`BitmapFactory.decodeByteArray`) and scrollable text/code documents directly from heap.\n")
    f.write("* **Emergency Panic Protocol**: 180-second countdown timer that automatically closes the modal and overwrites the memory buffer with zeros (`bytes.fill(0)`), plus a manual one-tap **'WIPE RAM'** panic button.\n")
    f.write("* **Air-Gapped Sovereign Design**: Refuses to broadcast plaintext buffers to external third-party apps, maintaining complete sovereign isolation.\n\n")
    f.write("### 3. 🛡️ WebApp Gibberish Resumability Fix (`Vault_App.html`)\n")
    f.write("* **State Bitmask Separation**: Resolved an issue where files locked with `-g` (`FlagGibberishName = 4`) were mistakenly flagged as interrupted operations during web decryption. The check now isolates operational state bits (`opState & 3`), enabling flawless 100% roundtrip decryption and streaming in WebCrypto.\n\n")
    f.write(f"### 4. 📱 Synchronized Universal Version Display (v{VERSION})\n")
    f.write(f'* **Android Application**: Synchronized to `versionName "{VERSION}"` and `versionCode 5540`, with `v{VERSION}` badge in the header.\n')
    f.write(f"* **Native CLI Binaries**: Go architecture updated to `v{VERSION}` across Windows, Linux, and macOS.\n")
    f.write(f"* **Python & PowerShell Engines**: Banners and `--version` / `version` flags updated to `v{VERSION}`.\n")
    f.write(f"* **Platform Launchers**: `Lock.bat`, `Unlock.bat`, `Status.bat`, `View.bat`, `lock.sh`, `unlock.sh`, `status.sh`, `view.sh` synchronized to display `V{VERSION}`.\n")
    f.write(f"* **Air-Gapped WebApp**: `Vault_App.html` header pill updated to `v{VERSION}`.\n\n")
    f.write(f"### 5. 📦 Official Release Bundles (`releases_v{VERSION}`)\n")
    f.write(f"* Standalone `UniversalVault-v{VERSION}.apk` ready for direct mobile installation.\n")
    f.write(f"* All platform archives (`Android`, `iOS`, `Linux`, `macOS`, `Universal`, `Windows`) updated with the new streaming utilities, `View.bat`, `view.sh`, and documentation.\n\n")
    f.write("---\n\n")
    f.write("## 🔒 Official Cryptographic Checksums (SHA-256)\n\n")
    f.write("### Release Package Archives (ZIP):\n```text\n")
    for name, h in packages:
        f.write(f"{h}  {name}\n")
    f.write("```\n\n")
    f.write("### Standalone Android APK:\n```text\n")
    if apk_hash:
        f.write(f"{apk_hash}  UniversalVault-v{VERSION}.apk\n")
    f.write("```\n\n")
    f.write("### Extracted Native CLI Binaries:\n```text\n")
    for fname, (plat, h) in cli_hashes.items():
        f.write(f"{h}  {fname} ({plat})\n")
    f.write("```\n\n")
    f.write("---\n\n")
    f.write("## 🚀 Quick Download & Install\n\n")
    f.write(f"* **Windows Users**: Download **`Universal-Vault-v{VERSION}-Windows.zip`**, extract, and double-click **`install.bat`**.\n")
    f.write(f"* **Linux Users**: Download **`Universal-Vault-v{VERSION}-Linux.zip`**, extract, and run `./install.sh`.\n")
    f.write(f"* **macOS Users**: Download **`Universal-Vault-v{VERSION}-macOS.zip`**, extract, and run `./install.sh`.\n")
    f.write(f"* **Android Users**: Download and install **`UniversalVault-v{VERSION}.apk`** (or download **`Universal-Vault-v{VERSION}-Android.zip`** which bundles the APK + portable web viewer + Termux scripts).\n")
    f.write(f"* **iOS / Browser Users**: Download **`Universal-Vault-v{VERSION}-iOS.zip`** or open [https://universal-vault.pages.dev/app/](https://universal-vault.pages.dev/app/).\n")

print(f"[+] Generated release template: {template_path}")
print(f"All release assets staged successfully in: {OUT_DIR}")

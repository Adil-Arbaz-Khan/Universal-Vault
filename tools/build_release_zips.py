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

VERSION = "5.5.3"
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
    "   - 600,000 PBKDF2-HMAC-SHA256 iterations (OWASP Gold Standard).\n"
    "   - Filename Gibberish Masking (-g / --gibberish) toggle built-in.\n"
    "   - Hardware write barrier synchronization (Os.fsync) & crash resumption.\n"
    "   - Live telemetry: speed (MB/s) and ETA countdown.\n\n"
    "2. PORTABLE OFFLINE WEB APPLICATION\n"
    "   File: Vault_App.html\n"
    "   - Open in Chrome, Brave, Firefox, or Edge.\n"
    "   - Stream encrypted 4K video, audio, and documents in RAM with zero disk writes.\n\n"
    "3. TERMUX CLI SCRIPTS (Advanced)\n"
    "   Run ./tools/setup_termux.sh, then lock.sh / unlock.sh / status.sh.\n"
)

android_files = [
    (os.path.join(ROOT_DIR, "bin", "android", f"UniversalVault-v{VERSION}.apk"), f"UniversalVault-v{VERSION}.apk"),
    (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
    (os.path.join(ROOT_DIR, "lock.sh"), "lock.sh"),
    (os.path.join(ROOT_DIR, "unlock.sh"), "unlock.sh"),
    (os.path.join(ROOT_DIR, "status.sh"), "status.sh"),
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
    (os.path.join(ROOT_DIR, "lock.sh"), "lock.sh"),
    (os.path.join(ROOT_DIR, "unlock.sh"), "unlock.sh"),
    (os.path.join(ROOT_DIR, "status.sh"), "status.sh"),
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
    f.write('> **"Featherweight footprint. High-performance terminal CLI as primary. 100% portable when you need it."**\n\n')
    f.write(f"Universal Vault **v{VERSION}** delivers full cross-platform filename masking (**Gibberish File Name Formatting**), disguising encrypted filenames to randomized 16-hex hashes across all platforms (Go Native CLI, Python Engine, PowerShell Engine, WebApp, and Native Android App), coupled with synchronized **v{VERSION}** terminal banners and application badges across all operating systems.\n\n")
    f.write("---\n\n")
    f.write(f"## 🌟 What's New in v{VERSION}\n\n")
    f.write("### 1. 🔀 Gibberish Filename Masking Across All Platforms\n")
    f.write("* **Zero-Leakage Filename Masking**: Encrypted files can now be disguised to randomized 16-hex lowercase strings with `.vault` extension (e.g. `e4f1a08b9c2d3e4f.vault`), preventing metadata disclosure, extension profiling, or shoulder-surfing.\n")
    f.write("* **104-Byte Binary Footer Integration**: Original filenames are safely preserved inside the 104-byte cryptographic footer using bitflag `FlagGibberishName = 4`, authenticated under master `HMAC-SHA256` AEAD.\n")
    f.write("* **Seamless In-Place Restoration**: Upon valid password entry during unlock, the engine automatically restores the file's original plaintext name and extension in-place.\n")
    f.write("* **CLI & Interactive Flags**:\n")
    f.write("  * Native CLI: `vault lock <path> -g` or `vault lock <path> --gibberish`\n")
    f.write("  * Python Engine: `python tools/vault.py lock <path> -g`\n")
    f.write("  * PowerShell Engine: `.\\tools\\header_vault.ps1 -Action Lock -Path <path> -Gibberish`\n")
    f.write("  * Launchers: Interactive option in `Lock.bat` and CLI flag in `lock.sh`\n")
    f.write("  * WebApp: Interactive Gibberish toggle in `Vault_App.html`\n")
    f.write("  * Android App: In-app gibberish toggle in `VaultScreen.kt`\n\n")
    f.write(f"### 2. 📱 Synchronized Universal Version Display (v{VERSION})\n")
    f.write(f'* **Android Application**: Synchronized to `versionName "{VERSION}"` and `versionCode 5530`, with `v{VERSION}` version pill badge in the brand header.\n')
    f.write(f"* **Native CLI Binaries**: Go architecture updated to `v{VERSION}` across Windows, Linux, and macOS.\n")
    f.write(f"* **Python & PowerShell Engines**: Banners and `--version` / `version` CLI flags updated to `v{VERSION}`.\n")
    f.write(f"* **Platform Launchers**: `Lock.bat`, `Unlock.bat`, `Status.bat`, `lock.sh`, `unlock.sh`, `status.sh` synchronized to display `V{VERSION}`.\n")
    f.write(f"* **Air-Gapped WebApp**: `Vault_App.html` header pill updated to `v{VERSION}`.\n\n")
    f.write(f"### 3. 📦 Merged Platform Release Bundles (v{VERSION})\n")
    f.write(f"* Updated all platform archives (`Android`, `iOS`, `Linux`, `macOS`, `Universal`, `Windows`) with the new `Vault_App.html`, updated release documentation, official website links, and the v{VERSION} Android APK.\n\n")
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

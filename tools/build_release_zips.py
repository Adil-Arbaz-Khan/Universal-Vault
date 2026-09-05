#!/usr/bin/env python3
"""
Universal Vault v5.5.2 Release Packager
Generates official release zip archives for Windows, Linux, macOS, Android, iOS, and Universal.
"""

import os
import zipfile
import shutil
import hashlib

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT_DIR, "releases_v5.5.2")

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
print("  Packaging Universal Vault v5.5.2 Official Release Archives")
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
packages.append(make_zip("Universal-Vault-v5.5.2-Windows.zip", win_files))

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
packages.append(make_zip("Universal-Vault-v5.5.2-Linux.zip", linux_files))

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
packages.append(make_zip("Universal-Vault-v5.5.2-macOS.zip", macos_files))

# 4. Android Package (Native APK + Web PWA + Termux CLI)
android_readme = (
    "Universal Vault v5.5.2 — Android Release\n"
    "=========================================\n\n"
    "1. NATIVE ANDROID APPLICATION (Recommended)\n"
    "   File: UniversalVault-v5.5.2.apk\n"
    "   - Install: Open this APK directly on your Android phone to install.\n"
    "   - 100% in-place sovereign encryption via Storage Access Framework (SAF).\n"
    "   - 600,000 PBKDF2-HMAC-SHA256 iterations (OWASP Gold Standard).\n"
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
    (os.path.join(ROOT_DIR, "bin", "android", "UniversalVault-v5.5.2.apk"), "UniversalVault-v5.5.2.apk"),
    (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
    (os.path.join(ROOT_DIR, "lock.sh"), "lock.sh"),
    (os.path.join(ROOT_DIR, "unlock.sh"), "unlock.sh"),
    (os.path.join(ROOT_DIR, "status.sh"), "status.sh"),
    (os.path.join(ROOT_DIR, "tools", "vault.py"), "tools/vault.py"),
    (os.path.join(ROOT_DIR, "tools", "setup_termux.sh"), "tools/setup_termux.sh"),
    (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
    (os.path.join(ROOT_DIR, "SECURITY.md"), "SECURITY.md"),
]
packages.append(make_zip("Universal-Vault-v5.5.2-Android.zip", android_files, custom_files={"README.txt": android_readme}))

# 5. iOS Package (PWA)
ios_files = [
    (os.path.join(ROOT_DIR, "Vault_App.html"), "Vault_App.html"),
    (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
]
packages.append(make_zip("Universal-Vault-v5.5.2-iOS.zip", ios_files))

# 6. Universal All-Platforms Package
universal_files = [
    (os.path.join(ROOT_DIR, "README.md"), "README.md"),
    (os.path.join(ROOT_DIR, "SECURITY.md"), "SECURITY.md"),
    (os.path.join(ROOT_DIR, "LICENSE"), "LICENSE"),
    (os.path.join(ROOT_DIR, "CONTRIBUTING.md"), "CONTRIBUTING.md"),
    (os.path.join(ROOT_DIR, "RELEASE_NOTES_v5.5.2.md"), "RELEASE_NOTES_v5.5.2.md"),
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
                full_p = os.path.join(root, f)
                rel_p = os.path.relpath(full_p, ROOT_DIR)
                universal_files.append((full_p, rel_p))

packages.append(make_zip("Universal-Vault-v5.5.2-Universal.zip", universal_files))

# Copy standalone Android APK to release directory
apk_src = os.path.join(ROOT_DIR, "bin", "android", "UniversalVault-v5.5.2.apk")
apk_dst = os.path.join(OUT_DIR, "UniversalVault-v5.5.2.apk")
apk_hash = None
if os.path.exists(apk_src):
    shutil.copy2(apk_src, apk_dst)
    apk_hash = sha256_file(apk_dst)
    print(f"[+] Copied Standalone APK: UniversalVault-v5.5.2.apk | SHA256: {apk_hash[:16]}...")

# Write SHA256SUMS.txt for the release packages
sums_path = os.path.join(OUT_DIR, "SHA256SUMS.txt")
with open(sums_path, "w", encoding="utf-8") as f:
    for name, h in packages:
        f.write(f"{h}  {name}\n")
    if apk_hash:
        f.write(f"{apk_hash}  UniversalVault-v5.5.2.apk\n")

print("\n[+] Wrote release checksums to:", sums_path)
print("All release assets staged successfully in:", OUT_DIR)

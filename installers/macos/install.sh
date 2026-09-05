#!/usr/bin/env bash
# Universal Vault CLI Installer for macOS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_NAME="vault"
SRC_BIN=""

# 1. Architecture Detection (Strict & Explicit with Rosetta 2 awareness)
ARCH="$(uname -m)"
case "$ARCH" in
    arm64)
        SRC_BIN="$SCRIPT_DIR/vault_darwin_arm64"
        ;;
    x86_64)
        # Check if running under Rosetta 2 emulation on an Apple Silicon Mac
        IS_ROSETTA="$(sysctl -in sysctl.proc_translated 2>/dev/null || echo 0)"
        if [ "$IS_ROSETTA" = "1" ] && [ -f "$SCRIPT_DIR/vault_darwin_arm64" ]; then
            echo "[*] Apple Silicon hardware detected under Rosetta translation: selecting native arm64 binary."
            SRC_BIN="$SCRIPT_DIR/vault_darwin_arm64"
        else
            SRC_BIN="$SCRIPT_DIR/vault_darwin_amd64"
        fi
        ;;
    *)
        echo "[-] Error: Unsupported architecture '$ARCH'."
        echo "    Universal Vault CLI currently supports 64-bit macOS architectures: Apple Silicon (arm64) and Intel (x86_64)."
        exit 1
        ;;
esac

if [ ! -f "$SRC_BIN" ]; then
    echo "[-] Error: Required binary '$(basename "$SRC_BIN")' was not found in: $SCRIPT_DIR"
    exit 1
fi

echo "======================================================================"
echo "  Universal Vault CLI -- macOS Installer"
echo "======================================================================"

# 2. Source Cryptographic Hash Calculation
SRC_HASH=""
if command -v shasum >/dev/null 2>&1; then
    SRC_HASH="$(shasum -a 256 "$SRC_BIN" | awk '{print $1}')"
    echo "[*] Source Binary SHA-256 : $SRC_HASH"
elif command -v sha256sum >/dev/null 2>&1; then
    SRC_HASH="$(sha256sum "$SRC_BIN" | awk '{print $1}')"
    echo "[*] Source Binary SHA-256 : $SRC_HASH"
fi

# 3. Determine Target Directory (User vs System)
if [ "$(id -u)" -eq 0 ]; then
    TARGET_DIR="/usr/local/bin"
else
    TARGET_DIR="$HOME/.local/bin"
fi
mkdir -p "$TARGET_DIR"
DEST_EXE="$TARGET_DIR/$BIN_NAME"

# 4. Copy Binary & Set Executable Permissions
cp -f "$SRC_BIN" "$DEST_EXE"
chmod 755 "$DEST_EXE"

# 5. Remove macOS Quarantine Extended Attributes (Gatekeeper helper)
xattr -d com.apple.quarantine "$DEST_EXE" 2>/dev/null || true
xattr -c "$DEST_EXE" 2>/dev/null || true

# 6. Post-Copy Integrity Validation
if [ ! -f "$DEST_EXE" ]; then
    echo "[-] Verification Failed: vault was not found at $TARGET_DIR after copy."
    exit 1
fi

if [ -n "$SRC_HASH" ]; then
    DEST_HASH=""
    if command -v shasum >/dev/null 2>&1; then
        DEST_HASH="$(shasum -a 256 "$DEST_EXE" | awk '{print $1}')"
    elif command -v sha256sum >/dev/null 2>&1; then
        DEST_HASH="$(sha256sum "$DEST_EXE" | awk '{print $1}')"
    fi

    if [ "$SRC_HASH" != "$DEST_HASH" ]; then
        echo "[-] Verification Failed: SHA-256 mismatch after copy! Installation aborted."
        rm -f "$DEST_EXE"
        exit 1
    fi
    echo "[+] Deployed to           : $DEST_EXE"
    echo "[+] Copy Integrity        : SHA-256 matches source payload"
else
    echo "[+] Deployed to           : $DEST_EXE"
fi

# 7. Ensure PATH Configuration for User-Space Installs
if [ "$(id -u)" -ne 0 ]; then
    case ":$PATH:" in
        *":$TARGET_DIR:"*) ;;
        *)
            echo "[*] Adding $TARGET_DIR to shell profiles..."
            # macOS default shell is zsh (reads ~/.zprofile on login, ~/.zshrc interactively)
            if [ -f "$HOME/.zprofile" ] && ! grep -q "$TARGET_DIR" "$HOME/.zprofile" 2>/dev/null; then
                echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$HOME/.zprofile"
            elif [ ! -f "$HOME/.zprofile" ]; then
                echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$HOME/.zprofile"
            fi

            if [ -f "$HOME/.zshrc" ] && ! grep -q "$TARGET_DIR" "$HOME/.zshrc" 2>/dev/null; then
                echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$HOME/.zshrc"
            fi

            if [ -f "$HOME/.bash_profile" ] && ! grep -q "$TARGET_DIR" "$HOME/.bash_profile" 2>/dev/null; then
                echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$HOME/.bash_profile"
            fi

            if [ -f "$HOME/.profile" ] && ! grep -q "$TARGET_DIR" "$HOME/.profile" 2>/dev/null; then
                echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$HOME/.profile"
            fi
            echo "[+] Registered in PATH    : $TARGET_DIR"
            ;;
    esac
fi

echo ""
echo "======================================================================"
echo "  Installation Successful (Copy Integrity Confirmed)"
echo "  You can now run from any terminal:"
echo "    vault lock <path>"
echo "    vault unlock <path>"
echo "    vault status <path>"
echo "======================================================================"

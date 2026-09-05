#!/usr/bin/env bash
# Universal Vault CLI Uninstaller for macOS
set -euo pipefail

echo "======================================================================"
echo "  Universal Vault CLI -- macOS Uninstaller"
echo "======================================================================"

REMOVED=0

# 1. Remove User Binary
if [ -f "$HOME/.local/bin/vault" ]; then
    rm -f "$HOME/.local/bin/vault"
    echo "[+] Removed: $HOME/.local/bin/vault"
    REMOVED=1
fi

# 2. Remove System Binary if root
if [ "$(id -u)" -eq 0 ] && [ -f "/usr/local/bin/vault" ]; then
    rm -f "/usr/local/bin/vault"
    echo "[+] Removed: /usr/local/bin/vault"
    REMOVED=1
elif [ -f "/usr/local/bin/vault" ]; then
    echo "[*] Notice: /usr/local/bin/vault exists. Run 'sudo ./uninstall.sh' to remove system-wide installation."
fi

if [ "$REMOVED" -eq 0 ]; then
    echo "[*] No active vault binary found to remove."
fi

echo ""
echo "Uninstallation Complete."

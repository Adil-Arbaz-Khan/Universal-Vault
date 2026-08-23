#!/data/data/com.termux/files/usr/bin/bash
echo "==============================================="
echo "   Setting up Universal Vault for Termux"
echo "==============================================="
termux-setup-storage
pkg update -y
pkg install -y python python-cryptography
echo ""
echo "Setup Complete! You can run:"
echo "  python tools/vault.py lock"
echo "  python tools/vault.py unlock"
echo "  python tools/vault.py status"
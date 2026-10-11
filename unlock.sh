#!/bin/bash
echo "======================================================="
echo "  UNIVERSAL VAULT V5.5.4 - AUTHENTICATED AEAD UNLOCKER"
echo "======================================================="

DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$1"
if [ -z "$TARGET" ]; then
    TARGET="$DIR"
fi
python3 "$DIR/tools/vault.py" unlock "$TARGET"
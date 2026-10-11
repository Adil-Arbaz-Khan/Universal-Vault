#!/bin/bash
echo "======================================================="
echo "    UNIVERSAL VAULT V5.5.4 - STREAM IN VOLATILE RAM"
echo "======================================================="

DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$1"
if [ -z "$TARGET" ]; then
    echo -n "Enter path of locked file to stream in RAM: "
    read -r TARGET
fi
python3 "$DIR/tools/vault.py" view "$TARGET"

#!/bin/bash
echo "======================================================="
echo "       UNIVERSAL VAULT V5.5.4 - CHECK STATUS"
echo "======================================================="

DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$DIR/tools/vault.py" status "$DIR"
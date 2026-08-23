#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$1"
if [ -z "$TARGET" ]; then
    TARGET="$DIR"
fi
python3 "$DIR/tools/vault.py" unlock "$TARGET"
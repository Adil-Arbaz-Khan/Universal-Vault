#!/bin/bash
echo "======================================================="
echo "   UNIVERSAL VAULT V5.5.3 - AUTHENTICATED AEAD LOCKER"
echo "======================================================="

DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET=""
EXTRA_ARGS=()

for arg in "$@"; do
    if [ "$arg" = "-g" ] || [ "$arg" = "--gibberish" ]; then
        EXTRA_ARGS+=("$arg")
    elif [ -z "$TARGET" ]; then
        TARGET="$arg"
    else
        EXTRA_ARGS+=("$arg")
    fi
done

if [ -z "$TARGET" ]; then
    TARGET="$DIR"
fi
python3 "$DIR/tools/vault.py" lock "$TARGET" "${EXTRA_ARGS[@]}"
#!/bin/sh
# Copies the sample skins (Skins/: Rose, Midnight, Mint) into Pix's skins folder, so they show under Skin in
# Pix's menu. Existing skins of the same name are overwritten; others are left alone.
set -e
cd "$(dirname "$0")/.."
DEST="$HOME/Library/Application Support/Pix/Skins"
mkdir -p "$DEST"
cp -R Skins/ "$DEST/"
echo "Skins in $DEST:"
ls "$DEST"

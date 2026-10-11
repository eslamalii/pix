#!/bin/sh
# Redraws packaging/AppIcon.icns from Pix's art in Art/ (run it after redrawing pix-idle or pix-face).
set -e
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
swiftc -O scripts/icon/main.swift Sources/AmbientCore/ArtContract.swift Sources/AmbientCore/Spot.swift -o "$TMP/make-icon"
"$TMP/make-icon" Art "$TMP/icon.png"
mkdir "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o packaging/AppIcon.icns
echo "  packaging/AppIcon.icns"

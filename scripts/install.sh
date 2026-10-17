#!/bin/sh
# Installs the latest Pix release into /Applications without macOS quarantine and launches it (Apple Silicon).
#   curl -fsSL https://raw.githubusercontent.com/eslamalii/pix/main/scripts/install.sh | sh
set -e

if [ "$(uname -m)" != "arm64" ]; then
  echo "Prebuilt releases are for Apple Silicon. On an Intel Mac, run: brew install eslamalii/tap/pix" >&2
  exit 1
fi

TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/eslamalii/pix/releases/latest | sed 's|.*/tag/||')"
VERSION="${TAG#v}"
URL="https://github.com/eslamalii/pix/releases/download/$TAG/Pix-$VERSION.zip"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Pix $VERSION..."
curl -fsSL "$URL" -o "$TMP/Pix.zip"
ditto -x -k "$TMP/Pix.zip" "$TMP"

pkill -x Pix 2>/dev/null && sleep 1 || true
rm -rf /Applications/Pix.app
mv "$TMP/Pix.app" /Applications/Pix.app
xattr -cr /Applications/Pix.app 2>/dev/null || true
open /Applications/Pix.app
echo "Installed Pix $VERSION to /Applications/Pix.app"

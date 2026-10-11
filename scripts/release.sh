#!/bin/sh
# Builds the release zip for GitHub Releases (Apple Silicon, ad hoc signed) and prints what the Homebrew
# formula needs. Run it on a clean, tagged commit.
set -e
cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
BUILD="$(git rev-list --count HEAD)"
[ -z "$(git status --porcelain)" ] || { echo "Commit (or remove) your changes first." >&2; exit 1; }
git describe --exact-match --tags HEAD >/dev/null 2>&1 || echo "warning: HEAD isn't tagged; tag it v$VERSION before releasing." >&2

PIX_BUILD="$BUILD" scripts/build-app.sh --bundle
ZIP="build/Pix-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/Pix.app "$ZIP"

echo
echo "Release zip: $ZIP"
echo "  sha256 $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo
echo "Homebrew formula (packaging/homebrew/pix.rb), once tag v$VERSION is on GitHub:"
echo "  url    https://github.com/eslamalii/pix/archive/refs/tags/v$VERSION.tar.gz"
echo "  sha256 \$(curl -sL https://github.com/eslamalii/pix/archive/refs/tags/v$VERSION.tar.gz | shasum -a 256 | cut -d' ' -f1)"
echo "  PIX_BUILD $BUILD"

#!/bin/sh
# Builds the release zip for GitHub Releases (Apple Silicon, ad hoc signed). Run it on a clean, tagged commit.
# .github/workflows/release.yml runs it on every v* tag, then publishes the release, the tap and the website.
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

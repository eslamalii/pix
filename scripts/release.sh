#!/bin/sh
# Builds the release zip for GitHub Releases (Universal: Apple Silicon and Intel, ad hoc signed). Run it on a clean, tagged commit.
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

DMG="build/Pix-$VERSION.dmg"
rm -f "$DMG"
DMG_DIR=$(mktemp -d)
RW_DMG="$DMG_DIR.rw.dmg"
MOUNT_DIR=$(mktemp -d)
trap 'hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true; rm -rf "$DMG_DIR" "$RW_DMG" "$MOUNT_DIR"' EXIT
chmod 755 "$DMG_DIR"
cp -R build/Pix.app "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
if [ -f packaging/AppIcon.icns ]; then
  cp packaging/AppIcon.icns "$DMG_DIR/.VolumeIcon.icns"
  SetFile -c icnC "$DMG_DIR/.VolumeIcon.icns"
fi
hdiutil create -volname "Pix" -srcfolder "$DMG_DIR" -ov -format UDRW "$RW_DMG" >/dev/null 2>&1
hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_DIR" -nobrowse >/dev/null 2>&1
[ -f "$MOUNT_DIR/.VolumeIcon.icns" ] && SetFile -a C "$MOUNT_DIR"
hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1
hdiutil convert "$RW_DMG" -format UDZO -o "$DMG" >/dev/null 2>&1

echo
echo "Release zip: $ZIP"
echo "  sha256 $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo "Release dmg: $DMG"
echo "  sha256 $(shasum -a 256 "$DMG" | cut -d' ' -f1)"

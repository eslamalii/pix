#!/bin/sh
# Builds Pix.app (release) and signs it ad hoc.
#   scripts/build-app.sh            then installs it to /Applications and launches it (development)
#   scripts/build-app.sh --bundle   stops at build/Pix.app (Homebrew and releases)
# Version comes from VERSION. The build number is $PIX_BUILD when set (a source tarball has no git history),
# otherwise the git commit count, so it only ever goes up.
set -e
cd "$(dirname "$0")/.."
VERSION="$(cat VERSION)"
BUILD="${PIX_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}"
APP=build/Pix.app

# Homebrew builds inside its own sandbox, where SwiftPM's sandbox can't nest.
[ "$1" = "--bundle" ] && SWIFT_FLAGS="--disable-sandbox"
swift build -c release $SWIFT_FLAGS
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release $SWIFT_FLAGS --show-bin-path)/Pix" "$APP/Contents/MacOS/"
cp -R Art "$APP/Contents/Resources/Art"  # the art contract: see README
[ -f packaging/AppIcon.icns ] && cp packaging/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>io.github.eslamalii.Pix</string>
  <key>CFBundleName</key><string>Pix</string>
  <key>CFBundleExecutable</key><string>Pix</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleURLTypes</key><array><dict>
    <key>CFBundleURLName</key><string>io.github.eslamalii.Pix</string>
    <key>CFBundleURLSchemes</key><array><string>pix</string></array>
  </dict></array>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
if [ "$1" = "--bundle" ]; then echo "Built $APP $VERSION ($BUILD)"; exit 0; fi

pkill -x Pix 2>/dev/null && sleep 1 || true
rm -rf /Applications/Pix.app
cp -R "$APP" /Applications/
open /Applications/Pix.app
echo "Installed Pix $VERSION ($BUILD)"

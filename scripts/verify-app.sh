#!/bin/sh
# Checks the finished bundle, including each requested architecture. Does not install or launch Pix.
set -eu
APP="${1:?usage: verify-app.sh app-path [--arch architecture ...]}"
shift
EXPECTED_ARCHS=""
while [ "$#" -gt 0 ]; do
  [ "$1" = "--arch" ] && [ "$#" -ge 2 ] || { echo "Expected --arch architecture" >&2; exit 1; }
  EXPECTED_ARCHS="$EXPECTED_ARCHS $2"
  shift 2
done
[ -n "$EXPECTED_ARCHS" ] || EXPECTED_ARCHS="$(uname -m)"
EXECUTABLE="$APP/Contents/MacOS/Pix"
PLIST="$APP/Contents/Info.plist"
plutil -lint "$PLIST" >/dev/null
[ "$(plutil -extract LSMinimumSystemVersion raw "$PLIST")" = "14.0" ] || { echo "Unexpected minimum macOS in Info.plist" >&2; exit 1; }
ACTUAL_ARCHS="$(lipo -archs "$EXECUTABLE")"
for ARCH in $EXPECTED_ARCHS; do
  case " $ACTUAL_ARCHS " in
    *" $ARCH "*) ;;
    *) echo "Missing architecture: $ARCH (found $ACTUAL_ARCHS)" >&2; exit 1 ;;
  esac
done
# Check every shipped slice, including any beyond those requested.
for ARCH in $ACTUAL_ARCHS; do
  MINOS="$(xcrun vtool -arch "$ARCH" -show-build "$EXECUTABLE" | awk '$1 == "minos" { print $2 }')"
  case "$MINOS" in
    14.0|14.0.0) ;;
    *) echo "Unexpected minimum macOS for $ARCH: $MINOS" >&2; exit 1 ;;
  esac
done
codesign --verify --deep --strict "$APP"
# Compare all shipped art with this checkout, including Occasion art.
SCRIPT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
diff -qr "$SCRIPT_ROOT/Art" "$APP/Contents/Resources/Art"
echo "Verified $APP ($ACTUAL_ARCHS; macOS 14.0; signature and art)"

#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
CONFIGURATION="${1:-release}"
DIST_DIR="$PROJECT_ROOT/dist"
APP_BUNDLE="$DIST_DIR/Sotto.app"
ZIP_PATH="$DIST_DIR/Sotto-1.0.0.zip"

if [[ "$APP_BUNDLE" != "$PROJECT_ROOT/dist/Sotto.app" ]]; then
  print -u2 "Refusing to package unexpected path: $APP_BUNDLE"
  exit 1
fi

cd "$PROJECT_ROOT"
swift build -c "$CONFIGURATION" --product Sotto
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN_DIR/Sotto" "$APP_BUNDLE/Contents/MacOS/Sotto"
cp "$PROJECT_ROOT/Sources/Sotto/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_ROOT/LICENSE" "$APP_BUNDLE/Contents/Resources/LICENSE.txt"
cp "$PROJECT_ROOT/Sources/Sotto/Resources/ThirdPartyNotices.txt" \
  "$APP_BUNDLE/Contents/Resources/ThirdPartyNotices.txt"

ICON="$PROJECT_ROOT/Sources/Sotto/Resources/AppIcon.icns"
if [[ -f "$ICON" ]]; then
  cp "$ICON" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

chmod 755 "$APP_BUNDLE/Contents/MacOS/Sotto"
plutil -lint "$APP_BUNDLE/Contents/Info.plist"
codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp=none \
  --sign - \
  --entitlements "$PROJECT_ROOT/Sources/Sotto/Resources/Sotto.entitlements" \
  "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

print "$APP_BUNDLE"
print "$ZIP_PATH"

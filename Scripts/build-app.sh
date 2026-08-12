#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
CONFIGURATION="${1:-release}"
SIGNING_MODE="${2:-local}"
DIST_DIR="$PROJECT_ROOT/dist"
APP_BUNDLE="$DIST_DIR/Sotto.app"
ZIP_PATH="$DIST_DIR/Sotto-1.0.0.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

write_checksum() {
  local zip_name="${ZIP_PATH:t}"
  local checksum_name="${CHECKSUM_PATH:t}"
  (
    cd "$DIST_DIR"
    shasum -a 256 "$zip_name" > "$checksum_name"
  )
}

case "$SIGNING_MODE" in
  local)
    SIGNING_IDENTITY="-"
    TIMESTAMP_ARGUMENT="--timestamp=none"
    ;;
  public)
    if [[ -z "${SOTTO_CODESIGN_IDENTITY:-}" || -z "${SOTTO_NOTARY_PROFILE:-}" ]]; then
      print -u2 "Public builds require SOTTO_CODESIGN_IDENTITY and SOTTO_NOTARY_PROFILE."
      exit 1
    fi
    SIGNING_IDENTITY="$SOTTO_CODESIGN_IDENTITY"
    TIMESTAMP_ARGUMENT="--timestamp"
    ;;
  *)
    print -u2 "Unknown signing mode: $SIGNING_MODE (expected local or public)"
    exit 1
    ;;
esac

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
  "$TIMESTAMP_ARGUMENT" \
  --sign "$SIGNING_IDENTITY" \
  --entitlements "$PROJECT_ROOT/Sources/Sotto/Resources/Sotto.entitlements" \
  "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -f "$ZIP_PATH"
ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
write_checksum

if [[ "$SIGNING_MODE" == "public" ]]; then
  xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$SOTTO_NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
  spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
  rm -f "$ZIP_PATH"
  ditto -c -k --norsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
  write_checksum
fi

print "$APP_BUNDLE"
print "$ZIP_PATH"
print "$CHECKSUM_PATH"

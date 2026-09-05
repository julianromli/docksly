#!/bin/sh
# Build an unsigned tester .dmg. Recipients must bypass Gatekeeper.
# Usage: scripts/build-tester-dmg.sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="1.0.0"
DERIVED="$ROOT/.build/DerivedData"
APP="$DERIVED/Build/Products/Release/Docksly.app"
STAGE="$ROOT/dist/dmg-root"
DMG="$ROOT/dist/Docksly-$VERSION-tester.dmg"

if ! command -v xcodebuild >/dev/null 2>&1; then
  printf '%s\n' "Install Xcode from the Mac App Store, then open it once." >&2
  exit 1
fi

xcodebuild \
  -project "$ROOT/Docksly.xcodeproj" \
  -scheme Docksly \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  build

if [ ! -d "$APP" ]; then
  printf '%s\n' "The build finished, but Docksly.app was not found." >&2
  exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Docksly.app"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/Read Me (testers).txt" <<'EOF'
Docksly tester build

This disk image is not signed with Developer ID and is not notarized.
macOS may block the app after you download the file.

1. Drag Docksly to Applications.
2. If macOS blocks the app, open System Settings → Privacy & Security, then choose Open Anyway.
   Or run: xattr -cr /Applications/Docksly.app
3. Open Docksly from Applications.

The 24-hour trial starts on first launch. After that, paste a Mayar license key in Settings.
EOF

rm -f "$DMG"
hdiutil create \
  -volname "Docksly $VERSION" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

rm -rf "$STAGE"
printf '%s\n' "Created $DMG"
printf '%s\n' "Do not sell this file. Share it only with trusted testers."

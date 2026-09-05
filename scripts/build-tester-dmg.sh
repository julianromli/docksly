#!/bin/sh
# Build an unsigned tester .dmg with a Docksly-styled Finder window.
# Recipients must bypass Gatekeeper. Usage: scripts/build-tester-dmg.sh
#
# Needs: Xcode, and `dmgbuild` (python3 -m pip install --user dmgbuild)

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="1.0.0"
VOLUME="Install Docksly"
DERIVED="$ROOT/.build/DerivedData"
APP="$DERIVED/Build/Products/Release/Docksly.app"
DMG="$ROOT/dist/Docksly-$VERSION-tester.dmg"
BG="$ROOT/scripts/dmg/background.png"
SETTINGS="$ROOT/scripts/dmg/dmgbuild_settings.py"
RUNNER="$ROOT/scripts/dmg/run_dmgbuild.py"

if ! command -v xcodebuild >/dev/null 2>&1; then
  printf '%s\n' "Install Xcode from the Mac App Store, then open it once." >&2
  exit 1
fi

if ! python3 -c 'import dmgbuild, ds_store' >/dev/null 2>&1; then
  printf '%s\n' "Install dmgbuild: python3 -m pip install --user dmgbuild" >&2
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

swift "$ROOT/scripts/generate_dmg_background.swift" "$BG"

mkdir -p "$ROOT/dist"
for vol in "/Volumes/$VOLUME" "/Volumes/Docksly $VERSION"; do
  if [ -d "$vol" ]; then
    hdiutil detach "$vol" -quiet -force || true
  fi
done
sleep 1
rm -f "$DMG"

python3 "$RUNNER" \
  -s "$SETTINGS" \
  -Dapp="$APP" \
  -Dbackground="$BG" \
  "$VOLUME" \
  "$DMG"

printf '%s\n' "Created $DMG"
printf '%s\n' "Do not sell this file. Share it only with trusted testers."

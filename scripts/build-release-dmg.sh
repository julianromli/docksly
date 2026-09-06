#!/bin/sh
# Build a public Docksly .dmg: Developer ID sign, notarize, staple.
# Usage: scripts/build-release-dmg.sh [--skip-notarize]
#
# Needs: Xcode, a Developer ID Application certificate for team 4YQMC7V3CB,
# dmgbuild, and a notarytool keychain profile named docksly-notarize.

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="1.0.0"
TEAM_ID="4YQMC7V3CB"
NOTARY_PROFILE="docksly-notarize"
VOLUME="Install Docksly"
DERIVED="$ROOT/.build/DerivedData"
APP="$DERIVED/Build/Products/Release/Docksly.app"
DMG="$ROOT/dist/Docksly-$VERSION.dmg"
BG="$ROOT/scripts/dmg/background.png"
SETTINGS="$ROOT/scripts/dmg/dmgbuild_settings.py"
RUNNER="$ROOT/scripts/dmg/run_dmgbuild.py"
SKIP_NOTARIZE="0"

for arg in "$@"; do
  case "$arg" in
    --skip-notarize) SKIP_NOTARIZE="1" ;;
    -h|--help)
      printf '%s\n' "Usage: scripts/build-release-dmg.sh [--skip-notarize]"
      printf '%s\n' "  --skip-notarize  Sign the app and the .dmg. Do not upload to Apple."
      exit 0
      ;;
    *)
      printf '%s\n' "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  printf '%s\n' "Install Xcode from the Mac App Store, then open it once." >&2
  exit 1
fi

if ! python3 -c 'import dmgbuild, ds_store' >/dev/null 2>&1; then
  printf '%s\n' "Install dmgbuild: python3 -m pip install --user dmgbuild" >&2
  exit 1
fi

IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' -v team="$TEAM_ID" '
  /Developer ID Application/ && $0 ~ team { print $2; exit }
')"
if [ -z "$IDENTITY" ]; then
  printf '%s\n' "No Developer ID Application certificate for team $TEAM_ID." >&2
  printf '%s\n' "Open Xcode → Settings → Accounts → Manage Certificates, then add one." >&2
  exit 1
fi

if [ "$SKIP_NOTARIZE" = "0" ]; then
  if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    printf '%s\n' "The notarytool profile \"$NOTARY_PROFILE\" is missing." >&2
    printf '%s\n' "Run: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --team-id \"$TEAM_ID\"" >&2
    exit 1
  fi
fi

if pgrep -x Docksly >/dev/null 2>&1; then
  osascript -e 'tell application "Docksly" to quit' >/dev/null 2>&1 || true
  sleep 1
  pkill -x Docksly >/dev/null 2>&1 || true
fi

printf '%s\n' "Signing with $IDENTITY"

xcodebuild \
  -project "$ROOT/Docksly.xcodeproj" \
  -scheme Docksly \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  build

if [ ! -d "$APP" ]; then
  printf '%s\n' "The build finished, but Docksly.app was not found." >&2
  exit 1
fi

codesign --force --options runtime --timestamp \
  --entitlements "$ROOT/Docksly/Docksly.entitlements" \
  --sign "$IDENTITY" \
  "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

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

codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --verbose=2 "$DMG"

if [ "$SKIP_NOTARIZE" = "1" ]; then
  printf '%s\n' "Created $DMG (signed, not notarized)."
  exit 0
fi

printf '%s\n' "Uploading $DMG to Apple notary service…"
SUBMIT_LOG="$(mktemp)"
if ! xcrun notarytool submit "$DMG" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait | tee "$SUBMIT_LOG"; then
  printf '%s\n' "notarytool submit failed." >&2
  rm -f "$SUBMIT_LOG"
  exit 1
fi

if ! grep -q "status: Accepted" "$SUBMIT_LOG"; then
  SUBMISSION_ID="$(awk '/^id: / { print $2; exit }' "$SUBMIT_LOG")"
  printf '%s\n' "Notarization was not accepted." >&2
  if [ -n "$SUBMISSION_ID" ]; then
    xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" >&2 || true
  fi
  rm -f "$SUBMIT_LOG"
  exit 1
fi
rm -f "$SUBMIT_LOG"

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
hdiutil verify "$DMG" >/dev/null

SITE_DMG="$ROOT/web/public/Docksly.dmg"
cp "$DMG" "$SITE_DMG"

printf '%s\n' "Created $DMG"
printf '%s\n' "Copied $SITE_DMG for the marketing site download."
printf '%s\n' "This file is signed, notarized, and stapled."

#!/bin/sh
# Build Docksly on this Mac from the repo. No Apple Developer team is required.
# Usage: scripts/build-from-source.sh [--debug] [--install]

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CONFIG="Release"
INSTALL="0"

for arg in "$@"; do
  case "$arg" in
    --debug) CONFIG="Debug" ;;
    --install) INSTALL="1" ;;
    -h|--help)
      printf '%s\n' "Usage: scripts/build-from-source.sh [--debug] [--install]"
      printf '%s\n' "  --debug    Build Debug (includes Settings → Developer)."
      printf '%s\n' "  --install  Copy the app to /Applications after the build."
      exit 0
      ;;
    *)
      printf '%s\n' "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

DERIVED="$ROOT/.build/DerivedData"
APP="$DERIVED/Build/Products/$CONFIG/Docksly.app"

if ! command -v xcodebuild >/dev/null 2>&1; then
  printf '%s\n' "Install Xcode from the Mac App Store, then open it once." >&2
  exit 1
fi

if pgrep -x Docksly >/dev/null 2>&1; then
  osascript -e 'tell application "Docksly" to quit' >/dev/null 2>&1 || true
  sleep 1
  pkill -x Docksly >/dev/null 2>&1 || true
fi

xcodebuild \
  -project "$ROOT/Docksly.xcodeproj" \
  -scheme Docksly \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  build

if [ ! -d "$APP" ]; then
  printf '%s\n' "The build finished, but Docksly.app was not found." >&2
  exit 1
fi

if [ "$INSTALL" = "1" ]; then
  rm -rf /Applications/Docksly.app
  cp -R "$APP" /Applications/Docksly.app
  open /Applications/Docksly.app
  printf '%s\n' "Opened /Applications/Docksly.app ($CONFIG)."
else
  open "$APP"
  printf '%s\n' "Opened $APP"
  printf '%s\n' "Login at login needs the app in /Applications. Run again with --install if you want that."
fi

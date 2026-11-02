#!/bin/sh
# After build-release-dmg.sh: create the GitHub release and update the Homebrew cask.
# Usage: scripts/publish-release.sh "Release notes"
#
# Needs: gh (logged in) and a clone of julianromli/homebrew-tap (it is cloned to a temp folder).

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="$(awk -F'"' '/^VERSION=/{print $2; exit}' "$ROOT/scripts/build-release-dmg.sh")"
DMG="$ROOT/dist/Docksly-$VERSION.dmg"
NOTES="${1:-Docksly $VERSION}"

if [ ! -f "$DMG" ]; then
  printf '%s\n' "Run scripts/build-release-dmg.sh first. $DMG is missing." >&2
  exit 1
fi
xcrun stapler validate "$DMG" >/dev/null

gh release create "v$VERSION" "$DMG" -R julianromli/docksly --title "Docksly $VERSION" --notes "$NOTES"

SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
TAP="$(mktemp -d)"
gh repo clone julianromli/homebrew-tap "$TAP" -- -q
sed -i '' "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$TAP/Casks/docksly.rb"
git -C "$TAP" commit -qam "Update Docksly to $VERSION"
git -C "$TAP" push -q
rm -rf "$TAP"

printf '%s\n' "Published v$VERSION and updated the cask (sha256 $SHA)."

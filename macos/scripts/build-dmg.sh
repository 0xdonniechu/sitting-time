#!/bin/bash
# Builds dist/SittingTime.dmg (drag-to-Applications installer) from a fresh .app.
# Usage: ./scripts/build-dmg.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/SittingTime.app"
DMG="$DIST/SittingTime.dmg"
VOL="SittingTime"

"$ROOT/scripts/build-app.sh"

echo "==> DMG $DMG"
rm -f "$DMG"
STAGE="$(mktemp -d)/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -fs HFS+ -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null
rm -rf "$(dirname "$STAGE")"
echo "OK: $DMG ($(du -h "$DMG" | cut -f1))"

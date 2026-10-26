#!/bin/bash
# Builds, tests and assembles dist/SittingTime.app (ad-hoc signed).
# Usage: ./scripts/build-app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/SittingTime.app"
BIN="$ROOT/.build/release/SittingTime"
# --disable-sandbox skips SwiftPM's internal sandbox-exec (needed under a
# sandboxed shell; harmless on a normal machine).
FLAGS="--disable-sandbox"

cd "$ROOT"

echo "==> Tests"
TESTLOG="$(mktemp)"
set +e
swift test $FLAGS >"$TESTLOG" 2>&1
TEST_STATUS=$?
set -e
grep -v "not accessible or not writable\|readonly database\|storing manifest" "$TESTLOG" \
    | grep -E "Test run|error:|Build failed" | head -n 10 || true
rm -f "$TESTLOG"
if [ "$TEST_STATUS" -ne 0 ]; then echo "FAIL: tests"; exit 1; fi

echo "==> Release build (0 warnings)"
LOG="$(mktemp)"
swift build -c release $FLAGS 2>&1 | tee "$LOG" | grep -v "not accessible or not writable\|readonly database\|storing manifest" | tail -n 3 || true
if grep -E "warning: " "$LOG" | grep -E "Sources/|Tests/" >/dev/null; then
    echo "FAIL: compiler warnings in own sources:"
    grep -E "warning: " "$LOG" | grep -E "Sources/|Tests/"
    exit 1
fi
rm -f "$LOG"

echo "==> Icon"
MODCACHE="${TMPDIR:-/tmp}/sittingtime-modcache"
mkdir -p "$MODCACHE"
GENBIN="$(mktemp -d)/genicon"
swiftc -module-cache-path "$MODCACHE" -O -o "$GENBIN" "$ROOT/scripts/generate-icon.swift" -framework AppKit
ICNS="$(mktemp -d)/SittingTime.icns"
"$GENBIN" "$ICNS"

echo "==> Assemble $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SittingTime"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ICNS" "$APP/Contents/Resources/SittingTime.icns"
mkdir -p "$APP/Contents/Resources/Zodiac"
cp "$ROOT/Resources/Zodiac/"*.png "$APP/Contents/Resources/Zodiac/"
codesign --force -s - "$APP"
echo "OK: $APP ($(du -sh "$APP" | cut -f1))"

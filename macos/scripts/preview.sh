#!/bin/bash
# Renders Stats / About / Flash screens to PNGs for human review.
# Usage: ./scripts/preview.sh [all|stats-day|stats-week|about|flash] [outdir]
# Compiles the view sources against the built SittingCore with the macro
# plugin loaded directly (sandbox blocks the plugin server) and a /tmp
# module cache (sandbox blocks the default one).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WHICH="${1:-all}"
OUTDIR="${2:-/tmp/sitting-previews}"
BIN="$OUTDIR/sitting-previews"
PLUG=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins

echo "==> SittingCore (release, incremental)"
swift build -c release --disable-sandbox --product SittingTime 2>&1 \
    | grep -E '^error:|Build complete' || true

echo "==> Compile previews"
mkdir -p "$OUTDIR"
swiftc -module-cache-path "$OUTDIR/ModuleCache" \
    -load-plugin-library "$PLUG/libSwiftUIMacros.dylib" \
    -o "$BIN" scripts/previews/main.swift \
    Sources/SittingTime/StatsView.swift \
    Sources/SittingTime/AboutView.swift \
    Sources/SittingTime/AppInfo.swift \
    Sources/SittingTime/FlashCenter.swift \
    -I .build/release .build/release/SittingCore.o \
    -framework AppKit -framework SwiftUI -framework Charts -framework AVFoundation

echo "==> Render $WHICH -> $OUTDIR"
"$BIN" "$WHICH" "$OUTDIR"

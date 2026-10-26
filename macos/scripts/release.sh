#!/bin/bash
# One-command release: bump version, test, build .app + .dmg, push, publish
# the GitHub release, byte-verify the download.
# Usage: ./scripts/release.sh <version> [build] [notes]
#   version: marketing version, e.g. 1.2.0
#   build:   build number (default: current + 1)
#   notes:   release notes (default: "Release macOS v<version>")
# Needs hdiutil + network: run unsandboxed (one approval) or outside Muse.
set -euo pipefail

if [ $# -lt 1 ]; then echo "Usage: $0 <version> [build] [notes]"; exit 1; fi
VERSION="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[ -d Sources/SittingCore ] || { echo "FAIL: run from the macOS worktree root"; exit 1; }

PLIST="$ROOT/Resources/Info.plist"
BUILD="${2:-}"
if [ -z "$BUILD" ]; then
    BUILD=$(($(plutil -extract CFBundleVersion raw "$PLIST") + 1))
fi
NOTES="${3:-Release macOS v$VERSION}"
DMG="$ROOT/dist/SittingTime.dmg"
REPO="0xdonniechu/sitting-time"
TAG="macos-v$VERSION"

echo "==> Bump $VERSION ($BUILD)"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$PLIST"
plutil -replace CFBundleVersion -string "$BUILD" "$PLIST"

echo "==> DMG (runs tests + release build inside)"
"$ROOT/scripts/build-dmg.sh"

echo "==> Sync to a fresh clone"
export GH_TOKEN
GH_TOKEN="$(gh auth token --user 0xdonniechu)"
CLONE="$(mktemp -d)/repo"
git clone --quiet "https://x-access-token:$GH_TOKEN@github.com/$REPO.git" "$CLONE"
rsync -a --delete --exclude=.build --exclude=dist --exclude=.git --exclude=.DS_Store "$ROOT/" "$CLONE/macos/"
cd "$CLONE"
git status --short
git diff --stat | tail -2

echo "==> Secrets scan (tracked diff + new files, fail-closed)"
# This script excludes itself: it holds the pattern list and the standard
# GH_TOKEN credential helper by design (verified: variable references only,
# no secret values). Everything else fails the release on any match.
PATTERN='api[_-]?key|secret|password|private[_-]?key|BEGIN .* PRIVATE KEY|ghp_|gho_|sk-|xox|Bearer [A-Za-z0-9]{10,}'
MATCHES="$(git diff | grep -i -E "$PATTERN" | grep -v 'scripts/release.sh' || true)"
NEWFILES="$(git status --short | awk '$1=="??" {print $2}' | grep -v '^macos/scripts/release.sh$' || true)"
for f in $NEWFILES; do
    MATCHES="$MATCHES$(grep -r -i -E "$PATTERN" "$f" || true)"
done
if [ -n "$MATCHES" ]; then echo "FAIL: possible secret:"; echo "$MATCHES"; exit 1; fi
echo "clean"

echo "==> Commit + push"
git -c user.name=0xdonniechu -c user.email=0xdonniechu@users.noreply.github.com add -A
git -c user.name=0xdonniechu -c user.email=0xdonniechu@users.noreply.github.com commit -m "macOS v$VERSION: $NOTES"
git -c credential.helper='!f() { echo username=x-access-token; echo "password=$GH_TOKEN"; }; f' push origin main

echo "==> Release $TAG"
gh release create "$TAG" "$DMG" --repo "$REPO" --title "macOS v$VERSION" --notes "$NOTES"
gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets[] | "\(.name) \(.size)"'

echo "==> Byte-verify download"
VERIFY="$(mktemp).dmg"
curl -sL -o "$VERIFY" "https://github.com/$REPO/releases/download/$TAG/SittingTime.dmg"
cmp "$VERIFY" "$DMG" && echo BYTE_IDENTICAL
rm -f "$VERIFY"
rm -rf "$(dirname "$CLONE")"
echo "OK: https://github.com/$REPO/releases/download/$TAG/SittingTime.dmg"

#!/bin/bash
# Build a universal dist/Dimmer.app, ad-hoc sign it and zip it for release.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="dist/Dimmer.app"

# Universal binary (Apple Silicon + Intel) so the release zip runs on any Mac.
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release --product Dimmer "${ARCHS[@]}"
BIN="$(swift build -c release --product Dimmer "${ARCHS[@]}" --show-bin-path)/Dimmer"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/"
cp scripts/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - --identifier com.mathiass.dimmer "$APP"
codesign --verify --strict "$APP" || { echo "codesign verification failed" >&2; exit 1; }
echo "Built $APP"

# Release zip for GitHub Releases.
rm -f dist/Dimmer.zip
ditto -c -k --keepParent "$APP" dist/Dimmer.zip
echo "Packed dist/Dimmer.zip"

#!/bin/bash
# Build dist/Dimmer.app from the SwiftPM executable and ad-hoc sign it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="dist/Dimmer.app"

swift build -c release --product Dimmer

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Dimmer "$APP/Contents/MacOS/"
cp scripts/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - --identifier com.mathiass.dimmer "$APP"
codesign --verify --strict "$APP" || { echo "codesign verification failed" >&2; exit 1; }
echo "Built $APP"

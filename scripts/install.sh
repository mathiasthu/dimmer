#!/bin/bash
# Copy dist/Dimmer.app to ~/Applications. Run scripts/build-app.sh first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -d "$ROOT/dist/Dimmer.app" ] || { echo "Run scripts/build-app.sh first" >&2; exit 1; }
mkdir -p "$HOME/Applications"
pkill -f "Dimmer.app/Contents/MacOS/Dimmer" 2>/dev/null || true
rm -rf "$HOME/Applications/Dimmer.app"
cp -R "$ROOT/dist/Dimmer.app" "$HOME/Applications/Dimmer.app"
echo "Installed ~/Applications/Dimmer.app. Grant Accessibility on first launch."

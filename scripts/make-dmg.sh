#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$ROOT/build"
APP="$OUT/Eye Guardian.app"
STAGE="$OUT/dmg-stage"

if [ ! -d "$APP" ]; then
    echo "missing $APP; run 'make bundle' first" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$OUT/Eye Guardian $VERSION.dmg"

rm -rf "$STAGE"
mkdir -p "$STAGE"
trap 'rm -rf "$STAGE"' EXIT

ditto "$APP" "$STAGE/Eye Guardian.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "Eye Guardian" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"

echo "Built $DMG"

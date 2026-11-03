#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/build}"

mkdir -p "$OUT/tools"
swiftc -O -parse-as-library \
    "$ROOT/Sources/EyeGuardian/Core/Models.swift" \
    "$ROOT/Sources/EyeGuardian/Platform/IconArtwork.swift" \
    "$ROOT/scripts/gen-icon.swift" \
    -o "$OUT/tools/gen-icon"

rm -rf "$OUT/AppIcon.iconset"
"$OUT/tools/gen-icon" "$OUT/AppIcon.iconset" "$OUT/icon-1024.png"
iconutil -c icns "$OUT/AppIcon.iconset" -o "$OUT/AppIcon.icns"
echo "wrote $OUT/AppIcon.icns"

#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SDK="$(xcrun --show-sdk-path)"
DEPLOY="13.0"
OUT="$ROOT/build"
APP="$OUT/Eye Guardian.app"
SIGN_ID="${CODESIGN_ID:-}"
SIGN_KEYCHAIN=""
if [ -z "$SIGN_ID" ]; then
    if SIGN_ID="$("$ROOT/scripts/dev-signing.sh")"; then
        SIGN_KEYCHAIN="$HOME/Library/Keychains/EyeGuardian.keychain-db"
    else
        echo "warning: could not create a local signing identity; falling back to ad-hoc" >&2
        SIGN_ID="-"
    fi
fi

mkdir -p "$OUT"

# App icon ---------------------------------------------------------------
mkdir -p "$OUT"
if [ ! -f "$OUT/icon-1024.png" ]; then
    swift scripts/gen-icon.swift "$OUT/icon-1024.png"
fi

ICONSET="$OUT/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$OUT/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$OUT/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$OUT/AppIcon.icns"

# Compile both architectures ---------------------------------------------
SRC="$(find Sources/EyeGuardian -name '*.swift' | sort)"
if [ -z "$SRC" ]; then
    echo "no Swift sources found" >&2
    exit 1
fi

rm -f "$OUT/EyeGuardian-arm64" "$OUT/EyeGuardian-x86_64" "$OUT/EyeGuardian"
for ARCH in arm64 x86_64; do
    # shellcheck disable=SC2086
    swiftc -sdk "$SDK" -target "${ARCH}-apple-macos${DEPLOY}" -swift-version 5 \
        -parse-as-library -O -whole-module-optimization $SRC -lsqlite3 \
        -o "$OUT/EyeGuardian-$ARCH"
done
lipo -create "$OUT/EyeGuardian-arm64" "$OUT/EyeGuardian-x86_64" -output "$OUT/EyeGuardian"

# Assemble the bundle ----------------------------------------------------
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$OUT/EyeGuardian" "$APP/Contents/MacOS/EyeGuardian"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Sources/EyeGuardian/Resources/en.lproj "$APP/Contents/Resources/"
cp -R Sources/EyeGuardian/Resources/zh-Hans.lproj "$APP/Contents/Resources/"
cp "$OUT/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

xattr -cr "$APP"
if [ -n "$SIGN_KEYCHAIN" ]; then
    codesign --force --keychain "$SIGN_KEYCHAIN" --sign "$SIGN_ID" "$APP"
else
    codesign --force --sign "$SIGN_ID" "$APP"
fi

echo "Built $APP"

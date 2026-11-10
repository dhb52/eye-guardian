#!/bin/sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

make dmg

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Info.plist)"
dmg="build/Eye Guardian ${version}.dmg"

key_output="$(swift scripts/update-key.swift generate)"
private_key="$(printf '%s\n' "$key_output" | sed -n 's/^private=//p')"
public_key="$(printf '%s\n' "$key_output" | sed -n 's/^public=//p')"

UPDATE_SIGNING_KEY="$private_key" swift scripts/update-key.swift sign "$dmg" > "${dmg}.sig"
swift scripts/update-key.swift verify "$dmg" "$(cat "${dmg}.sig")" "$public_key"

UPDATE_SMOKE_DMG="$dmg" \
UPDATE_SMOKE_VERSION="$version" \
UPDATE_SMOKE_BUNDLE_ID="$bundle_id" \
UPDATE_SMOKE_PUBLIC_KEY="$public_key" \
make test

echo "update smoke ok: $dmg"

#!/bin/bash
set -euo pipefail

KEYCHAIN="$HOME/Library/Keychains/EyeGuardian.keychain-db"
IDENTITY="EyeGuardian Local Signing"
PASSWORD="eyeguardian-local"

if security find-certificate -a -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1; then
    security unlock-keychain -p "$PASSWORD" "$KEYCHAIN" >/dev/null 2>&1 || true
    printf '%s\n' "$IDENTITY"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

openssl req -x509 -newkey rsa:2048 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -nodes -subj "/CN=$IDENTITY" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1

if ! openssl pkcs12 -export -legacy -out "$TMP/identity.p12" -inkey "$TMP/key.pem" \
    -in "$TMP/cert.pem" -passout "pass:$PASSWORD" >/dev/null 2>&1; then
    openssl pkcs12 -export -out "$TMP/identity.p12" -inkey "$TMP/key.pem" \
        -in "$TMP/cert.pem" -passout "pass:$PASSWORD" >/dev/null 2>&1
fi

security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
security create-keychain -p "$PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$PASSWORD" \
    -T /usr/bin/codesign >/dev/null 2>&1
security set-key-partition-list -S apple-tool:,apple: -s \
    -k "$PASSWORD" "$KEYCHAIN" >/dev/null 2>&1

printf '%s\n' "$IDENTITY"

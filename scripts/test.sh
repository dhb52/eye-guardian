#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SDK="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
mkdir -p build

CORE="$(find Sources/EyeGuardian/Core -name '*.swift' 2>/dev/null | sort)"
TESTS="$(find Tests -name '*.swift' | sort)"
# shellcheck disable=SC2086
swiftc -sdk "$SDK" -target "${ARCH}-apple-macos13.0" -swift-version 5 \
    -parse-as-library -O $CORE $TESTS -lsqlite3 -o build/CoreTests

./build/CoreTests

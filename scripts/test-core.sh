#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc Sources/Clothesline/DownloadIndex.swift Tests/DownloadIndexTests.swift -o "$TMP/tests"
"$TMP/tests"

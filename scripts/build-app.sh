#!/bin/bash
# Build locally on a Mac running macOS 14+. Requires Apple's Swift toolchain.
# Usage: scripts/build-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "Expected 'debug' or 'release'" >&2; exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "The graphical macOS app must be built on macOS (Darwin)." >&2; exit 2
fi
scripts/test-core.sh
if ! swift build -c "$CONFIG"; then
  # On some CLT-only macOS 27 installations SwiftUI SDK macro plugins may be
  # absent; try Apple's installed macOS 26 SDK as in the upstream build notes.
  if [[ -z "${SDKROOT:-}" ]]; then
    FALLBACK="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | sort -V | tail -1 || true)"
    if [[ -n "$FALLBACK" ]]; then
      export SDKROOT="$FALLBACK"
      echo "Retrying build with $FALLBACK" >&2
      swift build -c "$CONFIG"
    else
      echo "Please install full Xcode and retry." >&2
      exit 1
    fi
  else
    exit 1
  fi
fi
BINDIR="$(swift build -c "$CONFIG" --show-bin-path)"
APP="build/Clothesline.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINDIR/Clothesline" "$APP/Contents/MacOS/Clothesline"

# Generate an original Clothesline icon from a PNG bundled with this project.
ICONSET="$(mktemp -d)/Clothesline.iconset"
mkdir -p "$ICONSET"
for px in 16 32 128 256 512; do
  sips -z "$px" "$px" assets/clothesline-icon.png --out "$ICONSET/icon_${px}x${px}.png" >/dev/null
  sips -z "$((px*2))" "$((px*2))" assets/clothesline-icon.png --out "$ICONSET/icon_${px}x${px}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Clothesline.icns"
rm -rf "$(dirname "$ICONSET")"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Clothesline</string>
<key>CFBundleDisplayName</key><string>晾衣绳 Clothesline</string>
<key>CFBundleIdentifier</key><string>app.clothesline.Clothesline</string>
<key>CFBundleExecutable</key><string>Clothesline</string>
<key>CFBundleIconFile</key><string>Clothesline</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSDownloadsFolderUsageDescription</key>
<string>Clothesline watches the selected Downloads folder to display recently completed local files.</string>
<key>NSDocumentsFolderUsageDescription</key>
<string>Clothesline can watch a folder you choose; it does not move or delete files.</string>
</dict></plist>
PLIST

IDENTITY="${SIGN_IDENTITY:-}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - "$APP" >/dev/null
fi
printf '\nBuilt %s\nLaunch with: open %s\n' "$APP" "$APP"

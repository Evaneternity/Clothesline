#!/bin/bash
# Build locally on a Mac running macOS 14+. Requires Apple's Swift toolchain.
# Usage: scripts/build-app.sh [debug|release] [universal|native|arm64|x86_64]
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/ModuleCache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$CLANG_MODULE_CACHE_PATH}"
CONFIG="${1:-release}"
if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "Expected 'debug' or 'release'" >&2; exit 2
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "The graphical macOS app must be built on macOS (Darwin)." >&2; exit 2
fi
TARGET="${2:-universal}"
case "$TARGET" in
  universal) ARCHITECTURES=(arm64 x86_64) ;;
  native) ARCHITECTURES=("$(uname -m)") ;;
  arm64|x86_64) ARCHITECTURES=("$TARGET") ;;
  *) echo "Expected universal, native, arm64, or x86_64" >&2; exit 2 ;;
esac
scripts/test-core.sh
BINARIES=()
for ARCH in "${ARCHITECTURES[@]}"; do
  if ! swift build -c "$CONFIG" --arch "$ARCH"; then
    # On some CLT-only macOS 27 installations SwiftUI SDK macro plugins may be
    # absent; try Apple's installed macOS 26 SDK as in the upstream build notes.
    if [[ -z "${SDKROOT:-}" ]]; then
      FALLBACK="$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | sort -V | tail -1 || true)"
      if [[ -n "$FALLBACK" ]]; then
        export SDKROOT="$FALLBACK"
        echo "Retrying build with $FALLBACK" >&2
        swift build -c "$CONFIG" --arch "$ARCH"
      else
        echo "Please install full Xcode and retry." >&2
        exit 1
      fi
    else
      exit 1
    fi
  fi
  BINDIR="$(swift build -c "$CONFIG" --arch "$ARCH" --show-bin-path)"
  xcrun lipo "$BINDIR/Clothesline" -verify_arch "$ARCH"
  BINARIES+=("$BINDIR/Clothesline")
done
APP="build/Clothesline.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ "${#BINARIES[@]}" -gt 1 ]]; then
  xcrun lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/Clothesline"
else
  cp "${BINARIES[0]}" "$APP/Contents/MacOS/Clothesline"
fi
xcrun lipo "$APP/Contents/MacOS/Clothesline" -verify_arch "${ARCHITECTURES[@]}"
cp LICENSE "$APP/Contents/Resources/LICENSE"

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
<key>CFBundleVersion</key><string>3</string>
<key>ClotheslineReleaseVersion</key><string>0.1.0-rc.3</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSDownloadsFolderUsageDescription</key>
<string>Clothesline watches the selected Downloads folder to display recently completed local files.</string>
<key>NSDocumentsFolderUsageDescription</key>
<string>Clothesline can watch or display a folder you choose. Only an explicitly confirmed Trash action moves an item.</string>
</dict></plist>
PLIST

IDENTITY="${SIGN_IDENTITY:-}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - "$APP" >/dev/null
fi
codesign --verify --strict "$APP"
xcrun lipo -archs "$APP/Contents/MacOS/Clothesline"
printf '\nBuilt %s\nLaunch with: open %s\n' "$APP" "$APP"

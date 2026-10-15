#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${1:-universal}"
scripts/build-app.sh release "$TARGET"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :ClotheslineReleaseVersion' build/Clothesline.app/Contents/Info.plist)"
ARCHS="$(xcrun lipo -archs build/Clothesline.app/Contents/MacOS/Clothesline)"
if [[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]]; then
  ARCH=universal
else
  ARCH="$ARCHS"
fi
DMG="build/Clothesline-${VERSION}-${ARCH}.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto build/Clothesline.app "$STAGE/Clothesline.app"
ln -s /Applications "$STAGE/Applications"
cp LICENSE "$STAGE/LICENSE.txt"
cat > "$STAGE/安装说明.txt" <<'TEXT'
Clothesline V0.1 候选版 — macOS 14+（universal 包支持 Apple Silicon 与 Intel）
将 Clothesline.app 拖到 Applications 后打开。
默认监控 Downloads；菜单“添加监控文件夹…”可同时监控更多文件夹。
本候选版仅本地 ad-hoc 签名，尚未 Apple 公证。macOS 可能阻止首次打开；
请仅在确认下载来源后按照系统的“隐私与安全性”提示允许打开。
取下/清空仅隐藏；“移到废纸篓”确认后才操作原文件。

Clothesline release candidate — macOS 14 or later.
The universal DMG supports both Apple Silicon and Intel Macs natively.
Drag Clothesline.app into Applications, then open it.
Choose Language / 语言 → English for English menus.
This build is ad-hoc signed and not notarized by Apple.
Taking down or clearing cards keeps original files; only confirmed Trash moves originals.
TEXT
hdiutil create -volname Clothesline -srcfolder "$STAGE" -format UDZO -ov "$DMG"
hdiutil verify "$DMG"
(cd build && shasum -a 256 "$(basename "$DMG")") > "$DMG.sha256"

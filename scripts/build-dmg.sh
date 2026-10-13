#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh release
ARCH="$(uname -m)"
DMG="build/Clothesline-0.1.0-rc.1-${ARCH}.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto build/Clothesline.app "$STAGE/Clothesline.app"
ln -s /Applications "$STAGE/Applications"
cp LICENSE "$STAGE/LICENSE.txt"
cat > "$STAGE/安装说明.txt" <<'TEXT'
Clothesline V0.1 候选版 — macOS 14+（架构见 DMG 文件名）
将 Clothesline.app 拖到 Applications 后打开。
默认监控 Downloads；菜单“添加监控文件夹…”可同时监控更多文件夹。
本候选版仅本地 ad-hoc 签名，尚未 Apple 公证。macOS 可能阻止首次打开；
请仅在确认下载来源后按照系统的“隐私与安全性”提示允许打开。
取下/清空仅隐藏；“移到废纸篓”确认后才操作原文件。
TEXT
hdiutil create -volname Clothesline -srcfolder "$STAGE" -format UDZO -ov "$DMG"
hdiutil verify "$DMG"
(cd build && shasum -a 256 "$(basename "$DMG")") > "$DMG.sha256"

# 最新交接：README 演示与统一下载

2026-10-15。用户要求 macOS/Windows 下载放一起、使用演示上移、删除简介旧状态段。

README.md 与 README.en.md 现在依次为简介 → 使用演示 → 统一下载表格 → 功能与构建说明。删除原单独 Windows 章节与旧状态段，将两个平台的包、要求和校验入口集中在一张表。保留独立视频附件 URL，macOS rc.3 与 Windows rc.1 的原下载地址未变，未修改应用源码或安装包。

验证：审查双语顺序、下载链接和 Markdown 表格，git diff --check；按项目约定执行 scripts/build-app.sh release（含 test-core）。本轮不涉及 macOS 行为，无需重复 UI 或 Windows 安装测试。

下一步：提交并推送 main，核对远端 SHA。现有 macOS/Windows 的人工 UI 验收仍按 PROJECT_STATE.md 跟进，不重复发行已有安装包。

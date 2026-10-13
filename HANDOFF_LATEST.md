# 最新交接：rc.2 安装包与英文介绍

2026-10-13（Asia/Shanghai）。用户授权更新安装包到当前源码并增加英文介绍。

构建脚本发行文件名更新为 0.1.0-rc.2，CFBundleVersion 增为 2。包含当前彩色夹子；未新增应用功能。新增 README.en.md，中英文首页互链，下载入口更新至 rc.2，演示附件继续内嵌，MP4 下载仍使用 rc.1 附件。

验证：scripts/test-macos.sh、scripts/build-dmg.sh（含核心测试及 Release 构建）通过；hdiutil verify、只读挂载、codesign --verify --strict、版本与许可一致性、Applications 链接检查通过。SHA-256 见 PROJECT_STATE.md。已有旧式拖拽系统诊断未阻止测试通过；完整 UI 与跨应用拖拽仍需人工验收。

发布 v0.1.0-rc.2 预发行 DMG 和 SHA-256，保留 rc.1；仍 Apple Silicon、ad-hoc 签名且未公证。英文文档不代表应用 UI 已英文翻译。每次修改继续更新双语介绍并同步 GitHub。

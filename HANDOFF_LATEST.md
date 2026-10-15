# 最新交接：README 功能介绍整合

2026-10-15。按用户要求，README.md 的“新增工作流（源码开发版）”和“功能（V0.1）”去重整理为单一“功能介绍”，英文页合并为 Features。删除中文“macOS 构建与运行”和英文 Build from source 章节及残留构建命令；保留统一下载、视频、应用菜单、操作速查与许可。顺带修正旧限制列表对开机启动/英文界面的过时描述。

本轮仅文档改动。验证：双语功能覆盖与章节顺序审查、git diff --check；scripts/build-app.sh release（含核心测试）按项目约定执行。无需重复 macOS UI 或 Windows 安装回归，未声称 UI 实测。

下一步：提交、推送 main，并核对远端 SHA；已有候选安装包不重新发行，平台 UI 待验收项仍见 PROJECT_STATE.md。

# 最新交接：README 功能介绍整合

2026-10-15。按用户要求，README.md 的“新增工作流（源码开发版）”和“功能（V0.1）”去重整理为单一“功能介绍”，英文页合并为 Features。删除中文“macOS 构建与运行”和英文 Build from source 章节及残留构建命令；保留统一下载、视频、应用菜单、操作速查与许可。顺带修正旧限制列表对开机启动/英文界面的过时描述。

本轮仅文档改动。验证：双语功能覆盖与章节顺序审查、git diff --check；scripts/build-app.sh release（含核心测试）按项目约定执行。无需重复 macOS UI 或 Windows 安装回归，未声称 UI 实测。

下一步：提交、推送 main，并核对远端 SHA；已有候选安装包不重新发行，平台 UI 待验收项仍见 PROJECT_STATE.md。

同步记录：正文提交 86a644f；fetch 超时，推送两次（35/30 秒）超时。继续重试并核对远端；不能仅依据本地提交宣称 GitHub 页面已更新。

同步恢复：官方 Git 数据 API 已逐项匹配本地 blob、tree、commit SHA，原样传输 86a644f、189b315，再以 force=false 快进 main；核验远端 189b315。本地 origin/main 跟踪引用已更新。后续普通 Git 超时可采用同样的严格 SHA 匹配流程；若对象 SHA 不同或远端分叉，必须停止更新分支。

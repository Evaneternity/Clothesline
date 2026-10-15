# 最新交接：剪贴板菜单精简

2026-10-15。按用户要求，仅移除“挂上当前剪贴板”和底部“仅本机…”灰色说明；自动图片/文字开关、清空及错误提示保持。未实施此前讨论的手动暂存或持久保存方案。

AppDelegate 删除两处菜单创建代码；双语 README 同步移除手动入口介绍，保留隐私与临时副本说明。内部 captureCurrent 测试能力保留。

验证：scripts/test-core.sh、scripts/test-macos.sh、scripts/build-app.sh release 全部通过。macOS 废纸篓回归与 SwiftPM 在沙盒内受权限限制，提升执行权限后通过；既有粘贴板/CoreDrag/颜色空间诊断不影响通过。git diff --check 通过。未进行完整菜单 UI 实测；本地构建位于 build/Clothesline.app，rc.2 DMG 未更新。

下一步：用户验收菜单显示；按开发约定提交并推送 main，核对远端 SHA。

GitHub 同步待确认（2026-10-15）：菜单改动已提交 e1d61b2；fetch 空响应及重试超时，push 40 秒超时，尚未核验远端接收。后续需重试推送并比对 SHA。

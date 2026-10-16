# 最新交接：时间设置名称与提示文案

2026-10-16，feature/hover-delay-expiration。

## 改动
- 菜单、窗口标题和无障碍标签统一为“悬停显示晾衣绳延迟”；英文为 Hover to Show Clothesline Delay。
- 中英文提示直接说明默认值及行为，清理版本对比措辞；同步 README、变更日志和状态文档。
- 悬停默认 0.0 秒、0.1 秒精度，保留时间默认永不过期。沿用已有偏好及剪贴板适用逻辑，功能未变更。

## 验证
- scripts/build-app.sh release（含 scripts/test-core.sh）及 scripts/test-macos.sh 通过；双语菜单相邻位置检查已使用新名称。
- 源码和相关文档的旧名称/版本对比措辞检查、git diff --check 通过。
- 安装应用与构建二进制一致，严格全架构签名通过，确认单实例完成启动。此轮未重复 GUI 交互验收；上一轮独立预览输入与恢复默认验证见 PROJECT_STATE.md。
- 既有 GrabArea 捕获警告及粘贴板/CoreDrag/颜色空间诊断仍出现，未改动相关实现。

## 安装与同步
已更新 /Applications/Clothesline.app。备份：build/install-backups/20261016-145847/Clothesline.app。
二进制 SHA-256：d2c0db27d15a59f7d692260ae98d9b9b184601c4125cfc347273ffbb8fd37352。

代码和文档保留在当前功能分支。此前远端推送返回 403，当前账号无仓库写权限；完成本轮提交后按约定尝试推送，并在交付中报告结果。未创建 PR、合并 main 或发布新发行资产。

## 下一步
使用具备写权限的账号同步分支；按需补充原生菜单栏入口、真实持续悬停、多屏及睡眠的完整 UI 验收。Windows 尚未实现新增时间设置。

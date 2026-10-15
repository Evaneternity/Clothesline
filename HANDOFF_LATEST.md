# 最新交接：应用菜单与双语界面

2026-10-15。用户要求开机启动、检查更新、关于、中英文菜单切换。

在 feature/app-menu-settings 开发。AppServices.swift 包含登录项服务封装、语义版本与 GitHub 发布筛选、手动更新检查；AppLanguage.swift 提供持久语言选择与 UI 翻译。AppDelegate 动态菜单显示系统实际登录状态，待批准时可打开系统设置；不在启动时注册。关于显示完整随包 MIT 许可。主菜单、卡片右键、近期文件和身份/文件操作提示已联动。

检查更新仅由点击触发，匿名访问本仓库 GitHub Releases，15/20 秒超时，无缓存或持久 Cookie，不发送文件/剪贴板。候选版包含候选和正式版，正式版仅正式；过滤草稿与外部下载页；打开发布页，不自动下载安装。应用版本标记 0.1.0-rc.3 / build 3，未发行，不改变已有 rc.2 DMG。

验证：scripts/test-macos.sh 新增 Tests/AppServicesTests.swift，使用假登录服务验证开关/失败，不修改实际系统登录项；验证版本排序、候选过滤、草稿和 URL 筛选、真实 NSMenu 动作及语言保存。既有 macOS、scripts/test-core.sh（build-app 包含）、scripts/build-app.sh release 通过；最终 git diff --check、codesign --verify --strict。既有 CoreDrag/旧式 PB/颜色空间诊断非失败。未把自动回归当作完整 UI 验收。

下一步：安装到 Applications 后手动验收实际登录启动/关闭、网络检查更新、关于与语言；等待用户授权发行新版 DMG。开发完成后快进合并 main 并推送、核对 SHA。fetch 两次 20 秒超时；此前本地菜单精简提交一并保留待推送。

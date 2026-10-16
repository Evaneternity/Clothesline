# 最新交接：悬停延迟与监控项目过期

2026-10-16，feature/hover-delay-expiration，基于 origin/main d48feca。用户要求状态栏停留一定时间再展示（设置精度 0.1 秒），以及监控文件/文件夹过期隐藏、没有近期内容时悬停不展开。本轮按当前 macOS 环境实现。

## 实现
- DisplayPreferences：悬停默认 0.5 秒，范围 0–10 秒、0.1 秒归一化；目录默认 24 小时、1 分钟至 365 天或永不过期，按标准目录路径持久化。
- SettingsWindow：菜单“设置…”双语原生窗口，数值输入/步进和每目录时长/单位/到期隐藏开关，即时保存；切换语言和添加目录后刷新。
- LineRevealController：单调时钟连续停留检测、离开取消、空列表抑制、0.75 秒离开宽限；显式一直显示和拖入目标保留，源卡片拖拽不中断。
- FolderMonitors 将各目录过期策略传给 Line；2 秒轮询和读取失败持续刷新，设置修改立即重算。自动项按进入目录时间（缺失则创建时间）过滤绳上及近期列表；固定、手动、剪贴板不受影响。到期不修改任何源文件、不写取下记录，延长时长可恢复。
- scripts/build-app.sh：兼容 Swift 6.4 swiftbuild 架构共用输出路径，逐架构暂存后合并；逐个验证 lipo 架构，避免本机工具多参数解析失败。

## 验证
- scripts/test-core.sh：通过，新增持久化/精度、日期回退和过期边界、悬停取消/空列表/拖入/显示偏好。
- scripts/test-macos.sh：通过；自建真实双目录文件/目录监听，注入时间验证过期、源内容安全、按住/拖出延后更新、延长/关闭过期、固定/手动/重启、近期过滤；原有全部回归通过。
- scripts/build-app.sh release：通过，build/Clothesline.app 为 arm64 + x86_64。
- codesign --verify --strict --all-architectures、vtool 两种架构 minos 14.0、Info.plist、LICENSE 一致性、git diff --check：通过。
- 环境 macOS 27.0.1 / Apple Swift 6.4。已有 GrabArea capture warning、NSFilenamesPboardType/CoreDrag/颜色空间诊断仍出现，没有据此声称实际跨应用拖放已验收。

## 限制与后续
设置窗口构造和菜单入口通过，但 CUA 读取独立预览窗口失败（cgWindowNotFound），完整输入/真实鼠标/多屏/睡眠 UI 仍需验收。临时预览使用独立应用身份，不触及当前安装版；本轮不替换运行中的应用、不发行安装包。现有 rc.3 DMG 与 Windows 安装包不含这些新增设置。Windows 若需要对齐需单独实现验证。

功能提交 45933c0 已保存在本地 feature/hover-delay-expiration。按 AGENTS.md 尝试推送失败：全局凭据助手引用不存在的 /usr/bin/gh；以单次 Git 配置指定已安装的 gh 后，GitHub 返回 403，当前登录账号没有 zhongguozhang/Clothesline 写权限。未修改全局凭据配置，未同步远端、合并 main 或创建 Release。后续需具备写权限的身份推送该分支。

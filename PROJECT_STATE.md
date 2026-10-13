# Clothesline V0.1 项目状态

更新：2026-10-13（Asia/Shanghai）
状态：本地候选版；Release 构建、核心与 macOS 集成测试通过，完整 UI 验收待完成。

## 架构与功能
SwiftPM 可执行目标，macOS 14+；AppKit 浮层与菜单栏、SwiftUI 卡片、Quick Look、Carbon 快捷键。DownloadsWatcher 使用 vnode 事件及 2 秒轮询；DownloadIndex 扫描顶层文件与目录，排除隐藏项、符号链接及临时下载名，使用两次稳定样本和 2 秒静默期。

本轮更新：替换独立 logo（浅色圆角底、蓝色 T 恤、晾衣绳与夹子），应用包和菜单栏统一；源文件 assets/clothesline-icon.png，生成说明 assets/ICON_DESIGN.md。

前轮修复用户反馈的拖出失败：
- 按住及拖拽期间不切换源窗口鼠标穿透，不隐藏/移动源窗口。
- 延迟卡片列表刷新至交互结束，防止目录更新销毁源视图。
- 提供标准 file URL 与兼容旧应用的文件路径数组，忽略修饰键以维持 copy。

此前按用户要求完善：
- 右键“移到废纸篓…”确认后操作原文件或目录及内容，失败提示，旧卡片元数据失效时拒绝删除。
- Downloads 顶层目录自动显示；“挂上文件夹…”可选择其他目录，普通书签保留入口。手动目录优先显示，不改变 Downloads 监控。
- 菜单“一直显示晾衣绳”/“自动隐藏晾衣绳”，⌃⌥T 切换；设置持久化并在启动时应用。
- 目录使用系统图标，双击通过 Finder 打开；目录内容变化不清除取下状态。

## 验证证据
环境：macOS 26.6.2 / arm64，Apple Swift 6.3.3，Command Line Tools。
- scripts/test-core.sh：通过文件/目录过滤、临时下载目录排除、符号链接排除、稳定样本、静默期、目录隐藏指纹稳定性。
- scripts/test-macos.sh：通过真实目录监听、临时文件重命名、真实 URL 卡片、取下/空扫描/重启/清空保留源文件；手动目录跨重启、目录取下保留内容；文件及非空目录移到废纸篓、内容完整及恢复；已变更文件删除被拒绝；显示偏好跨实例持久化；copy-only 拖拽源掩码。
- 废纸篓测试仅操作唯一命名的自建临时文件/目录，移入后立即恢复至测试目录，再清理测试目录，不清空用户废纸篓。
- Release 构建并启动。运行应用的可访问性树新增实际 Downloads 目录 CEN_Submission_Package_Updated_2026-10-12，已核对其确为目录。
- 拖拽回归：独立粘贴板可由 NSURL 解码真实文件，旧式路径数组读取一致；按住/拖拽期间保留原卡片 ID，结束后应用待处理扫描。
- 本轮 Release 包通过 codesign --verify --strict、Info.plist 和 LICENSE 一致性检查。

## 文件安全与许可
×、取下、清空、退出仍只改变显示。仅单独的废纸篓命令移动原项目，UI 默认取消并明确说明目录包含其内容；没有永久删除接口。读取最新元数据核对卡片后调用系统 trashItem，不保证核对与系统移动之间绝对不存在外部替换竞争。拖出提供 copy。普通书签适用于当前非沙盒本地版本。

保留 LICENSE 中 Alejandro Buján 的原作者版权与完整 MIT；应用包包含许可。使用 Clothesline 独立名称与现有独立图标。

## 限制与下一步
- 微信等第三方应用实际接收尚未验收，不声称已端到端验证；本轮针对代码中发现的鼠标跟踪和源视图生命周期问题修复。
- 透明浮层 UI 自动化曾返回空白截图/不可点击元素；本轮模型/系统操作测试通过，不能替代右键确认弹窗、手动选择目录、鼠标离开保持显示的人工 UI 验收。
- Quick Look、双击、实际 Finder 拖拽，Chrome/Safari 下载，权限拒绝/重新授权、睡眠、多屏、macOS 14 兼容性仍待验收。
- 目录稳定仅看目录本身元数据，不递归判断内容写入；完成检测为启发式。
- 手动目录读不到时不展示，书签保留便于恢复访问；未增加单独的目录权限错误 UI。
- 隐藏记录尚未自动清理；本地 ad-hoc 签名，未公证，提供 DMG 候选版（v0.1.0-rc.1），不打正式版本标签。

## GitHub

已建立公开远端 origin：https://github.com/zhongguozhang/Clothesline，默认分支 main。用户授权后续开发持续同步；流程见 AGENTS.md。初次推送与 SHA 核验见本轮交付结果。

## 本轮：多目录监控与下载发行

新增 FolderMonitors：默认 Downloads，每个目录独立 watcher 和完成 gate；“添加监控文件夹…”支持多选，保存书签，启动恢复并兼容旧 folderBookmark。更新只替换各自快照，合并排序且去重；菜单显示每个目录及错误，唤醒重启全部 watcher。

macOS 集成测试通过两个自建目录同时发布真实文件、重复添加去重、跨目录路径去重、重启恢复及保留默认 Downloads。既有文件操作/废纸篓/显示/拖拽数据回归通过。

DMG 构建脚本 scripts/build-dmg.sh，包含 Clothesline.app、Applications 链接、MIT 与安装说明，生成 SHA-256。发布候选 v0.1.0-rc.1，Apple Silicon / macOS 14+，未 Developer ID 签名或公证。

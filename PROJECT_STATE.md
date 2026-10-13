# Clothesline V0.1 项目状态

更新：2026-10-13（Asia/Shanghai）
状态：本地候选版；macOS 构建/启动及核心链路通过，完整 UI 验收未完成。

## 架构与范围
SwiftPM 可执行目标，macOS 14+；AppKit 浮层与菜单栏，SwiftUI 晾衣绳，Quick Look 缩略图/预览，Carbon 快捷键。DownloadsWatcher 使用目录 vnode 事件及 2 秒轮询；DownloadIndex 顶层扫描并过滤临时文件，要求两次稳定样本和至少 2 秒静默。Line 管理真实 URL、卡片与隐藏记录；GrabArea 通告 copy 拖拽。

## 本轮修复
- 移除不存在的 QLPreviewPanelController 协议，使用 NSObject Quick Look 控制方法 override。
- 布局位置函数标注 MainActor。
- 空完成扫描不再清除持久隐藏记录；普通文件夹书签增加恢复兜底。
- 项目内编译缓存；构建应用包包含 LICENSE；独立 Clothesline 名称和现有独立图标。

## 已有证据
- 环境：macOS 26.6.2 / arm64，Apple Swift 6.3.3，Command Line Tools。
- scripts/test-core.sh：通过文件过滤、稳定样本、静默期与真实目录扫描。
- scripts/test-macos.sh：通过真实目录事件、临时文件重命名完成、真实 URL 卡片、取下/空扫描/重启/清空后隐藏与原文件字节不变、copy-only 源操作掩码。
- Debug 和 Release 构建成功；Debug 应用已启动；codesign --verify --strict 与 Info.plist 检查通过。
- 运行应用的可访问性树包含 Downloads 文件；新增 Clothesline-acceptance-20261013.txt 后自动出现其名称。测试文件保留供人工验收。
- LICENSE 已核对上游 MIT 版权 Copyright (c) 2026 Alejandro Buján；完整许可随应用包分发。

## 文件安全审查
生产代码未调用删除、移动、覆盖下载源文件的 API。dismiss/dismissAll 仅写 UserDefaults 和刷新显示；open/reveal 交给 NSWorkspace；复制写真实 URL 至剪贴板；拖出通告 copy。构建脚本删除范围仅 build/Clothesline.app 与自身临时图标目录；测试删除范围仅自建临时测试目录。

## 限制与待验收
- 透明浮层 UI 自动化返回空白截图/不可点击元素，无法证明完整可见效果及实际菜单操作。
- Quick Look、双击打开、Finder 拖拽、UI ×/清空需人工实际验收；模型安全测试已通过。
- Chrome/Safari 真实下载、权限拒绝/授权、睡眠、多屏、macOS 14 兼容性未验证。
- 完成检测为启发式；隐藏记录暂不自动清理，长期使用可能增长。
- 本地 ad-hoc 签名，无公证/DMG/远端 Git；不宣称正式发行完成。

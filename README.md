# 🧺 Clothesline · 晾衣绳

**把刚刚下载完成的真实文件挂在 macOS 屏幕顶部。**

Inspired by [Tendedero](https://github.com/alejandrobujan/tendedero) by Alejandro Buján, with its light transparent rope, clothespins, spring animations, and auto-hide interaction. Unlike Tendedero's screenshot workflow, Clothesline focuses on actual files in Downloads. Clothesline has its **own name and original icon** and does not claim endorsement by the Tendedero author.

**状态：V0.1 源码原型，非正式发行版。** Swift 下载检测核心测试已通过；尚未在真实 Mac 上构建 / 运行验证 AppKit/SwiftUI 的所有交互。下载前请注意：这是一个源码包，不是已签名可安装的 DMG。

## 功能（V0.1）

- 自动监听系统 `~/Downloads` 或手动选择的文件夹（无需云端和账号）。
- 启动后显示最近的下载文件，并持续检查最新加入的文件。
- 过滤 `.crdownload`、`.download`、`.part`、`.tmp` 等临时后缀和隐藏文件。
- 文件需连续两次扫描保持大小和修改时间不变，且静默期至少 2 秒才显示。
- 若目标文件存在对应临时下载文件（如 `paper.pdf.crdownload`），暂不显示 `paper.pdf`。
- `QuickLookThumbnailing` 生成 PDF/图片/视频缩略图；其他类型回退系统图标。
- 屏幕顶部晾衣绳、衣夹、卡片弹簧动画；悬停展开、移开收起。
- 单击 Quick Look；双击打开；右键 Finder 定位 / 复制文件 / 从晾衣绳取下。
- 拖出真实文件到其他 app 或 Finder；**默认只提供复制操作**，不移动源文件。
- 左上角 `×` 及“清空晾衣绳”只隐藏条目，**不删除、移动、覆盖** Downloads 里的任何文件。
- 菜单栏选择监控目录、控制显示数量和卡片尺寸、固定显示。
- `⌃⌥T` 固定显示 / 取消固定显示。
- 已移除条目保留本地抑制记录，重新下载替换文件后可再次显示。
- 轮询兜底用于处理事件丢失和睡眠唤醒。

## macOS 构建与运行

系统要求：macOS 14+，Apple Command Line Tools (Swift 5.9+) 或 Xcode；SwiftUI + AppKit。

在 Mac 的 Terminal 中，解压源码并进入项目目录：

```bash
cd Clothesline
scripts/test-core.sh
scripts/build-app.sh
open build/Clothesline.app
```

构建脚本默认使用本机架构（Apple Silicon 或 Intel）、`release` 配置，并进行本机 **ad-hoc 签名**，无需开发者证书。若需要 Debug 构建：`scripts/build-app.sh debug`。

第一次读取 Downloads 时，macOS 可能要求授权。若自动权限没有弹出或监听失败，请点击菜单栏的 🧺 → **选择监控文件夹…** → 选择 Downloads。自选文件夹采用 security-scoped bookmark（能够使用时）保留访问权限。重新构建后，macOS 可能重新请求授权。

**这是源码构建，不是苹果公证的发行安装包**；未提供 `.dmg` / 自动更新。项目不会修改系统的截图设置，不截屏，也不读取剪贴板。

## 操作速查

| 操作 | 结果 |
|---|---|
| 鼠标移到菜单栏 / 屏幕顶部 | 显示晾衣绳 |
| 鼠标离开晾衣绳 | 自动收起 |
| 单击文件 | Quick Look 预览 |
| 双击文件 | 默认应用打开 |
| 拖拽到 App/Finder | 复制真实文件链接所指的内容（由目标处理） |
| 右键 | 快速预览、打开、显示于 Finder、复制文件、从绳上取下 |
| 左上角 × | 仅隐藏卡片，源文件不变 |
| 菜单栏 → 清空 | 隐藏当前项目，不删除任何文件 |
| 菜单栏 → 重新显示已取下的文件 | 清除隐藏记录，重新展示最近文件 |
| ⌃⌥T | 切换固定显示 |

## 目录

```text
Clothesline/
├── Package.swift
├── Sources/Clothesline/
│   ├── main.swift, AppDelegate.swift
│   ├── DownloadsWatcher.swift     # vnode 事件 + 扫描 + 唤醒
│   ├── DownloadIndex.swift       # 下载文件过滤、完成度确认（可在 Linux 单测）
│   ├── Line.swift                # 文件列表、隐藏状态、真实文件操作、缩略图
│   ├── LinePanel.swift, LineView.swift, PeggedView.swift
│   ├── GrabArea.swift, QuickLook.swift, HotKey.swift
├── Tests/DownloadIndexTests.swift
├── scripts/test-core.sh
├── scripts/build-app.sh
└── assets/clothesline-icon.png  # 独立设计的图标
```

## 设计原则与限制

1. **文件原地不动。** 当前所有 UI 移除操作只针对应用内部显示；不会调用 `trashItem` 或 `removeItem` 对下载目录执行删除。关闭软件不会删除文件。
2. **不声称能百分之百识别下载完成。** 文件稳定检测 + 临时扩展名过滤足以覆盖常见浏览器流程，但极端情况下下载暂停超过 2 秒、文件先生成最终名称且没有临时伴随文件，仍有提前显示的可能。V0.2 可考虑扩展浏览器下载元数据、xattr 和更细粒度持续写入状态检测。
3. **本地访问。** 当前无联网逻辑、无遥测、无账户。监控目录选择及隐藏状态保存在本地 `UserDefaults`。
4. **单层监控。** V0.1 只扫描监控目录的顶层，不递归子目录；目录不会挂上晾衣绳。
5. **非破坏性拖出。** V0.1 源仅通告 `.copy`；如果想从 Downloads 移动到其他文件夹，需要使用 Finder 完成移动。未来可以考虑经确认的移动模式。
6. **可验收，不夸大。** 已在 Linux 编译运行 `DownloadIndex` 的基础测试，已通过 Swift 的语法解析。未在此运行 macOS 特有的 AppKit、SwiftUI、Quick Look、文件授权和多显示器交互测试；这些需要 Mac。
7. **未包含**：开机自启、原生 DMG 分发、Apple 公证、自动更新、高级全屏隐藏策略、完整无障碍 / VoiceOver、中文外其他本地化。这些属于后续版本。

## 后续 macOS 验收清单

- [ ] Mac 源码构建成功，打开后菜单栏可见 🧺。
- [ ] 选择 Downloads 后自动显示最近文件（约 2 秒稳定扫描）。
- [ ] Chrome 下载 PDF/ZIP 时 `.crdownload` 不出现，完成后出现。
- [ ] Safari `.download` 包未出现，完成后出现。
- [ ] PDF 第一页、图片缩略图，以及 ZIP/DMG 系统图标正常。
- [ ] Quick Look、双击打开、拖拽复制、Finder 定位可用。
- [ ] 点击 `×`、清空以及卡片自动退出不影响原文件。
- [ ] 睡眠唤醒、多屏、屏幕缩放、不同 macOS 版本验证。
- [ ] 用户取消 Downloads 权限时错误提示与重新授权路径清楚。

## 版权与来源

Tendedero 源码由 Alejandro Buján 按 MIT 发布；本项目借鉴并改写其晾衣绳结构、悬浮交互、动画与卡片设计思想。参见 [原项目许可证](https://github.com/alejandrobujan/tendedero/blob/main/LICENSE)。Tendedero 的名称、图标和文档配图不在其 MIT 授权范围内，本项目没有使用。Clothesline 为独立项目；完整许可见 `LICENSE`。

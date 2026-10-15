# <img src="assets/clothesline-icon.png" alt="Clothesline 图标" width="48" height="48"> Clothesline · 晾衣绳

[English](README.en.md) · **简体中文**

**把刚刚下载完成的真实文件挂在 macOS 屏幕顶部。**

Clothesline（晾衣绳）是一款 macOS 原生文件工具，将最近下载或新增的文件与目录，以卡片形式挂在屏幕顶部，方便随手预览、打开、拖拽和管理。

默认监控 Downloads，也可添加多个监控文件夹，或手动挂上常用目录。晾衣绳支持自动隐藏与一直显示；取下卡片只隐藏入口，删除则通过独立的“移到废纸篓”操作完成。所有功能在本机运行，无需账号或云端服务。

**状态：V0.1 本地候选版。** 已在 macOS 26.6.2 / Apple Silicon 构建并启动，核心与 macOS 监听、安全测试通过。完整 UI 验收仍待完成，见 PROJECT_STATE.md 和 HANDOFF_LATEST.md。

## 使用演示

下面是约 36 秒的实际使用录屏，展示晾衣绳的文件卡片与彩色夹子。

https://github.com/user-attachments/assets/aab83014-934a-43c0-bc72-8055df02e67b

**[下载演示视频（MP4，约 4 MB）](https://github.com/zhongguozhang/Clothesline/releases/download/v0.1.0-rc.1/Clothesline-demo.mp4)**

最新 rc.2 安装包已包含录屏中的彩色夹子。

## 新增工作流（源码开发版）

- 文件或文件夹卡片右键“固定 / 取消固定”，固定项不被新挂载挤走，重启后恢复；超过屏幕容量可滚动查看。取下会取消该项固定，清空会取消全部固定，均不删除源文件。
- 悬停卡片约 0.4 秒后，在独立信息浮层中显示完整名称、来源目录、大小、创建和修改时间；文件夹不递归计算大小。失效卡片保留并标红，提示源文件不存在或无法访问，显示最后记录的信息；恢复访问后自动恢复。

- 从 Finder 将一个或多个文件、文件夹拖到展开的晾衣绳上挂载，只保存入口，原文件不移动；菜单也可选择“挂上文件或文件夹…”。
- 卡片右键“重命名…”修改名称，保留文件扩展名；同名冲突或文件已变化时提示，不覆盖。
- 菜单“剪贴板挂载”：图片 / 截图、文字便签独立开关，默认均关闭，开启后仅处理新复制内容。
- 文字显示为便签，支持预览、双击编辑、复制文字、另存为；图片支持预览、复制图片、另存为。相同内容不重复挂载，应用自己的复制不会自动回流。
- 仅处理剪贴板截图，不专门监听已保存的截图；截图文件若在已有监控目录中，仍按普通文件显示。
- 剪贴板内容仅保留本次会话的本地临时副本，不加入持久最近文件记录。退出或“清空剪贴板挂载内容”清理副本，用户另存文件不受影响；异常退出可能留在系统临时目录中。每会话最多 100 条，图片输入 32 MB 以内，文字 200 KB 以内。文字可能包含敏感内容，请按需开启。
- 绳上“最近文件”或菜单“最近文件…”打开可搜索窗口，保存最多 200 个近期文件入口；可重新挂上取下的文件，也可拖出。删除或无法访问的源文件不显示。
- 卡片右键“分享…”调用 macOS 系统分享菜单，可用服务取决于系统与已安装应用。

上述新增功能已在源码和本地构建中提供，GitHub rc.2 DMG 仍为上一候选版本；完整鼠标交互与实际 AirDrop/邮件分享待人工验收。

## 功能（V0.1）

- 默认监听系统 `~/Downloads`，通过“添加监控文件夹…”可同时监听多个目录（无需云端和账号）。
- 启动后显示最近的下载文件和目录，并持续检查最新加入的项目。
- 菜单栏 → “挂上文件夹…”可挂上任意所选目录，保留原位置，重启后保留入口。
- 过滤 `.crdownload`、`.download`、`.part`、`.tmp` 等临时后缀和隐藏文件。
- 文件需连续两次扫描保持大小和修改时间不变，且静默期至少 2 秒才显示。
- 若目标文件存在对应临时下载文件（如 `paper.pdf.crdownload`），暂不显示 `paper.pdf`。
- `QuickLookThumbnailing` 生成 PDF/图片/视频缩略图；其他类型回退系统图标。
- 屏幕顶部晾衣绳、衣夹、卡片弹簧动画；悬停展开、移开收起。
- 单击 Quick Look；双击打开；右键 Finder 定位 / 复制 / 取下 / 移到废纸篓。
- “移到废纸篓…”经确认后移除原文件或整个目录，可在 Finder 废纸篓恢复。
- 拖出真实文件到其他 app 或 Finder；**默认只提供复制操作**，不移动源文件。
- 左上角 `×` 及“清空晾衣绳”只隐藏条目，**不删除、移动、覆盖** Downloads 里的任何文件。
- 菜单栏添加多个监控目录、控制显示数量和卡片尺寸、固定显示。
- 菜单栏选择“一直显示晾衣绳”或“自动隐藏晾衣绳”；`⌃⌥T` 切换，重启后保留选择。
- 已移除条目保留本地抑制记录，重新下载替换文件后可再次显示。
- 轮询兜底用于处理事件丢失和睡眠唤醒。

## 下载安装（V0.1 候选版）

[下载 Clothesline DMG（Apple Silicon）](https://github.com/zhongguozhang/Clothesline/releases/download/v0.1.0-rc.2/Clothesline-0.1.0-rc.2-arm64.dmg) · [发行说明和 SHA-256 校验文件](https://github.com/zhongguozhang/Clothesline/releases/tag/v0.1.0-rc.2)

要求 macOS 14+、Apple Silicon（M 系列）；本次不提供 Intel 安装包。打开 DMG，将 Clothesline.app 拖到 Applications，再打开应用。当前仅 ad-hoc 签名，未 Developer ID 签名/公证；macOS 可能阻止首次运行，请确认来自本仓库后，按系统“隐私与安全性”的提示允许打开。

默认监控 Downloads。菜单“添加监控文件夹…”可以一次选择多个目录，原监控继续运行；添加列表重启后保留。旧版本自选监控目录会保留，同时补回默认 Downloads。菜单列出所有目录及各自错误。 “挂上文件夹…”仅添加目录快捷入口，与持续监控内容不同。

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

第一次读取 Downloads 时，macOS 可能要求授权。若自动权限没有弹出或监听失败，请点击菜单栏的 Clothesline T 恤图标 → **添加监控文件夹…** → 选择 Downloads。自选文件夹采用 security-scoped bookmark（能够使用时）保留访问权限。重新构建后，macOS 可能重新请求授权。

**候选安装包尚未 Apple 公证**；已提供 `.dmg`，暂不支持自动更新。项目不截屏或修改系统截图设置；仅在开启对应自动功能时读取剪贴板。

## 应用菜单

- **开机启动**：菜单勾选开启，再点取消；状态读取 macOS 登录项。若系统要求批准，菜单提供系统设置入口。建议将应用放入“应用程序”后设置。
- **检查更新…**：仅点击时连接 GitHub 查询发布版本；有新版时前往发布页下载，不会自动安装。候选版可检查后续候选版和正式版，正式版只提示正式版。
- **关于 Clothesline…**：查看版本、项目主页和随应用携带的 MIT 许可。
- **语言 / Language**：切换简体中文、English，选择保留到下次启动。菜单、卡片右键菜单和近期文件界面随之切换；系统窗口及错误信息可能遵循系统语言。

本地开发构建为 `0.1.0-rc.3`（build 3），尚未发行；GitHub 现有 rc.2 安装包不包含这些新菜单。

## 操作速查

| 操作 | 结果 |
|---|---|
| 鼠标移到菜单栏 / 屏幕顶部 | 显示晾衣绳 |
| 鼠标离开晾衣绳 | 自动收起 |
| 单击文件 | Quick Look 预览 |
| 双击文件 | 默认应用打开 |
| 拖拽到 App/Finder | 复制真实文件链接所指的内容（由目标处理） |
| 右键 | 快速预览、打开、显示于 Finder、复制、取下、移到废纸篓 |
| 右键 → 移到废纸篓… | 确认后将原文件或目录及内容移到废纸篓 |
| 菜单栏 → 挂上文件夹… | 选择一个或多个目录挂上，原位置不变 |
| 菜单栏 → 一直显示 / 自动隐藏 | 设置显示方式并记住选择 |
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

1. **取下与删除分开。** ×、取下、清空和退出不改变源文件；独立的“移到废纸篓…”命令在确认后调用 macOS 废纸篓，失败会提示。不会永久删除。目录移到废纸篓包含全部内容。
2. **不声称能百分之百识别下载完成。** 文件稳定检测 + 临时扩展名过滤足以覆盖常见浏览器流程，但极端情况下下载暂停超过 2 秒、文件先生成最终名称且没有临时伴随文件，仍有提前显示的可能。V0.2 可考虑扩展浏览器下载元数据、xattr 和更细粒度持续写入状态检测。
3. **本地访问。** 仅手动检查更新时连接 GitHub 获取发布信息；文件与剪贴板内容不上传，无遥测、无账户。监控目录选择、手动目录书签、显示方式及隐藏状态保存在本地 `UserDefaults`。
4. **单层监控。** 自动扫描顶层文件与目录，不递归。目录使用系统图标，双击在 Finder 打开；手动挂上的目录通过普通书签保存，当前适用于非沙盒本地版本。临时下载目录和符号链接不挂上。
5. **非破坏性拖出。** V0.1 源仅通告 `.copy`；如果想从 Downloads 移动到其他文件夹，需要使用 Finder 完成移动。未来可以考虑经确认的移动模式。
6. **可验收，不夸大。** 已在 macOS 构建启动并测试真实目录监听、真实 URL 卡片及非破坏性取下。运行应用已识别 Downloads 新文件。浏览器下载、完整 UI 交互、多屏和权限拒绝仍待验收。
7. **未包含**：开机自启、Apple 公证、自动更新、高级全屏隐藏策略、完整无障碍 / VoiceOver、中文外其他本地化。这些属于后续版本。

## 后续 macOS 验收清单

- [ ] Mac 源码构建成功，打开后菜单栏可见 Clothesline T 恤图标。
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

## 持续开发

遵循 AGENTS.md，每轮更新 PROJECT_STATE.md、HANDOFF_LATEST.md、CHANGELOG.md 并提交 Git。运行 scripts/test-core.sh、scripts/test-macos.sh 和 scripts/build-app.sh release。GitHub 公开仓库：https://github.com/zhongguozhang/Clothesline。每轮验证、更新交接、提交后推送；开始工作先检查远端变化，禁止强制推送。

DMG 重建：`scripts/build-dmg.sh`（本机架构构建，当前发行包为 arm64）。

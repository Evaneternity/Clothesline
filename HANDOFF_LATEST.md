# 最新交接：复位动画中主动隐藏回归修复

2026-10-16。用户要求修复 review 的 P2：复位动画仍运行时主动隐藏，保持分支会重新写入显示宽限时间，动画结束后导致误展开。

- LineRevealController 的保持分支改为 lastInside = isRevealed ? now : nil，只延续可见状态。
- Tests/MissionControlReturnTests.swift 将实际 LinePanel 与状态机组合，在动画中隐藏并轮询超过动画和宽限时间；同一回归先失败后通过。核心状态测试同步覆盖隐藏保持释放。
- 完整核心/macOS 测试、Universal Release 构建及严格双架构签名通过，已重启 build/Clothesline.app，SHA-256：37aa6fb2fee48f65f00981c163aa6b8d90002f4fc8b4ad5c009cb3de5eeac78c。未声称本轮人工 Mission Control UI 验收。
- 独立 PR 在 ../Clothesline-pr-mission-control 工作树、fix/mission-control-occlusion 分支准备，直接基于上游 main，不包含已有设置/复制 PR 的功能。用户要求 PR 明确“仅 macOS 27 验证，其他版本未测试，仅供参考，请谨慎合并”。

## 前轮：总览内隐藏后退出误展开

2026-10-16。用户报告隐藏后点击 Mission Control 空白处退出，会再显示再隐藏。只读本地采样确认重新显示发生在退出前的普通按下事件，且用户补充退出方式为点击空白处。

## 本轮改动与验证
- 外部文件拖拽不再等同于全局左键按下。ExternalFileDragTracker 记录专用拖拽粘贴板在松开时的 changeCount，只接受按下期间产生的新会话及 file URL 类型。旧拖拽数据残留不会把后续点击当成拖拽，不读文件内容或系统剪贴板载荷。
- 总览内的展开规则集中到 LineRevealController：真实文件拖拽可在远离顶部时立即展开；隐藏面板透明区域不能触发悬停展开。AppDelegate 的窗口鼠标穿透也使用同一文件拖拽判定。
- Tests/MissionControlRevealTests.swift 复现 drag → drop → leave → hide → click → exit，分别覆盖透明区域内外，接入核心测试。修复前两类失败依次复现，修复后通过；另覆盖旧数据、非文件拖拽、延后提供类型、再次拖入、空绳和普通顶部悬停。
- 用户现场确认“已修复：能拖入，退出后保持隐藏”。reveal-after.jsonl 交叉验证：总览内隐藏后，点击空白处时 leftButton=true、fileDragging=false，revealed 保持 false，退出也保持 false；后续新拖拽和普通顶部悬停可正常展开。人机复现脚本从退出码 1 变为 0。
- 本轮临时探针仅记录布尔状态和坐标，已从源码移除并停止采样，副本与现场数据保存在被忽略的 build/debug-mission-control/。
- 核心/macOS 测试、Universal Release 构建及严格双架构签名通过；已重启为无探针的 build/Clothesline.app。二进制 SHA-256：6d32db4f76568bbec3f74a4dad10e85e9e983e015d647c4db3d09bd48fee00ee。
- 继续使用 feature/mission-control-avoidance；已有 PR #2/#3、/Applications 安装包和 Release 保持不变。

## 前轮：Mission Control 退出复位动画

2026-10-16。用户已确认检测修复后的真实 Finder 拖入及退出复位，随后要求放慢回到顶部的动作。当前仍在 feature/mission-control-avoidance。

## 本轮改动与验证
- LinePanel 将可见晾衣绳的退出复位改为 0.6 秒缓入缓出，使用公共主循环定时器更新实际窗口位置；动画结束后恢复 floating 层级，系统“减少动态效果”开启时直接复位。
- 相同目标的轮询不重启动画。按住、拖入或拖出时暂停，结束后续播；总览重新出现或屏幕/布局变化时取消旧动画。AppDelegate 在复位期间保持展示、暂停身份提示。
- 实际 AppKit 窗口测试覆盖中间位置、重复轮询、交互暂停/恢复、总览重开取消旧动画；scripts/test-macos.sh、scripts/build-app.sh release（含核心测试）、严格全架构签名均通过。
- 已退出上一试用进程并启动 build/Clothesline.app。二进制 SHA-256：d717d6a4f2e366e73a00a759d0e22fd3fc3511e0809ec9b31ec65f68527b187e。
- 当前动画观感待用户试用；本轮未再次进行真实 Mission Control 拖放人工验收。未替换 /Applications 安装包，未修改 PR #2/#3 或发布 Release。

## 前轮：macOS 27 Mission Control 漏检测修复

2026-10-16。用户反馈试用版完全未下移；先用 diagnosing-bugs 的人机复现循环采集实际窗口元数据，再修复。继续在 feature/mission-control-avoidance 工作，未改现有 PR。

## 根因与修复
- 现场确认完整 Mission Control 展开时，Dock 仍只有普通 layer 20 窗口。原先只查 Dock，返回的避让量始终为 0。
- 第二轮现场捕获确认 macOS 27.0.1 的总览表面属于 com.apple.WindowManager：layer 19 全屏，layer 14 顶部桌面栏。主屏桌面栏 244 pt，上方外屏 226 pt。
- MissionControlAvoidance 现在按 PID 对应的系统进程分别解释层级，同时支持 Dock 和 WindowManager。优先真实桌面栏高度加 16 pt，无单独桌面栏时仍使用估算。
- 排除 WindowManager layer 18 的“显示桌面”、小尺寸台前调度图标和其他进程同层窗口；无新权限请求、私有 API 或窗口标题读取。

## 回归证据
- Tests/Fixtures/mission-control-macos27.json 是现场窗口数值的最小 fixture：替换真实 PID，移除缩略图窗口，无标题、路径或内容。
- Tests/MissionControlReplayTests.swift 经真实解析入口回放 idle → active → idle。修复前明确失败：期望 260.0，实际 0.0；修复后主屏/上屏为 260/242，退出均回到 0。
- scripts/test-macos.sh 包含该回归，完整测试通过；scripts/build-app.sh release（含核心测试）和严格全架构签名通过。
- build/Clothesline.app 二进制 SHA-256：d49e3b1b3ad3f2d9ec5d38d8d9bd99483a937882d69d5339f450e84750e42fdf。
- 已按用户此前的重启要求退出旧试用进程并启动修复版。第三轮用户明确确认“能下移并挂上文件，退出后复位”，完成真实 Finder 拖入验收。
- 同步只读采样 trace.0DvbJU 记录 104 次状态变化，主屏面板由 Quartz y=33 / layer 3 下移至 y=260 / layer 25，退出后恢复 y=33 / layer 3；双屏检测量恢复为 0。人机复现脚本以 works 结束，位置断言通过、退出码 0。采样进程已停止，仅修复版应用继续运行。
- 临时采样和复现工具仅在被忽略的 build/debug-mission-control/ 中，无生产日志；只采样两个系统进程的层级/边界和本应用面板位置，不读取文件内容或剪贴板。

## 范围与限制
- 仍依赖系统未保证的窗口特征，其他系统版本的真实 UI 兼容性待验证；逐屏拖放和跨屏拖拽尚未单独验收。
- 本轮运行 build 中的试用包，未替换 /Applications 下的安装，未发布 Release。
- 现有 PR #2（时间设置）和 #3（复制名称/路径）保持不变；本分支仍包含此前完整开发历史，若要独立 PR 需另行提取。

## 调研交叉核对
现场捕获与 AltTab 的 macOS 27 检测记录一致：
https://github.com/lwouis/alt-tab-macos/blob/master/src/macos/api-wrappers/MissionControlOverlaySpecs.md
实现由本项目现场数据和既有检测模块独立修改，未复制第三方代码。

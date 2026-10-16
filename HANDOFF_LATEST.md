# 最新交接：Mission Control 临时下移试验

2026-10-16。用户确认问题发生于完整 Mission Control 窗口总览，并要求写代码试试。独立分支 feature/mission-control-avoidance 基于 ade3181，保留此前两个时间设置和名称/路径复制功能。

## 实现
- MissionControlAvoidance 只取 Dock 的窗口 PID、层级、边界；全屏 layer 18 或顶部宽条触发避让，普通全屏 layer 20 不触发。无私有 API、截图、窗口标题读取或权限请求。
- 全屏总览无法得知桌面栏单独边界时，采用屏幕高度 22%（160–280 pt）的预留空间。LinePanel 临时下移并使用 statusBar 层级，退出后回到 floating 与原顶部位置。
- AppDelegate 沿用源交互期间不移动窗口的保护；外部拖拽未结束时不向上复位。避让期间拖入能显示空绳，已接收拖入取消/结束会解除保持。普通空列表悬停和时间设置保持原有语义。
- Quartz 与 AppKit 坐标按主显示器转换，独立判断上下或错位显示器。枚举有 0.2 秒/1 秒节流，唤醒清除缓存。

## 验证与限制
- scripts/test-macos.sh：既有回归与新增窗口元数据、双屏、误判、缓存/恢复测试通过；实际 AppKit 面板位置/层级往返通过。
- scripts/build-app.sh release：含核心测试，arm64/x86_64 通用构建通过。
- git diff --check：通过。
- 仍有已有的 GrabArea 捕获警告、旧式粘贴板/CoreDrag/颜色空间诊断。
- Mission Control 窗口特征是启发式，不是稳定系统协议。自动化触发尝试未取得可验证的总览状态变化；没有声称完整总览中的 Finder 拖放已验收。
- 下一步手工试用：先退出旧应用，再打开 build/Clothesline.app；从 Finder 拖一个自建测试文件，展开完整 Mission Control，检查下移、可放入、退出复位，并在上下屏各重复一次。接收拖放只保存引用，不移动源文件。

## 交付与 GitHub
试用包 build/Clothesline.app。本轮未替换 /Applications/Clothesline.app，未发布 Release 或创建/修改 PR。现有上游 PR 已根据用户授权创建：
- https://github.com/zhongguozhang/Clothesline/pull/2 ：两个时间设置。
- https://github.com/zhongguozhang/Clothesline/pull/3 ：复制文件名/完整路径。

本轮完成提交后同步到个人 fork Evaneternity/Clothesline 的独立分支，并核对远端 SHA。该试验分支包含此前完整本地开发历史，若以后要求独立 PR，需要另行提取本轮提交；不要直接混入上述两个 PR。

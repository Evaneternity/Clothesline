# 最新交接：悬停显示晾衣绳延迟

2026-10-16，分支 feat/hover-display-delay，基于上游 main 的 d48feca。

在“自动隐藏晾衣绳”下方提供独立悬停延迟编辑页，范围 0.0–10.0 秒、精度 0.1 秒、默认 0.0 秒。离开顶部、切换屏幕或唤醒后重新计时；自动剪贴板接入遵守悬停规则。空绳保持隐藏，显式固定及拖入入口保留；右键菜单跟踪期间保护操作目标。

验证通过：scripts/test-core.sh、scripts/test-macos.sh、scripts/build-app.sh release native；git diff --check。覆盖偏好持久化、计时边界、取消/重置、空绳、拖拽保护、剪贴板图片/文字、右键菜单生命周期和双语菜单位置。真实上下双屏鼠标移动及睡眠恢复仍需人工验收。

构建验证为 Apple Silicon 原生 Release。Universal 打包的 Swift 6.4 兼容修复另留在本地开发分支，不混入本功能。既有编译/粘贴板/CoreDrag 诊断仍出现。

下一步：人工验收平台交互，确认 PR 草稿后再创建 PR。此分支不依赖其他功能分支，未更新系统安装应用或远端发行资产。

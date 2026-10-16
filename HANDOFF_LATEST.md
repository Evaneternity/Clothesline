# 最新交接：复制文件名与完整路径

2026-10-16，分支 feat/copy-file-name-path，基于上游 main 的 d48feca。

文件及文件夹卡片右键新增“复制文件名”和“复制完整路径”。名称保留扩展名，路径为标准绝对路径纯文本，沿用复制反馈与自身剪贴板标记；剪贴板图片/便签菜单保持内容复制。

验证通过：scripts/test-core.sh、scripts/test-macos.sh、scripts/build-app.sh release native；git diff --check。覆盖独立剪贴板验证文件/文件夹、中文、空格、特殊字符、扩展名、绝对路径纯文本及自身复制回流抑制。未声称真实跨应用粘贴 UI 已验收。

构建验证为 Apple Silicon 原生 Release。Universal 打包的 Swift 6.4 兼容修复另留在本地开发分支，不混入本功能。既有编译/粘贴板/CoreDrag 诊断仍出现。

下一步：人工验收平台交互，确认 PR 草稿后再创建 PR。此分支不依赖其他功能分支，未更新系统安装应用或远端发行资产。

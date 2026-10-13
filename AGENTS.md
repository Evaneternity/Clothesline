# Clothesline 开发约定

## 当前目标
V0.1 优先交付可运行的 macOS 14+ 原生应用。参考 Tendedero 的视觉与交互，核心为 Downloads 真实文件。除非用户要求，不扩展新功能。

## 每次开发流程
1. 阅读 PROJECT_STATE.md、HANDOFF_LATEST.md、ROADMAP.md；检查 git status，保留用户改动。
2. 完成一项有明确验收标准的小迭代；先修复构建、监听、文件安全问题。
3. 运行 scripts/test-core.sh；涉及 macOS 行为运行 scripts/test-macos.sh；构建 scripts/build-app.sh。不得将源码审查或模型测试写为 UI 实测。
4. 更新 PROJECT_STATE.md（当前事实/证据/限制）、HANDOFF_LATEST.md（改动/命令/下一步）和 CHANGELOG.md；范围变化同步 ROADMAP.md。
5. 检查 git diff --check，将代码和交接文档一起提交。main 保持可构建，较大工作使用 fix/ 或 feature/ 分支。
6. 仅在版本验收完成后打 vX.Y.Z 标签；候选版用 vX.Y.Z-rc.N。不自动推送、发布或修改系统权限。

## 安全与许可
- UI 取下、清空、退出只改变展示状态，不删除、移动或覆盖源文件。
- 拖出只提供 copy；测试使用唯一命名的自建文件，不能清理用户下载。
- 读取 Downloads 及自选目录仅用于本地功能，不增加网络或遥测。
- 保留 LICENSE 中 Alejandro Buján 的版权和 MIT 全文；应用包也携带 LICENSE。使用 Clothesline 独立名称及 assets/clothesline-icon.png，禁止引入上游名称、图标和文档图片。
- 编译产物与缓存不入 Git。没有证据的功能标记“待验证”。

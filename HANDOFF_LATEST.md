# 最新交接：Windows 首个候选包已验证，准备发行

2026-10-15。feature/windows-app 实现原生 WPF/.NET 10 LTS x64 应用，保留 macOS Swift 版本及现有 rc.3 DMG。Windows 主要能力和首版缺口见 windows/README.md / README.en.md；根目录双语说明新增 Windows 安装/便携下载。

源码 8b2e09b，Windows runner 38701416790 全流程成功：核心真实 watcher/稳定完成/固定/安全取下和重命名、WPF 构造与实际 FileDrop 数据、图片释放源锁、self-contained 编译、Inno Setup 安装、安装后 smoke、卸载与源文件 sentinel。不能把这些写成完整鼠标桌面验收。macOS 通用构建及核心回归通过。所有文件操作使用自建测试目录。

修复过早期 smoke 反射同名 Render 方法、拖出源捕获、外部拖入期间隐藏与图片文件锁。剪贴板会话副本限制当前用户访问；不持久化到最近文件。仅用户点击时写登录启动或查询更新，Windows 标签 windows-v 避免 macOS 误提示。

构建产物包含 Setup.exe、portable.zip、SHA256SUMS.txt，位于 GitHub Actions artifact Clothesline-Windows-x64。已验证的归档 digest c52a6f3e71477c77c38c83badc61333b41f245fc6120580ae18e922c67c75d40。发布工作流限定 main，验证 run 成功且标签 SHA 与产物源提交一致、SHA256/PE 架构/随包运行时和 MIT，然后上传。

下一步：合并 main、标签 windows-v0.1.0-rc.1 指向已验证 8b2e09b，触发 publish-windows.yml 的 run_id=38701416790，核对 Release 资产并更新最终记录。Windows 实际跨应用拖放、登录启动、多 DPI 和客户端 Windows 10/11 桌面操作仍待验收；首版主屏，暂不包含系统分享、废纸篓删除、全局快捷键。

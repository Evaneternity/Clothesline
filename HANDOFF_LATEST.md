# 最新交接：Windows 首个候选版已发布

2026-10-15。完成 Windows 原生 WPF/.NET 10 LTS x64 应用、Setup/便携包；保留 macOS Swift 应用及现有 rc.3 DMG。Windows 能力与差异见 windows/README.md、README.en.md，根目录双语下载已更新。

源提交 8b2e09b，候选标签 windows-v0.1.0-rc.1 精确指向该构建源。Windows runner 38701416790 全流程通过：核心完成检测/真实 watcher/固定/安全取下和改名、WPF 构造、真实 FileDrop 数据、图片源锁释放、self-contained 编译、Inno Setup 安装、安装后 smoke、卸载与源文件 sentinel。macOS 核心与 Universal build 通过。全部使用自建测试目录；未修改本机系统权限或安装 Windows 工具链。

云端发布 38702352934 success，核验 run 源与标签、SHA256、PE x64、随包运行时与完整 MIT 后发布。Release：https://github.com/zhongguozhang/Clothesline/releases/tag/windows-v0.1.0-rc.1 。公开候选，未 Authenticode 签名。

- Setup：54,961,625 字节；SHA-256 1afbe5bf8d65e057fca85f05ed4627bcc54eed038934701b41a545b10b5bcaad。
- Portable ZIP：77,658,705 字节；SHA-256 d89d81a717d870fd50ac63ca83f7abbfd45bb7d25af48cfaf8c782027daf8174。
- SHA256SUMS.txt 已上传；GitHub 资产 digest 已核对。

macOS 本机下载 132 MB Actions 归档曾超时，改为受限的 publish-windows.yml 手动触发云端发布，成功；没有将超时记录当作发布失败。main 与功能分支远端已核验 430dce6，最终文档追加后需推送并复核。

下一步仅 Windows 真机客户端人工验收：启动/托盘、跨应用实际拖放、剪贴板、登录启动与多 DPI。Windows Server 2022 runner 自动 smoke 不等于 Windows 10/11 完整桌面验收。首版只跟主屏，不含系统分享、废纸篓删除、全局快捷键；以后由用户确定迭代范围。不要重复创建本候选标签或覆盖现有资产。

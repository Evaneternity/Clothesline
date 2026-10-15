# 最新交接：Windows 原生版本开发中

2026-10-15。用户要求生成 Windows 版本，使用 feature/windows-app；保留 macOS Swift 应用和现有 rc.3 DMG。

windows/Clothesline.Core 为完成检测、取下、固定容量、重命名及设置；Clothesline.Windows 为 WPF 顶部绳、卡片和托盘、剪贴板临时副本、开机启动及独立 Windows 更新；Clothesline.Tests 为文件安全和真实 watcher 回归。安装程序使用 Inno Setup，self-contained 发布，不要求用户装 .NET，图标从独立 PNG 转 ICO。build-windows.ps1 包含发布 smoke、安装、安装后 smoke、卸载和自建源文件保留测试。

当前通过 .github/workflows/windows.yml 在 Windows runner 验证编译与测试，结果待核验；不能声称已运行 Windows GUI。首版能力和缺口详见 windows/README.md。下一步：查看 CI、修复编译/运行错误，取得安装包和校验和，再发布 Windows 独立候选版本 windows-v0.1.0-rc.1（平台标签避免触发 macOS 更新提示）。最终须更新状态、交接、CHANGELOG/ROADMAP，并同步 main 与 SHA。

中途证据：38700774792（e3eb25b）Windows 全流程成功，安装/卸载源文件 sentinel 保持。已定位早期 smoke 反射同名方法错误；后续补充外部拖入不隐藏、图片复制不保持源文件锁，待最终 CI。根目录中英文 README 已增加 Windows 下载入口，发布前须确认链接资产实际存在。

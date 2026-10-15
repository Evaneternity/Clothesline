# Clothesline for Windows — 首个候选版

[English](README.en.md) · 简体中文

原生 WPF / .NET 10 LTS，目标 Windows 10 1809+ / Windows 11 x64（Intel、AMD）。使用独立晾衣绳图标，安装包携带仓库完整 MIT 许可。

默认监听系统已知 Downloads 文件夹；可同时添加多个文件夹。完成检测要求至少两次稳定扫描、两秒静默，并过滤常见下载临时后缀。支持顶层文件/目录、拖入挂载、真实文件 copy-only 拖出、打开/图片缩略图、固定、保留扩展名重命名、悬停身份、最近文件搜索、自动隐藏/一直显示、中英文托盘与卡片菜单、手动检查 Windows 更新、开机启动开关及关于。

剪贴板图片/文字分别默认关闭；只接开启后新复制内容，去重并抑制自身复制。文字支持编辑，图片/文字可另存为；会话副本不进入持久最近记录，退出只清理应用自建会话目录。异常退出可能遗留临时副本。

首版仅主屏工作区域，不递归监听目录；不包含 macOS Quick Look、系统分享、废纸篓删除、全局快捷键与多屏跟随。取下/清空只改展示状态，原文件不变；重命名只有明确操作后才执行且拒绝覆盖。文件夹不递归统计大小，链接/隐藏/系统文件不自动挂载。

设置保存在 `%LocalAppData%\Clothesline\settings.json`，不存文件内容。仅点击检查更新时访问本仓库 GitHub Releases，不上传文件或剪贴板；Windows 使用 `windows-v` 标签，避免向 macOS 用户提示 Windows 安装包。开机启动只在显式选择时写入当前用户 Run 项，安装不自动开启。默认安装到当前用户的 Programs，无需管理员权限。卸载仅移除程序和指向本次安装的启动项，保留设置与用户源文件。

## 安装和使用

1. 安装 Setup.exe，或将便携 ZIP 完整解压到固定位置再运行 Clothesline.exe；不要只拷贝 EXE。
2. 启动后在任务栏通知区域（可能在折叠图标中）找到晾衣绳图标。
3. 鼠标移至主屏工作区域顶部展开；默认下载文件稳定约两秒后挂上。也可从托盘选择一直显示。
4. 从资源管理器拖入文件/文件夹；从卡片拖出到支持文件的窗口，提供 copy。右键操作卡片，滚轮查看溢出项目。
5. 语言 / Language 可切换中文、English。开机启动和剪贴板自动接入由用户自行开启。

## 构建与验证

在 Windows 安装 .NET 10 LTS SDK 和 Inno Setup 6，运行：

```powershell
./scripts/build-windows.ps1
```

自动运行核心测试、self-contained 发布、WPF 构造/文件拖放数据 smoke test、安装/卸载与源文件保留测试，输出 `build/windows/dist` 下的 Setup.exe、便携 ZIP 和 SHA256SUMS.txt。用户无需预装 .NET。`.github/workflows/windows.yml` 在 Windows runner 执行同样流程。

Windows runner [38701416790](https://github.com/zhongguozhang/Clothesline/actions/runs/38701416790) 已通过最终编译、核心/真实 watcher、WPF 构造与文件拖放数据、图片文件锁、安装/安装后测试与卸载及源文件保留验证；这些自动测试不能视为完整 Windows 桌面操作验收。安装程序暂未 Authenticode 签名，Windows 可能显示未知发布者。

完成检测属于启发式：如果下载使用最终文件名且暂停超过两秒，可能提前出现。首版不递归检查文件夹内写入完成状态。

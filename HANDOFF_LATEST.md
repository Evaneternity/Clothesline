# 最新交接：多目录监控与 DMG 候选发行

2026-10-13（Asia/Shanghai）。前序 e409f86。

## 改动
FolderMonitors 管理多个 DownloadsWatcher，默认保留 Downloads；菜单由“选择监控文件夹…”改为“添加监控文件夹…”，支持多选，新增目录不替换原目录。各 watcher 独立完成 gate，快照合并去重排序；失败按目录提示，唤醒全部重启。书签保存在 monitoredFolderBookmarks，兼容旧 folderBookmark。手动挂目录仍为独立快捷入口。

## 验证
scripts/test-core.sh 与 scripts/test-macos.sh 通过，后者增加同时监听两个自建目录、重复添加、路径去重及重启恢复默认 Downloads。旧废纸篓/源文件安全/拖拽数据/持续显示回归通过。没有改动用户监控设置或移动用户文件。

## DMG / GitHub
scripts/build-dmg.sh 重建本机架构 Release 与压缩 DMG，包含应用、Applications 链接、LICENSE 和安装说明，生成 SHA-256。发行标签 v0.1.0-rc.1；文件 Clothesline-0.1.0-rc.1-arm64.dmg 与 .sha256。下载入口在 README 顶部。本轮用户明确授权 GitHub 下载发布；候选版未 Developer ID 签名/公证，要求 macOS 14+ / Apple Silicon，首次打开可能被系统阻止，不提供 Intel 包。

hdiutil verify 与只读挂载检查通过：应用签名、许可、arm64 架构、Info.plist、Applications 链接均正常，测试镜像已卸载。随后提交、push、创建候选标签并发布预发行 Release，检查远端资产和 SHA。仅上传安装包和校验文件，不上传自建测试目录或用户 Downloads。

## 尚待验收
微信/编辑器实际拖入、完整浏览器下载流程、多屏/权限、macOS 14 真机兼容性仍待验收。每轮同步状态和交接，再推送 GitHub。没有定时后台同步。

# 最新交接：V0.1 接管与 macOS 首次验证

日期：2026-10-13（Asia/Shanghai）

## 已完成
保存原始基线提交 6939f43；建立 main、忽略构建产物及开发约定。完成源码/脚本/安全审查，修复 Quick Look 和 MainActor 编译错误、隐藏记录丢失及普通书签兜底；应用包附带 MIT。新增 macOS 实际 watcher 与卡片模型回归测试。

## 重现
```bash
scripts/test-core.sh
scripts/test-macos.sh
scripts/build-app.sh debug
scripts/build-app.sh release
open build/Clothesline.app
```
SwiftPM 在受限执行环境中可能因 sandbox-exec 被阻止，需允许正常本机构建；不应将沙盒权限错误当作 SDK 不兼容。项目缓存已放入 .build。

测试覆盖：临时扩展名过滤、事件/轮询、真实文件 URL、取下/重启/清空非破坏性。Mac 集成测试的人工 NSDraggingSession 会产生 CoreDragDispose -1850 诊断，测试断言仍通过；实际拖拽需 UI 验收。

Debug 与 Release 构建均成功；Release 应用包通过签名、Info.plist 和许可证一致性检查。

## 运行验证与下一步
应用已启动，默认 Downloads 已出现现有文件及新建测试文件 Clothesline-acceptance-20261013.txt。测试文件内容为 Clothesline V0.1 safe acceptance fixture，保留不删除。UI 自动化透明浮层截图空白，点击返回 offscreen/notImplemented，不能声称预览/拖拽已实测。

下一轮优先：人工顶部展开/⌃⌥T，预览测试文件，双击打开，拖到专用测试文件夹确认复制，×/清空后确认 Downloads 原件。再验证 Chrome/Safari 下载及权限拒绝。完成前保持候选版，不添加新功能、不打正式版本标签。每轮更新三份记录并提交 Git。

# 最新交接：右键复制文件名与完整路径

2026-10-16，继续本地 feature/hover-delay-expiration 分支。用户新增需求：晾衣绳上的文件、文件夹右键可复制文件名及完整路径。

## 改动
- GrabArea 普通文件/文件夹菜单新增“复制文件名”和“复制完整路径”，AppLanguage 增加英文标签。
- Line.copyFileText 将文件名（含扩展名）或标准绝对路径写为纯文本，不做 URL/shell 编码。允许失效卡片复制记录的引用，不访问或修改源内容；剪贴板临时项目不增加文件引用菜单。
- 沿用复制成功反馈与 ClipboardMonitor.markOwned，防止开启自动文字挂载时把文件名/路径再次挂成便签。
- 中英文 README、CHANGELOG 和 ROADMAP 同步。

## 验证与本机安装
- scripts/test-macos.sh 全部通过；在独立剪贴板新增真实文件/目录场景，覆盖中文/空格/#/%、扩展名、文本而非 file URL 以及自动挂载回流抑制；不读写系统剪贴板。
- scripts/build-app.sh release（含核心测试）通过。严格全架构签名、两种架构 minos 14.0、安装与构建的二进制一致性、git diff --check 通过。
- 已正常退出旧版、备份并更新 /Applications/Clothesline.app；验证单实例已完成启动。备份：build/install-backups/20261016-142616/Clothesline.app。
- 新二进制 SHA-256：f998edc1f9e4888fe89be2b112a98319d2815f9ca96973a1273008845bdf02aa。
- 既有 GrabArea 捕获警告、NSFilenamesPboardType/CoreDrag/颜色空间诊断仍出现；没有新增失败。未声称完整右键鼠标 UI 或跨应用粘贴已实测。

当前源码和安装包含前轮悬停延迟/目录过期；设置保留。未修改版本号、发布 DMG/Release 或 Windows。远端此前因当前账号无写权限返回 403，本轮按仓库约定再尝试推送，结果记录于交付信息；不得宣称未核验的远端同步成功。

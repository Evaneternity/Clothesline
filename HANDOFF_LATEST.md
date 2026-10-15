# 最新交接：Intel / Apple Silicon 通用安装包

2026-10-15。用户要求安装包增加 Intel 支持，使用 feature/universal-installer 分支完善打包。

build-app 默认 arm64、x86_64 分别 SwiftPM 编译，lipo 合并后统一签名，保留单架构选项。build-dmg 从应用元数据读取版本并按实际架构命名。双语 README 下载改为 rc.3 Universal。当前版本 0.1.0-rc.3 / build 3，包含上轮应用菜单功能。

验证：scripts/test-macos.sh、scripts/build-dmg.sh（包含核心及双架构 release 编译）、hdiutil verify 通过。只读挂载后核对 app 双架构、codesign --verify --strict --all-architectures、两架构 LC_BUILD_VERSION minos 14.0、MIT 全文及 Applications 链接，SHA-256 匹配。无可用 Rosetta，未修改系统安装它，不能把交叉编译写作 Intel 真机验收。旧式 PB/CoreDrag/颜色空间测试诊断仍非失败。

产物：build/Clothesline-0.1.0-rc.3-universal.dmg 及 .sha256。SHA-256：b6fa0e10482d20958b8a4294757913f0e3d0a37d5412f72074d915f0af4186cd。仍为 ad-hoc 签名、未公证候选版。

下一步：提交、快进合并 main，推送此前未同步提交；发布 rc.3 候选版及 DMG/校验文件并核对资产。Intel 真机、macOS 14 最低版本、实际登录启动等 UI 验收仍待进行。发布/同步结果另行追加。

已完成：main、功能分支和 rc.3 标签均远端核验 cf208af；GitHub rc.3 候选版已发布，DMG 2,935,401 字节，远端 sha256:b6fa0e10482d20958b8a4294757913f0e3d0a37d5412f72074d915f0af4186cd 与本地一致，.sha256 同时上传。此前未同步提交全部包含在 main。发行页：https://github.com/zhongguozhang/Clothesline/releases/tag/v0.1.0-rc.3 。后续只需 Intel/最低系统和完整 UI 验收，不重复创建该候选版或覆盖既有资产。

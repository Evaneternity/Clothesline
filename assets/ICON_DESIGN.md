# Clothesline 图标

2026-10-13：用户要求参考提供的浅色圆角底、蓝色 T 恤、晾衣绳与夹子样式替换 logo。

生成方式：内置 image_gen，透明 PNG；项目源文件 clothesline-icon.png。构建脚本生成全部 ICNS 尺寸；菜单栏同样使用应用图标。旧图标可从 Git 恢复。本图不使用 Tendedero 图标。

最终提示词：
Create a production macOS application icon for Clothesline inspired by the attached style reference, not an exact copy. Use case: logo-brand. Reference image: style only. A white to cool pearl rounded square macOS squircle tile with subtle beveled edge, soft restrained shadow. A pale powder blue T-shirt hangs centered from a gently sagging fine gray-blue clothesline across the upper third, held by two small dark navy clothespins. Crisp dark navy outline, soft dimensional material, simple readable silhouette, tasteful native macOS aesthetic. Front-on, perfectly square 1024x1024 composition, tile fills about 88 percent of canvas, comfortably centered, transparent outside the rounded tile with small soft shadow. No surrounding scene, no letters, no text, no watermark. Produce the actual app icon asset, not a photograph or mockup.

实际生成尺寸：1254 × 1254，带 alpha；构建时由 sips 缩放为 ICNS 所需尺寸。

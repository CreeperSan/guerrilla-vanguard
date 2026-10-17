# 应用图标

沿用游戏角色的橄榄绿头盔与橙色面巾，使用无文字像素头像，便于在手机桌面辨认。使用内置 image_gen 工具生成，尺寸派生由系统 sips 完成；原有 icon.svg 保留。

- `guerrilla_vanguard.png`：1024 × 1024，工程图标。
- `android_launcher_192.png`：192 × 192，Android 常规启动图标。
- `android_adaptive_432.png`：432 × 432，Android 自适应图标前景，系统负责圆形等裁切。
- `android_background_432.png`：432 × 432，深绿色不透明背景，覆盖自适应图标位移动画可能露出的边缘。

工程引用位于 `project.godot`；Android 引用位于 `export_presets.cfg`。图像保持方形且不预烘焙圆角。

## 生成提示词

Use case: stylized-concept. Asset type: finished mobile app icon for the pixel-art military arcade game Guerrilla Vanguard. Create one square 1024x1024 opaque edge-to-edge icon. A striking close-up portrait of a resolute guerrilla soldier wearing an olive-drab steel combat helmet and a warm burnt-orange scarf covering the lower face, strong expressive dark eyes, bold readable helmet silhouette. Retro 1990s military run-and-gun arcade pixel art, carefully placed crisp square pixel clusters, limited olive green, dark charcoal, khaki and ember orange palette. Subtle warm rim light. Dark forest-green background with a restrained amber halo behind the head, almost no environmental detail. Head and shoulders centered, symmetrical sturdy composition with a slight three-quarter turn, primary helmet/scarf silhouette contained within the central 62% of the canvas so circular and squircle launcher masks retain it. Strong contrast, simple large shapes legible at 48 pixels. Flat full-square artwork, no pre-rounded corners, no outside padding, no frame, no text, no letters, no watermark, no logos, no weapons pointing toward viewer, no gore, no UI, no mockup. Polished cohesive game icon rather than a photoreal portrait.

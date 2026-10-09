# 新武器图标

`sniper.png`、`rpg.png`、`flamethrower.png` 是内置 image_gen 生成的透明原图，保留原始 alpha。`*_icon.tres` 使用 AtlasTexture 排除几乎透明的空白边缘，共用于拾取物、商店与 HUD。

美术设定、数值、声音与验证见 `docs/SPECIAL_WEAPONS.md`，完整生成提示词与工具记录见 `source/generation_manifest.json`。弹丸外观由 Godot 程序绘制，不额外依赖高分辨率粒子贴图。

# 商人房美术资源

2026-10-08 使用内置 `imagegen` 生成，未使用 CLI、外部下载或第三方录音素材。两件 PNG 均保留原始 RGBA 透明像素，作为项目内源文件直接绑定，不覆盖旧素材。

- `merchant.png`：军需员 NPC，原图 1163×1353。商店按 `merchant_display_height` 等比显示，默认 56 世界单位，最近邻采样。
- `medical_kit.png`：带提手的浅色急救箱，原图 1536×1024。商品展示位按 32 世界单位等比显示，独立医疗包拾取物按 24 世界单位显示。
- 医疗包 prefab：`Prefab/Item/medical_kit.tscn`，类型编号 16，默认治疗 35 生命；不变更旧生命补给类型 3。
- 实际 Godot 渲染预览：`docs/art/merchant_room_preview.png`；F6 试购入口：`Prefab/Merchant/merchant_preview.tscn`。

## 商人提示词

Use case: stylized-concept. A single production NPC sprite for a military arcade top-down 2D pixel game GUERRILLA VANGUARD. A friendly rugged quartermaster merchant, full body facing down toward player in overhead three-quarter view, olive military jacket, tan cap, copper brown webbing, dark boots, large supply backpack, hands resting on belt. No weapon, no other characters or objects, no stall, no lettering. Compact chunky crisp pixel art with dark outlines, olive shadows, warm copper highlights, readable silhouette, matches 1990s military run-and-gun sprites. Single centered isolated sprite with ample transparent margin, true alpha transparent background, no floor, no shadow. Entire head and boots visible.

## 医疗包提示词

Use case: stylized-concept. Single production medical kit item sprite for GUERRILLA VANGUARD military arcade overhead 2D pixel game. Small stout light ivory metal first aid box with olive hinges and tan leather carrying handle, prominent mint green medical plus mark on front, copper highlights, dark thick pixel outlines, chunky crisp pixel clusters, top-down three-quarter view showing lid and front. Very readable at 24px tall, matching 1990s military arcade game pixel icons. One isolated centered object, full silhouette, generous transparent margins, true alpha transparent background, no other objects, no floor, no cast shadow, no text or letters.

## 音效

`Assets/Audio/SFX/Shop/purchase.wav`：0.32 秒上行三音。
`Assets/Audio/SFX/Shop/insufficient.wav`：0.27 秒下降双音。
用 `python3 tools/generate_shop_audio.py` 可复现，单声道 22050 Hz / 16 位 PCM。商人房播放节点使用 SFX 总线，不依附售出商品；已验证资源和播放触发，最终听感与混音需要试玩确认。

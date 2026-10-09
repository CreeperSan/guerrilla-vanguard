# 重型坦克素材

`source/tank_sheet.png` 为本轮 imagegen 生成的原始透明图集，保留原始字节。12 个 `.tres` 只引用对应区域，不修改 PNG。

- 第一行：四方向车体，无炮塔。
- 第二行：普通炮塔、过载炮塔、残骸、主炮弹丸。
- 第三行：四方向持枪驾驶员。

重新切片：`python3 tools/package_tank_art.py`。生成坐标对应此版源图，替换源图后需复查切片边界、`tank_visuals.gd` 的炮塔转轴补偿和 `cannon_muzzle_distance`。

动画由 `Prefab/BossTank/tank_visuals.gd` 驱动：履带滚动、车体方向、炮塔旋转/后坐、过载脉冲、出舱回弹、驾驶员跑动与枪焰。素材不是预烘焙逐帧动画。

音效由 `tools/generate_tank_audio.py` 固定种子合成，输出到 `Assets/Audio/SFX/Tank`。主炮、机枪、装填、过载、出舱、履带各自独立；驾驶员手枪复用项目现有手枪音效。

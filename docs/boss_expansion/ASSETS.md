# 新 Boss 资源

使用内置 imagegen 生成透明图集，保存到 `Assets/Art/MilitaryArcade/Bosses/tactical_boss_atlas.png`。五列对应动员兵、铁壁、猎隼、焚城、工兵；四行对应下、右、上、左。运行时四方向切换，不旋转角色碰撞体。图片 1402×1122，含真实 alpha，使用最近邻采样。

完整原始提示保存在 `imagegen_prompt.txt`；下面为提示摘要：

> Production game asset: a single transparent pixel-art sprite atlas, exactly 5 equal columns and 4 equal rows. 20 individual full body sprites, centered in each cell with generous empty padding, consistent scale. Columns: olive mobilizer commander with red beret, radio and no gun; heavy shield soldier with blue steel shield and short shotgun; camouflaged sniper with cloak and long rifle; orange armored flamethrower soldier with red fuel backpack; yellow demolition engineer with mine box and pistol. Rows: down/front, right, up/back, left. Top-down three-quarter military arcade pixel art, chunky dark outlines, olive/khaki/steel palette, crisp pixel clusters. No text, labels, gridlines or background.

音效由 `tools/generate_boss_audio.py` 固定种子生成，输出 `Assets/Audio/SFX/Bosses/`。包含 rally、charge、lock、sniper、flame、mine、detonate、phase 八个 WAV。使用 SFX 总线和位置衰减；已有手枪、爆炸与燃烧素材复用原资源。

预警圈、瞄准线、冲刺轨迹、护盾弧和火焰扇形使用运行时几何绘制，使显示与实际参数一致。

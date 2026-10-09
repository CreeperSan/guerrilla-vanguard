# 军事街机像素素材（2026-10-08）

## 来源与使用

使用内置 imagegen 生成角色、物品图集和 UI 面板；没有使用 CLI 或外部图片。
采用首页的橄榄绿军服、网纹钢盔、红围巾、铜色金属与黑色像素轮廓。
`source/` 保留生成原图；旧游戏素材未删除、未覆盖。
`tools/package_military_art.py` 仅做图集裁切、等比缩放及打包，可以重复运行。

## 文件与绑定

- `player_atlas.png`：288×640，3 列 × 8 行，每格96×80。列为站立/行走A/行走B；行依次为下、右、上、左、右上、左上、左下、右下。接入玩家 prefab 与 TestLevel，保留原动画名称、帧数和速度，显示缩放0.4，碰撞体未改。
- `pistol.png`、`smg.png`、`shotgun.png`：96×48，HUD 主副武器图标及武器拾取物。
- `grenade.png`、`molotov.png`、`shield.png`：64×64，装备栏、拾取物及特殊投掷弹。
- `mortar.png`、`bombing.png`：战场支援图标及拾取物。
- `sprint.png`、`dodge.png`：技能栏及技能拾取物。
- `health.png`：生命补给拾取物。
- `money.png`、`research.png`：货币 prefab、通用货币 LootItem 和 HUD 货币图标。
- `portrait.png`：玩家 HUD 头像。
- `bullet.png`、`shell.png`：普通子弹及支援下落炮弹。子弹仍按阵营配置伤害和检测掩码，贴图统一，世界显示大小维持原有尺度。
- `hud_panel.png`：256×256，StyleBoxTexture 九宫格拉伸，40像素切边。应用血量区、武器区、得分区、暂停/结算等面板。血量和换弹进度仍使用原有动态样式；触控圆形区域保留轮廓，调整为橄榄绿及铜色。

所有图标保持透明底，HUD 使用最近邻采样。道具显示尺寸由贴图缩放控制，不改变触碰区域；拾取框仍由实际显示尺寸计算，保留正弦缩放动画。
本次不重绘地图、敌人或爆炸动画。

## 玩家原图提示词

Production game sprite sheet for GUERRILLA VANGUARD military arcade pixel art. Exactly 3 columns and 8 rows of isolated FULL BODY sprites on genuine transparent background, evenly spaced identical cells. Each cell same scale and baseline, no clipping. A rugged olive green guerrilla with netted helmet, red neck scarf, olive webbing, dark boots, holding compact black gun. Chunky crisp pixel shapes and deep black outline, copper warm highlights, olive shadows matching a dramatic Metal Slug inspired painted pixel military cover. Orthographic overhead three-quarter game camera, compact proportions, readable at 32px height. Rows in this exact order: facing down, facing right, facing up, facing left, facing up-right, facing up-left, facing down-left, facing down-right. For each row columns: idle standing, walking left-foot forward, walking right-foot forward. Back rows show backpack and back of helmet, front rows show face. No labels no grid lines no ground shadow no background no muzzle flash. 24 sprites total. Uniform cells tightly controlled.

## 图标原图提示词

Use case: stylized-concept. Production military arcade pixel game ICON ATLAS, genuine transparent background, exactly 4 columns by 4 rows equal square cells, one separate centered icon per cell, generous transparent gutters, no text or grid or labels. Consistent crisp chunky pixels, black ink outline, olive green painted steel, brass/copper edges, ivory glints and warm orange highlight. GUERRILLA VANGUARD hero has netted olive helmet and red scarf. Readable silhouettes even at 32px. Exact row-major layout: row1 black compact pistol pointing right, olive black submachine gun pointing right, wooden-stock pump shotgun pointing right, olive pineapple grenade. Row2 green glass molotov with red rag tiny orange flame, olive riot shield with brass boss, mortar cannon on tripod, olive bomber airplane overhead. Row3 olive medical satchel with ivory cross, pile of brass gold coins, cyan research crystal in dark mechanical holder, running combat boot with gold speed streak. Row4 dodging olive soldier silhouette with cyan afterimage, hero helmeted face portrait bust with red scarf and stern tan face, pointed brass bullet, heavy olive falling artillery shell. Each object isolated entirely inside its own cell. No decorations outside cells, no photorealism, no background, no shadows on ground. Rich pixel-art texture same dramatic military arcade cover aesthetic.

## UI 面板原图提示词

Use case: stylized-concept. Asset type: game HUD nine-slice panel texture. One square military arcade pixel art UI PANEL FRAME, 512 by 512 conceptual size, centered fills entire canvas with outer 8px transparent margin. Dark olive steel inset panel interior almost flat very dark green, restrained faint pixel texture, thin layered copper/brass border, small rivets ONLY four corners, beveled chipped edges, warm ivory highlights upper left edge. Same high impact GUERRILLA VANGUARD military pixel arcade cover style but quiet UI, readable white text will be overlaid later. Interior 80 percent of panel must be almost solid dark green and unobstructed, uniform enough to stretch. Border thickness 24px, corners within32px, NO symbols, NO text, NO lettering, NO illustrations, NO buttons. Perfect rectangular square aligned to image axes, not perspective. Real transparent background around outside frame.

## 2026-10-08 持枪瞄准修订

使用内置 imagegen 编辑角色动作，`source/player_aiming_patch.png` 保存下、右、左三个方向的 9 帧修订源图。正面枪口朝向屏幕下方，侧面枪托抵肩、枪管水平朝前；站立与行走均保持瞄准。打包脚本只替换图集第 0、1、3 行，其他方向的角色像素沿用原图。动画格加宽至 96×80，为枪管留空间；角色显示缩放、帧率及碰撞体不变。旧图集存于 `source/player_atlas_before_aiming.png`。

修订提示词：

Use case: precise-object-edit. Input image is a STYLE AND CHARACTER reference for the existing game sprite. Produce a replacement sprite patch with exactly THREE columns and THREE rows (9 sprites), genuine transparent background. Keep identical olive guerrilla identity, netted helmet, red scarf, tan skin, dark boots, gun design, chunky pixel rendering, palette and game overhead three-quarter view. IMPORTANT change gun pose to ACTIVE AIMING READY TO SHOOT, not low-ready or carrying across chest. Stock firmly in shoulder, head aligned with sights, both arms holding raised rifle straight ahead. Row1 faces DOWN toward viewer / screen bottom: strongly foreshortened barrel, muzzle front-on toward viewer, barrel axis pointing screen-down, NOT diagonally across body. Row2 faces RIGHT: raised gun horizontal pointing exactly screen-right at shoulder height, muzzle beyond forward hand, cheek near stock. Row3 faces LEFT: raised gun horizontal pointing exactly screen-left at shoulder height, cheek near stock. All three columns in each row keep identical raised AIMING upper body: col1 standing, col2 walking left-foot forward, col3 walking right-foot forward. Uniform scale and baseline, evenly spaced cells on 3x3 grid, full body uncut, no other sprites. Keep fingers/arms readable. No muzzle flashes, no firing effects, no ground shadow, no grid lines, no labels, no text. Do not draw a low gun tilted across abdomen. This is a combat-ready aiming sprite sheet.

## 运行查看

按 F5：从首页进入关卡查看玩家、头像、武器、货币及 HUD。拾取不同装备/支援/技能查看对应图标；开火及投掷查看弹丸外观；切换输入设备查看不同 HUD 布局。F6 运行 TestLevel 可直接查看测试道具。
本次已直接查看生成图及打包后的玩家动画图集和武器图标；没有执行 Godot 运行、自动测试或设备适配验证。

## 2026-10-08 世界资源接入

后续已接入敌人、首领八方向、七主题地图、爆炸、燃烧与独立飞行物。详细资源布局、首领原图方向校正和运行验证记录见 [World/README.md](World/README.md)。上文“不重绘地图、敌人或爆炸”描述的是此前玩家/HUD批次。

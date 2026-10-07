# 首页生成美术

2026-10-07 使用内置 `image_gen` 工具生成，已将选用文件复制到项目中；旧 `Scene/MainMenu/title.png` 保留。

| 项目文件 | 用途 |
| --- | --- |
| `Scene/MainMenu/Art/cover.png` | 像素军事封面，左侧预留菜单空间，右侧为人物和战场 |
| `Scene/MainMenu/Art/title_wordmark.png` | GUERRILLA VANGUARD 两行透明图片标题 |
| `Scene/MainMenu/Art/upgrade_background.png` | 战场升级页研究基地背景 |

生成结果已人工查看：封面与背景没有嵌入 UI 文字，标题内容拼写正确；标题透明背景由工具生成并原样保留。美术不是运行截图。

## 最终提示词

### 封面

Use case: stylized-concept. Asset type: full screen cover art for the original 2D pixel military roguelike game GUERRILLA VANGUARD. Generate a landscape 16:9 composition with dramatic visual impact, polished chunky pixel illustration, crisp stepped edges and readable silhouettes, evocative of classic arcade key art, not photorealistic. On the RIGHT two thirds a courageous green-uniform guerrilla paratrooper with green helmet and compact SMG in dynamic forward leap, grenade and molotov on belt, shield strapped to back. Behind him a threatening red-uniform general standing in a fortress doorway, orange explosive muzzle flashes, incoming mortar shells, a pair of distant descending parachutes, jungle transitioning into ruined fortress city in background. Camera low three-quarter perspective, diagonal action and sparks, warm gold orange rim lighting versus mint teal shadows, olive drab military palette, strong silhouette, playful heroic non-gory violence. LEFT third contains atmospheric olive shadow and smoke with very few details, reserved quiet negative space for separately rendered menu and title. No text, no lettering, no logos, no watermark. Entire canvas is the artwork.

### 图片标题（transparent_background=true）

Use case: logo-brand. Transparent PNG title image for original pixel military roguelike GUERRILLA VANGUARD. Render ONLY exact text on two stacked lines: GUERRILLA then VANGUARD. Heavy condensed military stencil lettering with crisp stepped pixel edges, ivory cream face, burnt orange bevel, dark olive thick outline, subtle battle scuffs. Strong legible heroic arcade compact wordmark, horizontally wide, no extra words. Tiny parachute wing insignia beside letters. Genuinely transparent background, no opaque rectangle, no scene, no watermark, modest transparent margin.

### 战场升级背景

Use case: stylized-concept. Landscape 16:9 background for battlefield upgrades screen of original 2D pixel military roguelike GUERRILLA VANGUARD. Polished chunky pixel art, crisp stepped pixels and readable silhouettes. Secret guerrilla research bunker, olive metal workbench bottom and right perimeter, compact pistol and SMG parts on right, shield and helmet on shelf, glass canister of luminous cyan research crystals at right, tactical maps on concrete wall, warm amber desk lamp and cables. Muted olive darkness, mint teal research glow and amber accents. Center and LEFT 65 percent quietly textured and uncluttered for heading and future upgrade cards. Atmospheric depth, clean retro arcade style. No people, no lettering, no UI panels, no logos, no watermark.

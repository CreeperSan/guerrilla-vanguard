# 《Guerrilla Vanguard》美术设计

当前阶段：**美术方向已确认，设计图与一张概念实机渲染图已整理完成**。图像用于视觉参考，尚未切分为引擎资源，也未接入 Godot。

本轮根据用户提供的参考图，选取其中明亮手绘卡通的视觉语言：小比例角色、明确描边、适度纹理、清晰弹幕与环境差异。旧的几何像素方案和过度精绘的尝试已放入 `dock/art/archive`。

## 当前设计图

| 图纸 | 内容 |
| --- | --- |
| [角色与敌人](reference_style/01_characters_simple.png) | 玩家多视角、三种敌人、首领双阶段；重装兵已改为敌方深蓝灰和珊瑚红 |
| [五枪与物品](reference_style/02_equipment_simple.png) | 五枪、医疗包、手雷、弹药箱、情报、物资、武器箱、商店及 v1.1 预留物品 |
| [自然环境](reference_style/03_natural_scenes.png) | 森林、沙滩、乡村；出口分别为路牌、路牌、道路 |
| [建筑环境](reference_style/04_built_scenes.png) | 要塞、地牢、城市；出口分别为门口、门口、马路 |
| [互动装置](reference_style/05_interactables.png) | 门、路牌、道路的阻断与开放两态，以及商店、武器箱、弹药箱、医疗包 |
| [战斗特效](reference_style/06_effects.png) | 友弹、敌弹、攻击预警、爆炸、治疗、情报上传与受击反馈 |
| [战斗 UI](reference_style/07_ui.png) | 爱心、弹药/手雷/物资/情报、简图、武器槽、指挥部/商店/结算面板 |
| [菜单与叙事 UI](reference_style/08_menus.png) | 主菜单、武器库、音量设置、暂停、简报、结局 |
| [可行走与阻挡地形](reference_style/09_terrain_walkable_blocked.png) | 草地、土路、沙地、石砖等可行走表面，以及岩石、墙体、水域等阻挡示例 |
| [环境装饰](reference_style/10_decorations.png) | 花草、碎石、落叶、沙包、物资箱、建筑构件、路障与路牌 |
| [可交互物品](reference_style/11_interactable_items.png) | 五类武器、医疗/弹药/手雷补给与地雷外观；地雷玩法规则尚待策划定义 |
| [森林战斗概念实机渲染图](reference_style/12_forest_gameplay_render.png) | 玩家与敌人交火、敌弹与近战预警、森林边界掩体、出口路牌及 HUD 的组合效果 |

设计方向和使用限制见 [美术基准](ART_DIRECTION.md)，生成提示词集见 [提示词记录](reference_style/PROMPTS.md)。这些图片是统一风格的视觉设计稿和概念画面，可供开发对照；它们并非透明底精切图集或引擎运行截图。角色逐帧动画、图集、碰撞盒和 Godot 集成属于后续开发工作。图中 UI 数值和占位条不取代策划案规则。

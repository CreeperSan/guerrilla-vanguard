# 入场修正、制作名单入口与战斗粒子

## 可编辑资源

三类视觉效果均为原生 `CPUParticles2D`，无碰撞、无伤害脚本，可直接在 Godot 打开场景编辑：

| 场景 | 用途 | 默认效果 |
| --- | --- | --- |
| `Prefab/Effects/WalkingDust.tscn` | 玩家地面移动 | 5 枚浅褐色小尘粒，向脚后方扩散，0.42 秒消散 |
| `Prefab/Effects/BulletImpact.tscn` | 命中目标、墙壁、到达射程或超时消失 | 10 枚黄灰色细碎烟尘，0.32 秒消散 |
| `Prefab/Effects/ExplosionDebris.tscn` | 手雷、RPG、敌方爆炸等统一爆炸区域 | Debris 碎屑和 Smoke 烟尘两层，最长 0.95 秒 |

在 Inspector 中修改 `amount`（数量）、`lifetime`（寿命）、`initial_velocity_min/max`（速度）、`spread`（散射角）、`gravity`（重力）、`scale_amount_min/max`（尺寸）、`color_ramp`（颜色和透明度变化）、`scale_amount_curve`（尺寸变化）。也可给粒子节点设置自定义 Texture，以替换默认像素方片。

`combat_particle_burst.gd` 只负责启动与回收，回收时间由最长粒子寿命自动计算。新增粒子节点应直接放在效果根节点下，并使用一次性发射 `one_shot = true`、瞬间发射 `explosiveness = 1`。效果随战斗暂停，切关时清理，挂在世界节点下自然消散，不随玩家或弹丸移动。

玩家 Inspector 的 `walking_dust_scene`、`walking_dust_spacing` 控制使用的场景和脚步间距，默认每真实移动 18 个世界单位发射一次；撞墙原地按键、闪避、击退及入场动画不触发行走灰尘。弹丸的 `impact_particle_scene` 和爆炸的 `debris_particle_scene` 可替换或清空。

真实命中按目标去重，穿透弹每个命中点分别发射；终点按 `_is_finished` 去重。自然射程终止也发射烟尘。碎屑随爆炸半径有限度缩放，独立于爆炸主体存续，不改变爆炸伤害或阵营过滤。爆炸物理区域延迟到碰撞查询结束后加入，避免在命中回调中修改物理世界。

## 入场与 HUD

- 降落及跑入位置动画改为 `TRANS_LINEAR`，保持匀速。
- `Scene/LevelFortress/FortressLevel.tscn` 的 `LevelEntry/PlayerSpawn` 默认改为 `(0, 205)`，距起始房底部约 45 个世界单位；`RunStart` 保持 `(0, 295)`。
- 隐藏角色 → 生成房间并等待揭幕 → 设置动画起点、安装降落伞 → 同帧显示并播放。首次可见位置即为动画起点，不在落点提前显示。
- Boss 血条改到顶部中央得分面板下方，宽 360、高约 32、进度条高 8。布局和字体大小均在 `Scene/UI/HUD/HUD.tscn` 的 `BossHealthPanel` 子树编辑。

## 制作名单

首页新增“制作人员”按钮，与“关于游戏”并列，跳转已有 `Scene/Credits/Credits.tscn`。首页进入仅显示返回首页；通关战报进入仍保留返回战报。名单内容继续编辑 `Script/Presentation/credits.tres`。

## 验证

- `tests/combat_particles_test.tscn`：实际位移发射、命中/终点去重、爆炸伤害保持、暂停/回收、顶部血条及首页按钮实际导航。
- `tests/battle_planning_entry_test.tscn`：揭幕期间角色保持隐藏、线性降落、两种入场落点及冷却条回归。
- `tests/special_weapons_test.tscn`：穿透、RPG、喷火及爆炸伤害回归。
- `tests/presentation_navigation_test.tscn`：原启动、剧情、规划、关卡、结算和片尾导航回归。
- 图形预览 `tests/combat_particles_preview.tscn` 输出 `/private/tmp/gv-combat-particles.png` 和 `/private/tmp/gv-menu-credits.png`。

实体设备的连续移动手感、粒子密度与性能仍建议结合目标设备试玩调整。

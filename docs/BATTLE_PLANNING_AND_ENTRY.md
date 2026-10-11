# 作战规划、玩家入场与紧凑路线 HUD

## 正式流程

首页选择空降或反击 → GameManager 创建本局唯一真实路线 → BattlePlanning 逐张展示 → 全部锁定后等待 3 秒 → GameRun → 玩家入场 → 恢复战斗。

规划页与正式关卡共用同一个路线、模式及随机种子。规划期间不会加载敌人，也不计入有效作战耗时。首关降落、其余关卡跑入均匀速线性移动，入场起点准备完毕才显示角色，消除出生点闪现。入场期间暂停世界、输入和冷却；完成入场后才确认 ACTIVE，安全出口无法在此之前推进。

空降显示 5 张卡片，反击显示 7 张卡片，固定终点标注“最终突击”。卡片依次缩放展开、轻微旋转归正、闪光锁定，并逐段点亮路线。图案读取各主题自己的地形与装饰资源，名称保持为可编辑文字。

## 调整位置与演出

打开 `Scene/LevelFortress/FortressLevel.tscn`：

- `LevelEntry/PlayerSpawn`：相对**起始房中心**的落点，默认 `(0, 205)`，靠近地图底部中央。
- `LevelEntry/RunStart`：后续关卡从画面底部进入的起点，默认 `(0, 295)`。
- 两个 Marker 的位置按相对房间的偏移读取；保持父节点 LevelEntry 的变换为默认值。
- 正式 GameRun 继承该场景，所有关卡沿用这些 Marker；独立主题场景缺少 Marker 时使用相同默认偏移。
- 控制器 Inspector 的“玩家入场”可调整 Marker 路径、降落时长（2.4 秒）、跑入时长（1.15 秒）及降落高度（190）。
- 起始房生成物件前，根据落点预留底部通道，木箱、水池、敌人与主题掩体不会随机占据入场区域。自定义落点应保持在地板内、避开外墙。

打开 `Scene/BattlePlanning/BattlePlanning.tscn`，调整根节点 Inspector：

- `card_reveal_duration`：单张展开动画，默认 0.35 秒。
- `card_interval`：逐张锁定间隔，默认 0.15 秒。
- `hold_duration`：全部展示后的停留，默认 3 秒。

降落伞为原创可编辑矢量资源 `Assets/Art/MilitaryArcade/Entry/parachute.svg`，透明背景，无额外第三方资源；降落后收拢并淡出。

## HUD

装备面板新增独立共用冷却条。手雷、燃烧瓶和护盾的成功使用同步清空进度，1 秒恢复至满；最后一枚用完后仍能显示剩余冷却。暂停不计时，失败使用不会重置。

整局路线栏移至底部，高度约 24 像素：每关一张紧凑卡片，当前金色、完成绿色、失败红色。细进度条表示“已完成关数 + 当前关已清理房间占比”，未实例化的房间不会误判完成。底部操作面板与路线栏错开。

## 验证入口

- `tests/battle_planning_entry_test.tscn`：真实菜单 → 规划 → 首关降落 → 冷却与暂停 → 后续跑入；核对实际路线与展示一致。
- 添加参数 `-- --visual-preview`：图形模式保存截图至 `/private/tmp/gv-entry-*.png`。
- 添加 `--counterattack`：临时在内存解锁，验证七关路线，提交启动请求后立即还原，不改账户存档。
- 添加 `--touch-preview`：额外生成触控 HUD 截图。
- `tests/presentation_navigation_test.tscn`：原启动、漫画、菜单、规划、关卡、战报与片尾导航回归。
- `tests/presentation_flow_test.tscn`、`tests/combat_balance_test.tscn`：展示账本与装备/伤害规则回归。

触屏和手柄的实体设备操作、动画节奏的主观验收仍应在目标设备试玩。

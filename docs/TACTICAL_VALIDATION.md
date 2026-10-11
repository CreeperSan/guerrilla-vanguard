# 战术装备验证记录（2026-10-10）

环境：Godot 4.7.2 stable steam，macOS / Apple M2 Pro。正式装备 15 件，未加入余火罐。

## 新系统

`tests/tactical_equipment_test.tscn`：**156 项检查，0 失败**。

覆盖：15 份配置/独立能力/完整图标；可复现奖励与已持有过滤；组合倍率；基础数值隔离；当前生命截断不产生受伤事件；死亡不领取和清房回血；新玩家不继承；霰弹枪全部弹丸快照；失败射击不消费枪套；换弹实际进度与中途拾取；主动盾/闪避优先级；同房重入不刷新护板；清房去重；真实 HurtBox 接触；逐目标冷却；Boss 同步阶段回血时正确消费回力；磁环真实扩距与白名单；手雷/RPG/燃烧瓶隔离；购买前折扣、重复领取、余额不足、信号重入退款；Boss 奖励去重；背包/奖励暂停所有权；正式关卡生成器切换两关保留玩家、背包和生命代价。

```sh
/path/to/Godot --headless --path . tests/tactical_equipment_test.tscn
```

## 相关回归

| 场景 | 检查 | 失败 |
|---|---:|---:|
| special_weapons_test | 74 | 0 |
| player_actions_and_hints_test | 94 | 0 |
| player_enemy_contact_test | 15 | 0 |
| battlefield_upgrade_test | 439 | 0 |
| boss_tank_test | 190 | 0 |
| run_flow_test（场景包装运行） | 224 | 0 |
| merchant_room_test | 19843 | 2 |

商店的两项失败均为地图生成断言“Boss 仍单入口”：第 3、4 关，种子 134640。使用暂存版（此次战术改动前）的生成器另行运行相同 700 个样本，重现同样两项双入口问题。本次未修改生成器规则；商品交易检查没有新增失败。商店故意测试无效商品池、升级故意测试保存失败时会产生预期错误日志。

`run_flow_test.gd` 直接以 `--script` 启动会遇到既有 AutoLoad 编译时序问题；验证时临时改为 Node 场景入口、使用 `get_tree()`，不修改正式测试断言，224 项通过；临时包装已清理。

沙盒运行可见 user:// 日志/音频设置写入失败与 macOS 证书警告。进程退出时也有既有 ObjectDB/音频回收警告（空基线同样有 ObjectDB 警告），没有将这些警告当作运行时验收成功依据。

## 运行时预览

`tests/tactical_equipment_preview.tscn` 可在编辑器直接 F6。它使用正式玩家组件、装备目录、奖励及背包界面。内置 imagegen 生成图集，原图、提示词和打包脚本均已保存。

已使用真实 OpenGL/Metal 窗口渲染检查 1280×720 截图：

- `docs/art/tactical_reward_preview.png`：三选一、完整说明、生命值前后变化及默认领取焦点。
- `docs/art/tactical_inventory_preview.png`：背包计数、图标、说明和返回焦点。
- `docs/art/tactical_shop_preview.png`：三件原补给、额外战术位、价格及购买说明。

```sh
/path/to/Godot --path . --resolution 1280x720 tests/tactical_equipment_preview.tscn -- --capture
```

已完成代码和场景契约验证、桌面截图检查；没有完成多轮实战平衡、真实手柄操作或移动设备触屏验收。当前项目没有独立地面弹药拾取类型，磁环实际扩距作用于金钱，并为未来显式声明 magnetic_ammo 的弹药保留接口；武器补弹拾取不作为弹药远程领取。

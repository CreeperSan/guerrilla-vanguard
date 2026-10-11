# 模式与战斗平衡配置

“强攻模式”统一更名为“反击模式”，仍然是 ID `1`，空降通关解锁、七关路线、地下要塞终点及片尾流程不变。原研究账户与战报不需迁移；旧脚本的 `FULL_ASSAULT` 保留兼容别名，新代码使用 `COUNTERATTACK`。新旧战报均根据模式 ID 显示当前名称。

## 配置入口

项目默认资源：`Script/Balance/combat_balance.tres`。Godot Inspector 可直接编辑 `CombatBalanceConfig` 和每个 `BattleModeProfile`，不必改角色或攻击脚本。

| 参数层 | 配置参数 | 默认值 |
| --- | --- | --- |
| 全局基础 | `base_enemy_damage_multiplier` | 2.0（保留上一轮敌军伤害翻倍） |
| 空降模式 | `enemy_health_multiplier` | 1.0 |
| 空降模式 | `enemy_damage_multiplier` | 1.0 |
| 反击模式 | `enemy_health_multiplier` | 2.0 |
| 反击模式 | `enemy_damage_multiplier` | 2.0 |

这里的“200%”相对当前基础难度：原始士兵生命 8，在空降为 8、反击为 16；原始攻击伤害 2，经过上一轮基础调整后空降为 4、反击为 8。玩家和佣兵的攻击、生命不受这些敌军系数影响。可破坏陷阱与地形不属于敌人，不提高它们的生命。

## 不改项目资源的外部参数

复制 `docs/config/combat_balance.example.cfg` 到 Godot 用户数据目录，命名为 `combat_balance.cfg`，下次启动自动读取。也可以在启动参数 `--` 后指定任意绝对路径：

```sh
godot --path /path/to/guerrilla-vanguard -- --combat-balance-config=/path/to/my_balance.cfg
```

导出程序同样支持：

```sh
./GuerrillaVanguard -- --combat-balance-config=/path/to/my_balance.cfg
```

CFG 的 `[base] enemy_damage_multiplier` 对应全局基础系数，`[airborne]` 与 `[counterattack]` 对应两个模式。支持小数；未填写字段沿用 `.tres` 默认配置。文件不存在时使用默认资源；错误类型、非有限数、非正生命倍率或负伤害倍率会拒绝整份覆盖，保留默认参数并输出明确日志。伤害系数允许 0，用于无敌军伤害的调试模式。

## 运行时扩展约定

`BattleBalance` 常驻服务在正式新局开始时读取模式参数快照，跨关复用。运行中修改 `BattleBalance.config` 不会改变当前对局，下一局才生效；磁盘 CFG 或 `.tres` 文件修改后需要重启读取。返回首页恢复空降基础规则。复用同一份配置资源也不会被运行时状态污染。

`HealthComponent.reset_enemy_health(base_health)` 是敌军出生与 Boss 切阶段的唯一生命入口。从基础值计算，向上取整、最少 1 点，不在已缩放的当前值上再次相乘。普通士兵、General、坦克的全部阶段、战术 Boss、远征 Boss 三阶段和召唤伙伴均接入。新增敌军必须通过此方法设置出生与阶段生命，不能直接对当前生命乘系数。

敌军伤害在 `HealthComponent.damage` 中依据来源阵营统一计算一次：原始伤害 × 全局基础系数 × 模式伤害系数，再向上取整并交给护盾、闪避和通用减伤。弹丸转为爆炸/燃烧时仍携带原始伤害，不能在发射端再次放大。这样接触、子弹、爆炸、持续效果和 Boss 技能统一生效。

新增参数可扩展 `BattleModeProfile`，并在对应系统读取；新增模式需增加枚举和资源条目，并补充该模式的路线规则。参数服务与角色实现分离。

## 验证

```sh
godot --headless --path . res://tests/counterattack_balance_test.tscn
```

覆盖稳定模式 ID、名称、空降基础难度、反击倍率、重复初始化、真实士兵、四类 Boss 所有阶段及阶段信号、召唤敌人、玩家/佣兵隔离、小数倍率、外部 CFG、非法覆盖回滚和回首页复位。通过命令行指定有效参数文件时，还额外检查启动时实际读取的三个覆盖参数。

本轮验证：模式与命令行配置 37 项、基础平衡 19 项、战报 30 项、真实导航 15 项、坦克 Boss 190 项、战术 Boss 267 项、既有路线推进 224 项，共 782 项检查零失败。路线检查使用自动加载就绪后的临时 Node 入口执行原有断言，未改变其检查内容。

## 战场升级数值资源：在 Inspector 中调整项目费用、三级倍率和霰弹枪散射参数。
## 资源被配置读取器直接引用，导出游戏时会随依赖打包，无需额外包含 JSON 文件。
class_name BattlefieldUpgradeBalance
extends Resource

## 每项包含 group、name、costs（三个整数）和 multipliers（三个累计倍率）。
@export var upgrades: Dictionary = {}
## 每次开火的霰弹弹丸数；默认五枚，每次仍只消耗一发弹匣弹药。
@export_range(1, 20, 1) var shotgun_pellets: int = 5
## 以面向方向为中心的总散布角，默认 24 度，即左右各 12 度。
@export_range(0.0, 180.0, 1.0) var shotgun_spread_degrees: float = 24.0

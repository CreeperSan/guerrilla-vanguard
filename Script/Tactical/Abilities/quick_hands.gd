## 快手：只修正本轮换弹时长，不改武器永久升级基础值。
extends TacticalAbility


## 数值从装备定义读取，组件按来源隔离并组合修正。
func install() -> void:
    modify(&"reload", parameter("duration", 0.9))

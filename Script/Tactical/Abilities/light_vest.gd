## 轻量背心：移动收益与最大生命代价同时安装，生命只做上限截断。
extends TacticalAbility


## 数值从装备定义读取，组件按来源隔离并组合修正。
func install() -> void:
    modify(&"move_speed", parameter("speed", 1.1))
    modify(&"max_health", parameter("health", 0.8))

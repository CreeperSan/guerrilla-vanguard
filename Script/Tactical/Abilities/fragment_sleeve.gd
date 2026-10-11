## 破片衬套：仅登记手雷快照修正，RPG 和燃烧瓶不会读取。
extends TacticalAbility


## 数值从装备定义读取，组件按来源隔离并组合修正。
func install() -> void:
    modify(&"grenade_radius", parameter("radius", 1.2))
    modify(&"grenade_damage", parameter("damage", 0.9))

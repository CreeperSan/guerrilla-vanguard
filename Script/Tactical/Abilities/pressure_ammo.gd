## 加压弹药：枪械伤害与换弹代价分开登记，不影响投掷和接触伤害。
extends TacticalAbility


## 数值从装备定义读取，组件按来源隔离并组合修正。
func install() -> void:
    modify(&"gun_damage", parameter("damage", 1.2))
    modify(&"reload", parameter("duration", 1.15))

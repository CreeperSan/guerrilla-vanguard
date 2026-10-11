## 古老金币：唯一使用加法百分点属性，不影响金额和研究概率。
extends TacticalAbility


## 数值从装备定义读取，组件按来源隔离并组合修正。
func install() -> void:
    modify(&"money_chance", parameter("chance", 0.05))

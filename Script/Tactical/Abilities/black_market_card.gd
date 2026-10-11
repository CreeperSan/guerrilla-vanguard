## 黑市会员卡：交易和治疗独立属性，购买本卡本身使用购买前价格。
extends TacticalAbility


## 数值从装备定义读取，组件按来源隔离并组合修正。
func install() -> void:
    modify(&"shop_price", parameter("price", 0.85))
    modify(&"healing", parameter("healing", 0.8))

## 独立货币拾取物，复用 LootItem 的触碰检测层、边框和缓动缩放表现。
class_name CurrencyPickup
extends LootItem

@export var currency_kind: RunCurrencyWallet.Kind = RunCurrencyWallet.Kind.MONEY


## 赋予有效的拾取物类型，再执行已有外观和循环动画初始化。
func _ready() -> void:
	type = Type.CurrencyMoney if currency_kind == RunCurrencyWallet.Kind.MONEY else Type.CurrencyResearch
	super._ready()
	if currency_kind == RunCurrencyWallet.Kind.RESEARCH and pickup_frame != null:
		pickup_frame.default_color = Color("#7cdecf")


## 直接使用 prefab 配置的货币贴图，避免改动原武器和装备的外观规则。
func _update_appearance() -> void:
	sprite.region_enabled = false


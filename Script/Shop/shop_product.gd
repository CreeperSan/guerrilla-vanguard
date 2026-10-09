## 单件商品配置：类型、名称、效果数量、金钱价格与贴图均可在 Inspector 调整。
class_name ShopProduct
extends Resource

@export var display_name: String = ""
@export var loot_type: LootItem.Type = LootItem.Type.Empty
## 武器为子弹数，医疗包为治疗量，研究为点数；投掷装备每份沿用现有的 10 个。
@export_range(1, 999, 1) var amount: int = 1
@export_range(1, 9999, 1) var price: int = 1
@export var icon: Texture2D
@export var description: String = ""


## 配置无效时不允许进入商品池，避免显示可扣钱却不能发放的物品。
func is_valid() -> bool:
	return not display_name.is_empty() and amount > 0 and price > 0 and icon != null and loot_type in [
		LootItem.Type.WeaponSMG, LootItem.Type.WeaponShortgun, LootItem.Type.MedicalKit,
		LootItem.Type.EquipmentGrenade, LootItem.Type.EquipmentMolotov,
		LootItem.Type.EquipmentShield, LootItem.Type.CurrencyResearch,
	]

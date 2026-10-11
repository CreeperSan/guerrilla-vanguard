## 单件商品配置：类型、名称、效果数量、金钱价格与贴图均可在 Inspector 调整。
class_name ShopProduct
extends Resource

@export var display_name: String = ""
@export var loot_type: LootItem.Type = LootItem.Type.Empty
## 武器为子弹数，医疗包为治疗量，研究为点数；投掷装备每份发放 2 个。
@export_range(1, 999, 1) var amount: int = 1
@export_range(1, 9999, 1) var price: int = 1
@export var icon: Texture2D
@export var description: String = ""
## 战术商品使用独立 ID，不扩展投掷装备枚举或混用原唯一装备槽。
@export var tactical_id: StringName = &""


## 配置无效时不允许进入商品池，避免显示可扣钱却不能发放的物品。
func is_valid() -> bool:
	if not tactical_id.is_empty():
		var config := TacticalCatalog.get_definition(tactical_id)
		return config != null and config.is_valid() and not display_name.is_empty() and price > 0 and icon != null
	return not display_name.is_empty() and amount > 0 and price > 0 and icon != null and loot_type in [
		LootItem.Type.WeaponSMG, LootItem.Type.WeaponShortgun, LootItem.Type.WeaponSniper, LootItem.Type.WeaponRPG, LootItem.Type.WeaponFlamethrower, LootItem.Type.MedicalKit,
		LootItem.Type.EquipmentGrenade, LootItem.Type.EquipmentMolotov,
		LootItem.Type.EquipmentShield, LootItem.Type.CurrencyResearch,
	]


## 独立适配器将战术定义转为商店展示数据，原商品配置与库存算法保持不变。
static func from_tactical(config: TacticalDefinition) -> ShopProduct:
	var product := ShopProduct.new()
	product.tactical_id = config.id
	product.display_name = config.display_name
	product.price = config.price
	product.icon = config.icon
	product.description = config.description
	return product

## 商店商品池资源：抽取三个不同种类，各关使用房间种子复现，不消耗关卡布局随机流。
class_name ShopCatalog
extends Resource

@export var products: Array[ShopProduct] = []


## 去除无效及重复类型后无放回抽取三件；商品对象只读，售出状态由每个房间实例持有。
func select_stock(stock_seed: int) -> Array[ShopProduct]:
	var pool: Array[ShopProduct] = []
	var seen: Dictionary = {}
	for product: ShopProduct in products:
		if product != null and product.is_valid() and not seen.has(product.loot_type):
			pool.append(product)
			seen[product.loot_type] = true
	if pool.size() < 3:
		push_error("商店商品池至少需要三个有效且不同类型的商品。")
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = stock_seed ^ 0x53484F50
	var selected: Array[ShopProduct] = []
	for index: int in range(3):
		var choice := rng.randi_range(0, pool.size() - 1)
		selected.append(pool[choice])
		pool.remove_at(choice)
	return selected

## 战斗补给房契约测试：关卡唯一性、分支拓扑、清场解锁与固定类别奖励。
extends Node

var _checks: int = 0
var _failures: int = 0


## 延迟到 AutoLoad 初始化后执行生成器和真实房间内容测试。
func _ready() -> void:
	_run.call_deferred()


## 覆盖多关种子和兜底布局，并通过击杀全部守卫验证补给箱解锁。
func _run() -> void:
	for level: int in range(1, 8):
		for seed_value: int in range(100):
			_check_battle_supply_map(FortressRoomGenerator.generate_level(level, seed_value * 7919 + 17))
		_check_battle_supply_map(FortressRoomGenerator._make_fallback_level(level, 97, 4))

	var world := Node2D.new()
	add_child(world)
	var room := (load("res://Scene/LevelFortress/Room_1x1_01/Room_1x1_01.tscn") as PackedScene).instantiate() as FortressRoomTemplate
	room.configure_room({"id": 1, "origin": Vector2i.ONE, "size": Vector2i.ONE, "type": "combat_supply", "style_index": 1}, {
		"north": [], "east": [], "south": [], "west": [],
	})
	world.add_child(room)
	room.activate_room()
	var cache := room.get_node_or_null("LazyContent/BattleSupplyCache") as BattleSupplyCache
	_check(cache != null and not cache.is_opened(), "战斗补给房进入时显示关闭状态的箱子")
	var enemies: Array[EnemySoilder] = []
	for node: Node in room.find_children("*", "Node", true, false):
		if node is EnemySoilder:
			enemies.append(node as EnemySoilder)
	_check(enemies.size() >= 7, "战斗补给房生成至少七名敌人")
	_check(_collect_loot_items(room).is_empty(), "清场前补给内容不可拾取")
	for enemy: EnemySoilder in enemies:
		enemy.health_component.damage(9999)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(cache != null and cache.is_opened(), "全部敌人死亡后补给箱自动打开")
	var reward_types: Dictionary = {}
	for reward: LootItem in _collect_loot_items(room):
		reward_types[reward.type] = true
	_check(reward_types.size() == 5, "开箱后一次性生成五份奖励")
	_check(reward_types.has(LootItem.Type.WeaponSMG) or reward_types.has(LootItem.Type.WeaponShortgun) or reward_types.has(LootItem.Type.WeaponSniper) or reward_types.has(LootItem.Type.WeaponRPG) or reward_types.has(LootItem.Type.WeaponFlamethrower), "奖励包含武器")
	_check(reward_types.has(LootItem.Type.EquipmentGrenade) or reward_types.has(LootItem.Type.EquipmentMolotov) or reward_types.has(LootItem.Type.EquipmentShield), "奖励包含装备")
	_check(reward_types.has(LootItem.Type.MedicalKit), "奖励包含医疗包")
	_check(reward_types.has(LootItem.Type.CurrencyMoney), "奖励包含本局金钱")
	_check(reward_types.has(LootItem.Type.CurrencyResearch), "奖励包含本局研究点数")
	if cache != null:
		cache.open_and_release_rewards(room.get_node("LazyContent"), 20261009)
		_check(_collect_loot_items(room).size() == 5, "重复打开不会复制奖励")
	world.queue_free()
	await get_tree().process_frame
	print("BATTLE_SUPPLY_ROOM_TEST checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## 确认生成图和固定兜底图都恰有一间独立可达的 1×1 战斗补给房。
func _check_battle_supply_map(level_map: Dictionary) -> void:
	var rooms: Array = level_map.get("rooms", [])
	var supply_rooms: Array[Dictionary] = []
	for room: Dictionary in rooms:
		if str(room.get("type", "")) == "combat_supply":
			supply_rooms.append(room)
	_check(supply_rooms.size() == 1, "每个关卡恰好有一间战斗补给房")
	if supply_rooms.size() != 1:
		return
	var supply: Dictionary = supply_rooms[0]
	_check(supply.get("size", Vector2i.ZERO) == Vector2i.ONE, "战斗补给房尺寸为 1×1")
	_check(FortressRoomGenerator._room_degree(int(supply.id), level_map.connections) == 1, "战斗补给房只有一个入口")
	_check(not level_map.get("main_path", []).has(int(supply.id)), "战斗补给房不在 Boss 主路线")
	_check(FortressRoomGenerator._shortest_path_length(rooms.size(), level_map.connections, 0, int(supply.id)) > 0, "战斗补给房从起点可达")
	for room: Dictionary in rooms:
		if int(room.id) != int(supply.id):
			_check(not Rect2i(supply.origin, supply.size).intersects(Rect2i(room.origin, room.size)), "战斗补给房不与其他房间重叠")


## 显式按脚本类型收集奖励，包含继承 LootItem 的金钱和研究点数拾取物。
func _collect_loot_items(root: Node) -> Array[LootItem]:
	var loot_items: Array[LootItem] = []
	for node: Node in root.find_children("*", "Node", true, false):
		if node is LootItem:
			loot_items.append(node as LootItem)
	return loot_items


## 统计所有契约断言，并在失败时输出便于定位的说明。
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[BattleSupplyRoomTest] " + message)

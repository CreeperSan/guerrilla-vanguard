## 可复用的 500 单位网格矩形房间；关卡路线通过 configure_room 指定实际开放的门位。
class_name FortressRoomTemplate
extends Node2D

signal sig_door_entered(room_id: int, side: String, slot: int, body: Node2D)
signal sig_room_cleared(room_id: int)

const UNIT_SIZE := 500.0
const DOOR_WIDTH := 64.0
const WALL_THICKNESS := 16.0
const GROUND_TEXTURE: Texture2D = preload("res://Assets/Art/MilitaryArcade/World/Terrain/Fortress/ground.png")
const WALL_TEXTURE: Texture2D = preload("res://Assets/Art/MilitaryArcade/World/Terrain/Fortress/wall.png")
const WATER_TEXTURE: Texture2D = preload("res://Assets/Art/MilitaryArcade/World/Terrain/Fortress/water.png")
## 路线出口使用现有 Entrance 图片，标识与触发区域一起位于房间内侧。
const ENTRANCE_TEXTURE: Texture2D = preload("res://Assets/Art/MilitaryArcade/World/entrance.png")
const ENEMY_SCENE: PackedScene = preload("res://Prefab/EnemySoilder/enemy_soilder.tscn")
const BOX_SCENE: PackedScene = preload("res://Prefab/Terrain/box_crate.tscn")
const BATTLE_SUPPLY_CACHE_SCENE: PackedScene = preload("res://Prefab/BattleSupplyCache/battle_supply_cache.tscn")
const LOOT_TYPES: Array[LootItem.Type] = [
	LootItem.Type.WeaponSMG,
	LootItem.Type.WeaponShortgun,
	LootItem.Type.WeaponSniper,
	LootItem.Type.WeaponRPG,
	LootItem.Type.WeaponFlamethrower,
	LootItem.Type.EquipmentGrenade,
	LootItem.Type.EquipmentMolotov,
	LootItem.Type.EquipmentShield,
	LootItem.Type.SupportMortarStriker,
	LootItem.Type.SupportTacticalBombing,
	LootItem.Type.SkillSprint,
	LootItem.Type.SkillDodge,
]

## 模板的网格尺寸；每个网格单元为 500×500 世界单位。
@export var room_size_units: Vector2i = Vector2i.ONE
## 该场景对应的房间类型；boss 类型才允许生成 Boss。
@export_enum("combat", "combat_supply", "boss", "merchant", "mercenary") var room_type: String = "combat"
## 同尺寸模板的美术样式编号，由关卡种子决定并与场景后缀对应。
@export_range(1, 99, 1) var room_style_index: int = 1
## 首次进入房间时才实例化的遭遇、拾取物等内容；位置与场景按索引对应。
@export var lazy_content_scenes: Array[PackedScene] = []
@export var lazy_content_positions: Array[Vector2] = []
## 房间首次激活时生成基础敌人、补给、木箱与水域；关闭后仅使用手动配置的延迟内容。
@export var populate_on_first_entry: bool = true
## 出口贴近房间边缘；默认内移 8 单位，减少房间内部走动时误进入。
@export_range(0.0, 120.0, 1.0) var entrance_inset: float = 8.0
## 出口标识的世界缩放；默认 1.5 倍，比上一版 3 倍显示缩小一半。
@export_range(0.5, 3.0, 0.1) var entrance_scale: float = 1.5
## 同一房间模板逻辑可以套用不同环境的贴图、掩体和装饰配置。
@export var battlefield_theme: BattlefieldTheme

var room_id: int = -1
var population_seed: int = 0
var opened_doors: Dictionary = {"north": [], "east": [], "south": [], "west": []}
var _generated_nodes: Array[Node] = []
var _door_gates: Array[StaticBody2D] = []
var _door_triggers: Array[Area2D] = []
var _door_markers: Array[Sprite2D] = []
var _contents_initialized: bool = false
var _clear_signal_sent: bool = false
var _tracked_enemy_ids: Dictionary = {}
## 战斗补给房的宝箱在首次激活时生成，清场时才打开并释放拾取物。
var _battle_supply_cache: BattleSupplyCache


## 配置房间身份和路线连接，并重建门洞，未连接的门位保持墙体封闭。
func configure_room(room_data: Dictionary, door_data: Dictionary) -> void:
	room_id = int(room_data.get("id", -1))
	room_size_units = room_data.get("size", Vector2i.ONE)
	room_type = str(room_data.get("type", "combat"))
	room_style_index = int(room_data.get("style_index", room_style_index))
	opened_doors = door_data.duplicate(true)
	if is_inside_tree():
		_rebuild_room_geometry()


## 首次进入房间时才创建遭遇和拾取内容，未访问房间只保留静态地图与门触发器。
func activate_room() -> void:
	if _contents_initialized:
		return
	_contents_initialized = true
	var content_root := Node2D.new()
	content_root.name = "LazyContent"
	add_child(content_root)
	# 商人房只生成独立商店场景；跳过所有战斗、免费补给与延迟敌人配置。
	if room_type == "merchant":
		var shop := preload("res://Prefab/Merchant/merchant_room.tscn").instantiate() as MerchantRoom
		shop.stock_seed = population_seed
		content_root.add_child(shop)
		_check_room_cleared()
		return
	# 雇佣兵房使用专属场景内的招募点，不生成敌群、免费物资或普通随机战利品。
	if room_type == "mercenary":
		_check_room_cleared()
		return
	if room_type == "combat_supply":
		_battle_supply_cache = BATTLE_SUPPLY_CACHE_SCENE.instantiate() as BattleSupplyCache
		if _battle_supply_cache != null:
			_battle_supply_cache.position = Vector2(0.0, -12.0)
			content_root.add_child(_battle_supply_cache)
	for index: int in range(lazy_content_scenes.size()):
		var content_scene := lazy_content_scenes[index]
		if content_scene == null:
			continue
		var content := content_scene.instantiate() as Node2D
		if content == null:
			push_warning("房间 %d 的延迟内容必须以 Node2D 为根节点。" % room_id)
			continue
		content.position = lazy_content_positions[index] if index < lazy_content_positions.size() else Vector2.ZERO
		content_root.add_child(content)
	if populate_on_first_entry:
		_populate_room(content_root)
	for enemy: Node in content_root.find_children("*", "Node", true, false):
		if enemy.is_in_group("enemies"):
			track_enemy(enemy as Node2D)
	_check_room_cleared()


## 当前房间内所有敌人（包含 Boss）被清除后才允许关卡控制器切换房间。
func is_room_safe() -> bool:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and is_ancestor_of(enemy):
			return false
	return true


## 监听房间中的敌人或 Boss 最终死亡；未激活房间不运行任何遭遇轮询。
func track_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or _tracked_enemy_ids.has(enemy.get_instance_id()):
		return
	_tracked_enemy_ids[enemy.get_instance_id()] = true
	var boss := enemy as BattlefieldBoss
	if boss != null:
		boss.sig_defeated.connect(_on_tracked_enemy_removed)
		return
	var health := enemy.get_node_or_null("Health") as HealthComponent
	if health != null:
		health.sig_die.connect(_on_tracked_enemy_removed)


## 延迟到敌人死亡回调结束后检查安全状态，确保 queue_free 已标记该敌人。
func _on_tracked_enemy_removed() -> void:
	_check_room_cleared.call_deferred()


## 房间变安全时只发一次通知，门口等待的玩家可在清场后继续传送。
func _check_room_cleared() -> void:
	# 固定竞技场不预生成守卫；等待首领生成后才允许清场检查，避免入场即开门。
	if room_type == "boss" and not has_meta("boss_spawned"):
		return
	if not _contents_initialized or _clear_signal_sent or not is_room_safe():
		return
	_clear_signal_sent = true
	if room_type == "combat_supply" and is_instance_valid(_battle_supply_cache):
		var content_root := get_node_or_null("LazyContent") as Node2D
		if content_root != null:
			_battle_supply_cache.open_and_release_rewards(content_root, population_seed)
	_open_room_doors()
	sig_room_cleared.emit(room_id)


## 清场后移除所有路线门的碰撞门板，未清场时玩家无法走出或返回房间。
func _open_room_doors() -> void:
	for gate: StaticBody2D in _door_gates:
		if is_instance_valid(gate):
			gate.queue_free()
	_door_gates.clear()
	for marker: Sprite2D in _door_markers:
		if is_instance_valid(marker):
			marker.modulate.a = 1.0
	# 触发区内移后，等待清场的玩家可能已经站在其中；延迟转发可避免必须重新进出。
	for trigger: Area2D in _door_triggers:
		if not is_instance_valid(trigger):
			continue
		for body: Node2D in trigger.get_overlapping_bodies():
			_on_door_body_entered.call_deferred(body, str(trigger.get_meta("side")), int(trigger.get_meta("slot")))


## 按房间尺寸和样式生成敌人、补给、木箱和水池，所有内容只在首次进入时实例化。
func _populate_room(content_root: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = population_seed if population_seed != 0 else (room_id + 1) * 7919 + room_style_index * 104729
	var room_bounds := Vector2(room_size_units) * UNIT_SIZE
	var half_bounds := room_bounds * 0.5
	var area_units: int = room_size_units.x * room_size_units.y
	var enemy_count: int = 1 if room_type == "start" else 2 + mini(int(area_units / 2), 4)
	if room_type == "boss":
		enemy_count = 2 + mini(int(area_units / 3), 3)
	elif room_type == "combat_supply":
		# 补给房至少七名敌人；大房间增加敌群但限制上限，避免生成负担失控。
		enemy_count = 7 + mini(area_units - 1, 5)
	for enemy_index: int in range(enemy_count):
		_spawn_enemy(content_root, _random_inner_position(rng, half_bounds, 118.0), enemy_index, rng)

	# 补给房的奖励必须等清场后开启，因而不放置可提前破坏并掉落物品的木箱。
	var crate_count: int = 0 if room_type == "combat_supply" else 1 + mini(int(area_units / 4), 3)
	for crate_index: int in range(crate_count):
		var crate := BOX_SCENE.instantiate() as TerrainBoxCrate
		if crate == null:
			push_error("木箱预制体未挂载 TerrainBoxCrate 脚本。")
			continue
		crate.name = "BoxCrate%d" % crate_index
		crate.position = _random_inner_position(rng, half_bounds, 92.0)
		crate.loot_drop_probability = 0.4
		crate.appearance_texture = _get_terrain_texture(&"box_texture", null)
		content_root.add_child(crate)

	var water_count: int = 0 if room_type == "combat_supply" else 1 + mini(int(area_units / 5), 2)
	for water_index: int in range(water_count):
		var water_size := Vector2(rng.randf_range(64.0, 118.0), rng.randf_range(44.0, 90.0))
		var water_position := _random_inner_position(rng, half_bounds, maxf(water_size.x, water_size.y))
		_add_water_patch(content_root, water_position, water_size, water_index)

	var loot_count: int = 0 if room_type == "combat_supply" else (1 if room_type == "start" else 1 + int(rng.randf() > 0.55))
	# 物品类型使用独立的房间种子随机流，各类型等概率抽取，起始房也能生成 SMG。
	# 不消耗布局随机流，保持敌人、木箱、水域及补给位置的既有生成结果。
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = rng.seed ^ 0x4C4F4F54
	for loot_index: int in range(loot_count):
		var loot_type: LootItem.Type = LOOT_TYPES[loot_rng.randi_range(0, LOOT_TYPES.size() - 1)]
		# 每次生成一份补给；武器由拾取效果补满备弹，不再按数量累加弹药。
		var amount: int = LootItem.get_default_drop_amount(loot_type)
		var loot_item := PrefabManager.create_loot_item(loot_type, amount)
		if loot_item == null:
			continue
		loot_item.name = "RoomLoot%d" % loot_index
		loot_item.position = _random_inner_position(rng, half_bounds, 76.0)
		content_root.add_child(loot_item)
	_populate_theme_terrain(content_root, rng, half_bounds, area_units)


## 首次进入主题房间时增加掩体和边缘装饰；未访问房间不创建这些内容。
func _populate_theme_terrain(content_root: Node2D, rng: RandomNumberGenerator, half_bounds: Vector2, area_units: int) -> void:
	if battlefield_theme == null:
		return
	if battlefield_theme.cover_texture != null:
		var cover_size := battlefield_theme.cover_size.max(Vector2(16.0, 16.0))
		var count := battlefield_theme.cover_count + mini(int(area_units / 3), 2)
		for index: int in range(count):
			var cover_position := _find_theme_cover_position(content_root, rng, half_bounds, cover_size * 0.5)
			if cover_position == Vector2.INF:
				continue
			var cover := StaticBody2D.new()
			cover.name = "ThemeCover%d" % index
			cover.position = cover_position
			cover.collision_layer = Definition.PHYSICS_LAYER_TERRAIN
			cover.collision_mask = 0
			var collision := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = cover_size
			collision.shape = shape
			cover.add_child(collision)
			var sprite := Sprite2D.new()
			sprite.texture = battlefield_theme.cover_texture
			sprite.region_enabled = true
			sprite.region_rect = Rect2(Vector2.ZERO, cover_size)
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			cover.add_child(sprite)
			content_root.add_child(cover)
	if battlefield_theme.decoration_texture == null:
		return
	# 装饰集中在四周，留出中央战斗区，并沿用种子保证同一关卡可以复现。
	for index: int in range(mini(4 + area_units * 2, 16)):
		var decoration := Sprite2D.new()
		decoration.name = "ThemeDecoration%d" % index
		decoration.texture = battlefield_theme.decoration_texture
		var inner_half := half_bounds - Vector2.ONE * 100.0
		match index % 4:
			0: decoration.position = Vector2(rng.randf_range(-inner_half.x, inner_half.x), -inner_half.y)
			1: decoration.position = Vector2(inner_half.x, rng.randf_range(-inner_half.y, inner_half.y))
			2: decoration.position = Vector2(rng.randf_range(-inner_half.x, inner_half.x), inner_half.y)
			3: decoration.position = Vector2(-inner_half.x, rng.randf_range(-inner_half.y, inner_half.y))
		decoration.z_index = -2
		content_root.add_child(decoration)


## 为新增掩体寻找空位，避开出生中心、门口以及已生成的敌人、拾取物和地形。
func _find_theme_cover_position(content_root: Node2D, rng: RandomNumberGenerator, half_bounds: Vector2, cover_half: Vector2) -> Vector2:
	for _attempt: int in range(24):
		var candidate := _random_inner_position(rng, half_bounds, maxf(cover_half.x, cover_half.y) + entrance_inset + 40.0)
		if candidate.length() < 72.0 + cover_half.length():
			continue
		var overlaps := false
		for existing: Node in content_root.get_children():
			var item := existing as Node2D
			if item == null:
				continue
			var existing_half := Vector2(32.0, 32.0)
			var collision := item.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if collision != null and collision.shape is RectangleShape2D:
				existing_half = (collision.shape as RectangleShape2D).size * 0.5
			var distance := (candidate - item.position).abs()
			var minimum := cover_half + existing_half + Vector2.ONE * 24.0
			if distance.x < minimum.x and distance.y < minimum.y:
				overlaps = true
				break
		if not overlaps:
			return candidate
	return Vector2.INF


## 获取主题贴图；未指定主题或单项贴图时保留原 Fortress 的对应资源。
func _get_terrain_texture(property_name: StringName, fallback: Texture2D) -> Texture2D:
	if battlefield_theme == null:
		return fallback
	var texture := battlefield_theme.get(property_name) as Texture2D
	return texture if texture != null else fallback


## 第二种房间样式使用主题自己的配色，原要塞继续沿用已有配色。
func _get_room_style_tint(fallback: Color) -> Color:
	if room_style_index == 1:
		return Color.WHITE
	return battlefield_theme.secondary_style_tint if battlefield_theme != null else fallback


## 生成并配置房间敌人；不同房间尺寸与样式使用不同制服、行为和战斗参数。
func _spawn_enemy(content_root: Node2D, spawn_position: Vector2, enemy_index: int, rng: RandomNumberGenerator) -> void:
	var enemy := ENEMY_SCENE.instantiate() as EnemySoilder
	if enemy == null:
		push_error("敌人士兵预制体未挂载 EnemySoilder 脚本。")
		return
	enemy.name = "RoomEnemy%d" % enemy_index
	enemy.position = spawn_position
	enemy.health = 6 + mini(room_size_units.x + room_size_units.y, 6)
	enemy.weapon_damage = 4 if room_type == "boss" else 2
	enemy.fire_interval = 0.65 if room_type == "start" else rng.randf_range(0.42, 0.72)
	enemy.fire_duration = 1.2
	enemy.magazine_size = 8
	enemy.reload_duration = 1.8
	enemy.alert_range = 280.0
	enemy.weapon_range = 210.0
	enemy.move_speed = 42.0 + float(mini(room_size_units.x + room_size_units.y, 6)) * 5.0
	enemy.behavior_mode = EnemySoilder.BehaviorMode.STATIONARY_GUARD if enemy_index % 3 == 0 else EnemySoilder.BehaviorMode.WANDER_AND_CHASE
	enemy.uniform_color = Color(0.82, 0.32, 0.3, 1.0) if enemy_index % 2 == 0 else Color(0.9, 0.55, 0.22, 1.0)
	content_root.add_child(enemy)


## 创建挡住玩家与敌人的水池碰撞体；子弹仍可穿过水域。
func _add_water_patch(content_root: Node2D, center: Vector2, size: Vector2, patch_index: int) -> void:
	var water := StaticBody2D.new()
	water.name = "WaterPatch%d" % patch_index
	water.position = center
	water.collision_layer = Definition.PHYSICS_LAYER_WATER
	water.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	water.add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = _get_terrain_texture(&"water_texture", WATER_TEXTURE)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, size)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.z_index = -1
	water.add_child(sprite)
	content_root.add_child(water)


## 在房间中心安全边界内抽取内容坐标，给玩家出生点与墙边留出空间。
func _random_inner_position(rng: RandomNumberGenerator, half_bounds: Vector2, margin: float) -> Vector2:
	var safe_half_bounds := Vector2(maxf(half_bounds.x - margin, 24.0), maxf(half_bounds.y - margin, 24.0))
	return Vector2(rng.randf_range(-safe_half_bounds.x, safe_half_bounds.x), rng.randf_range(-safe_half_bounds.y, safe_half_bounds.y))


## 生成地面和带物理碰撞的墙体；导出的房间尺寸只改变占地与门位数量。
func _ready() -> void:
	# 本房间的手绘地形统一使用线性采样，保留抗锯齿笔触与柔和色块。
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rebuild_room_geometry()


## 清理上一次生成的几何节点后，按当前尺寸和门位重新创建房间。
func _rebuild_room_geometry() -> void:
	for generated: Node in _generated_nodes:
		if is_instance_valid(generated):
			generated.queue_free()
	_generated_nodes.clear()
	_door_gates.clear()
	_door_triggers.clear()
	_door_markers.clear()
	_build_ground()
	_build_side_walls("north")
	_build_side_walls("east")
	_build_side_walls("south")
	_build_side_walls("west")


## 使用可重复地面纹理铺满房间内部。
func _build_ground() -> void:
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.texture = _get_terrain_texture(&"ground_texture", GROUND_TEXTURE)
	ground.region_enabled = true
	# 地面铺至外墙外沿，补齐墙角和门洞的底色；相机边界内不会露出关卡背景。
	ground.region_rect = Rect2(Vector2.ZERO, Vector2(room_size_units) * UNIT_SIZE + Vector2.ONE * WALL_THICKNESS * 2.0)
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.modulate = _get_room_style_tint(Color(0.78, 0.9, 0.88, 1.0))
	ground.z_index = -10
	_generated_nodes.append(ground)
	add_child(ground)


## 将房间边界划分成 500 单位门位槽，只为未开放门位创建带碰撞墙段。
func _build_side_walls(side: String) -> void:
	var horizontal := side == "north" or side == "south"
	var slot_count := room_size_units.x if horizontal else room_size_units.y
	var total_length := float(slot_count) * UNIT_SIZE
	var half_length := total_length * 0.5
	var center_offset := -half_length
	var wall_center := _side_center(side)
	var open_slots: Array = opened_doors.get(side, [])
	for slot: int in range(slot_count):
		var segment_start := center_offset + float(slot) * UNIT_SIZE
		var segment_end := segment_start + UNIT_SIZE
		var door_center := (segment_start + segment_end) * 0.5
		var door_is_open := open_slots.has(slot)
		if door_is_open:
			_add_wall_segment(side, wall_center, segment_start, door_center - DOOR_WIDTH * 0.5, horizontal)
			_add_wall_segment(side, wall_center, door_center + DOOR_WIDTH * 0.5, segment_end, horizontal)
			_add_door_trigger(side, slot, door_center, horizontal)
		else:
			_add_wall_segment(side, wall_center, segment_start, segment_end, horizontal)


## 取得指定墙边的中心坐标，墙体位于房间边界外侧。
func _side_center(side: String) -> Vector2:
	var half_size := Vector2(room_size_units) * UNIT_SIZE * 0.5
	match side:
		"north": return Vector2(0.0, -half_size.y - WALL_THICKNESS * 0.5)
		"east": return Vector2(half_size.x + WALL_THICKNESS * 0.5, 0.0)
		"south": return Vector2(0.0, half_size.y + WALL_THICKNESS * 0.5)
		_: return Vector2(-half_size.x - WALL_THICKNESS * 0.5, 0.0)


## 创建有碰撞的纹理墙段，并记录节点以便房间路线变化时重建。
func _add_wall_segment(side: String, side_center: Vector2, segment_start: float, segment_end: float, horizontal: bool) -> void:
	var length := segment_end - segment_start
	if length <= 0.0:
		return
	var body := StaticBody2D.new()
	body.name = "%sWall" % side.capitalize()
	body.collision_layer = Definition.PHYSICS_LAYER_TERRAIN
	body.collision_mask = 0
	var local_center := side_center
	if horizontal:
		local_center.x = (segment_start + segment_end) * 0.5
	else:
		local_center.y = (segment_start + segment_end) * 0.5
	body.position = local_center
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, WALL_THICKNESS) if horizontal else Vector2(WALL_THICKNESS, length)
	collision.shape = shape
	body.add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = _get_terrain_texture(&"wall_texture", WALL_TEXTURE)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, shape.size)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.modulate = _get_room_style_tint(Color(0.82, 0.88, 0.9, 1.0))
	body.add_child(sprite)
	_generated_nodes.append(body)
	add_child(body)


## 在房间内侧创建路线出口标识和触发区域，清场后交由关卡控制器切房。
func _add_door_trigger(side: String, slot: int, door_center: float, horizontal: bool) -> void:
	_add_locked_door_gate(side, slot, door_center, horizontal)
	var trigger := Area2D.new()
	trigger.name = "%sDoor%d" % [side.capitalize(), slot]
	trigger.collision_layer = 0
	trigger.collision_mask = 1 << 0
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(DOOR_WIDTH, 16.0) if horizontal else Vector2(16.0, DOOR_WIDTH)
	shape_node.shape = shape
	trigger.add_child(shape_node)
	var half_size := Vector2(room_size_units) * UNIT_SIZE * 0.5
	var trigger_position := Vector2.ZERO
	if horizontal:
		trigger_position.x = door_center
		trigger_position.y = -half_size.y + entrance_inset if side == "north" else half_size.y - entrance_inset
	else:
		trigger_position.y = door_center
		trigger_position.x = half_size.x - entrance_inset if side == "east" else -half_size.x + entrance_inset
	trigger.position = trigger_position
	trigger.set_meta("side", side)
	trigger.set_meta("slot", slot)
	var marker := Sprite2D.new()
	marker.name = "EntranceMarker"
	marker.texture = _get_terrain_texture(&"entrance_texture", ENTRANCE_TEXTURE)
	marker.scale = Vector2.ONE * entrance_scale
	marker.rotation = {"north": 0.0, "east": PI * 0.5, "south": PI, "west": -PI * 0.5}[side]
	marker.modulate.a = 0.4
	trigger.add_child(marker)
	_door_markers.append(marker)
	_door_triggers.append(trigger)
	trigger.body_entered.connect(_on_door_body_entered.bind(side, slot))
	_generated_nodes.append(trigger)
	add_child(trigger)


## 为尚未清场的开放门槽放置墙体门板，清场信号发出时再移除。
func _add_locked_door_gate(side: String, slot: int, door_center: float, horizontal: bool) -> void:
	var gate := StaticBody2D.new()
	gate.name = "%sDoorGate%d" % [side.capitalize(), slot]
	gate.position = _side_center(side)
	if horizontal:
		gate.position.x = door_center
	else:
		gate.position.y = door_center
	gate.collision_layer = Definition.PHYSICS_LAYER_TERRAIN
	gate.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(DOOR_WIDTH, WALL_THICKNESS) if horizontal else Vector2(WALL_THICKNESS, DOOR_WIDTH)
	collision.shape = shape
	gate.add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = _get_terrain_texture(&"wall_texture", WALL_TEXTURE)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, shape.size)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	gate.add_child(sprite)
	_door_gates.append(gate)
	_generated_nodes.append(gate)
	add_child(gate)


## 将有效玩家的门触碰事件转发给关卡级房间切换器。
func _on_door_body_entered(body: Node2D, side: String, slot: int) -> void:
	if body.is_in_group("player"):
		sig_door_entered.emit(room_id, side, slot, body)

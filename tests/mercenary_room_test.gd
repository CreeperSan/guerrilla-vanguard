## 雇佣兵契约测试：房间抽取、招募扣款、换人离场、永久死亡与击杀计分/掉落规则。
extends Node

class TestController extends FortressLevelController:
	## 测试自行配置玩家与钱包，不启动正式主题关卡或连接 HUD。
	func _ready() -> void:
		pass

var _checks := 0
var _failures := 0


## 等 AutoLoad 初始化后测试种子布局及真实佣兵场景。
func _ready() -> void:
	_run.call_deferred()


## 对一批种子复核独立 20% 抽取，并验证房间契约和佣兵生命周期。
func _run() -> void:
	for seed_value: int in range(160):
		var level_map := FortressRoomGenerator.generate_level(1 + seed_value % 6, seed_value * 7919 + 17)
		_check_mercenary_room_map(level_map)
	var controller := TestController.new()
	add_child(controller)
	var player_scene := load("res://Prefab/Player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as Player
	controller.add_child(player)
	controller._player = player
	var mercenary_room_scene := load("res://Scene/LevelFortress/Room_Mercenary/Room_Mercenary.tscn") as PackedScene
	var mercenary_room := mercenary_room_scene.instantiate() as FortressRoomTemplate
	mercenary_room.configure_room({"id": 77, "origin": Vector2i.ZERO, "size": Vector2i.ONE, "type": "mercenary", "style_index": 1}, {
		"north": [], "east": [], "south": [], "west": [],
	})
	controller.add_child(mercenary_room)
	mercenary_room.activate_room()
	_check(mercenary_room.has_node("RecruitmentPoint"), "佣兵房加载专属招募点")
	var room_enemy_count := 0
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if mercenary_room.is_ancestor_of(enemy):
			room_enemy_count += 1
	_check(room_enemy_count == 0, "佣兵房不生成战斗敌人")
	controller.money_drop_chance = 1.0
	controller.money_drop_amount = Vector2i.ONE
	controller.research_drop_chance = 1.0
	controller.research_drop_amount = Vector2i.ONE
	CurrencyManager.begin_run()
	CurrencyManager.money = 200

	var room_candidate := mercenary_room.get_node("HireableMercenary") as HiredMercenary
	_check(not room_candidate._health_bar.visible, "未签约的展示佣兵不显示战斗血条")
	_check(controller.hire_mercenary(room_candidate), "余额充足时签约并带走房间内的佣兵")
	var first_mercenary := get_tree().get_first_node_in_group("hired_mercenaries") as HiredMercenary
	_check(first_mercenary != null, "佣兵加入关卡并成为唯一雇佣单位")
	_check(first_mercenary == room_candidate and first_mercenary.get_parent() == controller, "签约后招募预览角色转移到关卡控制器")
	if first_mercenary != null:
		_check(first_mercenary.health_component.health_max == 120, "佣兵生命值为 120")
		_check(first_mercenary.weapon_damage == 3 and first_mercenary.magazine_size == 6, "佣兵使用伤害 3、六发弹匣手枪")
	_check(CurrencyManager.money == 120, "招募扣除 80 金")
	await _check_companion_behavior(controller, player, first_mercenary)

	_check(controller.hire_mercenary(), "再次付费可招募新佣兵")
	var mercenaries := get_tree().get_nodes_in_group("hired_mercenaries")
	_check(mercenaries.size() == 1, "换人后只有一名有效佣兵")
	if first_mercenary != null:
		_check(first_mercenary._departing, "旧佣兵停止战斗并进入离场流程")
		_check(not first_mercenary._health_bar.visible, "离场佣兵隐藏血条")
	var current_mercenary := mercenaries[0] as HiredMercenary if not mercenaries.is_empty() else null
	if current_mercenary != null:
		current_mercenary.health_component.damage(120, Definition.Faction.Enemy)
		_check(not current_mercenary.is_in_group("hired_mercenaries"), "生命归零后佣兵永久退出战斗")

	var friend_kill_target := _create_enemy(controller)
	controller.register_enemy(friend_kill_target)
	friend_kill_target.health_component.damage(9999, Definition.Faction.Friend)
	_check(controller.total_score == 0, "佣兵击杀不产生玩家积分")
	await get_tree().process_frame
	var currency_drops := controller.find_children("*", "CurrencyPickup", true, false)
	_check(currency_drops.size() == 2, "佣兵击杀仍正常生成金钱与研究点数掉落")

	var player_kill_target := _create_enemy(controller)
	controller.register_enemy(player_kill_target)
	player_kill_target.health_component.damage(9999, Definition.Faction.Player)
	_check(controller.total_score == 100, "玩家击杀仍按普通敌人规则计分")
	await get_tree().process_frame
	controller.queue_free()
	await get_tree().process_frame
	print("MERCENARY_ROOM_TEST checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## 在真实角色、Boss 和物理帧中检查选敌、避敌、受伤血条及连续跟随表现。
func _check_companion_behavior(controller: Node, player: Player, mercenary: HiredMercenary) -> void:
	if mercenary == null:
		return
	player.set_physics_process(false)
	mercenary.set_physics_process(false)
	player.position = Vector2(350.0, 0.0)
	mercenary.position = Vector2(80.0, 0.0)
	_check(mercenary._health_bar.visible and mercenary._health_bar.value == 120.0, "已雇佣佣兵显示满生命血条")
	var enemy := _create_enemy(controller)
	enemy.set_physics_process(false)
	enemy.position = Vector2.ZERO
	_check(enemy._find_combat_target() == mercenary, "普通敌人主动选择更近的已雇佣佣兵")
	var retreat := mercenary._get_safe_follow_direction(player, enemy, Vector2.ZERO)
	_check(retreat.dot(Vector2.RIGHT) > 0.9, "进入最低安全距离时远离敌人")
	mercenary.position = Vector2(120.0, 0.0)
	var buffer_move := mercenary._get_safe_follow_direction(player, enemy, Vector2.ZERO)
	_check(buffer_move.dot(Vector2.LEFT) <= 0.0, "缓冲区内不会跟随玩家贴向敌人")
	var bosses: Array[BattlefieldBoss] = []
	for scene_path: String in ["res://Prefab/BossGeneral/boss_general.tscn", "res://Prefab/BossTank/boss_tank.tscn"]:
		var boss := (load(scene_path) as PackedScene).instantiate() as BattlefieldBoss
		controller.add_child(boss)
		boss.set_physics_process(false)
		boss.position = Vector2.ZERO
		bosses.append(boss)
		_check(boss._find_combat_target() == mercenary, "Boss 主动选择更近的已雇佣佣兵")
	# 使用敌人的真实子弹结算受击，覆盖阵营过滤与血条信号更新。
	var previous_children := controller.get_children()
	enemy._fire_at(enemy.global_position.direction_to(mercenary.global_position))
	for child: Node in controller.get_children():
		if child is ProjectileBullet and not previous_children.has(child):
			child._handle_hit(mercenary)
	_check(mercenary.health_component.health == 118 and mercenary._health_bar.value == 118.0, "敌方子弹可伤害佣兵并同步头顶血条")
	mercenary.health_component.heal(2)
	_check(mercenary._health_bar.value == 120.0, "治疗实时恢复头顶血条")
	mercenary.position = Vector2(450.0, 0.0)
	_check(enemy._find_combat_target() == player, "玩家更近时普通敌人仍攻击玩家")
	for boss: BattlefieldBoss in bosses:
		_check(boss._find_combat_target() == player, "玩家更近时 Boss 仍攻击玩家")
		boss.queue_free()
	enemy.queue_free()
	await get_tree().process_frame
	# 连续行走及冲刺均手动推进玩家与佣兵，验证能追上且不会触发脱队瞬移计时。
	# 跟随测试放在专属房间墙体之外，给行走和冲刺提供足够长的直线空间。
	player.position = Vector2(3000.0, 3000.0)
	mercenary.position = player.position + Vector2(-64.0, 0.0)
	mercenary._follow_offset = Vector2(-64.0, 0.0)
	mercenary._wander_remaining = 100.0
	for speed: float in [150.0, 300.0]:
		for step: int in range(60):
			await get_tree().physics_frame
			player.velocity = Vector2(speed, 0.0)
			player.position += player.velocity / 60.0
			mercenary._physics_process(1.0 / 60.0)
		_check(mercenary.global_position.distance_to(player.global_position) < HiredMercenary.FOLLOW_DISTANCE_MAX, "以 %.0f 速度连续移动时佣兵能跟上玩家，距离 %.1f" % [speed, mercenary.global_position.distance_to(player.global_position)])
		_check(mercenary._far_from_player_remaining == 0.0, "常规跟随不触发脱队瞬移倒计时")
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	mercenary.set_physics_process(true)


## 核对每个种子的独立概率结果，并确认命中的佣兵房唯一、可达且不在 Boss 主线。
func _check_mercenary_room_map(level_map: Dictionary) -> void:
	var seed_value := int(level_map.get("seed", 0))
	var chance_rng := RandomNumberGenerator.new()
	chance_rng.seed = seed_value ^ 0x4D455243
	var expected_count := 1 if chance_rng.randf() < FortressRoomGenerator.MERCENARY_ROOM_CHANCE else 0
	var mercenary_rooms: Array[Dictionary] = []
	var rooms: Array = level_map.get("rooms", [])
	for room: Dictionary in rooms:
		if str(room.get("type", "")) == "mercenary":
			mercenary_rooms.append(room)
	_check(mercenary_rooms.size() == expected_count and mercenary_rooms.size() <= 1, "佣兵房按关卡独立 20% 概率出现且每关最多一间")
	if mercenary_rooms.is_empty():
		return
	var room: Dictionary = mercenary_rooms[0]
	_check(room.get("size", Vector2i.ZERO) == Vector2i.ONE, "佣兵房使用独立 1×1 房间")
	_check(FortressRoomGenerator._room_degree(int(room.id), level_map.connections) == 1, "佣兵房只连接一间相邻房")
	_check(not level_map.get("main_path", []).has(int(room.id)), "佣兵房位于可选支路")
	_check(FortressRoomGenerator._shortest_path_length(rooms.size(), level_map.connections, 0, int(room.id)) > 0, "佣兵房可以从起点抵达")


## 使用正式士兵场景生成可由关卡控制器跟踪的测试敌人。
func _create_enemy(parent: Node) -> EnemySoilder:
	var enemy_scene := load("res://Prefab/EnemySoilder/enemy_soilder.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as EnemySoilder
	parent.add_child(enemy)
	# 将掉落测试放在玩家拾取范围之外，避免物品在断言前被自动收集。
	enemy.global_position = Vector2(1200.0, 1200.0)
	return enemy


## 统计测试断言，失败时输出对应的佣兵契约。
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[MercenaryRoomTest] " + message)

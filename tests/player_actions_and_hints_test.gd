## 玩家动作、体力、边缘入口、房间抽样及屏幕外敌人提示的真实 Godot 契约测试。
## 不执行永久账户结算，测试输入在结束前释放，HUD 使用正式场景但跳过开场倒计时。
extends Node

## 只跳过 HUD 的倒计时与设备布局副作用，保留正式节点、样式和状态更新方法。
class TestHUD extends GameHUD:
	## 保留真实 HUD 节点绑定，只跳过自动倒计时与布局切换。
	func _ready() -> void:
		pass

var _checks := 0
var _failures := 0


## 采用场景入口，等自动加载准备完毕后运行测试。
func _ready() -> void:
	_run.call_deferred()


## 顺序验证动作互斥、体力边界、真实物理闪避、HUD、入口与尺寸类别分布。
func _run() -> void:
	var world := Node2D.new()
	add_child(world)
	var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
	player.position = Vector2(4000, 4000)
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.skill_type = LootItem.Type.SkillSprint
	Input.action_press("move_right")
	Input.action_press("use_skill")
	for second: int in range(3):
		player._update_skill_input(1.0)
		_check(player.sprint_active and is_equal_approx(player.stamina, 100.0 - (second + 1) * 25.0), "奔跑每秒耗 25 体力")
	player._update_skill_input(1.0)
	_check(not player.sprint_active and player.stamina == 0.0 and player._sprint_exhausted, "四秒耗尽后停止奔跑")
	player._update_skill_input(2.9)
	_check(player.stamina == 0.0, "停止不到三秒不恢复")
	player._update_skill_input(0.6)
	_check(is_equal_approx(player.stamina, 10.0) and not player.sprint_active, "跨三秒边界只恢复额外半秒，按住不自动重启")
	Input.action_release("use_skill")
	player._update_skill_input(0.0)
	Input.action_press("use_skill")
	player._update_skill_input(0.0)
	_check(player.sprint_active, "松开后重新按住可使用恢复的体力")
	Input.action_release("move_right")
	player._update_skill_input(0.5)
	_check(not player.sprint_active and is_equal_approx(player.stamina, 10.0), "原地按住不奔跑、不消耗体力")
	Input.action_release("use_skill")
	player._update_skill_input(10.0)
	_check(player.stamina == player.stamina_max, "体力恢复不超过上限")

	player.skill_type = LootItem.Type.SkillDodge
	player._skill_cooldown_remaining = 0.0
	player.facing_direction = Vector2.UP
	player.anim.self_modulate.a = 0.8
	player._start_dodge()
	_check(player.dodge_active and is_equal_approx(player._dodge_time_remaining, 0.5), "闪避持续半秒")
	_check(is_equal_approx(player.anim.self_modulate.a, 0.4), "闪避期间身体不透明度减半")
	player.equipment_type = Player.EquipmentType.GRENADE
	player.equipment_amount = 10
	player.battle_support_type = LootItem.Type.SupportMortarStriker
	player.use_equipment()
	player.use_battle_support()
	_check(player.equipment_amount == 10 and player.battle_support_type == LootItem.Type.SupportMortarStriker, "闪避不消耗装备或支援")
	var weapon := player.node_weapon_manager.active_slot
	var ammo_before := weapon.ammo_magazine_cur
	player.node_weapon_manager.action_fire(player)
	_check(not weapon.try_fire(player) and weapon.ammo_magazine_cur == ammo_before, "管理器与直接发射入口都禁止闪避射击")
	weapon.ammo_magazine_cur -= 1
	player.node_weapon_manager.action_reload()
	_check(not weapon.is_reloading, "闪避不允许手动换弹")
	player.node_weapon_manager.smg_unlocked = true
	player.node_weapon_manager.action_switch_weapon(1)
	player.node_weapon_manager.action_switch_next_weapon()
	_check(player.node_weapon_manager.active_slot == weapon, "闪避不允许切枪")
	player.set_touch_aim_direction(Vector2.RIGHT)
	_check(player.facing_direction == Vector2.UP, "闪避不能触控转向")
	_check(not player.obtain_skill_from_loot(LootItem.Type.SkillSprint) and player.dodge_active, "闪避不能换技能绕过动作锁")
	var health_before := player.health_current
	player.node_health.damage(10)
	_check(player.health_current == health_before, "原有闪避无敌保留")
	Input.action_press("move_right")
	Input.action_press("use_equipment")
	Input.action_press("fire")
	player._process(0.01)
	_check(player.equipment_amount == 10 and weapon.ammo_magazine_cur == ammo_before - 1, "真实输入处理在闪避中不攻击或用装备")
	Input.action_release("fire")
	Input.action_release("use_equipment")
	var start := player.position
	player.set_physics_process(true)
	var frames := 0
	while player.dodge_active and frames < 40:
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
		if player.dodge_active:
			_check(is_equal_approx(player.velocity.length(), 120.0) and player.velocity.x == 0.0 and player.facing_direction == Vector2.UP, "实际物理帧锁定方向并保持速度 120")
			_check(is_equal_approx(player.anim.self_modulate.a, 0.4), "整个闪避动作中身体持续半透明")
	player.set_physics_process(false)
	Input.action_release("move_right")
	_check(not player.dodge_active and absf(player.position.x - start.x) < 0.01, "闪避结束前不能手动横移")
	_check(absf((start.y - player.position.y) - 60.0) < 2.1, "半秒速度 120 约移动 60 单位")
	_check(is_equal_approx(player.anim.self_modulate.a, 0.8), "闪避结束后恢复身体原先的不透明度")

	var hud := load("res://Scene/UI/HUD/HUD.tscn").instantiate() as GameHUD
	hud.set_script(TestHUD)
	add_child(hud)
	hud.set_stamina(20.0, 100.0)
	_check(hud._stamina_bar.value == 20.0 and hud._stamina_fill_style.bg_color == Color("edb666"), "正式 HUD 体力进度与低体力样式同步")
	var room := load("res://Scene/LevelFortress/Room_1x1_01/Room_1x1_01.tscn").instantiate() as FortressRoomTemplate
	room.configure_room({"id": 7, "size": Vector2i.ONE, "type": "combat"}, {"north": [0], "east": [0], "south": [0], "west": [0]})
	world.add_child(room)
	var controller := FortressLevelController.new()
	for trigger: Area2D in room._door_triggers:
		var side := str(trigger.get_meta("side"))
		var axis := absf(trigger.position.y) if side in ["north", "south"] else absf(trigger.position.x)
		_check(is_equal_approx(axis, 242.0), "四侧入口距边缘 8 单位")
		var shape := (trigger.get_child(0) as CollisionShape2D).shape as RectangleShape2D
		_check(minf(shape.size.x, shape.size.y) == 16.0, "入口法向厚度缩小为 16")
		_check(controller._door_landing_position(room, side, 0).distance_to(trigger.position) >= 64.0, "传送落点不会重叠返回入口")
	var boss_room := FortressRoomTemplate.new()
	boss_room.room_size_units = Vector2i.ONE
	boss_room.opened_doors = {"north": [0], "east": [], "south": [], "west": []}
	world.add_child(boss_room)
	var exit_area := controller._create_boss_exit(boss_room, {})
	_check(exit_area.position == Vector2(0, 242) and not exit_area.monitoring, "Boss 通关出口在返回门对侧边缘，清场前关闭")
	controller.free()

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	var counts := [0, 0, 0]
	for draw: int in range(20000):
		var size := FortressRoomGenerator._pick_room_size(rng)
		var area := size.x * size.y
		counts[0 if area == 1 else (1 if area <= 4 else 2)] += 1
	_check(absf(counts[0] / 20000.0 - 0.6) < 0.015 and absf(counts[1] / 20000.0 - 0.3) < 0.015 and absf(counts[2] / 20000.0 - 0.1) < 0.015, "两万次尺寸抽样符合 60/30/10")
	print("ROOM_SIZE_SAMPLE counts=%s" % str(counts))

	var indicator := hud._enemy_hints
	var marker_player := Node2D.new()
	marker_player.position = Vector2(400, 300)
	world.add_child(marker_player)
	indicator.player = marker_player
	indicator.current_room_id = 7
	hud._game_started = true
	indicator.visible = true
	var near_enemy := _enemy(room, Vector2(1800, 300))
	var same_direction := _enemy(room, Vector2(2500, 300))
	var visible_enemy := _enemy(room, Vector2(450, 320))
	var dead_enemy := _enemy(room, Vector2(-1200, 300))
	dead_enemy.get_node("Health").health = 0
	var other_room := Node2D.new()
	world.add_child(other_room)
	var elsewhere := _enemy(other_room, Vector2(400, -1800))
	indicator.refresh_hints()
	_check(indicator.hints.size() == 1 and indicator.hints[0]["direction"].x > 0.99, "屏幕外同方向合并，屏幕内/死亡/其他房间不提示")
	# 验证方向逐帧跟踪真实目标，而不是等待下一次低频敌人筛选。
	indicator._update_visual_hints(0.5)
	var visual: Dictionary = indicator._visual_hints[near_enemy.get_instance_id()]
	var original_angle := float(visual["angle"])
	near_enemy.position.y += 400.0
	indicator._update_visual_hints(1.0 / 60.0)
	var target_angle := (near_enemy.get_global_transform_with_canvas().origin - marker_player.get_global_transform_with_canvas().origin).angle()
	_check(float(visual["angle"]) > original_angle and float(visual["angle"]) < target_angle, "方向逐帧更新并平滑转向，不直接跳到目标角度")
	var screen := indicator.get_viewport_rect()
	_check(is_equal_approx(indicator._edge_visibility(Vector2(screen.end.x + 60.0, screen.get_center().y), screen), 0.5), "屏幕外 60 像素时透明度衰减至一半")
	_check(is_zero_approx(indicator._edge_visibility(screen.get_center(), screen)), "进入视野后目标透明度为零")
	var previous_alpha := float(visual["alpha"])
	near_enemy.global_position += screen.get_center() - near_enemy.get_global_transform_with_canvas().origin
	indicator._update_visual_hints(1.0 / 60.0)
	_check(float(visual["alpha"]) > 0.0 and float(visual["alpha"]) < previous_alpha, "进入视野时逐帧渐隐，不突然消失")
	indicator.refresh_hints()
	indicator._update_visual_hints(1.0)
	_check(not indicator._visual_hints.has(near_enemy.get_instance_id()), "淡出完成后清除旧绘制状态")
	near_enemy.queue_free()
	same_direction.queue_free()
	visible_enemy.queue_free()
	dead_enemy.queue_free()
	elsewhere.queue_free()
	await get_tree().process_frame
	for direction: Vector2 in [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]:
		_enemy(room, marker_player.position + direction.normalized() * 2000.0)
	indicator.refresh_hints()
	_check(indicator.hints.size() == 4, "八个不同方向最多显示四个淡色箭头")
	get_tree().paused = true
	indicator._process(0.2)
	_check(indicator.hints.is_empty(), "暂停时清除提示")
	get_tree().paused = false
	for child: Node in room.get_children():
		if child.is_in_group("enemies"):
			child.queue_free()
	await get_tree().process_frame
	indicator.refresh_hints()
	_check(indicator.hints.is_empty(), "清场后没有方向提示")
	hud.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("PLAYER_ACTION_TEST checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## 创建有真实生命组件的敌人组节点，验证方位筛选而不启动敌人战斗 AI。
func _enemy(parent: Node2D, position_value: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.add_to_group("enemies")
	enemy.position = position_value
	var health := HealthComponent.new()
	health.name = "Health"
	enemy.add_child(health)
	parent.add_child(enemy)
	return enemy


## 累计断言并输出明确失败原因，最终进程使用失败数返回状态。
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[PlayerActionTest] " + message)

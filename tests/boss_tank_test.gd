## 坦克 Boss 运行契约测试：在真实 Godot 场景/物理空间验证阶段、武器、换位和房间接入。
## 所有奖励只在内存中检查，不结算或改写玩家研究存档。
extends Node

## 带生命组件的物理目标，允许范围效果测试玩家/敌方阵营过滤。
class TestTarget extends CharacterBody2D:
	var faction: Definition.Faction = Definition.Faction.Player

## 此检查只验证血条接口；跳过已有 HUD 输入布局的启动副作用。
class TestHUD extends GameHUD:
	func _ready() -> void:
		pass

## 测试宿主复用真实 Boss 生成/奖励/出口流程，跳过关卡导航和玩家初始化。
class TestController extends FortressLevelController:
	func _ready() -> void:
		pass

var _checks := 0
var _failures := 0
var _defeats := 0


## 等自动加载完成后运行，采用场景入口避免 --script 的 AutoLoad 编译时序差异。
func _ready() -> void:
	_run.call_deferred()


## 顺序检查生命阶段、固定时长移动、独立弹匣、驾驶员换位、范围伤害与随机 Boss。
func _run() -> void:
	var world := Node2D.new()
	add_child(world)
	var target := Node2D.new()
	target.add_to_group("player")
	world.add_child(target)
	target.position = Vector2(250, 100)
	var tank := load("res://Prefab/BossTank/boss_tank.tscn").instantiate() as BossTank
	world.add_child(tank)
	tank.set_physics_process(false)
	tank.sig_defeated.connect(func(): _defeats += 1)
	_check(tank.health_component.health == 120 and tank.current_phase == 1, "坦克第一阶段 120 生命")
	_check(tank._track_audio.stream is AudioStreamWAV and tank._track_audio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "履带采用循环独立资源")
	for direction: Vector2 in [Vector2(1, 2), Vector2(-2, 1), Vector2(2, -1), Vector2(1, -2)]:
		var cardinal := tank._cardinal_direction(direction)
		_check(is_equal_approx(cardinal.length(), 1.0) and (cardinal.x == 0.0 or cardinal.y == 0.0), "坦克追击为四轴单位方向")
	for index: int in range(30):
		var before := tank.position
		tank._update_tank_movement(0.1, target)
		var actual := tank.position - before
		_check(absf(actual.x) < 0.001 or absf(actual.y) < 0.001, "真实位移不产生斜向移动")
	_check(is_equal_approx(tank._rest_remaining, 5.0), "第一阶段移动三秒后休息五秒")
	var stopped := tank.position
	tank._update_tank_movement(4.9, target)
	_check(tank.position == stopped, "休息期间不移动")
	tank._update_tank_movement(0.1, target)
	_check(tank.position == stopped, "完整五秒休息结束前不提前移动")
	var before_shot := _count_bullets(world)
	tank._cannon["cooldown"] = 0.0
	tank._update_weapon(tank._cannon, 0.0, 1, 3.0, 0.0, "cannon", target)
	_check(_count_bullets(world) == before_shot + 1 and tank._cannon["ammo"] == 0, "主炮弹匣一发")
	_check(is_equal_approx(tank._cannon["reload"], 3.0), "主炮最后一发后立刻换弹三秒")
	tank._update_weapon(tank._cannon, 2.9, 1, 3.0, 0.0, "cannon", target)
	_check(_count_bullets(world) == before_shot + 1, "主炮换弹期间不能发射")
	tank._update_weapon(tank._cannon, 0.1, 1, 3.0, 0.0, "cannon", target)
	tank._update_weapon(tank._cannon, 0.0, 1, 3.0, 0.0, "cannon", target)
	_check(_count_bullets(world) == before_shot + 2, "主炮完成三秒换弹可再次发射")

	tank.health_component.damage(120)
	_check(tank.current_phase == 2 and tank.health_component.health == 120 and _defeats == 0, "第一阶段耗尽只进入过载")
	tank._move_remaining = 0.1
	tank._update_tank_movement(0.1, target)
	_check(is_equal_approx(tank._rest_remaining, 3.0), "过载休息三秒")
	_check(tank.overload_move_speed > tank.tank_move_speed, "过载移动稍快")
	tank._machine["cooldown"] = 0.0
	before_shot = _count_bullets(world)
	for index: int in range(5):
		tank._update_weapon(tank._machine, 0.0 if index == 0 else 0.3, 5, 5.0, 0.3, "machine", target)
	_check(_count_bullets(world) == before_shot + 5 and tank._machine["ammo"] == 0, "机枪五发及 0.3 秒射速")
	_check(is_equal_approx(tank._machine["reload"], 5.0), "机枪五秒换弹")
	tank._cannon["cooldown"] = 0.0
	tank._cannon["reload"] = 0.0
	tank._cannon["ammo"] = 1
	before_shot = _count_bullets(world)
	tank._update_weapon(tank._cannon, 0.0, 1, 3.0, 0.0, "cannon", target)
	_check(_count_bullets(world) == before_shot + 1 and tank._machine["reload"] == 5.0, "机枪换弹不阻止主炮")
	var last_shell: TankShell
	for child: Node in world.get_children():
		if child is TankShell:
			last_shell = child
	_check(last_shell.leaves_fire, "过载主炮留下燃烧")

	# 房间只监听最终死亡，中间阶段不会清场或奖励；HUD 保留坦克名称。
	var hud := load("res://Scene/UI/HUD/HUD.tscn").instantiate() as GameHUD
	hud.set_script(TestHUD)
	add_child(hud)
	hud.show_boss_health(tank.boss_display_name, 120, 120, 2)
	hud.set_boss_phase(3, 30, 30)
	_check(hud._boss_name_label.text.contains("重型坦克") and not hud._boss_name_label.text.contains("GENERAL"), "阶段血条保留 Boss 名称")
	tank.health_component.damage(120)
	_check(tank.current_phase == 3 and tank.health_component.health == 30 and _defeats == 0, "过载耗尽进入 30 生命驾驶员")
	await get_tree().process_frame
	_check(tank._body_shape.shape.radius == 8.0 and tank._hurt_shape.shape.radius == 11.0, "驾驶员收缩碰撞和受击范围")
	target.position = tank.position + Vector2(80, 80)
	var before := tank.position
	tank._update_driver_movement(0.1, target)
	var displacement := tank.position - before
	_check(displacement.x > 0.0 and displacement.y > 0.0, "驾驶员允许斜向接近")
	target.position = tank.position + Vector2(5, 0)
	tank._update_driver_movement(0.1, target)
	_check(tank.position.distance_to(target.position) > 5.0, "贴身时主动后退")
	target.position = tank.position + Vector2(60, 0)
	tank._pistol["cooldown"] = 0.0
	before_shot = _count_bullets(world)
	for index: int in range(3):
		tank._update_weapon(tank._pistol, 0.0 if index == 0 else 0.5, 3, 3.0, 0.5, "pistol", target)
	_check(_count_bullets(world) == before_shot + 3 and tank._pistol["ammo"] == 0, "驾驶员三发手枪及 0.5 秒射速")
	_check(tank._relocating and tank._has_relocation_target and is_equal_approx(tank._pistol["reload"], 3.0), "打完一轮同时换弹并选位")
	for index: int in range(20):
		tank._choose_relocation(target)
		_check(tank._has_relocation_target and tank._relocation_target.distance_to(target.position) >= tank.driver_min_distance, "换位目标保持最小距离")
	before_shot = _count_bullets(world)
	tank._update_weapon(tank._pistol, 3.0, 3, 3.0, 0.5, "pistol", target)
	tank._update_weapon(tank._pistol, 0.1, 3, 3.0, 0.5, "pistol", target)
	_check(_count_bullets(world) == before_shot, "换位未完成不开始下一轮")
	tank.position = tank._relocation_target
	tank._update_driver_movement(0.0, target)
	_check(not tank._relocating, "到达随机位置后准备下一轮")
	tank.health_component.damage(30)
	tank._on_phase_depleted()
	_check(_defeats == 1 and tank.is_queued_for_deletion(), "最终死亡只触发一次")

	# 炮弹真实引爆后生成两个效果，爆炸击中范围内敌对目标但不伤友军。
	var victim := _target(world, Vector2(1000, 0), Definition.Faction.Player)
	var ally := _target(world, Vector2(1010, 0), Definition.Faction.Enemy)
	var outside := _target(world, Vector2(1150, 0), Definition.Faction.Player)
	await get_tree().physics_frame
	var shell := load("res://Prefab/BossTank/tank_shell.tscn").instantiate() as TankShell
	shell.leaves_fire = true
	shell.bullet_from = Definition.Faction.Enemy
	shell.bullet_damage = 8
	shell.position = Vector2(1000, 0)
	world.add_child(shell)
	shell.set_physics_process(false)
	shell._finish_at(shell.global_position)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.08).timeout
	var explosion_count := 0
	var fire_count := 0
	for child: Node in world.get_children():
		if child is ProjectileExplosion:
			explosion_count += 1
		if child is BurningEffect:
			fire_count += 1
	_check(explosion_count == 1 and fire_count == 1, "过载炮弹真实创建爆炸和燃烧")
	_check(victim.get_node("Health").health < 100, "爆炸实际范围伤害生效")
	_check(ally.get_node("Health").health == 100 and outside.get_node("Health").health == 100, "同阵营和范围外目标不受伤")

	var selector := FortressLevelController.new()
	var seen: Dictionary = {}
	for seed: int in range(100):
		var chosen := selector._select_boss_scene(seed)
		_check(chosen == selector._select_boss_scene(seed), "同种子复现 Boss 选择")
		seen[chosen.resource_path] = true
	_check(seen.size() == 1, "无主题时固定使用默认 Boss，不随种子抽取")
	selector.free()
	var controller := TestController.new()
	add_child(controller)
	controller.boss_scenes = [load("res://Prefab/BossTank/boss_tank.tscn")]
	var room := FortressRoomTemplate.new()
	room.room_id = 9
	room.room_type = "boss"
	room.population_seed = 12345
	room.populate_on_first_entry = false
	controller.add_child(room)
	room._contents_initialized = true
	controller._room_nodes[9] = room
	controller.current_room_id = 9
	controller.level_map = {"boss_room_id": 9}
	var exit := Area2D.new()
	exit.monitoring = false
	room.add_child(exit)
	controller._boss_exit = exit
	controller._spawn_boss_for_current_room()
	var room_boss := room.get_node("Boss") as BossTank
	room_boss.set_physics_process(false)
	controller._spawn_boss_for_current_room()
	_check(room.find_children("Boss", "", false, false).size() == 1, "重复进入 Boss 房不重复实例化")
	room_boss.health_component.damage(120)
	room_boss.health_component.damage(120)
	await get_tree().process_frame
	_check(controller.total_score == 0 and not controller.boss_defeated and not room.is_room_safe() and not exit.monitoring, "前两阶段不计分、不清场、不开放出口")
	var guard := Node2D.new()
	guard.add_to_group("enemies")
	room.add_child(guard)
	room_boss.health_component.damage(30)
	await get_tree().process_frame
	_check(controller.total_score == 500 and controller.boss_defeated, "驾驶员死亡最终计分一次")
	_check(not is_instance_valid(guard) or guard.is_queued_for_deletion(), "Boss 死亡同时清除剩余守卫")
	await get_tree().process_frame
	controller._open_boss_exit()
	await get_tree().process_frame
	_check(room.is_room_safe() and controller.is_current_level_cleared() and exit.monitoring, "Boss 与守卫全部死亡才开放出口")
	controller._spawn_boss_for_current_room()
	_check(room.get_node_or_null("Boss") == null, "最终死亡后不重生 Boss")
	# 先停止测试创建的短音效，给混音器处理释放的时间，避免退出时持有播放资源。
	for node: Node in world.find_children("*", "AudioStreamPlayer2D", true, false):
		(node as AudioStreamPlayer2D).stop()
	controller.queue_free()
	hud.queue_free()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	print("[boss_tank_test] checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


## 创建带玩家/敌方阵营和圆形碰撞的范围伤害目标。
func _target(parent: Node2D, location: Vector2, faction: Definition.Faction) -> TestTarget:
	var target := TestTarget.new()
	target.faction = faction
	target.collision_layer = 1
	target.collision_mask = 0
	target.position = location
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	shape_node.shape = shape
	target.add_child(shape_node)
	var health := HealthComponent.new()
	health.name = "Health"
	target.add_child(health)
	parent.add_child(target)
	return target


## 统计真实弹丸实例，冻结其物理更新防止人工快进的换弹测试被飞行回收干扰。
func _count_bullets(parent: Node) -> int:
	var count := 0
	for child: Node in parent.get_children():
		if child is ProjectileBullet and not child.is_queued_for_deletion():
			child.set_physics_process(false)
			count += 1
	return count


## 所有断言继续执行，失败统一通过非零退出码返回。
func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[boss_tank_test] " + description)

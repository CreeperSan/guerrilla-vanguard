## 新佣兵集成回归：真实招募场景、抛物手雷范围伤害、友军过滤、近战冷却和 Boss 击退免疫。
extends Node

var _checks := 0
var _failures := 0
var _world: Node2D


## 等待自动加载就绪后按真实场景执行，所有单位位于房间墙体以外。
func _ready() -> void:
	_run.call_deferred()


## 串行验证共用物理空间的行为，不写入研究账户或永久升级。
func _run() -> void:
	_world = Node2D.new()
	add_child(_world)
	await _test_room_variants()
	await _test_grenadier()
	await _test_fearless()
	_world.queue_free()
	await get_tree().process_frame
	print("MERCENARY_VARIANTS_TEST checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(1 if _failures else 0)


## 固定三个兵种复核房内预览和肖像，随机种子池也必须覆盖新增兵种。
func _test_room_variants() -> void:
	var seen := {}
	var random_seen := {}
	for role: int in range(-1, 3):
		for seed_value: int in range(12 if role == -1 else 1):
			var room := load("res://Scene/LevelFortress/Room_Mercenary/Room_Mercenary.tscn").instantiate() as FortressRoomTemplate
			room.set("recruitment_role", role)
			room.population_seed = seed_value * 7919 + 17
			_world.add_child(room)
			var candidate := room.get_node("HireableMercenary") as HiredMercenary
			var point := room.get_node("RecruitmentPoint") as MercenaryRecruitment
			_check(not candidate._is_hired and not candidate.is_in_group("combat_targets"), "三个兵种预览均不加入战斗或误受伤")
			_check(point._candidate_name == candidate.get_display_name(), "招募名称与真实候选人一致")
			_check((point.get_node("Portrait") as Sprite2D).texture == candidate.get_portrait(), "招募肖像与真实兵种一致")
			seen[candidate.get_display_name()] = true
			if role == -1:
				random_seen[candidate.get_display_name()] = true
			candidate.activate_for_hire()
			_check(candidate.is_in_group("hired_mercenaries") and candidate.is_in_group("combat_targets"), "三个兵种均可使用公共签约入口激活")
			room.free()
	_check(seen.size() == 3 and random_seen.size() == 3, "固定及随机佣兵房覆盖全部三个兵种")


## 真实抛物投掷命中范围内多个敌人；落点不跟踪，友军免伤、墙体可截停。
func _test_grenadier() -> void:
	var merc := _mercenary("grenadier") as GrenadierMercenary
	merc.position = Vector2(3000, 3000)
	_check(merc.health_component.health == 45 and merc.animated_sprite.sprite_frames.has_animation("attack_up"), "掷弹手生命与八方向攻击美术已接入")
	var enemy := _enemy(Vector2(3140, 3000))
	var near := _enemy(Vector2(3160, 3000))
	var outside := _enemy(Vector2(3230, 3000))
	var friend := _mercenary("fearless")
	friend.position = enemy.position
	var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
	_world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.position = enemy.position
	player.obtain_equipment_from_loot(LootItem.Type.EquipmentShield, 1)
	_check(player.shield_health == 10, "护盾拾取耐久为 10")
	player.obtain_equipment_from_loot(LootItem.Type.EquipmentShield, 1)
	_check(player.shield_health == 10, "重复拾取护盾不会叠加耐久")
	merc._throw_remaining = 0.0
	merc._update_attack(0.0, enemy)
	var grenades := _grenades()
	_check(grenades.size() == 1, "远距离目标触发一次真实手雷投掷")
	merc._update_attack(0.1, enemy)
	_check(_grenades().size() == 1, "投掷冷却期间不会重复创建手雷")
	var grenade := grenades[0]
	grenade.set_physics_process(false)
	var landing := grenade.landing_position
	enemy.position += Vector2(0, 150)
	grenade._physics_process(0.375)
	_check(grenade._sprite.position.y < -30.0 and grenade.landing_position == landing, "手雷沿弧线飞行，目标移动不改变锁定落点")
	grenade._physics_process(0.375)
	grenade._detonate()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(enemy.health_component.health == 100, "移动离开原落点的目标可避开爆炸")
	_check(near.health_component.health == 94 and outside.health_component.health == 100, "爆炸造成 6 点范围伤害并受半径限制")
	_check(friend.health_component.health == 120 and player.health_current == 100, "友军手雷不伤害玩家或其他佣兵")
	var explosions := _explosions()
	_check(explosions.size() == 1, "重复引爆调用只创建一次爆炸")
	for explosion: ProjectileExplosion in explosions:
		explosion.free()
	# 投掷区间两侧都不得开火，避免贴脸无限投掷和超射程攻击。
	merc._throw_remaining = 0.0
	enemy.position = merc.position + Vector2(60, 0)
	merc._update_attack(0.0, enemy)
	enemy.position = merc.position + Vector2(300, 0)
	merc._update_attack(0.0, enemy)
	_check(_grenades().is_empty(), "过近和超出射程时不投掷")
	# 地形层上的实体墙截停飞行，爆炸不得出现在墙后。
	var wall := StaticBody2D.new()
	wall.collision_layer = Definition.PHYSICS_LAYER_TERRAIN
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12, 100)
	shape.shape = rectangle
	wall.add_child(shape)
	_world.add_child(wall)
	wall.position = merc.position + Vector2(70, 0)
	await get_tree().physics_frame
	var blocked := MercenaryGrenade.new()
	blocked.landing_position = merc.position + Vector2(140, 0)
	_world.add_child(blocked)
	blocked.begin_throw(merc.position)
	blocked.set_physics_process(false)
	blocked._physics_process(0.75)
	_check(blocked._finished and blocked.global_position.x < wall.global_position.x, "手雷接触墙面提前爆炸")
	for child: Node in _world.get_children():
		child.queue_free()
	await get_tree().process_frame


## 重甲近战实际扣血、冷却限频、普通士兵轻击退，两个真实 Boss 均不位移。
func _test_fearless() -> void:
	var merc := _mercenary("fearless") as FearlessMercenary
	merc.position = Vector2(4000, 4000)
	_check(merc.health_component.health == 120 and merc._get_follow_speed(merc, 100.0) == 85.0, "重甲战士生命 120、常规速度 85")
	var enemy := _enemy(merc.position + Vector2(20, 0))
	await get_tree().physics_frame
	merc._update_attack(0.0, enemy)
	_check(enemy.health_component.health == 96 and enemy.health_component.last_damage_faction == Definition.Faction.Friend, "近战造成 4 点友军伤害")
	_check(enemy._melee_knockback_remaining > 0.0 and merc._attack_pose_remaining > 0.0, "近战命中触发轻击退及挥击姿势")
	var original := enemy.position
	for step: int in range(8):
		await get_tree().physics_frame
		enemy._physics_process(1.0 / 60.0)
	_check(enemy.position.x > original.x and enemy.position.distance_to(original) <= 12.1, "普通敌人通过物理移动被轻推约 12 单位，实际 %.2f" % enemy.position.distance_to(original))
	merc._update_attack(0.1, enemy)
	_check(enemy.health_component.health == 96, "近战冷却防止逐帧扣血")
	for boss_path: String in ["res://Prefab/BossGeneral/boss_general.tscn", "res://Prefab/BossTank/boss_tank.tscn"]:
		var boss := load(boss_path).instantiate() as BattlefieldBoss
		_world.add_child(boss)
		boss.set_physics_process(false)
		boss.position = merc.position + Vector2(24, 0)
		var boss_position := boss.position
		var previous_health := boss.health_component.health
		merc._melee_remaining = 0.0
		merc._update_attack(0.0, boss)
		_check(boss.health_component.health < previous_health and boss.position == boss_position, "Boss 受到近战伤害但不会被击退")
		boss.free()


## 创建正式新兵种并关闭自动 AI，以便按断言逐步推进。
func _mercenary(kind: String) -> HiredMercenary:
	var actor := load("res://Prefab/Mercenary/mercenary_%s.tscn" % kind).instantiate() as HiredMercenary
	_world.add_child(actor)
	actor.set_physics_process(false)
	return actor


## 敌人使用真实身体、生命和 HurtBox，生命设为 100 避免单次攻击杀死测试对象。
func _enemy(point: Vector2) -> EnemySoilder:
	var enemy := load("res://Prefab/EnemySoilder/enemy_soilder.tscn").instantiate() as EnemySoilder
	enemy.health = 100
	_world.add_child(enemy)
	enemy.position = point
	enemy.set_physics_process(false)
	return enemy


## 仅收集当前世界内尚未回收的佣兵手雷。
func _grenades() -> Array[MercenaryGrenade]:
	var result: Array[MercenaryGrenade] = []
	for node: Node in _world.get_children():
		if node is MercenaryGrenade and not node.is_queued_for_deletion():
			result.append(node)
	return result


## 只收集爆炸节点，检查重复引爆和范围结算。
func _explosions() -> Array[ProjectileExplosion]:
	var result: Array[ProjectileExplosion] = []
	for node: Node in _world.get_children():
		if node is ProjectileExplosion:
			result.append(node)
	return result


## 汇总断言并返回可用于命令行回归的失败退出码。
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[MercenaryVariants] " + message)

## 武器拾取回归：验证普通掉落、首次解锁、备弹重置、容量升级及 HUD 信号。
## 使用真实玩家和拾取物，不保存永久升级；测试只修改本局武器容量。
extends Node

var _checks: int = 0
var _failures: int = 0
var _last_ammo: Vector2i


## 采用场景入口，等待自动加载初始化完成。
func _ready() -> void:
	_run.call_deferred()


## 直接执行真实拾取效果，隔离开火输入与自动拾取造成的时间变化。
func _run() -> void:
	var world := Node2D.new()
	add_child(world)
	var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
	player.position = Vector2(4000, 4000)
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	var weapons := player.node_weapon_manager
	weapons.set_process(false)
	# 排除磁盘账户升级，使基础数量断言可重复。
	weapons.slot1.ammo_magazine_max = 30
	weapons.slot1.ammo_back_max = 120
	weapons.slot2.ammo_magazine_max = 8
	weapons.slot2.ammo_back_max = 40
	weapons.sig_active_ammo_change.connect(func(current: int, back: int): _last_ammo = Vector2i(current, back))
	weapons.slot1.ammo_magazine_cur = 30
	weapons.slot1.ammo_back_cur = 10
	weapons.slot2.ammo_magazine_cur = 3
	weapons.slot2.ammo_back_cur = 2
	var smg := PrefabManager.create_loot_item(LootItem.Type.WeaponSMG, LootItem.get_default_drop_amount(LootItem.Type.WeaponSMG))
	_check(smg.apply_to(player) and _last_ammo == Vector2i(30, 120), "首次拾取补满备弹并同步 HUD，弹匣不变")
	weapons.slot1.ammo_magazine_cur = 7
	weapons.slot1.ammo_back_cur = 15
	_check(smg.apply_to(player) and _last_ammo == Vector2i(7, 120), "重复拾取直接补满备弹，部分弹匣不变")
	_check(not smg.apply_to(player), "备弹已满时普通拾取物不消耗")
	weapons._drop_empty_weapon(weapons.slot1)
	_check(smg.apply_to(player) and _last_ammo == Vector2i(0, 120), "丢弃后重新拾取只补备弹，空弹匣仍为空")
	weapons.slot1.ammo_magazine_max = 44
	weapons.slot1.ammo_back_max = 192
	weapons.slot1.ammo_magazine_cur = 17
	weapons.slot1.ammo_back_cur = 4
	smg.num = 999
	_check(smg.apply_to(player) and _last_ammo == Vector2i(17, 192), "使用升级后备弹上限，忽略拾取数量，弹匣不变")
	weapons.slot1.is_reloading = true
	weapons.slot1.reload_time_remaining = 0.5
	weapons.slot1.ammo_back_cur = 1
	_check(smg.apply_to(player) and weapons.slot1.is_reloading and is_equal_approx(weapons.slot1.reload_time_remaining, 0.5), "拾取不打断进行中的换弹")
	var shotgun := PrefabManager.create_loot_item(LootItem.Type.WeaponShortgun, LootItem.get_default_drop_amount(LootItem.Type.WeaponShortgun))
	_check(shotgun.apply_to(player) and _last_ammo == Vector2i(3, 40), "霰弹枪同样补满备弹，弹匣保持 3 发")
	smg.free()
	shotgun.free()
	# 实际木箱掉落流程覆盖随机武器种类，验证调用方也使用统一数量。
	seed(20261009)
	var found_smg := false
	var found_shotgun := false
	for draw: int in range(100):
		var crate := load("res://Prefab/Terrain/box_crate.tscn").instantiate() as TerrainBoxCrate
		crate.loot_drop_probability = 1.0
		world.add_child(crate)
		crate._try_drop_loot()
		for child: Node in world.get_children():
			if child is LootItem:
				if child.type == LootItem.Type.WeaponSMG:
					found_smg = true
					_check(child.num == 1, "木箱 SMG 掉落一份备弹补满物品")
				elif child.type == LootItem.Type.WeaponShortgun:
					found_shotgun = true
					_check(child.num == 1, "木箱霰弹枪掉落一份备弹补满物品")
				child.free()
		crate.free()
	_check(found_smg and found_shotgun, "实际木箱流程覆盖两种武器")
	# 直接调用正式房间填充流程，避免只验证共享函数却遗漏生成器调用点。
	var found_room_smg := false
	for room_seed: int in range(40):
		var room := FortressRoomTemplate.new()
		room.population_seed = room_seed + 1
		room.populate_on_first_entry = false
		var content := Node2D.new()
		room.add_child(content)
		room._populate_room(content)
		for child: Node in content.get_children():
			if child is LootItem and child.type == LootItem.Type.WeaponSMG:
				found_room_smg = true
				_check(child.num == 1, "真实房间生成一份 SMG 备弹补满物品")
		room.free()
	_check(found_room_smg, "房间补给流程覆盖 SMG")
	world.queue_free()
	await get_tree().process_frame
	print("WEAPON_PICKUP_AMMO_TEST checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## 输出每个失败条件并累计测试退出状态。
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)

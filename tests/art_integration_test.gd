## 军事街机美术运行检查：加载正式预制体，验证八方向边界、阶段切换与效果资源。
## 执行：Godot --headless --path . res://tests/art_integration_test.tscn
extends Node

var _checks: int = 0
var _failures: int = 0


## 自动加载完成后再创建战斗实例，确保 PrefabManager 等依赖已就绪。
func _ready() -> void:
	_run_tests.call_deferred()


## 使用正式场景检查资源与运行行为；目标为无战斗逻辑节点，不读取或修改通关存档。
func _run_tests() -> void:
	var boss := load("res://Prefab/BossGeneral/boss_general.tscn").instantiate() as BossGeneral
	get_tree().root.add_child(boss)
	boss.set_physics_process(false)
	var target := Node2D.new()
	target.add_to_group("player")
	get_tree().root.add_child(target)
	var sprite := boss.body_sprite
	_check(sprite.texture.get_size() == Vector2(192, 768), "首领图集完整加载")
	_check(sprite.hframes == 2 and sprite.vframes == 8, "首领图集两阶段八方向")

	# 每个阶段检查八方向中心角以及所有扇区边界两侧，覆盖负角度与 0/360 度环绕。
	var rows: Array[int] = [1, 7, 0, 6, 3, 5, 2, 4]
	for phase: int in [BossGeneral.Phase.FIRST, BossGeneral.Phase.SECOND]:
		boss.current_phase = phase
		for sector: int in range(8):
			for offset: float in [-22.4, 0.0, 22.4]:
				var direction := Vector2.from_angle(deg_to_rad(sector * 45.0 + offset))
				target.global_position = boss.global_position + direction * 10.0
				# 近距离使首领保持静止，验证休息/站立时仍然跟随玩家转向。
				boss._physics_process(0.016)
				_check(boss._facing_row == rows[sector], "首领角度边界选择正确")
				_check(sprite.frame % 2 == phase - 1, "图像武器与战斗阶段一致")
				var expected_row := rows[sector]
				var mirrored := false
				if phase == BossGeneral.Phase.FIRST and expected_row == 4:
					expected_row = 5
					mirrored = true
				if phase == BossGeneral.Phase.SECOND and rows[sector] in [3, 5, 6]:
					expected_row = 1 if rows[sector] == 3 else (4 if rows[sector] == 5 else 7)
					mirrored = true
				_check(int(sprite.frame / 2) == expected_row and sprite.flip_h == mirrored, "首领原图枪口修正生效")
		var previous_frame := sprite.frame
		boss._update_facing(Vector2.ZERO)
		_check(sprite.frame == previous_frame, "目标重合时保持朝向")

	# 通过真实生命组件耗尽第一阶段，检查换枪立即发生，生命重置为第二阶段配置。
	boss.current_phase = BossGeneral.Phase.FIRST
	boss._apply_phase_settings(true)
	boss._update_facing(Vector2.LEFT)
	boss.health_component.damage(boss.health_component.health)
	_check(boss.current_phase == BossGeneral.Phase.SECOND, "真实伤害触发第二阶段")
	_check(sprite.frame == 3 and sprite.flip_h, "阶段切换立即显示朝左冲锋枪")
	_check(boss.health_component.health == boss.phase_two_health, "阶段生命规则保留")

	var soldier := load("res://Prefab/EnemySoilder/enemy_soilder.tscn").instantiate() as EnemySoilder
	get_tree().root.add_child(soldier)
	soldier.set_physics_process(false)
	var names: Array[String] = ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
	for sector: int in range(8):
		for moving: bool in [false, true]:
			soldier.velocity = Vector2.RIGHT * (10.0 if moving else 0.0)
			soldier._update_animation(Vector2.from_angle(sector * PI / 4.0))
			var expected := ("move_" if moving else "idle_") + names[sector]
			_check(soldier.animated_sprite.animation == expected, "敌人八方向站立与行走有效")
			var texture := soldier.animated_sprite.sprite_frames.get_frame_texture(expected, 0) as AtlasTexture
			_check(texture.atlas.resource_path.ends_with("World/enemy_atlas.png"), "敌人动画引用新图集")
			_check(texture.region.position.y == rows[sector] * 80, "敌人图集行与朝向一致")
	_check(soldier.animated_sprite.modulate == soldier.uniform_color, "敌人模式制服染色保留")

	# 效果使用正式场景，确认四帧动画、采样和伤害区域可同时初始化。
	var explosion := load("res://Prefab/explosion/explosion.tscn").instantiate() as ProjectileExplosion
	get_tree().root.add_child(explosion)
	_check(explosion.node_animation.sprite_frames.get_frame_count("default") == 4, "爆炸四帧加载")
	var burning := load("res://Prefab/burning/burning.tscn").instantiate() as BurningEffect
	get_tree().root.add_child(burning)
	var fire := burning.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(fire.is_playing() and fire.sprite_frames.get_frame_count("default") == 4, "燃烧四帧循环运行")
	for theme_name: String in ["Fortress", "Jungle", "Village", "Valley", "Metropolis", "UndergroundFortress", "MineShaft"]:
		var theme := load("res://Scene/Level%s/theme.tres" % theme_name) as BattlefieldTheme
		_check(theme != null and theme.ground_texture.resource_path.contains("World/Terrain/" + theme_name), "主题地形加载")
		_check(theme.entrance_texture.resource_path.ends_with("World/entrance.png"), "主题出口加载")

	# 旧场景可能仍带图集裁切，替换成独立飞行图片后必须完整显示，并保持伤害参数。
	for kind: int in [Definition.BulletType.Bullet, Definition.BulletType.Explosion, Definition.BulletType.Burning]:
		var bullet := load("res://Prefab/bullet/bullet.tscn").instantiate() as ProjectileBullet
		bullet.bullet_from = Definition.Faction.Enemy
		bullet.bullet_type = kind
		bullet.bullet_direction = Vector2.UP
		bullet.bullet_damage = 7
		bullet.get_node("Sprite2D").region_enabled = true
		get_tree().root.add_child(bullet)
		bullet.set_physics_process(false)
		var expected_path := "enemy_bullet_round" if kind == Definition.BulletType.Bullet else ("grenade_flight" if kind == Definition.BulletType.Explosion else "molotov_flight")
		_check(bullet.node_sprite.texture.resource_path.ends_with("World/" + expected_path + ".png"), "弹丸飞行图片按类型加载")
		_check(not bullet.node_sprite.region_enabled and bullet.bullet_damage == 7, "替换贴图取消旧裁切且不改变伤害")
		if kind == Definition.BulletType.Bullet:
			_check(bullet.node_sprite.texture.get_size() == Vector2(64, 64), "普通弹采用圆形图片的正方形画布")
		bullet.queue_free()

	# 释放所有测试节点，等待异步伤害循环与实例清理，不污染后续测试。
	for node: Node in [target, boss, soldier, explosion, burning]:
		node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("[art_integration_test] checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


## 汇总失败，返回非零退出码，使资源路径或方向回归可直接定位。
func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[art_integration_test] " + description)

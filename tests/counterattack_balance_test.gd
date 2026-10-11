## 模式平衡集成回归：参数覆盖、错误回滚、真实敌人/Boss 阶段与稳定模式 ID。
extends Node
var _checks := 0
var _failures := 0
var _world: Node2D

## 自动加载完成后执行，保存并恢复运行时配置，测试不会写入用户参数文件。
func _ready() -> void:
	_run.call_deferred()

## 验证默认倍率、外部配置以及各敌军生命初始化入口。
func _run() -> void:
	var original: CombatBalanceConfig = BattleBalance.config
	# 指定参数文件时额外验证常驻服务确实在启动阶段读取了外部覆盖。
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(BattleBalance.CLI_CONFIG_PREFIX):
			var supplied := ConfigFile.new()
			supplied.load(argument.trim_prefix(BattleBalance.CLI_CONFIG_PREFIX))
			_check(original.base_enemy_damage_multiplier == supplied.get_value("base", "enemy_damage_multiplier"), "命令行文件覆盖基础倍率")
			_check(original.get_profile(RogueRunManager.AttackMode.COUNTERATTACK).enemy_health_multiplier == supplied.get_value("counterattack", "enemy_health_multiplier"), "命令行文件覆盖模式生命")
			_check(original.get_profile(RogueRunManager.AttackMode.COUNTERATTACK).enemy_damage_multiplier == supplied.get_value("counterattack", "enemy_damage_multiplier"), "命令行文件覆盖模式伤害")
	BattleBalance.config = BattleBalance.DEFAULT_CONFIG.duplicate(true)
	_check(BattleBalance.config.is_valid(), "默认资源参数完整有效")
	_check(RogueRunManager.AttackMode.COUNTERATTACK == RogueRunManager.AttackMode.FULL_ASSAULT, "旧模式编号仍然兼容")
	_check(GameManager.get_mode_name(RogueRunManager.AttackMode.COUNTERATTACK) == "反击模式", "管理器显示现行名称")
	BattleBalance.configure_mode(RogueRunManager.AttackMode.AIRBORNE)
	_check(BattleBalance.scale_enemy_health(9) == 9 and BattleBalance.scale_enemy_damage(3) == 6, "空降维持既有基础生命和伤害")
	BattleBalance.configure_mode(RogueRunManager.AttackMode.COUNTERATTACK)
	_check(BattleBalance.scale_enemy_health(9) == 18 and BattleBalance.scale_enemy_damage(3) == 12, "反击相对当前基础生命伤害均为百分之二百")
	var health := HealthComponent.new()
	add_child(health)
	health.reset_enemy_health(9)
	health.reset_enemy_health(9)
	_check(health.health_max == 18, "重复初始化从基础值计算，不二次叠乘")
	health.health = 100
	_check(health.damage(3, Definition.Faction.Enemy) == 12, "敌军倍率在实际伤害入口生效一次")
	_check(health.damage(3, Definition.Faction.Player) == 3 and health.damage(3, Definition.Faction.Friend) == 3, "玩家及佣兵攻击保持原值")
	_world = Node2D.new()
	add_child(_world)
	var soldier := preload("res://Prefab/EnemySoilder/enemy_soilder.tscn").instantiate() as EnemySoilder
	_world.add_child(soldier)
	soldier.set_physics_process(false)
	_check(soldier.health_component.health_max == soldier.health * 2, "真实普通士兵生命翻倍")
	var boss_specs := [
		["res://Prefab/BossGeneral/boss_general.tscn", ["phase_one_health", "phase_two_health"]],
		["res://Prefab/BossTank/boss_tank.tscn", ["tank_health", "overload_health", "driver_health"]],
		["res://Prefab/BossSquad/Sniper.tscn", ["first_health", "second_health"]],
		["res://Prefab/BossExpedition/Canal.tscn", ["first_health", "second_health", "third_health"]]
	]
	for spec: Array in boss_specs:
		var boss: BattlefieldBoss = load(spec[0]).instantiate()
		_world.add_child(boss)
		boss.set_physics_process(false)
		var phase_snapshot := Vector2i.ZERO
		var events: Array[Vector2i] = []
		boss.sig_phase_changed.connect(func(_phase: int, current: int, maximum: int): events.append(Vector2i(current, maximum)))
		for index: int in range(spec[1].size()):
			if index > 0:
				boss._on_phase_depleted()
			var expected := int(boss.get(spec[1][index])) * 2
			_check(boss.health_component.health_max == expected and boss.health_component.health == expected, "%s 第 %d 阶段生命翻倍" % [boss.name, index + 1])
			if index > 0 and not events.is_empty():
				phase_snapshot = events.back()
				_check(phase_snapshot == Vector2i(expected, expected), "阶段信号与真实缩放生命一致")
		boss.free()
	var companion := ExpeditionCompanion.new()
	companion.role = 0
	companion.art = preload("res://Assets/Art/MilitaryArcade/Expedition/Canal/companion.png")
	_world.add_child(companion)
	companion.set_physics_process(false)
	_check(companion._health.health_max == 140, "首领召唤敌军同样翻倍")
	var player := preload("res://Prefab/Player/player.tscn").instantiate() as Player
	_world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	_check(player.health_max == 100, "模式倍率不会误改玩家生命")
	var merc := preload("res://Prefab/Mercenary/mercenary.tscn").instantiate() as HiredMercenary
	_world.add_child(merc)
	merc.set_physics_process(false)
	_check(merc.health_component.health_max == merc.initial_health, "模式倍率不会误改佣兵生命")
	# 外部文件覆盖小数系数，未配置字段继承资源值，错误参数整份回滚。
	var path := "/private/tmp/gv-counterattack-override.cfg"
	var file := ConfigFile.new()
	file.set_value("base", "enemy_damage_multiplier", 3.0)
	file.set_value("counterattack", "enemy_health_multiplier", 1.5)
	file.set_value("counterattack", "enemy_damage_multiplier", 1.25)
	file.save(path)
	_check(BattleBalance.config.load_overrides(path) == OK, "外部 CFG 能覆盖独立模式倍率")
	_check(BattleBalance.scale_enemy_health(9) == 18, "已开始的对局参数快照不受配置后续编辑影响")
	BattleBalance.configure_mode(RogueRunManager.AttackMode.COUNTERATTACK)
	_check(BattleBalance.scale_enemy_health(9) == 14 and BattleBalance.scale_enemy_damage(2) == 8, "新局读取小数配置并统一向上取整")
	file.set_value("counterattack", "enemy_health_multiplier", -1.0)
	file.save(path)
	_check(BattleBalance.config.load_overrides(path) == ERR_INVALID_DATA and BattleBalance.config.get_profile(RogueRunManager.AttackMode.COUNTERATTACK).enemy_health_multiplier == 1.5, "非法覆盖不部分提交")
	_check(not BattleBalance.configure_mode(99), "未知模式不能启动规则")
	BattleBalance.config = original
	GameManager.reset_run()
	_check(BattleBalance.scale_enemy_health(9) == 9, "回首页恢复基础模式，不污染下一局")
	health.free()
	_world.queue_free()
	await get_tree().process_frame
	print("COUNTERATTACK_BALANCE_TEST checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(1 if _failures else 0)

## 输出所有失败并累计退出状态，便于定位具体模式与阶段。
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)

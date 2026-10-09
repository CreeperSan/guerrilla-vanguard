## 管理一局中的通用玩家、HUD、摄像机、伤害反馈和敌人状态。
class_name LevelController
extends Node2D

## 玩家、HUD 与跟随摄像机由具体关卡场景通过节点路径指定。
@export_group("关卡组件")
@export_node_path("Node2D") var player_path: NodePath
@export_node_path("CanvasLayer") var hud_path: NodePath
@export_node_path("Camera2D") var camera_path: NodePath

@export_group("货币掉落")
## 两类货币独立判定，可同时掉落；数量区间包含端点，支持 Inspector 调整。
@export_range(0.0, 1.0, 0.01) var money_drop_chance: float = 0.65
@export var money_drop_amount: Vector2i = Vector2i(4, 12)
@export_range(0.0, 1.0, 0.01) var research_drop_chance: float = 0.18
@export var research_drop_amount: Vector2i = Vector2i(1, 3)
## Boss 只有最终阶段死亡才直接入账，无需在地面拾取。
@export var boss_research_amount: Vector2i = Vector2i(10, 20)

## 当前关卡累计分数；普通敌人 100 分，Boss 500 分。
var total_score: int = 0
## 由子类和外部关卡脚本访问的玩家、HUD、相机引用。
var controlled_player: Node2D
var controlled_hud: GameHUD
var controlled_camera: FollowCamera

var _registered_enemy_ids: Dictionary = {}


## 解析关卡组件、连接 HUD 信号，并注册场景中已存在的敌人。
func _ready() -> void:
	# 只在创建新宿主时重置局内货币，同一宿主内切换关卡时保留钱包。
	CurrencyManager.begin_run()
	controlled_player = get_node_or_null(player_path) as Node2D if not player_path.is_empty() else null
	controlled_hud = get_node_or_null(hud_path) as GameHUD if not hud_path.is_empty() else null
	controlled_camera = get_node_or_null(camera_path) as FollowCamera if not camera_path.is_empty() else null

	if controlled_player == null:
		push_warning("关卡没有配置有效的玩家节点路径。")
	if controlled_hud == null:
		push_warning("关卡没有配置有效的 HUD 节点路径。")
	if controlled_camera != null and controlled_player != null:
		controlled_camera.set_target(controlled_player, true)

	_bind_player_state()
	if controlled_hud != null:
		controlled_hud.set_score(total_score)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		register_enemy(enemy as Node2D)


## 连接玩家生命、装备、技能和武器状态，并将当前值立即同步到 HUD。
func _bind_player_state() -> void:
	if controlled_player == null or controlled_hud == null:
		return
	var player := controlled_player as Player
	if player == null:
		push_warning("玩家节点未挂载 Player 脚本，HUD 状态无法绑定。")
		return

	controlled_hud.set_enemy_hint_player(player)
	player.sig_health_updated.connect(controlled_hud.set_health)
	player.sig_stamina_updated.connect(controlled_hud.set_stamina)
	player.sig_equipment_updated.connect(controlled_hud.set_equipment)
	player.sig_battle_support_updated.connect(controlled_hud.set_battle_support)
	player.sig_skill_updated.connect(controlled_hud.set_skill)
	controlled_hud.set_health(player.health_current, player.health_max)
	controlled_hud.set_stamina(player.stamina, player.stamina_max)
	controlled_hud.set_equipment(player.equipment_type, player.equipment_amount, player.shield_active)
	controlled_hud.set_battle_support(player.battle_support_type)
	controlled_hud.set_skill(player.skill_type, 0.0, 0.3, false)

	var player_health := player.get_node_or_null("Health") as HealthComponent
	if player_health != null:
		player_health.sig_health_change.connect(_on_target_health_change.bind(player, Definition.Faction.Player))
		player_health.sig_die.connect(_on_player_died)

	var weapon_manager := player.get_node_or_null("WeaponManager") as PlayerWeaponManager
	if weapon_manager == null:
		push_warning("玩家缺少 PlayerWeaponManager，武器 HUD 无法绑定。")
		return
	weapon_manager.sig_active_weapon_change.connect(controlled_hud.set_weapon)
	weapon_manager.sig_weapon_change.connect(controlled_hud.set_weapon_slots)
	weapon_manager.sig_switch_progress.connect(controlled_hud.set_switch_progress)
	weapon_manager.sig_active_ammo_change.connect(controlled_hud.set_ammo)
	weapon_manager.sig_active_reload.connect(controlled_hud.set_reload_progress)
	if weapon_manager.active_slot != null:
		controlled_hud.set_weapon(weapon_manager.active_slot)
		controlled_hud.set_weapon_slots(weapon_manager.active_slot, weapon_manager.get_secondary_slot())
		controlled_hud.set_ammo(weapon_manager.active_slot.ammo_magazine_cur, weapon_manager.active_slot.ammo_back_cur)
		controlled_hud.set_reload_progress(1.0)
	controlled_hud.set_switch_progress(1.0)


## 注册敌人生命反馈；Boss 使用阶段信号驱动血条，普通敌人死亡后计分。
func register_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or _registered_enemy_ids.has(enemy.get_instance_id()):
		return
	var enemy_health := enemy.get_node_or_null("Health") as HealthComponent
	if enemy_health == null:
		return
	_registered_enemy_ids[enemy.get_instance_id()] = true
	enemy_health.sig_health_change.connect(_on_target_health_change.bind(enemy, Definition.Faction.Enemy))

	var boss := enemy as BattlefieldBoss
	if boss != null:
		enemy_health.sig_health_updated.connect(_on_boss_health_updated)
		boss.sig_phase_changed.connect(_on_boss_phase_changed)
		boss.sig_defeated.connect(_on_registered_boss_defeated.bind(boss))
		if controlled_hud != null:
			controlled_hud.show_boss_health(boss.boss_display_name, enemy_health.health, enemy_health.health_max, boss.current_phase)
	else:
		enemy_health.sig_die.connect(_on_enemy_died.bind(enemy))


## 为受到伤害的目标创建伤害飘字；治疗不会显示伤害数字。
func _on_target_health_change(health_change: int, target: Node2D, faction: Definition.Faction) -> void:
	if health_change >= 0 or not is_instance_valid(target):
		return
	var damage_pop: DamagePop = PrefabManager.create_damage_pop(-health_change, faction)
	if damage_pop == null:
		return
	add_child(damage_pop)
	damage_pop.global_position = target.global_position


## 普通敌人死亡时增加积分，并同步 HUD。
func _on_enemy_died(enemy: Node2D) -> void:
	var enemy_health := enemy.get_node_or_null("Health") as HealthComponent if is_instance_valid(enemy) else null
	# 佣兵击杀仍走普通敌人的掉落逻辑，但不给玩家或佣兵增加击杀积分。
	if enemy_health == null or enemy_health.last_damage_faction != Definition.Faction.Friend:
		total_score += 100
		if controlled_hud != null:
			controlled_hud.set_score(total_score)
	if not is_instance_valid(enemy):
		return
	# 在敌人所属房间生成，使隐藏房间和切关清理规则同样作用于掉落物。
	var parent := enemy.get_parent()
	var death_position := enemy.global_position
	if randf() < money_drop_chance:
		_spawn_currency_drop.call_deferred(parent, death_position + Vector2(-8, 0), RunCurrencyWallet.Kind.MONEY, _roll_currency_amount(money_drop_amount))
	if randf() < research_drop_chance:
		_spawn_currency_drop.call_deferred(parent, death_position + Vector2(8, 0), RunCurrencyWallet.Kind.RESEARCH, _roll_currency_amount(research_drop_amount))


## 将区间规范为非负升序；0 数量不生成掉落物，便于关闭特定奖励。
func _roll_currency_amount(amount_range: Vector2i) -> int:
	return randi_range(maxi(0, mini(amount_range.x, amount_range.y)), maxi(0, maxi(amount_range.x, amount_range.y)))


## 物理回调结束后加入 Area2D，避免碰撞查询期间修改物理空间。
func _spawn_currency_drop(parent: Node, drop_position: Vector2, kind: RunCurrencyWallet.Kind, amount: int) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var pickup := PrefabManager.create_currency(kind, amount)
	if pickup == null:
		return
	parent.add_child(pickup)
	pickup.global_position = drop_position


## 玩家死亡时冻结游戏并显示本局积分。
func _on_player_died() -> void:
	# 战败也带出已经获得的研究点数；未拾取的地面货币不计入收益。
	CurrencyManager.settle_run()
	if controlled_hud != null:
		controlled_hud.show_defeat(total_score)


## Boss 最终死亡时增加积分并隐藏 Boss 血条。
func _on_registered_boss_defeated(boss: BattlefieldBoss) -> void:
	var boss_health := boss.get_node_or_null("Health") as HealthComponent if is_instance_valid(boss) else null
	# 佣兵可以完成 Boss 战并保留研究奖励，但其击杀不增加计分。
	if boss_health == null or boss_health.last_damage_faction != Definition.Faction.Friend:
		total_score += 500
	if CurrencyManager.credit(RunCurrencyWallet.Kind.RESEARCH, _roll_currency_amount(boss_research_amount)):
		var player := controlled_player as Player
		if player != null:
			player.play_currency_pickup_sound(RunCurrencyWallet.Kind.RESEARCH)
	if controlled_hud != null:
		controlled_hud.set_score(total_score)
		controlled_hud.hide_boss_health()


## 佣兵只显示友军伤害飘字，不注册为敌人以免计分或阻止房间清场。
func register_hired_mercenary(mercenary: Node2D) -> void:
	if not is_instance_valid(mercenary):
		return
	var health := mercenary.get_node_or_null("Health") as HealthComponent
	if health == null:
		return
	health.sig_health_change.connect(_on_target_health_change.bind(mercenary, Definition.Faction.Friend))


## 将 Boss 当前生命值变化同步到魂类风格血条。
func _on_boss_health_updated(current_health: int, max_health: int) -> void:
	if controlled_hud != null:
		controlled_hud.set_boss_health(current_health, max_health)


## Boss 阶段变化时同时更新血条标题、上限和当前生命值。
func _on_boss_phase_changed(phase: int, current_health: int, max_health: int) -> void:
	if controlled_hud != null:
		controlled_hud.set_boss_phase(phase, current_health, max_health)

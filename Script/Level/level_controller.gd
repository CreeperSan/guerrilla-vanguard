## 管理一局中的通用玩家、HUD、摄像机、伤害反馈和敌人状态。
class_name LevelController
extends Node2D

## 玩家、HUD 与跟随摄像机由具体关卡场景通过节点路径指定。
@export_group("关卡组件")
@export_node_path("Node2D") var player_path: NodePath
@export_node_path("CanvasLayer") var hud_path: NodePath
@export_node_path("Camera2D") var camera_path: NodePath

## 当前关卡累计分数；普通敌人 100 分，Boss 500 分。
var total_score: int = 0
## 由子类和外部关卡脚本访问的玩家、HUD、相机引用。
var controlled_player: Node2D
var controlled_hud: GameHUD
var controlled_camera: FollowCamera

var _registered_enemy_ids: Dictionary = {}


## 解析关卡组件、连接 HUD 信号，并注册场景中已存在的敌人。
func _ready() -> void:
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

	player.sig_health_updated.connect(controlled_hud.set_health)
	player.sig_equipment_updated.connect(controlled_hud.set_equipment)
	player.sig_battle_support_updated.connect(controlled_hud.set_battle_support)
	player.sig_skill_updated.connect(controlled_hud.set_skill)
	controlled_hud.set_health(player.health_current, player.health_max)
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

	var boss := enemy as BossGeneral
	if boss != null:
		enemy_health.sig_health_updated.connect(_on_boss_health_updated)
		boss.sig_phase_changed.connect(_on_boss_phase_changed)
		boss.sig_defeated.connect(_on_registered_boss_defeated)
		if controlled_hud != null:
			controlled_hud.show_boss_health("GENERAL", enemy_health.health, enemy_health.health_max, boss.current_phase)
	else:
		enemy_health.sig_die.connect(_on_enemy_died)


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
func _on_enemy_died() -> void:
	total_score += 100
	if controlled_hud != null:
		controlled_hud.set_score(total_score)


## 玩家死亡时冻结游戏并显示本局积分。
func _on_player_died() -> void:
	if controlled_hud != null:
		controlled_hud.show_defeat(total_score)


## Boss 最终死亡时增加积分并隐藏 Boss 血条。
func _on_registered_boss_defeated() -> void:
	total_score += 500
	if controlled_hud != null:
		controlled_hud.set_score(total_score)
		controlled_hud.hide_boss_health()


## 将 Boss 当前生命值变化同步到魂类风格血条。
func _on_boss_health_updated(current_health: int, max_health: int) -> void:
	if controlled_hud != null:
		controlled_hud.set_boss_health(current_health, max_health)


## Boss 阶段变化时同时更新血条标题、上限和当前生命值。
func _on_boss_phase_changed(phase: int, current_health: int, max_health: int) -> void:
	if controlled_hud != null:
		controlled_hud.set_boss_phase(phase, current_health, max_health)

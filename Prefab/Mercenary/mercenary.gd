## 雇佣佣兵：继承普通士兵的动画与受击表现，使用独立盟友 AI 和无限手枪弹药。
class_name HiredMercenary
extends EnemySoilder

signal sig_permanently_died

const FOLLOW_DISTANCE_MIN := 48.0
const FOLLOW_DISTANCE_MAX := 112.0
## 常规跟随比玩家略快；远距离追赶支持玩家冲刺，瞬移只用于持续脱队的兜底。
const FOLLOW_MOVE_SPEED := 180.0
const CATCH_UP_MULTIPLIER := 1.35
const TELEPORT_DISTANCE := 720.0
const TELEPORT_DELAY := 1.5
## 进入最低安全距离时后撤，在缓冲距离内避免继续朝敌人靠近。
const ENEMY_MIN_DISTANCE := 96.0
const ENEMY_COMFORT_DISTANCE := 144.0
const TARGET_RANGE := 360.0
const PISTOL_DAMAGE := 3
const PISTOL_MAGAZINE_SIZE := 6
const PISTOL_RELOAD_DURATION := 1.1
const PISTOL_FIRE_INTERVAL := 0.32
const PISTOL_BULLET_SPEED := 420.0
const PISTOL_BULLET_RANGE := 480.0
const DEPARTURE_DURATION := 0.65
const HIRE_COST := 80

## 雇佣房预览实例关闭此开关；签约后才加入战斗目标并可受到伤害。
@export var starts_hired: bool = true
## 佣兵属性固定为 120 生命、每发 3 点伤害和六发弹匣；换弹不消耗备弹。
var faction: Definition.Faction = Definition.Faction.Friend
var _is_hired: bool = false
var _pistol_ammo: int = PISTOL_MAGAZINE_SIZE
var _pistol_fire_cooldown: float = 0.0
var _pistol_reload_remaining: float = 0.0
var _wander_remaining: float = 0.0
var _follow_offset: Vector2
var _far_from_player_remaining: float = 0.0
var _departing: bool = false
var _departure_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var _health_bar: ProgressBar = $HealthBar


## 沿用士兵动画、碰撞和生命组件初始化，并将自身标记为友军目标而非敌人或拾取者。
func _ready() -> void:
	health = 120
	weapon_damage = PISTOL_DAMAGE
	magazine_size = PISTOL_MAGAZINE_SIZE
	uniform_color = Color(0.72, 0.96, 0.61, 1.0)
	super._ready()
	remove_from_group("enemies")
	_is_hired = starts_hired
	if _is_hired:
		add_to_group("hired_mercenaries")
		add_to_group("combat_targets")
	else:
		# 未签约角色是安全的场景展示对象，不被流弹误伤或被敌人选作目标。
		collision_layer = 0
		var preview_hurt_box := get_node_or_null("HurtBox") as Area2D
		if preview_hurt_box != null:
			preview_hurt_box.monitorable = false
	_rng.randomize()
	_choose_follow_point()
	_pistol_ammo = PISTOL_MAGAZINE_SIZE
	health_component.health_max = 120
	health_component.health = 120
	health_component.sig_health_updated.connect(_update_health_bar)
	health_component.sig_die.connect(_on_mercenary_die)
	_update_health_bar(health_component.health, health_component.health_max)


## 佣兵围绕玩家跟随游走，同时优先射击当前房间内最近的存活敌人。
func _physics_process(delta: float) -> void:
	if not _is_hired:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.DOWN)
		return
	if _departing:
		_process_departure(delta)
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var player_distance := global_position.distance_to(player.global_position)
	_far_from_player_remaining = _far_from_player_remaining + delta if player_distance > TELEPORT_DISTANCE else 0.0
	if _far_from_player_remaining >= TELEPORT_DELAY:
		global_position = player.global_position + Vector2(-24.0, 18.0)
		_far_from_player_remaining = 0.0
		_wander_remaining = 0.0
		player_distance = global_position.distance_to(player.global_position)

	var target := _find_nearest_enemy()
	var follow_target := _get_follow_target(player, delta)
	var move_direction := _get_safe_follow_direction(player, target, follow_target)
	velocity = move_direction * _get_follow_speed(player, player_distance)
	move_and_slide()
	_update_animation(target.global_position - global_position if is_instance_valid(target) else move_direction)
	_update_pistol(delta, target)


## 以玩家实际移速调整跟随速度；落后时加速追赶，避免冲刺让佣兵长期掉队。
func _get_follow_speed(player: Node2D, player_distance: float) -> float:
	var player_speed := 0.0
	if player is Player:
		player_speed = maxf(player.prop_move_speed, player.velocity.length())
	var follow_speed := maxf(maxf(move_speed, FOLLOW_MOVE_SPEED), player_speed * 1.15)
	return follow_speed * CATCH_UP_MULTIPLIER if player_distance > FOLLOW_DISTANCE_MAX + 40.0 else follow_speed


## 跟随与避敌共用移动入口：过近先后撤，缓冲区内移除朝敌人的移动分量。
func _get_safe_follow_direction(player: Node2D, target: Node2D, follow_target: Vector2) -> Vector2:
	var difference := follow_target - global_position
	var direction := difference.normalized() if difference.length() > 18.0 else Vector2.ZERO
	if global_position.distance_to(player.global_position) > FOLLOW_DISTANCE_MAX + 40.0:
		direction = global_position.direction_to(player.global_position)
	if not is_instance_valid(target):
		return direction
	var away := global_position - target.global_position
	var enemy_distance := away.length()
	if enemy_distance >= ENEMY_COMFORT_DISTANCE:
		return direction
	# 重合时也给出确定的后撤方向，避免归一化零向量后留在敌人身上。
	if away.is_zero_approx():
		away = global_position - player.global_position
		if away.is_zero_approx():
			away = Vector2.RIGHT
	away = away.normalized()
	if enemy_distance < ENEMY_MIN_DISTANCE:
		return away
	var inward_speed := minf(direction.dot(away), 0.0)
	direction -= away * inward_speed
	if direction.is_zero_approx() and inward_speed < 0.0:
		# 敌人挡在跟随路线中时沿其侧面绕行，避免停在原地等到脱队瞬移。
		var tangent := Vector2(-away.y, away.x)
		if tangent.dot(follow_target - global_position) < 0.0:
			tangent = -tangent
		direction = tangent
	return direction.limit_length(1.0)


## 生命变化即同步头顶血条；未雇佣的展示角色和离场佣兵不显示战斗 UI。
func _update_health_bar(current_health: int, max_health: int) -> void:
	_health_bar.max_value = maxi(max_health, 1)
	_health_bar.value = current_health
	_health_bar.visible = _is_hired and not _departing and current_health > 0


## 从当前已加载敌群里挑选最近目标；不把同伴或玩家列入射击对象。
func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D
	var nearest_distance := TARGET_RANGE * TARGET_RANGE
	for candidate: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		var enemy_health := enemy.get_node_or_null("Health") as HealthComponent if enemy != null else null
		if enemy == null or enemy_health == null or enemy_health.health <= 0 or enemy.is_queued_for_deletion():
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


## 每隔一段时间在玩家身边抽取新位置，距离过远时直接优先靠近玩家。
func _get_follow_target(player: Node2D, delta: float) -> Vector2:
	_wander_remaining -= delta
	if _wander_remaining <= 0.0 or global_position.distance_to(player.global_position + _follow_offset) < 14.0:
		_choose_follow_point()
	return player.global_position + _follow_offset


## 以玩家为中心储存相对点位，令佣兵跟随时保持在近距离活动。
func _choose_follow_point() -> void:
	_wander_remaining = _rng.randf_range(0.8, 1.5)
	_follow_offset = Vector2.from_angle(_rng.randf_range(-PI, PI)) * _rng.randf_range(FOLLOW_DISTANCE_MIN, FOLLOW_DISTANCE_MAX)


## 玩家完成付款后将房间里的预览角色激活为正式盟友。
func activate_for_hire() -> void:
	if _is_hired:
		return
	_is_hired = true
	starts_hired = true
	collision_layer = 1
	add_to_group("hired_mercenaries")
	add_to_group("combat_targets")
	var preview_hurt_box := get_node_or_null("HurtBox") as Area2D
	if preview_hurt_box != null:
		preview_hurt_box.set_deferred("monitorable", true)
	_choose_follow_point()
	# 直接招募的新实例可能尚未入树，生命组件与血条会在 _ready 中统一初始化。
	if is_node_ready():
		_update_health_bar(health_component.health, health_component.health_max)


## 六发打完后固定时间换弹；弹药状态只循环弹匣，不存在耗尽条件。
func _update_pistol(delta: float, target: Node2D) -> void:
	_pistol_fire_cooldown = maxf(_pistol_fire_cooldown - delta, 0.0)
	if _pistol_reload_remaining > 0.0:
		_pistol_reload_remaining = maxf(_pistol_reload_remaining - delta, 0.0)
		if _pistol_reload_remaining <= 0.0:
			_pistol_ammo = PISTOL_MAGAZINE_SIZE
		return
	if not is_instance_valid(target) or _pistol_fire_cooldown > 0.0:
		return
	var direction := global_position.direction_to(target.global_position)
	var bullet := PrefabManager.create_bullet(Definition.Faction.Friend, PISTOL_DAMAGE, direction)
	if bullet == null:
		return
	bullet.bullet_speed = PISTOL_BULLET_SPEED
	bullet.bullet_range = PISTOL_BULLET_RANGE
	bullet.collision_layer = 4
	bullet.collision_mask = 3
	get_parent().add_child(bullet)
	bullet.global_position = global_position + direction * 9.0
	_pistol_ammo -= 1
	_pistol_fire_cooldown = PISTOL_FIRE_INTERVAL
	if _pistol_ammo <= 0:
		_pistol_reload_remaining = PISTOL_RELOAD_DURATION


## 被再次雇佣时旧佣兵停止战斗并短暂离开画面，然后销毁自身。
func depart_and_remove() -> void:
	if _departing or not is_inside_tree():
		return
	_departing = true
	_health_bar.hide()
	_departure_remaining = DEPARTURE_DURATION
	collision_layer = 0
	remove_from_group("hired_mercenaries")
	remove_from_group("combat_targets")
	var hurt_box := get_node_or_null("HurtBox") as Area2D
	if hurt_box != null:
		hurt_box.set_deferred("monitorable", false)
		hurt_box.set_deferred("monitoring", false)


## 离场时向玩家反方向移动，计时结束后释放实例，不产生击杀或掉落。
func _process_departure(delta: float) -> void:
	_departure_remaining = maxf(_departure_remaining - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		velocity = global_position.direction_to(player.global_position) * -90.0
		move_and_slide()
	if _departure_remaining <= 0.0:
		queue_free()


## 生命归零后立即离开战斗目标分组；佣兵不会复活、计分或掉落战利品。
func _on_mercenary_die() -> void:
	remove_from_group("hired_mercenaries")
	remove_from_group("combat_targets")
	sig_permanently_died.emit()
	queue_free()

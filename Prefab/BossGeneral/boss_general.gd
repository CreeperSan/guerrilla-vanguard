## General Boss：锁定玩家开火，并按阶段切换生命值、武器和分段追击参数。
class_name BossGeneral
extends CharacterBody2D

## Boss 的两个战斗阶段；第二阶段在第一阶段生命耗尽时立即开始。
enum Phase {
	FIRST = 1,
	SECOND = 2,
}

## 阶段切换时同步阶段编号与新阶段生命值；用于 HUD 更新 Boss 血条。
signal sig_phase_changed(phase: int, current_health: int, max_health: int)
## 只有最终阶段被击败时才发出，避免阶段切换被误计为一次击杀。
signal sig_defeated

@export_group("阶段一 / 手枪")
## 第一阶段生命值、单发伤害、弹匣容量、射速与换弹时间。
@export_range(1, 9999, 1) var phase_one_health: int = 100
@export_range(1, 999, 1) var phase_one_damage: int = 4
@export_range(1, 99, 1) var phase_one_magazine: int = 3
@export_range(0.05, 10.0, 0.05) var phase_one_fire_interval: float = 0.3
@export_range(0.05, 30.0, 0.05) var phase_one_reload_duration: float = 3.0

@export_group("阶段二 / 冲锋枪")
## 第二阶段独立生命值、单发伤害、弹匣容量、射速与换弹时间。
@export_range(1, 9999, 1) var phase_two_health: int = 60
@export_range(1, 999, 1) var phase_two_damage: int = 3
@export_range(1, 99, 1) var phase_two_magazine: int = 6
@export_range(0.05, 10.0, 0.05) var phase_two_fire_interval: float = 0.2
@export_range(0.05, 30.0, 0.05) var phase_two_reload_duration: float = 2.0

@export_group("阶段一 / 移动")
## 第一阶段与玩家保持的最小间距、单段移动长度、段间休息时间和移动速度。
@export_range(0.0, 2000.0, 1.0) var phase_one_stop_distance: float = 60.0
@export_range(1.0, 2000.0, 1.0) var phase_one_move_distance: float = 30.0
@export_range(0.0, 60.0, 0.1) var phase_one_rest_duration: float = 3.0
@export_range(0.0, 1000.0, 0.1) var phase_one_move_speed: float = 5.0

@export_group("阶段二 / 移动")
## 第二阶段与玩家保持的最小间距、单段移动长度、段间休息时间和移动速度。
@export_range(0.0, 2000.0, 1.0) var phase_two_stop_distance: float = 30.0
@export_range(1.0, 2000.0, 1.0) var phase_two_move_distance: float = 40.0
@export_range(0.0, 60.0, 0.1) var phase_two_rest_duration: float = 2.0
@export_range(0.0, 1000.0, 0.1) var phase_two_move_speed: float = 8.0

@export_group("弹丸")
## Boss 子弹速度和最大飞行距离，子弹始终朝发射瞬间的玩家位置飞行。
@export_range(1.0, 2000.0, 1.0) var bullet_speed: float = 260.0
@export_range(1.0, 3000.0, 1.0) var bullet_range: float = 700.0

@onready var health_component: HealthComponent = $Health
@onready var body_sprite: Sprite2D = $Sprite2D

var current_phase: Phase = Phase.FIRST
var _ammo_in_magazine: int = 0
var _fire_cooldown: float = 0.25
var _reload_remaining: float = 0.0
var _move_distance_remaining: float = 0.0
var _rest_remaining: float = 0.0
var _is_defeated: bool = false


## 初始化第一阶段生命与弹药，并在 Boss 最终死亡时回收场景实例。
func _ready() -> void:
	add_to_group("enemies")
	collision_mask |= Definition.PHYSICS_LAYER_TERRAIN | Definition.PHYSICS_LAYER_WATER
	health_component.sig_die.connect(_on_phase_depleted)
	_apply_phase_settings(true)
	_emit_phase_changed()


## 每个物理帧更新目标方向、分段移动和自动射击。
func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var target_direction := global_position.direction_to(player.global_position)
	_update_segmented_movement(delta, player, target_direction)
	_update_weapon(delta)
	if absf(target_direction.x) > 0.01:
		body_sprite.flip_h = target_direction.x < 0.0


## 阶段一被击败时重置为阶段二生命与冲锋枪；阶段二被击败才结束 Boss 战。
func _on_phase_depleted() -> void:
	if _is_defeated:
		return
	if current_phase == Phase.FIRST:
		current_phase = Phase.SECOND
		_apply_phase_settings(true)
		body_sprite.modulate = Color(1.0, 0.72, 0.72, 1.0)
		_emit_phase_changed()
		return

	_is_defeated = true
	velocity = Vector2.ZERO
	sig_defeated.emit()
	queue_free()


## 将阶段配置写入生命组件、弹药和换弹状态，并重置分段移动节奏。
func _apply_phase_settings(reset_magazine: bool) -> void:
	var phase_health: int = phase_one_health if current_phase == Phase.FIRST else phase_two_health
	health_component.health_max = maxi(phase_health, 1)
	health_component.health = health_component.health_max
	if reset_magazine:
		_ammo_in_magazine = _current_magazine_size()
		_reload_remaining = 0.0
		_fire_cooldown = 0.25
	_move_distance_remaining = 0.0
	_rest_remaining = 0.0


## 根据玩家距离执行单段移动，达到段长或安全距离后停下并开始休息。
func _update_segmented_movement(delta: float, player: Node2D, target_direction: Vector2) -> void:
	var distance_to_player := global_position.distance_to(player.global_position)
	var stop_distance := _current_stop_distance()
	if _rest_remaining > 0.0:
		_rest_remaining = maxf(_rest_remaining - delta, 0.0)
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if distance_to_player <= stop_distance:
		# 因安全距离提前结束移动段时，也进入完整休息时间再追击。
		if _move_distance_remaining > 0.0:
			_move_distance_remaining = 0.0
			_rest_remaining = _current_rest_duration()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _move_distance_remaining <= 0.0:
		_move_distance_remaining = _current_move_distance()

	# 单帧移动量同时受速度、剩余段长和玩家安全距离限制，避免冲过任一边界。
	var distance_before_stop := distance_to_player - stop_distance
	var step_distance := minf(
		_current_move_speed() * delta,
		minf(_move_distance_remaining, distance_before_stop)
	)
	if step_distance <= 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	velocity = target_direction * (step_distance / maxf(delta, 0.0001))
	var previous_position := global_position
	move_and_slide()
	var actual_distance := previous_position.distance_to(global_position)
	_move_distance_remaining = maxf(_move_distance_remaining - actual_distance, 0.0)
	if actual_distance <= 0.001 or _move_distance_remaining <= 0.001:
		_move_distance_remaining = 0.0
		_rest_remaining = _current_rest_duration()
		velocity = Vector2.ZERO


## 管理弹匣和换弹计时；每次开火都重新读取玩家位置以持续锁定目标。
func _update_weapon(delta: float) -> void:
	if _reload_remaining > 0.0:
		_reload_remaining = maxf(_reload_remaining - delta, 0.0)
		if _reload_remaining <= 0.0:
			_ammo_in_magazine = _current_magazine_size()
		return

	if _ammo_in_magazine <= 0:
		_reload_remaining = _current_reload_duration()
		return

	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if _fire_cooldown > 0.0:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return
	var locked_direction := global_position.direction_to(player.global_position)
	if _fire_at(locked_direction):
		_ammo_in_magazine -= 1
		_fire_cooldown = _current_fire_interval()


## 创建敌方阵营子弹并使用玩家位置作为发射方向。
func _fire_at(direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false
	var bullet: ProjectileBullet = PrefabManager.create_bullet(
		Definition.Faction.Enemy,
		_current_damage(),
		direction
	)
	if bullet == null:
		return false

	bullet.bullet_speed = bullet_speed
	bullet.bullet_range = bullet_range
	bullet.collision_layer = 4
	bullet.collision_mask = 3
	get_parent().add_child(bullet)
	bullet.global_position = global_position + direction * 12.0
	return true


## 通知场景控制器和 HUD 当前阶段生命值。
func _emit_phase_changed() -> void:
	sig_phase_changed.emit(current_phase, health_component.health, health_component.health_max)


## 读取当前阶段弹匣容量。
func _current_magazine_size() -> int:
	return maxi(phase_one_magazine if current_phase == Phase.FIRST else phase_two_magazine, 1)


## 读取当前阶段单发伤害。
func _current_damage() -> int:
	return maxi(phase_one_damage if current_phase == Phase.FIRST else phase_two_damage, 1)


## 读取当前阶段射击间隔。
func _current_fire_interval() -> float:
	return maxf(phase_one_fire_interval if current_phase == Phase.FIRST else phase_two_fire_interval, 0.05)


## 读取当前阶段换弹时间。
func _current_reload_duration() -> float:
	return maxf(phase_one_reload_duration if current_phase == Phase.FIRST else phase_two_reload_duration, 0.05)


## 读取当前阶段停止移动的玩家距离。
func _current_stop_distance() -> float:
	return maxf(phase_one_stop_distance if current_phase == Phase.FIRST else phase_two_stop_distance, 0.0)


## 读取当前阶段每次移动的段长。
func _current_move_distance() -> float:
	return maxf(phase_one_move_distance if current_phase == Phase.FIRST else phase_two_move_distance, 1.0)


## 读取当前阶段段间休息时间。
func _current_rest_duration() -> float:
	return maxf(phase_one_rest_duration if current_phase == Phase.FIRST else phase_two_rest_duration, 0.0)


## 读取当前阶段移动速度。
func _current_move_speed() -> float:
	return maxf(phase_one_move_speed if current_phase == Phase.FIRST else phase_two_move_speed, 0.0)

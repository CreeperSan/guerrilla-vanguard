## 可配置敌人士兵：按行为模式巡逻、追击、瞄准和使用弹匣开火。
class_name EnemySoilder
extends CharacterBody2D

## 敌人行为模式；关卡实例可直接在 Inspector 中指定。
enum BehaviorMode {
    STATIONARY_GUARD,      ## 原地警戒，进入射程后站立开火。
    WANDER_AND_CHASE,      ## 平时随机走动，进入警觉范围后追击并站立开火。
    CHASE_AND_STAND,       ## 始终追击，进入射程后站立开火。
    CHASE_AND_STRAFE_FIRE, ## 始终追击，进入射程后随机走动并开火。
}

## 敌人行为模式与视觉制服颜色。
@export var behavior_mode: BehaviorMode = BehaviorMode.STATIONARY_GUARD
@export var uniform_color: Color = Color(1.0, 0.45, 0.45, 1.0)
## 生命值和战斗参数由关卡实例配置。
@export_range(1, 9999, 1) var health: int = 8
@export_range(1, 999, 1) var weapon_damage: int = 1
@export_range(0.05, 10.0, 0.05) var fire_interval: float = 0.35
@export_range(0.05, 30.0, 0.05) var fire_duration: float = 1.6
@export_range(0.0, 30.0, 0.05) var fire_pause_duration: float = 0.8
@export_range(1, 999, 1) var magazine_size: int = 12
@export_range(0.05, 30.0, 0.05) var reload_duration: float = 1.5
## 感知和移动参数，距离单位为像素。
@export_range(1.0, 2000.0, 1.0) var alert_range: float = 240.0
@export_range(1.0, 2000.0, 1.0) var weapon_range: float = 180.0
@export_range(0.0, 1000.0, 1.0) var move_speed: float = 55.0
@export_range(0.0, 1000.0, 1.0) var wander_radius: float = 100.0
@export_range(1.0, 1000.0, 1.0) var strafe_radius: float = 40.0
@export_range(0.1, 10.0, 0.1) var movement_change_interval: float = 1.2
## 敌人弹丸参数。
@export_range(1.0, 2000.0, 1.0) var bullet_speed: float = 300.0
@export_range(1.0, 3000.0, 1.0) var bullet_range: float = 500.0

@onready var health_component: HealthComponent = $Health
@onready var animated_sprite: AnimatedSprite2D = $Body/AnimatedSprite2D
@onready var perception_hear: CollisionShape2D = $Perception/RangeHear
@onready var perception_vision: CollisionShape2D = $Perception/RangeVision

var _spawn_position: Vector2
var _wander_target: Vector2
var _movement_timer: float = 0.0
var _fire_cooldown: float = 0.0
var _burst_remaining: float = 0.0
var _burst_pause_remaining: float = 0.0
var _reload_remaining: float = 0.0
var _ammo_in_magazine: int = 0
var _is_burst_active: bool = false


## 初始化血量、感知显示范围和巡逻位置，并连接死亡回收。
func _ready() -> void:
    _spawn_position = global_position
    _wander_target = _spawn_position
    _ammo_in_magazine = maxi(magazine_size, 1)
    health_component.health_max = maxi(health, 1)
    health_component.health = health_component.health_max
    health_component.sig_die.connect(_on_die)
    _set_shape_radius(perception_hear, alert_range)
    _set_shape_radius(perception_vision, weapon_range)
    animated_sprite.modulate = uniform_color


## 每帧依据模式更新移动、朝向和武器状态。
func _physics_process(delta: float) -> void:
    var player: Player = get_tree().get_first_node_in_group("player") as Player
    var target_distance: float = INF
    var target_direction: Vector2 = Vector2.ZERO
    if is_instance_valid(player):
        target_direction = player.global_position - global_position
        target_distance = target_direction.length()

    var is_alerted: bool = is_instance_valid(player) and (
        behavior_mode != BehaviorMode.WANDER_AND_CHASE or target_distance <= alert_range
    )
    var in_weapon_range: bool = is_alerted and target_distance <= weapon_range
    var movement_direction: Vector2 = _get_movement_direction(
        delta,
        player,
        target_direction,
        is_alerted,
        in_weapon_range
    )

    velocity = movement_direction * maxf(move_speed, 0.0)
    move_and_slide()
    _update_animation(target_direction if is_instance_valid(player) else movement_direction)
    _update_weapon(delta, in_weapon_range, target_direction)


## 按四种行为模式计算移动方向；射程内的站立射击模式保持静止。
func _get_movement_direction(
    delta: float,
    player: Player,
    target_direction: Vector2,
    is_alerted: bool,
    in_weapon_range: bool
) -> Vector2:
    if behavior_mode == BehaviorMode.STATIONARY_GUARD:
        return Vector2.ZERO

    if behavior_mode == BehaviorMode.WANDER_AND_CHASE and not is_alerted:
        return _move_toward_wander_point(delta, _spawn_position, wander_radius)

    if not is_instance_valid(player):
        return Vector2.ZERO

    if not in_weapon_range:
        return target_direction.normalized()

    if behavior_mode == BehaviorMode.CHASE_AND_STRAFE_FIRE:
        return _move_toward_wander_point(delta, player.global_position, strafe_radius)

    return Vector2.ZERO


## 定时选择活动中心附近的新点，供巡逻和射程内随机走动复用。
func _move_toward_wander_point(delta: float, center: Vector2, radius: float) -> Vector2:
    _movement_timer -= delta
    if _movement_timer <= 0.0 or global_position.distance_to(_wander_target) < 6.0:
        _movement_timer = maxf(movement_change_interval, 0.1)
        _wander_target = center + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(0.0, radius)
    return global_position.direction_to(_wander_target)


## 进入射程后按连发时长、射速、弹匣容量和换弹时间开火。
func _update_weapon(delta: float, can_fire: bool, target_direction: Vector2) -> void:
    _fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
    if _reload_remaining > 0.0:
        _reload_remaining -= delta
        if _reload_remaining <= 0.0:
            _ammo_in_magazine = maxi(magazine_size, 1)
        return

    if not can_fire:
        _is_burst_active = false
        _burst_remaining = 0.0
        return

    if _ammo_in_magazine <= 0:
        _reload_remaining = maxf(reload_duration, 0.05)
        _is_burst_active = false
        return

    if not _is_burst_active:
        _burst_pause_remaining = maxf(_burst_pause_remaining - delta, 0.0)
        if _burst_pause_remaining > 0.0:
            return
        _is_burst_active = true
        _burst_remaining = maxf(fire_duration, fire_interval)

    _burst_remaining -= delta
    if _fire_cooldown <= 0.0 and _fire_at(target_direction.normalized()):
        _fire_cooldown = maxf(fire_interval, 0.05)
        _ammo_in_magazine -= 1

    if _burst_remaining <= 0.0:
        _is_burst_active = false
        _burst_pause_remaining = maxf(fire_pause_duration, 0.0)


## 创建敌方子弹并调整碰撞层，使其能命中玩家身体或 HurtBox。
func _fire_at(direction: Vector2) -> bool:
    if direction == Vector2.ZERO:
        return false
    var bullet: ProjectileBullet = PrefabManager.create_bullet(
        Definition.Faction.Enemy,
        weapon_damage,
        direction
    )
    if bullet == null:
        return false

    bullet.bullet_speed = bullet_speed
    bullet.bullet_range = bullet_range
    bullet.collision_layer = 4
    bullet.collision_mask = 3
    get_parent().add_child(bullet)
    bullet.global_position = global_position + direction * 8.0
    return true


## 根据移动或玩家方向选择已有的八方向待机与走路动画。
func _update_animation(direction: Vector2) -> void:
    if direction.length_squared() < 0.01:
        direction = Vector2.DOWN
    var angle_degrees: float = fposmod(rad_to_deg(direction.angle()), 360.0)
    var direction_name: String = "down"
    if angle_degrees >= 337.5 or angle_degrees < 22.5:
        direction_name = "right"
    elif angle_degrees < 67.5:
        direction_name = "down_right"
    elif angle_degrees < 112.5:
        direction_name = "down"
    elif angle_degrees < 157.5:
        direction_name = "down_left"
    elif angle_degrees < 202.5:
        direction_name = "left"
    elif angle_degrees < 247.5:
        direction_name = "up_left"
    elif angle_degrees < 292.5:
        direction_name = "up"
    elif angle_degrees < 337.5:
        direction_name = "up_right"

    var animation_prefix: String = "move" if velocity.length_squared() > 1.0 else "idle"
    animated_sprite.play(animation_prefix + "_" + direction_name)


## 修改感知圈的圆形碰撞半径，供编辑器查看和场景参数同步。
func _set_shape_radius(collision_shape: CollisionShape2D, radius: float) -> void:
    var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
    if circle_shape != null:
        circle_shape.radius = maxf(radius, 1.0)


## 敌人死亡时移除整个士兵实例。
func _on_die() -> void:
    queue_free()

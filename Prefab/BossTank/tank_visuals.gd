## 坦克分层动画：车体四方向、炮塔独立旋转、履带运动、过载热光和驾驶员跑动。
## 位图来自透明图集切片；程序只控制姿态与补充瞬时枪焰/履带，不改变碰撞方向。
class_name TankBossVisuals
extends Node2D

const HULLS: Array[Texture2D] = [preload("res://Assets/Art/MilitaryArcade/Tank/hull_down.tres"), preload("res://Assets/Art/MilitaryArcade/Tank/hull_right.tres"), preload("res://Assets/Art/MilitaryArcade/Tank/hull_up.tres"), preload("res://Assets/Art/MilitaryArcade/Tank/hull_left.tres")]
const DRIVERS: Array[Texture2D] = [preload("res://Assets/Art/MilitaryArcade/Tank/driver_down.tres"), preload("res://Assets/Art/MilitaryArcade/Tank/driver_right.tres"), preload("res://Assets/Art/MilitaryArcade/Tank/driver_up.tres"), preload("res://Assets/Art/MilitaryArcade/Tank/driver_left.tres")]
const TURRET: Texture2D = preload("res://Assets/Art/MilitaryArcade/Tank/turret.tres")
const HOT_TURRET: Texture2D = preload("res://Assets/Art/MilitaryArcade/Tank/turret_overload.tres")
const WRECK: Texture2D = preload("res://Assets/Art/MilitaryArcade/Tank/wreck.tres")

@onready var hull: Sprite2D = $Hull
@onready var turret: Sprite2D = $Turret
@onready var driver: Sprite2D = $Driver

var _phase: int = 1
var _direction := Vector2.RIGHT
var _hull_direction: int = 0
var _clock: float = 0.0
var _moving: bool = false
var _shot_remaining: float = 0.0
var _shot_kind: String = ""
var _transition_remaining: float = 0.0


## 显示姿态与实际位移保持同步；静止坦克保留车体朝向，炮塔继续转向玩家。
func update_pose(phase: int, aim: Vector2, movement: Vector2, moving: bool, delta: float) -> void:
	_phase = phase
	_clock += delta
	_moving = moving
	_shot_remaining = maxf(_shot_remaining - delta, 0.0)
	_transition_remaining = maxf(_transition_remaining - delta, 0.0)
	if aim != Vector2.ZERO:
		_direction = aim.normalized()
	if moving:
		_hull_direction = _direction_index(movement)
	hull.visible = phase != 3
	turret.visible = phase != 3
	driver.visible = phase == 3
	hull.texture = HULLS[_hull_direction]
	# 生成素材车体中心略高于切片中心，补偿轴心并保留四方向原始姿态。
	hull.offset = Vector2(12.0, -22.0)
	turret.texture = HOT_TURRET if phase == 2 else TURRET
	# 炮塔切片包含右伸炮管，旋转轴在圆形转台，而不是整张切片的几何中心。
	turret.offset = Vector2(78.0, -30.0)
	turret.rotation = _direction.angle()
	turret.position = -_direction * (_shot_remaining / 0.16 * 4.0 if _shot_kind == "cannon" else 0.0)
	driver.texture = DRIVERS[_direction_index(_direction)]
	driver.position.y = sin(_clock * 18.0) * 1.3 if moving else 0.0
	driver.rotation = sin(_clock * 18.0) * 0.045 if moving else 0.0
	var heat := 0.85 + sin(_clock * 5.0) * 0.15
	hull.modulate = Color(1.0, heat, heat) if phase == 2 else Color.WHITE
	var flash := 0.5 + 0.5 * sin(_clock * 24.0) if _transition_remaining > 0.0 else 0.0
	modulate = Color(1.0, 1.0 - flash * 0.35, 1.0 - flash * 0.5)
	queue_redraw()


## 四方向切片选择；驾驶员物理移动仍可全向，图像采用最近的方向。
func _direction_index(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 1 if direction.x > 0.0 else 3
	return 0 if direction.y >= 0.0 else 2


## 每次射击触发短枪焰；主炮额外后坐四像素。
func play_shot(kind: String) -> void:
	_shot_kind = kind
	_shot_remaining = 0.16 if kind == "cannon" else 0.08
	queue_redraw()


## 过载闪烁与驾驶员出舱；车体残骸留在击毁位置作为无碰撞装饰。
func play_transition(phase: int) -> void:
	_transition_remaining = 0.8
	if phase == 3:
		var wreck := Sprite2D.new()
		wreck.name = "TankWreck"
		wreck.texture = WRECK
		wreck.scale = hull.scale
		wreck.z_index = -1
		get_parent().get_parent().add_child(wreck)
		wreck.global_position = global_position
		# 出舱从缩小状态回弹到正常尺寸，不改变角色或碰撞位置。
		driver.scale = Vector2.ZERO
		create_tween().tween_property(driver, "scale", Vector2(0.12, 0.12), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 附加履带滚动与枪口闪光；动态光环明确提示过载，但不承担伤害判定。
func _draw() -> void:
	if _phase == 2:
		draw_arc(Vector2.ZERO, 32.0 + sin(_clock * 5.0) * 1.5, 0.0, TAU, 36, Color(1.0, 0.27, 0.08, 0.45), 2.0)
	if _moving and _phase != 3:
		var vertical := _hull_direction in [0, 2]
		for side: float in [-1.0, 1.0]:
			for index: int in range(5):
				var offset := fposmod(index * 9.0 + _clock * 32.0, 45.0) - 22.5
				var point := Vector2(side * 26.0, offset) if vertical else Vector2(offset, side * 26.0)
				draw_line(point - (Vector2(2, 0) if vertical else Vector2(0, 2)), point + (Vector2(2, 0) if vertical else Vector2(0, 2)), Color(0.55, 0.48, 0.36, 0.7), 2.0)
	if _shot_remaining > 0.0:
		var length := float(get_parent().get("cannon_muzzle_distance")) if _shot_kind == "cannon" else (32.0 if _shot_kind == "machine" else 15.0)
		var point := _direction * length
		var perpendicular := _direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([point, point + _direction * 4.0 + perpendicular * 4.0, point + _direction * 12.0, point + _direction * 4.0 - perpendicular * 4.0]), Color(1.0, 0.76, 0.22, 0.9))

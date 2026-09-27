class_name Bullet
extends Area2D

@export var flight_speed: float = 400 # 子弹飞行速度
@export var flight_range: float = 200 # 子弹有效射程
@export var flight_direction: Vector2 = Vector2.UP # 子弹朝向
@export var bullet_from: From = From.PLAYER # 来源
@export var bullet_damage: int = 10 # 伤害

var travel_dist: float = 0.0       # 记录已经飞行的距离



func _ready() -> void:
	# 注册命中监听
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	# 单帧移动距离
	var move_step: float = flight_speed * delta
	# 位移
	position += flight_direction.normalized() * move_step
	# 累计飞行路程
	travel_dist += move_step

	# 超出射程，销毁子弹
	if travel_dist >= flight_range:
		queue_free()


# 子弹命中物体
func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox:
		queue_free()


enum From {
	PLAYER,
	ENEMY,
	FRIEND,
}

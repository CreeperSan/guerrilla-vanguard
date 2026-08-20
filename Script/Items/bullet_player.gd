extends Area2D

@export var speed: float = 400 # 子弹飞行速度
@export var range: float = 200 # 子弹有效射程
@export var direction: Vector2 = Vector2.UP # 子弹朝向

var travel_dist: float = 0.0       # 记录已经飞行的距离

func _process(delta: float) -> void:
	# 单帧移动距离
	var move_step: float = speed * delta
	# 位移
	position += direction.normalized() * move_step
	# 累计飞行路程
	travel_dist += move_step

	# 超出射程，销毁子弹
	if travel_dist >= range:
		queue_free()

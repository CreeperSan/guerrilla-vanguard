## 房间出口占位：未清空敌人时阻挡通行，房间安全后开放并发出进入信号。
class_name RoomEntrance
extends Node2D

## 玩家穿过已开启出口时发出，后续关卡切换可连接此信号。
signal sig_entered(body: Node2D)

@onready var door_collision: CollisionShape2D = $DoorBody/CollisionShape2D
@onready var door_sprite: Sprite2D = $Sprite2D
@onready var entrance_area: Area2D = $EntranceArea

var is_open: bool = false


## 连接出口触发区域，并以关闭状态开始。
func _ready() -> void:
	entrance_area.body_entered.connect(_on_body_entered)
	set_open(false)


## 开启或关闭出口碰撞，并使用颜色区分出口状态。
func set_open(open: bool) -> void:
	is_open = open
	door_collision.disabled = open
	door_sprite.modulate = Color(0.75, 0.82, 0.62, 1.0) if open else Color.WHITE


## 只有出口已开放且进入者为玩家时，才发出关卡入口信号。
func _on_body_entered(body: Node2D) -> void:
	if is_open and body is Player:
		sig_entered.emit(body)

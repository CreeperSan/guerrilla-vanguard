## 伤害飘字：显示伤害数值，并沿随机方向移动、淡出后自动销毁。
class_name DamagePop
extends Sprite2D

################################################################################ 伤害属性

## 伤害数值。
@export var damange_num: int = 0

## 伤害归属（表明是谁收到伤害，玩家收到伤害数字为红色，否则数字为白色）。
@export var damage_faction: Definition.Faction = Definition.Faction.Player

## 伤害跳出效果持续时间。
@export var damage_duration: float = 0.4

################################################################################ 实例属性

## 创建时间。
@export var self_create_time: float = 0.0

## 跳出方向（每次出现都随机方向）。
@export var self_direction: Vector2 = Vector2.LEFT

## 飘字速度，单位为像素/秒。
@export var damage_speed: float = 55.0

## 飘字文本节点。
@onready var node_label: Label = $Label


################################################################################ 事件处理

## 设置伤害文本和阵营颜色，并为本次飘字抽取随机运动方向。
func _ready() -> void:
    self_create_time = 0.0
    self_direction = Vector2.from_angle(randf_range(0.0, TAU))
    node_label.text = str(damange_num)
    node_label.modulate = Color(1.0, 0.25, 0.25) if damage_faction == Definition.Faction.Player else Color.WHITE


## 沿随机方向移动并淡出；持续时间结束后释放节点。
func _process(delta: float) -> void:
    var duration: float = maxf(damage_duration, 0.01)
    self_create_time += delta
    global_position += self_direction * damage_speed * delta
    modulate.a = clampf(1.0 - self_create_time / duration, 0.0, 1.0)

    if self_create_time >= duration:
        queue_free()

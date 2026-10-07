extends Area2D

# 当前的警觉状态
@export var perception_state: State = State.NONE
# 警觉范围
@onready var perception_range_hear: CollisionShape2D = $RangeHear
@onready var perception_range_vision: CollisionShape2D = $RangeVision
# 锁定目标
@export var perception_target: Node = null


func _ready() -> void:
    pass



enum State {
    NONE,	# 不警觉
    LOCK,	# 锁定目标
    RANGE,	# 范围检测
}

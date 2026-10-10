## 动员兵护卫：复用士兵射击，以固定世界方向槽位跟随，移动受地形碰撞约束。
## 补员单位不重复提供积分/掉落；领袖死亡后立即退出战斗。
extends EnemySoilder

## 所属领袖与固定槽位；槽位不随朝向旋转。
var commander: Node2D
var formation_offset: Vector2


## 在正常士兵初始化前禁用奖励，随后保留原有生命、武器和死亡回收。
func _ready() -> void:
    set_meta("suppress_death_rewards", true)
    super._ready()


## 槽位被墙挡住时尝试沿墙偏转；绝不通过设置位置或传送穿越障碍。
func _get_movement_direction(_delta: float, _player: Node2D, _target_direction: Vector2, _is_alerted: bool, _in_weapon_range: bool) -> Vector2:
    if not is_instance_valid(commander) or commander.is_queued_for_deletion():
        queue_free()
        return Vector2.ZERO
    var desired := commander.global_position + formation_offset
    var difference := desired - global_position
    if difference.length() < 6.0:
        return Vector2.ZERO
    var direction := difference.normalized()
    for angle: float in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0]:
        var candidate := direction.rotated(angle)
        if not test_move(global_transform, candidate * 18.0):
            return candidate
    return Vector2.ZERO

## 逃生哨：实际受伤后短暂移动加速，重复受伤只刷新持续时间。
extends TacticalAbility

var _remaining: float = 0.0


## 治疗、护盾和生命上限变化不经过实际受伤事件。
func damaged() -> void:
    _remaining = parameter("duration", 2.0)
    modify(&"move_speed", parameter("speed", 1.25))
    equipment.ability_triggered.emit(definition.id)


## 到期覆盖本来源修正为 1，不反向除玩家速度，避免叠加漂移。
func tick(delta: float) -> void:
    if _remaining <= 0.0:
        return
    _remaining = maxf(_remaining - delta, 0.0)
    if _remaining <= 0.0:
        modify(&"move_speed", 1.0)

## 战术枪套：切枪装填一次增伤，实际射击后开始冷却，失败开火不消费。
extends TacticalAbility

var _armed: bool = false
var _cooldown: float = 0.0


## 冷却期间切枪不排队，避免高频切换绕过触发间隔。
func weapon_changed() -> void:
    if _cooldown <= 0.0:
        _armed = true


## 每帧只推进本能力私有冷却。
func tick(delta: float) -> void:
    _cooldown = maxf(_cooldown - delta, 0.0)


## 下一枪效果在创建所有弹丸期间保持一致。
func shot_multiplier(_weapon: PlayerWeaponSlot) -> float:
    return parameter("damage", 1.3) if _armed else 1.0


## 成功一枪后消费并启动冷却，不按弹丸数重复触发。
func shot_committed(_weapon: PlayerWeaponSlot) -> void:
    if _armed:
        _armed = false
        _cooldown = parameter("cooldown", 3.0)
        equipment.ability_triggered.emit(definition.id)

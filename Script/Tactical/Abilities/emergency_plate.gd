## 应急护板：每个战斗房一次实际入血伤害减免，主动盾和闪避不会消耗。
extends TacticalAbility

var _available: bool = false
var _spent_rooms: Dictionary = {}


## 中途购买不提供安全房减免，只有进入战斗房才装填。
func room_entered(combat: bool) -> void:
    _available = combat and not _spent_rooms.has(equipment.current_room_key())


## 奇数伤害向上取整，至少承受一半；零伤害不会消费护板。
func filter_damage(value: int) -> int:
    if not _available or value <= 0:
        return value
    _available = false
    _spent_rooms[equipment.current_room_key()] = true
    equipment.ability_triggered.emit(definition.id)
    return maxi(ceili(value * parameter("damage", 0.5)), 1)

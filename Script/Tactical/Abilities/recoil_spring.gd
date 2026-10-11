## 回力弹簧：闪避结束后提供短时下一次接触增伤，本能力本身不生成攻击。
extends TacticalAbility

var _remaining: float = 0.0


## 动作真正结束后才打开窗口，避免全部持续时间在无敌动作中耗尽。
func dodge_finished() -> void:
    _remaining = parameter("duration", 1.0)


## 私有窗口计时，暂停期间不前进。
func tick(delta: float) -> void:
    _remaining = maxf(_remaining - delta, 0.0)


## 仅接触攻击读取此倍率，不影响枪械、手雷和支援。
func contact_multiplier() -> float:
    return parameter("damage", 2.0) if _remaining > 0.0 else 1.0


## 一次有效接触后关闭窗口，多敌人同时接触也只有第一击翻倍。
func contact_committed() -> void:
    if _remaining > 0.0:
        equipment.ability_triggered.emit(definition.id)
    _remaining = 0.0

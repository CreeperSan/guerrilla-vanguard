## 战地绷带：房间首次清空回血，房间去重由组件处理，治疗仍经过通用过滤链。
extends TacticalAbility


## 只治疗存活玩家；最低一点避免小生命上限下完全失效。
func room_cleared() -> void:
    var player: Player = equipment.player
    if player.health_current <= 0:
        return
    player.node_health.heal(maxi(roundi(player.health_max * parameter("healing", 0.03)), 1))
    equipment.ability_triggered.emit(definition.id)

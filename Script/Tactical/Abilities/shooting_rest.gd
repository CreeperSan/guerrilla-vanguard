## 定点射击架：只依赖组件的真实站定时间，不混入玩家输入或移动代码。
extends TacticalAbility


## 再核对本帧实际位移，避免物理节点处理顺序导致移动首帧仍有加成。
func shot_multiplier(_weapon: PlayerWeaponSlot) -> float:
    var player: Player = equipment.player
    if player.dodge_active or player.velocity.length_squared() > 0.01:
        return 1.0
    return parameter("damage", 1.2) if equipment.stationary_time >= parameter("wait", 0.8) else 1.0

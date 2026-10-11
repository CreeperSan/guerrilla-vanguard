## 最后一颗子弹：依据扣弹前弹匣判断，一次散射的所有弹丸获得相同倍率。
extends TacticalAbility


## 查询不消耗状态，空弹匣的失败射击不会触发。
func shot_multiplier(weapon: PlayerWeaponSlot) -> float:
    return parameter("damage", 1.6) if weapon.ammo_magazine_cur == 1 else 1.0

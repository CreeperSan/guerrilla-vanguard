## 霰弹枪：有限备弹、五枚前向散射；弹丸数与散布角读取独立升级配置资源。
class_name PlayerWeaponShortgun
extends PlayerWeaponSlot


## 配置霰弹枪的八发弹匣和每次五发的宽散布射击。
func _init() -> void:
    ammo_magazine_max = 8
    ammo_magazine_cur = ammo_magazine_max
    ammo_back_max = 40
    ammo_back_cur = ammo_back_max
    reload_duration = 1.45
    fire_gap = 0.65
    bullet_basic_speed = 500.0
    bullet_basic_range = 210.0
    bullet_basic_damage = 3
    bullet_basic_size = 2.0
    bullet_basic_duration = 0.8
    # 同时向前方扇形散射五枚弹丸；公共开火流程只扣除一发弹匣弹药。
    var config: Dictionary = BattlefieldUpgradeConfig.get_config().get("shotgun", {})
    bullet_count = maxi(int(config.get("pellets", 5)), 1)
    bullet_spread_degrees = clampf(float(config.get("spread_degrees", 24.0)), 0.0, 180.0)

class_name PlayerWeaponShortgun
extends PlayerWeaponSlot


## 配置霰弹枪的八发弹匣和每次三发的宽散布射击。
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
    bullet_count = 3
    bullet_spread_degrees = 24.0

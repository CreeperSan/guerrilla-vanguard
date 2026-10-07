class_name PlayerWeaponPistol
extends PlayerWeaponSlot


## 配置手枪的弹匣、无限备弹和基础射击参数。
func _init() -> void:
    ammo_magazine_max = 12
    ammo_magazine_cur = ammo_magazine_max
    ammo_back_max = INFINITY
    ammo_back_cur = INFINITY
    ammo_back_infinite = true
    reload_duration = 0.75
    fire_gap = 0.24
    bullet_basic_speed = 560.0
    bullet_basic_range = 460.0
    bullet_basic_damage = 4
    bullet_basic_size = 2.0
    bullet_basic_duration = 2.0
    bullet_count = 1
    bullet_spread_degrees = 2.0

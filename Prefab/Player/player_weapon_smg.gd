class_name PlayerWeaponSMG
extends PlayerWeaponSlot


## 配置冲锋枪的快速连射、弹匣和有限备弹。
func _init() -> void:
    ammo_magazine_max = 30
    ammo_magazine_cur = ammo_magazine_max
    ammo_back_max = 120
    ammo_back_cur = ammo_back_max
    reload_duration = 1.2
    fire_gap = 0.09
    bullet_basic_speed = 620.0
    bullet_basic_range = 420.0
    bullet_basic_damage = 2
    bullet_basic_size = 1.8
    bullet_basic_duration = 1.5
    bullet_count = 1
    bullet_spread_degrees = 5.0

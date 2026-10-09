## 狙击步枪：高伤害长射程，最多连续命中六个目标。
class_name PlayerWeaponSniper
extends PlayerWeaponSlot


## 基础数值在实例创建时写入；战场升级由武器管理器随后统一应用。
func _init() -> void:
    weapon_id = "sniper"
    display_name = "狙击步枪"
    weapon_icon = preload("res://Assets/Art/MilitaryArcade/Weapons/sniper_icon.tres")
    fire_sound = preload("res://Assets/Audio/SFX/Weapons/sniper_fire.wav")
    ammo_magazine_max = 5
    ammo_magazine_cur = ammo_magazine_max
    ammo_back_max = 25
    ammo_back_cur = ammo_back_max
    reload_duration = 2.0
    fire_gap = 1.15
    bullet_basic_speed = 1100.0
    bullet_basic_range = 900.0
    bullet_basic_damage = 18
    bullet_basic_size = 2.0
    bullet_basic_duration = 4.0
    bullet_spread_degrees = 0.5
    bullet_penetration = 5
    projectile_style = "sniper"

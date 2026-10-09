## 喷火枪：低伤害高频率，宽火焰最多命中三人，遇敌减速并偏转。
class_name PlayerWeaponFlamethrower
extends PlayerWeaponSlot


## 基础数值在实例创建时写入；战场升级由武器管理器随后统一应用。
func _init() -> void:
    weapon_id = "flamethrower"
    display_name = "喷火枪"
    weapon_icon = preload("res://Assets/Art/MilitaryArcade/Weapons/flamethrower_icon.tres")
    fire_sound = preload("res://Assets/Audio/SFX/Weapons/flamethrower_fire.wav")
    ammo_magazine_max = 80
    ammo_magazine_cur = ammo_magazine_max
    ammo_back_max = 320
    ammo_back_cur = ammo_back_max
    reload_duration = 2.1
    fire_gap = 0.045
    bullet_basic_speed = 260.0
    bullet_basic_range = 125.0
    bullet_basic_damage = 1
    bullet_basic_size = 13.0
    bullet_basic_duration = 4.0
    bullet_spread_degrees = 16
    bullet_penetration = 2
    projectile_style = "flamethrower"

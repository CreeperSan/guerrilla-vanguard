## RPG 火箭发射器：单发装填，命中或射程终点触发范围爆炸。
class_name PlayerWeaponRPG
extends PlayerWeaponSlot


## 基础数值在实例创建时写入；战场升级由武器管理器随后统一应用。
func _init() -> void:
    weapon_id = "rpg"
    display_name = "RPG 火箭发射器"
    weapon_icon = preload("res://Assets/Art/MilitaryArcade/Weapons/rpg_icon.tres")
    fire_sound = preload("res://Assets/Audio/SFX/Weapons/rpg_fire.wav")
    ammo_magazine_max = 1
    ammo_magazine_cur = ammo_magazine_max
    ammo_back_max = 8
    ammo_back_cur = ammo_back_max
    reload_duration = 2.8
    fire_gap = 1.8
    bullet_basic_speed = 340.0
    bullet_basic_range = 580.0
    bullet_basic_damage = 42
    bullet_basic_size = 3.0
    bullet_basic_duration = 4.0
    bullet_spread_degrees = 0
    bullet_penetration = 0
    bullet_type = Definition.BulletType.Explosion
    projectile_style = "rocket"
    explosion_radius = 72.0

class_name LootItem
extends Area2D

enum Type {
    Empty, # 空 - 这是个错误状态，正常来说需要在实例化后的时候就要赋值
    
    WeaponSMG = 1, # 武器 - 冲锋枪
    WeaponShortgun = 2, # 武器 - 霰弹枪
    #WeaponFlame, # 武器 - 喷火器
    #WeaponMachineGun, # 武器 - 机关枪
    #WeaponRocketLauncher, # 武器 - 火箭发射器
    #WeaponSniperRifle, # 武器 - 狙击步枪

    Health = 3, # 道具 - 生命补给
    # 4、5 是历史弹药枚举值，保留编号，避免改变既有场景保存的物品类型。
    EquipmentGrenade = 6, # 装备 - 手雷
    EquipmentMolotov = 7, # 装备 - 莫洛托夫燃烧瓶
    EquipmentShield = 8, # 装备 - 护盾
    SupportMortarStriker = 10, # 战场支援 - 迫击炮打击
    SupportTacticalBombing = 11, # 战场支援 - 战术轰炸
    SkillSprint = 12, # 自身技能 - 奔跑
    SkillDodge = 13, # 自身技能 - 闪避
}

# 自身属性
@export var type: Type = Type.Empty
@export var num: int = 1

# 节点 - 样式
@onready var sprite: Sprite2D = $Sprite2D
var pickup_frame: Line2D
var _base_scale: Vector2

func _ready() -> void:
    if type == Type.Empty:
        print("战利品状态错误，不能为 Empty，进行清除")
        queue_free()
        return

    _update_appearance()
    _base_scale = scale
    _create_pickup_frame()
    _start_zoom_animation()


## 根据物品类型应用效果；只有成功增加道具时才返回 true 并允许玩家移除物品。
func apply_to(player: Player) -> bool:
    if player == null or num <= 0:
        return false
    if type in [Type.WeaponSMG, Type.WeaponShortgun] and player.node_weapon_manager == null:
        return false

    match type:
        Type.WeaponSMG:
            # 已拥有的武器由武器管理器自动补充备弹，未拥有时则解锁并切为主武器。
            return player.node_weapon_manager.obtain_smg(num)
        Type.WeaponShortgun:
            # 同一种武器拾取物既负责解锁武器，也负责按拾取数量补充备弹。
            return player.node_weapon_manager.obtain_shortgun(num)
        Type.Health:
            return _apply_health_to(player)
        Type.EquipmentGrenade, Type.EquipmentMolotov, Type.EquipmentShield:
            return player.obtain_equipment_from_loot(type, num)
        Type.SupportMortarStriker, Type.SupportTacticalBombing:
            return player.obtain_battle_support_from_loot(type)
        Type.SkillSprint, Type.SkillDodge:
            return player.obtain_skill_from_loot(type)

    return false


## 为生命值未满的玩家补充生命，并据实际恢复结果决定是否消耗拾取物。
func _apply_health_to(player: Player) -> bool:
    if player.node_health == null:
        return false

    var health_before: int = player.node_health.health
    player.node_health.heal(num)
    return player.node_health.health > health_before


## 武器拾取物显示对应图标，其他道具沿用场景中配置的 Sprite2D 样式。
func _update_appearance() -> void:
    match type:
        Type.WeaponSMG:
            sprite.texture = load("res://Prefab/Player/player_weapon_smg.png") as Texture2D
            sprite.region_enabled = false
            sprite.scale = Vector2(0.5, 0.5)
        Type.WeaponShortgun:
            sprite.texture = load("res://Prefab/Player/player_weapon_shortgun.png") as Texture2D
            sprite.region_enabled = false
            sprite.scale = Vector2(0.5, 0.5)
        Type.EquipmentGrenade:
            sprite.texture = load("res://Prefab/grenade/grenade.png") as Texture2D
            sprite.region_enabled = false
            sprite.scale = Vector2(0.75, 0.75)
        Type.EquipmentMolotov:
            sprite.texture = load("res://Prefab/molotov/molotov.png") as Texture2D
            sprite.region_enabled = false
            sprite.scale = Vector2(0.75, 0.75)
        Type.SupportMortarStriker:
            sprite.texture = load("res://Prefab/MortarStriker/mortar_strike.png") as Texture2D
            sprite.region_enabled = false
            sprite.scale = Vector2(1.0, 1.0)
        Type.SupportTacticalBombing:
            sprite.texture = load("res://Prefab/TactialBoming/tactial_boming.png") as Texture2D
            sprite.region_enabled = false
            sprite.scale = Vector2(1.0, 1.0)
        Type.SkillSprint:
            sprite.texture = load("res://Assets/UI/skill_sprint.svg") as Texture2D
            sprite.region_enabled = false
            sprite.scale = Vector2(0.75, 0.75)
        Type.SkillDodge:
            sprite.texture = load("res://Assets/UI/skill_dodge.svg") as Texture2D
            sprite.region_enabled = false
            sprite.scale = Vector2(0.75, 0.75)
        Type.EquipmentShield:
            sprite.texture = load("res://Prefab/shield/shield.png") as Texture2D
            sprite.region_enabled = false
            sprite.scale = Vector2(0.75, 0.75)


## 为拾取物绘制一圈浅色边框，边框按图标的实际区域和缩放尺寸适配。
func _create_pickup_frame() -> void:
    pickup_frame = Line2D.new()
    pickup_frame.name = "PickupFrame"
    pickup_frame.width = 1.25
    pickup_frame.default_color = Color("#f2d98a")
    pickup_frame.antialiased = true
    pickup_frame.closed = true
    pickup_frame.z_index = 1

    var visual_size: Vector2 = Vector2(12.0, 12.0)
    if sprite.texture != null:
        visual_size = sprite.region_rect.size if sprite.region_enabled else sprite.texture.get_size()
        visual_size *= sprite.scale.abs()
    var half_size: Vector2 = visual_size * 0.5 + Vector2(2.0, 2.0)
    pickup_frame.points = PackedVector2Array([
        Vector2(-half_size.x, -half_size.y),
        Vector2(half_size.x, -half_size.y),
        Vector2(half_size.x, half_size.y),
        Vector2(-half_size.x, half_size.y),
    ])
    add_child(pickup_frame)


## 使用正弦缓入缓出的循环 Tween 轻微放大缩小，避免匀速缩放显得生硬。
func _start_zoom_animation() -> void:
    var zoom_tween: Tween = create_tween().set_loops()
    zoom_tween.set_trans(Tween.TRANS_SINE)
    zoom_tween.set_ease(Tween.EASE_IN_OUT)
    zoom_tween.tween_property(self, "scale", _base_scale * 1.06, 0.7)
    zoom_tween.tween_property(self, "scale", _base_scale, 0.7)

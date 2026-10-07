## 全局预制体管理器：按资源路径缓存 PackedScene，避免调用方重复查找和转换资源。
extends Node


# 预制体资源缓存；使用 var 以允许首次加载后写入缓存，不缓存 instantiate() 创建的节点实例。
var _prefab_dictionary: Dictionary[String, PackedScene] = {}


## 获取缓存的 PackedScene；首次访问时从资源路径加载并写入缓存。
func _get_or_create_as(path: String) -> PackedScene:
    if path.is_empty():
        push_error("预制体资源路径不能为空。")
        return null
    # 命中缓存时直接返回，避免重复执行资源查找和类型转换。
    if _prefab_dictionary.has(path):
        return _prefab_dictionary[path]
    # path 是运行时字符串，不能传给要求常量路径的 preload()，因此使用 ResourceLoader。
    var loaded_resource: Resource = ResourceLoader.load(path)
    if loaded_resource == null:
        push_error("无法加载预制体资源：%s" % path)
        return null
    # 仅缓存 PackedScene，避免把其他 Resource 错当作可实例化场景。
    var packed_scene := loaded_resource as PackedScene
    if packed_scene == null:
        push_error("资源不是 PackedScene，无法作为预制体使用：%s" % path)
        return null
    _prefab_dictionary[path] = packed_scene
    return packed_scene


## 创建并配置新子弹；调用方负责设置位置并将节点加入场景树。
func create_bullet(
    faction: Definition.Faction = Definition.Faction.Player,
    damage: int = 1,
    direction: Vector2 = Vector2.RIGHT,
    bullet_type: Definition.BulletType = Definition.BulletType.Bullet
) -> ProjectileBullet:
    var packed_scene := _get_or_create_as("res://Prefab/bullet/bullet.tscn")
    if packed_scene == null:
        return null
    # 从独立子弹场景创建实例，并在加入场景树前应用本次发射的参数。
    var bullet := packed_scene.instantiate() as ProjectileBullet
    if bullet == null:
        push_error("新子弹预制体实例不是 ProjectileBullet 类型，请检查场景根节点脚本。")
        return null
    bullet.bullet_from = faction
    bullet.bullet_damage = damage
    bullet.bullet_direction = direction
    bullet.bullet_type = bullet_type
    return bullet


## 创建并配置爆炸节点；调用方负责设置位置并将节点加入场景树。
func create_explosion(
    faction: Definition.Faction = Definition.Faction.Player,
    damage: int = 10
) -> ProjectileExplosion:
    var packed_scene := _get_or_create_as("res://Prefab/explosion/explosion.tscn")
    if packed_scene == null:
        return null
    var explosion := packed_scene.instantiate() as ProjectileExplosion
    if explosion == null:
        push_error("爆炸预制体实例不是 ProjectileExplosion 类型，请检查场景根节点脚本。")
        return null
    explosion.explision_faction = faction
    explosion.explision_damange = damage
    return explosion


## 创建并配置燃烧节点；调用方负责设置位置并将节点加入场景树。
func create_burning(
    faction: Definition.Faction = Definition.Faction.Player,
    damage: int = 1,
    duration: float = 10.0,
    damage_gap: float = 0.5
) -> BurningEffect:
    var packed_scene := _get_or_create_as("res://Prefab/burning/burning.tscn")
    if packed_scene == null:
        return null
    var burning := packed_scene.instantiate() as BurningEffect
    if burning == null:
        push_error("燃烧预制体实例不是 BurningEffect 类型，请检查场景根节点脚本。")
        return null
    burning.burining_faction = faction
    burning.bruning_damage = damage
    burning.burning_duration = duration
    burning.burning_damage_gap = damage_gap
    return burning


## 创建并配置伤害飘字；调用方负责设置位置并将节点加入场景树。
func create_damage_pop(
    damage: int,
    faction: Definition.Faction
) -> DamagePop:
    var packed_scene := _get_or_create_as("res://Prefab/DamagePop/damage_pop.tscn")
    if packed_scene == null:
        return null
    var damage_pop := packed_scene.instantiate() as DamagePop
    if damage_pop == null:
        push_error("伤害飘字预制体实例不是 DamagePop 类型，请检查场景根节点脚本。")
        return null
    damage_pop.damange_num = absi(damage)
    damage_pop.damage_faction = faction
    return damage_pop


## 创建迫击炮持续打击预制体；调用方负责指定固定打击中心并加入场景树。
func create_mortar_striker() -> Node2D:
    return _create_support("res://Prefab/MortarStriker/mortar_striker.tscn", "MortarStriker")


## 创建战术轰炸预制体；调用方负责指定固定起始位置并加入场景树。
func create_tactical_bombing() -> Node2D:
    return _create_support("res://Prefab/TactialBoming/tactical_bombing.tscn", "TacticalBombing")


## 统一加载战场支援场景并检查根节点类型，避免错误资源进入关卡。
func _create_support(path: String, expected_name: String) -> Node2D:
    var packed_scene: PackedScene = _get_or_create_as(path)
    if packed_scene == null:
        return null
    var support: Node2D = packed_scene.instantiate() as Node2D
    if support == null:
        push_error("%s 预制体根节点不是 Node2D 类型：%s" % [expected_name, path])
        return null
    return support


## 创建来袭炮弹；具体落点与效果由战场支援实例在加入场景后配置。
func create_incoming_shell() -> IncomingShell:
    var packed_scene: PackedScene = _get_or_create_as("res://Prefab/IncomingShell/incoming_shell.tscn")
    if packed_scene == null:
        return null
    var shell: IncomingShell = packed_scene.instantiate() as IncomingShell
    if shell == null:
        push_error("来袭炮弹预制体实例不是 IncomingShell 类型，请检查场景根节点脚本。")
        return null
    return shell

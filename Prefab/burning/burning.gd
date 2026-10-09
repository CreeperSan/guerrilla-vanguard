## 燃烧区域：在持续时间内按固定间隔伤害范围中的敌对目标，然后自动销毁。
class_name BurningEffect
extends Area2D

const SFX_MOLOTOV_EXPLOSION: AudioStream = preload("res://Assets/Audio/SFX/molotov_explosion.wav")

## 燃烧所属阵营；玩家与盟友视为同一侧。
@export var burining_faction: Definition.Faction = Definition.Faction.Enemy

## 燃烧效果持续的秒数。
@export var burning_duration: float = 10.0

## 每次燃烧伤害之间的秒数。
@export var burning_damage_gap: float = 0.5

## 每次伤害结算的伤害值。
@export var bruning_damage: int = 1

## 创建时间保留为可编辑状态，供关卡或发射物记录燃烧来源时间。
@export var self_create_time: float = 0.0

@onready var node_ignition_audio: AudioStreamPlayer2D = get_node_or_null("IgnitionAudio") as AudioStreamPlayer2D

## 每个目标保存下一次燃烧伤害的剩余冷却；离开火区时会清除对应记录。
var _target_damage_cooldowns: Dictionary[int, float] = {}
var _remaining_duration: float = 0.0


## 初始化燃烧区域并启动按物理帧更新的接触伤害判定。
func _ready() -> void:
    # 燃烧范围也检测可破坏地形层，让箱子能受到持续伤害。
    collision_mask |= Definition.PHYSICS_LAYER_TERRAIN
    if node_ignition_audio != null:
        node_ignition_audio.stream = SFX_MOLOTOV_EXPLOSION
        node_ignition_audio.play()
    _remaining_duration = maxf(burning_duration, 0.0)


## 新进入火区的目标立即受伤；持续停留时按固定间隔再次受伤，到期释放火区。
func _physics_process(delta: float) -> void:
    if _remaining_duration <= 0.0:
        queue_free()
        return

    _damage_overlapping_targets(delta)
    _remaining_duration = maxf(_remaining_duration - delta, 0.0)
    if _remaining_duration <= 0.0:
        queue_free()


## 每帧汇总 Area2D 与物理实体，按目标根节点去重后处理进入、持续停留和离开。
func _damage_overlapping_targets(delta: float) -> void:
    var current_targets: Dictionary[int, Node] = {}
    for area: Area2D in get_overlapping_areas():
        _add_damageable_target(area, current_targets)
    for body: Node2D in get_overlapping_bodies():
        _add_damageable_target(body, current_targets)

    # 已离开燃烧范围的目标清除冷却；之后重新踏入时会再次立即受伤。
    for target_id: int in _target_damage_cooldowns.keys():
        if not current_targets.has(target_id):
            _target_damage_cooldowns.erase(target_id)

    var damage_interval := maxf(burning_damage_gap, 0.01)
    for target_id: int in current_targets:
        var target_root: Node = current_targets[target_id]
        var health: HealthComponent = target_root.get_node_or_null("Health") as HealthComponent
        if health == null:
            continue

        if not _target_damage_cooldowns.has(target_id):
            # 新进入的接触目标不等待伤害间隔，首次物理重叠即刻结算。
            health.damage(bruning_damage, burining_faction)
            _target_damage_cooldowns[target_id] = damage_interval
            continue

        var cooldown: float = float(_target_damage_cooldowns[target_id]) - delta
        if cooldown <= 0.0:
            health.damage(bruning_damage, burining_faction)
            cooldown += damage_interval
        _target_damage_cooldowns[target_id] = cooldown


## 将 HurtBox 解析到拥有生命组件的根节点，并过滤同阵营目标与重复碰撞形状。
func _add_damageable_target(target: Node, current_targets: Dictionary[int, Node]) -> void:
    if not is_instance_valid(target):
        return
    var target_root: Node = target
    if target is HurtBox:
        target_root = target.get_parent()
    if not is_instance_valid(target_root):
        return

    var health: HealthComponent = target_root.get_node_or_null("Health") as HealthComponent
    if health == null or _is_same_side(target_root):
        return
    current_targets[target_root.get_instance_id()] = target_root


## 玩家和盟友互为友军；其他未声明 faction 的生命目标按敌人处理。
func _is_same_side(target_root: Node) -> bool:
    var target_faction: Definition.Faction = Definition.Faction.Enemy
    if target_root is Player:
        target_faction = Definition.Faction.Player
    else:
        for property: Dictionary in target_root.get_property_list():
            if property.get("name") == "faction":
                target_faction = target_root.get("faction")
                break

    return target_faction == burining_faction \
        or (target_faction != Definition.Faction.Enemy and burining_faction != Definition.Faction.Enemy)

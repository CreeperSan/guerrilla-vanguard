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


## 启动持续伤害循环；循环中会重新查询重叠对象以同步进入和离开的目标。
func _ready() -> void:
    if node_ignition_audio != null:
        node_ignition_audio.stream = SFX_MOLOTOV_EXPLOSION
        node_ignition_audio.play()
    _apply_damage_over_time()


## 按伤害间隔结算当前范围中的敌对目标，到期后自动释放燃烧区域。
func _apply_damage_over_time() -> void:
    var remaining_time: float = maxf(burning_duration, 0.0)
    var damage_interval: float = maxf(burning_damage_gap, 0.01)

    # 首次结算放在物理帧之后，保证 Area2D 已经完成初始重叠检测。
    await get_tree().physics_frame
    while is_inside_tree() and remaining_time > 0.0:
        _damage_overlapping_targets()

        var wait_time: float = minf(damage_interval, remaining_time)
        await get_tree().create_timer(wait_time).timeout
        remaining_time -= wait_time

    if is_inside_tree():
        queue_free()


## 对本次采样中的每个目标至多造成一次伤害。
func _damage_overlapping_targets() -> void:
    var hit_targets: Dictionary[int, bool] = {}
    for area: Area2D in get_overlapping_areas():
        _damage_target(area, hit_targets)
    for body: Node2D in get_overlapping_bodies():
        _damage_target(body, hit_targets)


## 解析 HurtBox 或角色本体，过滤同阵营目标并调用其 HealthComponent。
func _damage_target(target: Node, hit_targets: Dictionary[int, bool]) -> void:
    var target_root: Node = target
    if target is HurtBox:
        target_root = target.get_parent()
    if target_root == null:
        return

    var target_id: int = target_root.get_instance_id()
    if hit_targets.has(target_id):
        return

    var health: HealthComponent = target_root.get_node_or_null("Health") as HealthComponent
    if health == null or _is_same_side(target_root):
        return

    hit_targets[target_id] = true
    health.damage(bruning_damage)


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

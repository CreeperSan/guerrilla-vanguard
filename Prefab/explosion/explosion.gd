## 爆炸区域：播放一次性动画，对范围内有效目标造成一次伤害后自动销毁。
class_name ProjectileExplosion
extends Area2D

## 爆炸所属阵营，用于避免伤害同阵营目标。
@export var explision_faction: Definition.Faction = Definition.Faction.Enemy

## 爆炸对每个有效目标造成的伤害。
@export var explision_damange: int = 10

## 可选爆炸半径；0 沿用原场景，RPG 在加入场景树前覆盖为独立范围。
var blast_radius: float = 0.0

## 动画播放速度；动画结束后爆炸节点会自动销毁。
@export var animation_speed: float = 10.0

@onready var node_animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var node_audio: AudioStreamPlayer2D = get_node_or_null("ExplosionAudio") as AudioStreamPlayer2D

## 记录已经命中过的目标，避免范围持续重叠时重复结算伤害。
var damaged_targets: Dictionary[int, bool] = {}


## 初始化一次性动画、范围检测和生命周期信号。
func _ready() -> void:
    if blast_radius > 0.0:
        # 独立复制资源，避免 RPG 的半径污染手雷等其他爆炸实例。
        var collision := $CollisionShape2D as CollisionShape2D
        var circle := collision.shape.duplicate() as CircleShape2D
        var original_radius: float = maxf(circle.radius, 0.1)
        circle.radius = blast_radius
        collision.shape = circle
        node_animation.scale *= blast_radius / original_radius
    # 爆炸范围也检测可破坏地形层，让箱子能受到范围伤害。
    collision_mask |= Definition.PHYSICS_LAYER_TERRAIN
    area_entered.connect(_on_area_entered)
    body_entered.connect(_on_body_entered)
    node_animation.animation_finished.connect(_on_animation_finished)

    # 当前爆炸动画资源可能设置为循环播放；改成单次播放才能可靠收到结束信号。
    node_animation.sprite_frames.set_animation_loop(node_animation.animation, false)
    node_animation.speed_scale = maxf(animation_speed / maxf(node_animation.sprite_frames.get_animation_speed(node_animation.animation), 0.001), 0.001)
    node_animation.play()
    if node_audio != null:
        node_audio.play()

    # 初始检测处理爆炸生成时已经处于范围内的对象。
    await get_tree().physics_frame
    if is_inside_tree():
        for area: Area2D in get_overlapping_areas():
            _apply_damage_to(area)
        for body: Node2D in get_overlapping_bodies():
            _apply_damage_to(body)


## 面积型碰撞对象进入爆炸范围时尝试造成伤害。
func _on_area_entered(area: Area2D) -> void:
    _apply_damage_to(area)


## 角色等物理实体进入爆炸范围时尝试造成伤害。
func _on_body_entered(body: Node2D) -> void:
    _apply_damage_to(body)


## 查找目标生命组件并进行阵营过滤，每个目标只结算一次。
func _apply_damage_to(target: Node) -> void:
    var target_root: Node = target
    if target is HurtBox:
        target_root = target.get_parent()

    if target_root == null:
        return
    # 闪避期间跳过爆炸命中记录，避免免疫帧内的碰撞被标记为已受击。
    var player_target: Player = target_root as Player
    if player_target != null and player_target.dodge_active:
        return

    var target_id: int = target_root.get_instance_id()
    if damaged_targets.has(target_id):
        return

    var health: HealthComponent = target_root.get_node_or_null("Health") as HealthComponent
    if health == null:
        return

    # Player 类型明确代表玩家阵营；带 faction 属性的其他目标可自行声明阵营。
    var target_faction: Definition.Faction = Definition.Faction.Enemy
    if target_root is Player:
        target_faction = Definition.Faction.Player
    else:
        for property: Dictionary in target_root.get_property_list():
            if property.get("name") == "faction":
                target_faction = target_root.get("faction")
                break

    # 玩家与盟友属于同一侧，避免默认盟友爆炸误伤玩家。
    var same_side: bool = target_faction == explision_faction \
        or (target_faction != Definition.Faction.Enemy and explision_faction != Definition.Faction.Enemy)
    if same_side:
        return

    damaged_targets[target_id] = true
    health.damage(explision_damange, explision_faction)


## 一次性爆炸动画播放完毕后释放节点。
func _on_animation_finished() -> void:
    queue_free()

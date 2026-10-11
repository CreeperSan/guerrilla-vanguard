## 独立的角色遗体：接管三帧死亡演出，随后仅留下一个静态 Sprite2D。
## 不持有生命、AI、碰撞或导航组件，也不运行逐帧逻辑；房间销毁时一起回收。
class_name CharacterRemains
extends Node2D

signal settled

enum Appearance { PLAYER, SOLDIER, COMMANDER, MERCENARY, VICTORY }

const DEFAULT_CONFIG: DeathVisualConfig = preload("res://Script/Presentation/death_visuals.tres")
const ACTOR_META := "character_remains_instance"

## 预算与图集都可以在场景 Inspector 或外部资源中编辑。
@export var config: DeathVisualConfig = DEFAULT_CONFIG
@export var appearance: Appearance = Appearance.SOLDIER
@export var ground_z_index: int = -3
var is_settled := false
var _scope: Node
var _retiring := false
@onready var sprite: Sprite2D = $Sprite2D


## 从可见角色贴图复制世界变换，先显示新姿态，再隐藏原角色，避免闪现和位置跳动。
## 元数据保证同一死亡事件只有一份遗体；胜利姿态也复用此演出但不计入遗体预算。
static func spawn_for_actor(actor: Node2D, style: Appearance, profile: DeathVisualConfig = DEFAULT_CONFIG) -> CharacterRemains:
    var previous: Variant = actor.get_meta(ACTOR_META) if actor.has_meta(ACTOR_META) else null
    if previous is WeakRef:
        var existing := previous.get_ref() as CharacterRemains
        if is_instance_valid(existing):
            return existing
    var source := _find_visual(actor)
    var visual_transform := source.global_transform if source != null else actor.global_transform
    var source_size := _visual_size(source, profile.frame_size)
    var parent := actor.get_parent()
    # 普通敌人一般直接属于 Room；嵌套敌人同样归最近的 Room 管理。
    var ancestor := parent
    while ancestor != null:
        if ancestor.has_method("is_room_safe"):
            parent = ancestor
            break
        ancestor = ancestor.get_parent()
    var remains := load("res://Prefab/Corpse/Corpse.tscn").instantiate() as CharacterRemains
    remains.config = profile
    remains.appearance = style
    if style == Appearance.VICTORY:
        remains.ground_z_index = 2
    remains._scope = parent
    parent.add_child(remains)
    remains.global_transform = visual_transform
    remains.scale *= Vector2(source_size) / Vector2(profile.frame_size)
    if source is Sprite2D or source is AnimatedSprite2D:
        remains.sprite.flip_h = source.flip_h
        remains.sprite.flip_v = source.flip_v
    actor.set_meta(ACTOR_META, weakref(remains))
    _disable_actor(actor)
    return remains


## 找到实际可见的身体贴图；坦克最终阶段使用驾驶员而非已经隐藏的车体。
static func _find_visual(actor: Node) -> Node2D:
    for child: Node in actor.get_children():
        if child is CanvasItem and not child.visible:
            continue
        if child is Sprite2D or child is AnimatedSprite2D:
            return child
        var nested := _find_visual(child)
        if nested != null:
            return nested
    return null


## 图集帧尺寸用于匹配角色原来的世界比例，不把 Boss 和驾驶员缩成统一尺寸。
static func _visual_size(source: Node2D, fallback: Vector2i) -> Vector2i:
    if source is Sprite2D and source.texture != null:
        return Vector2i(source.texture.get_size() / Vector2(source.hframes, source.vframes))
    if source is AnimatedSprite2D and source.sprite_frames != null:
        var texture: Texture2D = source.sprite_frames.get_frame_texture(source.animation, source.frame)
        if texture != null:
            return Vector2i(texture.get_size())
    return fallback


## 立即退出战斗分组、关闭输入和 AI；物理属性延迟修改以兼容子弹碰撞回调。
## 玩家节点保留供 HUD/结算读取，敌人由原有死亡函数继续 queue_free。
static func _disable_actor(actor: Node2D) -> void:
    for group: String in ["enemies", "combat_targets", "hired_mercenaries"]:
        actor.remove_from_group(group)
    if actor is CharacterBody2D:
        actor.velocity = Vector2.ZERO
    actor.process_mode = Node.PROCESS_MODE_DISABLED
    actor.hide()
    var nodes: Array[Node] = [actor]
    nodes.append_array(actor.find_children("*", "Node", true, false))
    for node: Node in nodes:
        if node is CollisionObject2D:
            node.set_deferred("collision_layer", 0)
            node.set_deferred("collision_mask", 0)
        if node is Area2D:
            node.set_deferred("monitoring", false)
            node.set_deferred("monitorable", false)
        if node is CollisionShape2D or node is CollisionPolygon2D:
            node.set_deferred("disabled", true)


## 演出使用有限的 Tween 回调；即使终局暂停了世界，已开始的倒地动作也会播完。
func _ready() -> void:
    z_index = ground_z_index
    _set_frame(0)
    if appearance != Appearance.VICTORY:
        add_to_group("character_remains")
        _enforce_budget()
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    for frame: int in range(1, config.frame_count):
        tween.tween_interval(1.0 / config.frames_per_second)
        tween.tween_callback(_set_frame.bind(frame))
    tween.tween_interval(1.0 / config.frames_per_second)
    tween.tween_callback(_settle)


## AtlasTexture 只引用共享图集，不复制或每帧截取显存中的图像。
func _set_frame(frame: int) -> void:
    var texture := AtlasTexture.new()
    texture.atlas = config.atlas
    texture.region = Rect2(Vector2(frame * config.frame_size.x, int(appearance) * config.frame_size.y), Vector2(config.frame_size))
    sprite.texture = texture


## 最后一帧保持不变，外部只需监听一次完成信号。
func _settle() -> void:
    is_settled = true
    settled.emit()


## 按房间和关卡双重限制数量；已淡出的节点不再占预算，防止密集死亡反复淘汰同一个节点。
func _enforce_budget() -> void:
    var room_bodies: Array[CharacterRemains] = []
    var level_bodies: Array[CharacterRemains] = []
    for node: Node in get_tree().get_nodes_in_group("character_remains"):
        var body := node as CharacterRemains
        if body == null or body._retiring or body.is_queued_for_deletion():
            continue
        if body._scope == _scope:
            room_bodies.append(body)
        # 不同房间的共同父节点是关卡；玩家则直接挂在关卡下。
        if body._level_scope() == _level_scope():
            level_bodies.append(body)
    while room_bodies.size() > config.room_limit:
        room_bodies.pop_front()._retire()
    level_bodies = level_bodies.filter(func(body): return not body._retiring)
    while level_bodies.size() > config.level_limit:
        level_bodies.pop_front()._retire()


## Room 的父节点就是关卡；测试或独立场景中的其他容器自身就是预算作用域。
func _level_scope() -> Node:
    if is_instance_valid(_scope) and _scope.has_method("is_room_safe"):
        return _scope.get_parent()
    return _scope


## 超预算遗体短暂淡出后释放；普通静态遗体永远不创建循环计时器。
func _retire() -> void:
    _retiring = true
    remove_from_group("character_remains")
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(self, "modulate:a", 0.0, config.eviction_fade)
    tween.tween_callback(queue_free)

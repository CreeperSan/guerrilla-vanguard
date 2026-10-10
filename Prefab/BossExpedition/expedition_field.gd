## 八主题首领的有限寿命危险区：预警、伤害范围和实际判定共享同一半径。
## 所有效果归属当前房间，继承暂停；可射毁陷阱不会产生爆炸或额外收益。
class_name ExpeditionField
extends Node2D

## delay 秒内仅预警；激活后持续 lifetime 秒，每 tick 秒结算一次敌对目标伤害。
var delay: float = 1.0
var lifetime: float = 3.0
var radius: float = 42.0
var damage: int = 3
var tick: float = 0.75
var destructible: bool = false
var tint: Color = Color(0.5, 0.9, 0.2, 0.7)
## 拖拽只通过物理移动实现，碰到墙会停止，不直接改写角色位置。
var pull_origin: Vector2 = Vector2.INF
var _contacts: Dictionary = {}
var _active: bool = false
var _spent: bool = false


## 陷阱使用敌方 HurtBox，复用玩家和佣兵弹丸的阵营判定。
func _ready() -> void:
    add_to_group("boss_hazards")
    if not destructible:
        return
    var health := HealthComponent.new()
    health.name = "Health"
    health.health = 6
    health.health_max = 6
    add_child(health)
    health.sig_die.connect(_disarm)
    var hurt := HurtBox.new()
    hurt.name = "HurtBox"
    hurt.collision_layer = 2
    hurt.collision_mask = 4
    var collision := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 12.0
    collision.shape = shape
    hurt.add_child(collision)
    add_child(hurt)


## 射毁即时停用逻辑，延迟释放碰撞节点以兼容物理查询。
func _disarm() -> void:
    _spent = true
    queue_free()


## 进入危险区立即命中，持续停留按独立目标计时；离开后重入重新判定。
func _physics_process(delta: float) -> void:
    if _spent:
        return
    if not _active:
        delay -= delta
        if delay > 0:
            queue_redraw()
            return
        _active = true
    lifetime -= delta
    if lifetime <= 0:
        _disarm()
        return
    var inside: Dictionary = {}
    for candidate: Node in get_tree().get_nodes_in_group("combat_targets"):
        var target := candidate as Node2D
        if not is_instance_valid(target) or target.is_queued_for_deletion():
            continue
        var health := target.get_node_or_null("Health") as HealthComponent
        if health == null or health.health <= 0 or global_position.distance_to(target.global_position) > radius:
            continue
        var id := target.get_instance_id()
        var remaining: float = float(_contacts.get(id, 0.0)) - delta
        if remaining <= 0:
            health.damage(damage, Definition.Faction.Enemy, global_position)
            remaining = tick
        inside[id] = remaining
        if pull_origin.is_finite() and target is CharacterBody2D:
            target.move_and_collide(target.global_position.direction_to(pull_origin) * minf(35.0 * delta, target.global_position.distance_to(pull_origin)))
    _contacts = inside
    queue_redraw()


## 十字预警与半透明实体区不遮挡角色；绳索与拖拽起点保持同步。
func _draw() -> void:
    if _spent:
        return
    if _active:
        draw_circle(Vector2.ZERO, radius, Color(tint, 0.2))
    draw_arc(Vector2.ZERO, radius, 0, TAU, 40, tint, 2.0)
    draw_line(Vector2(-9, 0), Vector2(9, 0), tint, 2)
    draw_line(Vector2(0, -9), Vector2(0, 9), tint, 2)
    if destructible:
        draw_circle(Vector2.ZERO, 8, tint)
    if pull_origin.is_finite():
        draw_line(Vector2.ZERO, to_local(pull_origin), tint, 2)

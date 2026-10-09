## 可配置子弹：按速度和射程移动，命中目标后造成伤害或生成范围效果。
class_name ProjectileBullet
extends Area2D

## 子弹所属阵营。
@export var bullet_from: Definition.Faction = Definition.Faction.Player
## 普通子弹命中时造成的伤害，也作为爆炸/燃烧效果的基础伤害。
@export var bullet_damage: int = 1
## 可穿透的额外目标数；0 表示首次命中后结束。
@export var bullet_penetration: int = 0
## 子弹最大飞行距离，单位为像素。
@export var bullet_range: float = 500.0
## 子弹移动速度，单位为像素/秒。
@export var bullet_speed: float = 400.0
## 碰撞圆半径，运行时同步到 CollisionShape2D。
@export var bullet_size: float = 2.0
## 最大存续秒数，用作射程之外的安全回收条件。
@export var bullet_duration: float = 10.0
## 命中后的效果类型。
@export var bullet_type: Definition.BulletType = Definition.BulletType.Bullet
## 燃烧弹触发的燃烧持续时间与伤害间隔。
@export var bullet_effect_duration: float = 10.0
@export var bullet_effect_damage_gap: float = 0.5
## 子弹移动方向。
@export var bullet_direction: Vector2 = Vector2.RIGHT

## 非空样式启用新武器的扫掠检测与程序绘制；原有投掷物和子弹保持原流程。
var projectile_style: String = ""
## RPG 专属爆炸半径；0 表示沿用原预制体尺寸。
var explosion_radius: float = 0.0
## 火焰速度低于此值时回收，避免静止残留的伤害区域。
const FLAME_STOP_SPEED: float = 8.0
## 每次命中后的保速倍率和最大偏转角；第三名敌人命中后立即结束。
const FLAME_HIT_SPEED_FACTOR: float = 0.68
const FLAME_DEFLECTION: float = 0.12
## 同一目标的身体与 HurtBox 共用命中记录，防止穿透弹重复伤害同一人。
var _hit_targets: Dictionary[int, bool] = {}
## 按升级后射程计算火焰减速度，保持基础自由飞行距离约 125 像素。
var _flame_deceleration: float = 0.0
## 墙面偏转保护，避免同一位置的多个墙体回调反复弹跳。
var _wall_deflection_time: float = -1.0

## 子弹精灵节点，用于根据阵营切换外观。
@onready var node_sprite: Sprite2D = $Sprite2D
## 子弹碰撞节点，用于应用导出的命中半径。
@onready var node_collision_shape: CollisionShape2D = $CollisionShape2D

## 当前累计飞行距离，用于触发射程终点效果。
var _travelled_distance: float = 0.0
## 当前存续时间，用于超时回收。
var _elapsed_time: float = 0.0
## 初始化时复制穿透配置，命中后递减。
var _remaining_penetration: int = 0
## 防止同一帧的多个碰撞回调重复销毁或生成效果。
var _is_finished: bool = false


## 初始化碰撞、外观、阵营检测和子弹初始状态。
func _ready() -> void:
    area_entered.connect(_on_area_entered)
    body_entered.connect(_on_body_entered)
    # 玩家和敌方子弹都能命中墙；水层不加入掩码，因此子弹可以穿过水面。
    collision_mask = (2 if bullet_from == Definition.Faction.Player else 3) | Definition.PHYSICS_LAYER_TERRAIN
    _remaining_penetration = maxi(bullet_penetration, 0)
    bullet_direction = bullet_direction.normalized()
    if bullet_direction == Vector2.ZERO:
        bullet_direction = Vector2.RIGHT

    # 独立复制形状，兼容仍使用共享子资源的旧内嵌场景。
    node_collision_shape.shape = node_collision_shape.shape.duplicate()
    var circle_shape := node_collision_shape.shape as CircleShape2D
    if circle_shape != null:
        circle_shape.radius = maxf(bullet_size, 0.1)

    if not projectile_style.is_empty():
        node_sprite.visible = false
        _flame_deceleration = bullet_speed * bullet_speed / (2.0 * maxf(bullet_range, 1.0))
        queue_redraw()

    # 投掷物沿用原显示尺寸；普通弹使用约6像素直径的高亮圆形外观。
    # 玩家黄白、敌方红白，明亮核心与深色描边同时适配深浅地图；物理半径仍由 bullet_size 决定。
    # TestLevel 内嵌弹丸仍带旧图集裁切区域；独立图片必须取消裁切才能完整显示。
    node_sprite.region_enabled = false
    if bullet_type == Definition.BulletType.Explosion:
        node_sprite.texture = load("res://Assets/Art/MilitaryArcade/World/grenade_flight.png")
        node_sprite.scale = Vector2(0.1625, 0.1625)
    elif bullet_type == Definition.BulletType.Burning:
        node_sprite.texture = load("res://Assets/Art/MilitaryArcade/World/molotov_flight.png")
        node_sprite.scale = Vector2(0.1625, 0.1625)
    elif bullet_from == Definition.Faction.Enemy:
        node_sprite.scale = Vector2(0.09375, 0.09375)
        node_sprite.texture = load("res://Assets/Art/MilitaryArcade/World/enemy_bullet_round.png")
    else:
        node_sprite.scale = Vector2(0.09375, 0.09375)
        node_sprite.texture = load("res://Assets/Art/MilitaryArcade/World/player_bullet_round.png")


## 推进子弹并在射程或存续时间耗尽时触发最终效果。
func _physics_process(delta: float) -> void:
    if _is_finished:
        return

    var previous_speed: float = bullet_speed
    if projectile_style == "flamethrower":
        bullet_speed = maxf(bullet_speed - _flame_deceleration * delta, 0.0)
        if bullet_speed <= FLAME_STOP_SPEED:
            _finish_at(global_position)
            return
    # 梯形积分让减速弹在不同物理帧率下保持近似相同射程。
    var step_distance: float = maxf((previous_speed + bullet_speed) * 0.5, 0.0) * delta
    step_distance = minf(step_distance, maxf(bullet_range - _travelled_distance, 0.0))
    if projectile_style.is_empty():
        global_position += bullet_direction * step_distance
    else:
        _sweep_motion(step_distance)
        queue_redraw()
    _travelled_distance += step_distance
    _elapsed_time += delta

    if _travelled_distance >= maxf(bullet_range, 0.0) or _elapsed_time >= maxf(bullet_duration, 0.0):
        _finish_at(global_position)


## 处理敌方 HurtBox 命中；非伤害区域不消耗穿透次数。
func _on_area_entered(area: Area2D) -> void:
    if area is HurtBox:
        _handle_hit(area)


## 处理带生命组件的物理角色命中。
func _on_body_entered(body: Node2D) -> void:
    if body.get_node_or_null("Health") is HealthComponent:
        _handle_hit(body)
    elif (body.collision_layer & Definition.PHYSICS_LAYER_TERRAIN) != 0:
        # 墙体会截停普通弹丸；爆炸类弹丸则在接触墙面的位置触发范围效果。
        if projectile_style == "flamethrower":
            _deflect_from_wall()
        else:
            _finish_at(global_position)


## 依据子弹类型直接伤害或生成效果，并应用穿透次数。
func _handle_hit(target: Node) -> void:
    if _is_finished:
        return

    var target_root: Node = target.get_parent() if target is HurtBox else target
    var is_damageable_terrain: bool = target_root != null and target_root.is_in_group("damageable_terrain")
    if target_root == null or (_is_same_side(target_root) and not is_damageable_terrain):
        return
    # 闪避期间不结算命中，也不消耗子弹，让炮弹继续通过玩家位置。
    var player_target: Player = target_root as Player
    if player_target != null and player_target.dodge_active:
        return

    var health: HealthComponent = target_root.get_node_or_null("Health") as HealthComponent
    var target_id: int = target_root.get_instance_id()
    if health == null or health.health <= 0 or _hit_targets.has(target_id):
        return
    _hit_targets[target_id] = true
    if projectile_style == "flamethrower":
        bullet_speed *= FLAME_HIT_SPEED_FACTOR
        bullet_direction = bullet_direction.rotated(randf_range(-FLAME_DEFLECTION, FLAME_DEFLECTION))

    match bullet_type:
        Definition.BulletType.Bullet:
            health.damage(bullet_damage, bullet_from)
        Definition.BulletType.Explosion:
            _spawn_explosion(global_position)
            _is_finished = true
            queue_free()
            return
        Definition.BulletType.Burning:
            _spawn_burning(global_position)
            _is_finished = true
            queue_free()
            return

    if _remaining_penetration <= 0 or (projectile_style == "flamethrower" and bullet_speed <= FLAME_STOP_SPEED):
        _is_finished = true
        queue_free()
    else:
        _remaining_penetration -= 1


## 普通子弹射程耗尽时消失，范围弹则在当前位置生成对应效果。
func _finish_at(effect_position: Vector2) -> void:
    if _is_finished:
        return
    _is_finished = true

    match bullet_type:
        Definition.BulletType.Explosion:
            _spawn_explosion(effect_position)
        Definition.BulletType.Burning:
            _spawn_burning(effect_position)

    queue_free()


## 使用全局预制体管理器创建并配置爆炸效果。
func _spawn_explosion(effect_position: Vector2) -> void:
    var explosion: ProjectileExplosion = PrefabManager.create_explosion(bullet_from, bullet_damage)
    if explosion == null:
        return
    var effect_parent: Node2D = get_parent() as Node2D
    if effect_parent == null:
        return
    if explosion_radius > 0.0:
        explosion.blast_radius = explosion_radius
    explosion.position = effect_parent.to_local(effect_position)
    effect_parent.add_child(explosion)


## 使用全局预制体管理器创建并配置燃烧效果。
func _spawn_burning(effect_position: Vector2) -> void:
    var burning: BurningEffect = PrefabManager.create_burning(
        bullet_from,
        bullet_damage,
        bullet_effect_duration,
        bullet_effect_damage_gap
    )
    if burning == null:
        return
    var effect_parent: Node2D = get_parent() as Node2D
    if effect_parent == null:
        return
    burning.position = effect_parent.to_local(effect_position)
    effect_parent.add_child(burning)


## 玩家与盟友互为友军；其他未声明阵营的生命目标按敌人处理。
func _is_same_side(target_root: Node) -> bool:
    var target_faction: Definition.Faction = Definition.Faction.Enemy
    if target_root is Player:
        target_faction = Definition.Faction.Player
    else:
        for property: Dictionary in target_root.get_property_list():
            if property.get("name") == "faction":
                target_faction = target_root.get("faction")
                break

    return target_faction == bullet_from \
        or (target_faction != Definition.Faction.Enemy and bullet_from != Definition.Faction.Enemy)


## 新武器按碰撞半径细分位移，补足 Area2D 高速移动可能漏过薄目标的问题。
## 火焰使用宽圆形查询；每段先处理墙，再处理生命目标，避免伤害墙后的敌人。
func _sweep_motion(distance: float) -> void:
    var steps: int = maxi(ceili(distance / maxf(bullet_size * 0.75, 1.0)), 1)
    var step: float = distance / float(steps)
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = node_collision_shape.shape
    query.collision_mask = collision_mask
    query.collide_with_areas = true
    query.collide_with_bodies = true
    query.exclude = [get_rid()]
    for index: int in range(steps):
        if _is_finished:
            return
        var previous_position := global_position
        global_position += bullet_direction * step
        query.transform = Transform2D(0.0, global_position)
        var hits := get_world_2d().direct_space_state.intersect_shape(query, 64)
        for hit: Dictionary in hits:
            var body := hit["collider"] as PhysicsBody2D
            if body != null and (body.collision_layer & Definition.PHYSICS_LAYER_TERRAIN) != 0:
                if projectile_style == "flamethrower":
                    # 可破坏箱体先受伤再挡住火焰，实墙仅反弹；两者都不允许穿墙。
                    if body.get_node_or_null("Health") is HealthComponent:
                        _handle_hit(body)
                    global_position = previous_position
                    _deflect_from_wall()
                    return
                # 木箱有生命组件：狙击弹按穿透次数结算；实墙终止飞行。
                if not body.get_node_or_null("Health") is HealthComponent:
                    _finish_at(global_position)
                    return
        for hit: Dictionary in hits:
            if _is_finished:
                return
            var collider := hit["collider"] as Node2D
            if collider is Area2D:
                _on_area_entered(collider)
            elif collider is PhysicsBody2D:
                _on_body_entered(collider)


## 无生命墙体使火焰反弹并损失速度；不会穿墙或因重复回调快速反复翻转。
func _deflect_from_wall() -> void:
    if _is_finished or is_equal_approx(_wall_deflection_time, _elapsed_time):
        return
    _wall_deflection_time = _elapsed_time
    bullet_direction = (-bullet_direction).rotated(randf_range(-FLAME_DEFLECTION, FLAME_DEFLECTION))
    bullet_speed *= 0.55
    if bullet_speed <= FLAME_STOP_SPEED:
        _finish_at(global_position)


## 程序绘制弹丸动画：狙击曳光、带尾焰火箭和不断膨胀衰减的火团。
## 绘制与物理圆形共用半径，火焰不会出现视觉小而伤害范围过大的错觉。
func _draw() -> void:
    if projectile_style.is_empty():
        return
    var direction := bullet_direction.normalized()
    match projectile_style:
        "sniper":
            draw_line(-direction * 18.0, direction * 3.0, Color("482f1d"), 4.0)
            draw_line(-direction * 16.0, direction * 3.0, Color("fff1a3"), 2.0)
        "rocket":
            var side := direction.orthogonal()
            draw_colored_polygon(PackedVector2Array([-direction * 9.0 + side * 3.0, direction * 5.0 + side * 3.0, direction * 10.0, direction * 5.0 - side * 3.0, -direction * 9.0 - side * 3.0]), Color("626849"))
            draw_line(-direction * 10.0, -direction * (18.0 + sin(_elapsed_time * 65.0) * 3.0), Color("ffb846"), 4.0)
        "flamethrower":
            var life: float = clampf(_travelled_distance / maxf(bullet_range, 1.0), 0.0, 1.0)
            var radius: float = bullet_size * lerpf(0.65, 1.0, life)
            var alpha: float = lerpf(0.95, 0.35, life)
            draw_circle(Vector2.ZERO, radius, Color(1.0, 0.22, 0.03, alpha))
            draw_circle(direction * 2.0, radius * 0.65, Color(1.0, 0.65, 0.08, alpha))
            draw_circle(direction * 3.0, radius * 0.32, Color(1.0, 0.96, 0.58, alpha))

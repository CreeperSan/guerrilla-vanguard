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

    var circle_shape := node_collision_shape.shape as CircleShape2D
    if circle_shape != null:
        circle_shape.radius = maxf(bullet_size, 0.1)

    # 特殊投掷弹使用对应拾取物图标，普通子弹继续按阵营显示弹丸贴图。
    if bullet_type == Definition.BulletType.Explosion:
        node_sprite.texture = load("res://Prefab/grenade/grenade.png")
        node_sprite.scale = Vector2(0.65, 0.65)
    elif bullet_type == Definition.BulletType.Burning:
        node_sprite.texture = load("res://Prefab/molotov/molotov.png")
        node_sprite.scale = Vector2(0.65, 0.65)
    elif bullet_from == Definition.Faction.Enemy:
        node_sprite.texture = load("res://Prefab/bullet/bullet_enemy.png")
    else:
        node_sprite.texture = load("res://Prefab/bullet/bullet_player.png")


## 推进子弹并在射程或存续时间耗尽时触发最终效果。
func _physics_process(delta: float) -> void:
    if _is_finished:
        return

    var step_distance: float = maxf(bullet_speed, 0.0) * delta
    global_position += bullet_direction * step_distance
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

    match bullet_type:
        Definition.BulletType.Bullet:
            var health: HealthComponent = target_root.get_node_or_null("Health") as HealthComponent
            if health != null:
                health.damage(bullet_damage)
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

    if _remaining_penetration <= 0:
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

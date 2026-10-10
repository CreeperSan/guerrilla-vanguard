## 夜幕搭档、机械犬与窗口护卫：独立受击实体，生命周期由所属首领管理。
## 不补员、不发放独立收益；房间暂停和地形碰撞继续使用现有合约。
class_name ExpeditionCompanion
extends CharacterBody2D

signal defeated

## role 0 为近战搭档，1 为机械犬，2 为静态窗口枪手。
var role: int = 0
var commander: TacticalBoss
var art: Texture2D
var _health: HealthComponent
var _sprite: Sprite2D
var _state: String = "follow"
var _remaining: float = 1.5
var _direction: Vector2 = Vector2.DOWN
var _hit: bool = false
var _dead: bool = false


## 在入树时构造实际受击、地形碰撞和精灵，避免仅作为不可交互装饰。
func _ready() -> void:
    add_to_group("enemies")
    set_meta("suppress_death_rewards", true)
    collision_layer = 0
    collision_mask = Definition.PHYSICS_LAYER_TERRAIN | Definition.PHYSICS_LAYER_WATER
    _health = HealthComponent.new()
    _health.name = "Health"
    _health.health_max = 70 if role == 0 else (45 if role == 1 else 18)
    _health.health = _health.health_max
    add_child(_health)
    _health.sig_die.connect(_die)
    _sprite = Sprite2D.new()
    _sprite.texture = art
    _sprite.hframes = 1 if art.get_height() > art.get_width() else 4
    _sprite.vframes = 4 if art.get_height() > art.get_width() else 1
    _sprite.scale = Vector2.ONE * 0.22
    add_child(_sprite)
    var body := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 12
    body.shape = shape
    add_child(body)
    var hurt := HurtBox.new()
    hurt.name = "HurtBox"
    hurt.collision_layer = 2
    hurt.collision_mask = 4
    var collision := CollisionShape2D.new()
    collision.shape = shape
    hurt.add_child(collision)
    add_child(hurt)


## 近战始终先锁向预警再突进；窗口枪手单发射击且受视线限制。
func _physics_process(delta: float) -> void:
    if _dead or not is_instance_valid(commander) or commander.is_queued_for_deletion():
        queue_free()
        return
    var target := commander._find_combat_target()
    if target == null:
        return
    _remaining -= delta
    if _state == "warning":
        if _remaining <= 0:
            _state = "dash"
            _remaining = 0.5
            _hit = false
    elif _state == "dash":
        velocity = _direction * (190 if role == 1 else 150)
        move_and_slide()
        if not _hit and global_position.distance_to(target.global_position) < 26:
            target.get_node("Health").damage(4, Definition.Faction.Enemy, global_position)
            _hit = true
        if _remaining <= 0 or get_slide_collision_count() > 0:
            _state = "follow"
            _remaining = 2.8
    else:
        _direction = global_position.direction_to(target.global_position)
        if role != 2:
            velocity = _direction * (65 if role == 1 else 48)
            if global_position.distance_to(target.global_position) > 110:
                move_and_slide()
        if _remaining <= 0:
            if role == 2:
                var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, Definition.PHYSICS_LAYER_TERRAIN)
                if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
                    var bullet := PrefabManager.create_bullet(Definition.Faction.Enemy, 3, _direction)
                    if bullet != null:
                        bullet.position = position + _direction * 18
                        get_parent().add_child(bullet)
                _remaining = 2.2
            elif role == 1 or commander.state == "recover":
                _state = "warning"
                _remaining = 0.9
    _sprite.frame = 1 if absf(_direction.x) > absf(_direction.y) and _direction.x > 0 else (3 if absf(_direction.x) > absf(_direction.y) else (2 if _direction.y < 0 else 0))
    queue_redraw()


## 先锁死动作再通知领袖，重复伤害不会重复触发阶段切换。
func _die() -> void:
    if _dead:
        return
    _dead = true
    defeated.emit()
    queue_free()


## 突进方向与攻击锁向一致；小血条便于玩家选择先攻击搭档或机械犬。
func _draw() -> void:
    if _health == null:
        return
    draw_rect(Rect2(-18, -34, 36, 3), Color(0.1, 0.1, 0.1))
    draw_rect(Rect2(-18, -34, 36.0 * _health.health / _health.health_max, 3), Color(1, 0.6, 0.15))
    if _state == "warning":
        draw_line(Vector2.ZERO, _direction * 100, Color(1, 0.5, 0.1), 2)

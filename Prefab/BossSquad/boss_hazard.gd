## Boss 地雷/手雷落点：统一可视预警、延迟爆炸和地雷射毁，不直接伤害友军。
## 生命周期归属所在 Boss 房；最终死亡清场会统一删除 boss_hazards 组节点。
class_name BossHazard
extends Node2D

## 手雷会自动爆炸；地雷启动后只在敌对目标进入时或遥控倒计时结束时引爆。
var is_mine: bool = false
var delay: float = 1.5
var radius: float = 40.0
var damage: int = 6
var armed: bool = false
var detonation_remaining: float = -1.0
## 手雷空中轨迹仅负责表现；落点与引信在投掷时锁定。
var throw_origin: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _spent: bool = false


## 地雷构建独立生命与 HurtBox，沿用玩家子弹的阵营判定。
func _ready() -> void:
    add_to_group("boss_hazards")
    if is_mine:
        var health := HealthComponent.new()
        health.name = "Health"
        health.health = 4
        health.health_max = 4
        add_child(health)
        health.sig_die.connect(_disarm)
        var hurt := HurtBox.new()
        hurt.name = "HurtBox"
        hurt.collision_layer = 2
        hurt.collision_mask = 0
        var shape := CollisionShape2D.new()
        var circle := CircleShape2D.new()
        circle.radius = 10.0
        shape.shape = circle
        hurt.add_child(shape)
        add_child(hurt)


## 推进预警与触发检测；已失效的地雷永不爆炸。
func _physics_process(delta: float) -> void:
    if _spent:
        return
    _age += delta
    delay = maxf(0.0, delay - delta)
    if delay <= 0.0:
        armed = true
    if detonation_remaining >= 0.0:
        detonation_remaining -= delta
        if detonation_remaining <= 0.0:
            _explode()
    elif armed:
        if not is_mine:
            _explode()
        else:
            for target: Node in get_tree().get_nodes_in_group("combat_targets"):
                if target is Node2D and global_position.distance_to(target.global_position) < 22.0:
                    _explode()
                    break
    queue_redraw()


## 遥控也提供可读预警；设置不同时间让多枚雷依次爆炸。
func schedule_detonation(seconds: float) -> void:
    if not _spent:
        detonation_remaining = maxf(seconds, 1.0)


## 玩家射毁只移除，不产生范围伤害，奖励主动清雷。
func _disarm() -> void:
    _spent = true
    queue_free()


## 延迟创建范围效果，避免在碰撞查询中直接修改物理空间。
func _explode() -> void:
    if _spent:
        return
    _spent = true
    _create_explosion.call_deferred()


## 复用已有阵营过滤与爆炸音效；缩放同时影响碰撞与视觉。
func _create_explosion() -> void:
    if is_queued_for_deletion():
        return
    var explosion := PrefabManager.create_explosion(Definition.Faction.Enemy, damage)
    if explosion != null:
        explosion.position = position
        explosion.scale = Vector2.ONE * radius / 22.022715
        explosion.add_to_group("boss_hazards")
        get_parent().add_child(explosion)
    queue_free()


## 黄色表示启动中，红色表示已启动/遥控；落点圈始终展示实际爆炸范围。
func _draw() -> void:
    var color := Color(1.0, 0.65, 0.15, 0.8)
    if armed or detonation_remaining >= 0.0:
        color = Color(1.0, 0.2, 0.1, 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.025))
    draw_arc(Vector2.ZERO, radius, 0, TAU, 40, color, 1.5)
    draw_circle(Vector2.ZERO, 7.0 if is_mine else 4.0, color)
    draw_line(Vector2(-10, 0), Vector2(10, 0), color, 2.0)
    draw_line(Vector2(0, -10), Vector2(0, 10), color, 2.0)

    if not is_mine and _age < 0.7:
        var progress := clampf(_age / 0.7, 0, 1)
        var airborne := throw_origin.lerp(Vector2.ZERO, progress) + Vector2.UP * sin(progress * PI) * 50.0
        draw_circle(airborne, 5.0, Color(0.4, 0.5, 0.2))
        draw_arc(airborne, 5.0, 0, TAU, 12, Color(1, 0.9, 0.4), 1.5)

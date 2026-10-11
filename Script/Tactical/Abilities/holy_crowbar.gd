## 物理学圣剑：能力私有接触传感器与逐目标冷却，完全独立于枪械命中逻辑。
extends TacticalAbility

var _sensor: Area2D
var _cooldowns: Dictionary = {}


## 只检测敌人 HurtBox 层；身体与 HurtBox 归一到同一实体，避免重复命中。
func install() -> void:
    _sensor = Area2D.new()
    _sensor.name = "TacticalContactSensor"
    _sensor.collision_layer = 0
    _sensor.collision_mask = 2
    var collision := CollisionShape2D.new()
    var shape := CapsuleShape2D.new()
    shape.radius = 8.0
    shape.height = 30.0
    collision.shape = shape
    _sensor.add_child(collision)
    equipment.player.add_child.call_deferred(_sensor)


## 能力卸载时传感器一起释放，不在玩家上留下监听器。
func uninstall() -> void:
    if is_instance_valid(_sensor):
        _sensor.queue_free()


## 基于游戏时间维护每目标间隔；过期条目删除，不持有敌人强引用。
func tick(delta: float) -> void:
    for key: int in _cooldowns.keys():
        _cooldowns[key] = maxf(float(_cooldowns[key]) - delta, 0.0)
        if _cooldowns[key] <= 0.0:
            _cooldowns.erase(key)
    if not is_instance_valid(_sensor) or not _sensor.is_inside_tree():
        return
    for area: Area2D in _sensor.get_overlapping_areas():
        if area is HurtBox:
            hit(area.get_parent() as Node2D)


## 接触命中共用正式生命/阵营反馈；Boss 不被推离固定竞技场。
func hit(enemy: Node2D) -> bool:
    var player: Player = equipment.player
    if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_in_group("enemies") or not enemy.can_process():
        return false
    if player.health_current <= 0 or _cooldowns.has(enemy.get_instance_id()):
        return false
    var health := enemy.get_node_or_null("Health") as HealthComponent
    if health == null or health.health <= 0:
        return false
    _cooldowns[enemy.get_instance_id()] = parameter("cooldown", 0.8)
    var taken := health.damage(equipment.contact_damage(int(parameter("damage", 8))), Definition.Faction.Player, player.global_position)
    if taken <= 0:
        return false
    equipment.commit_contact()
    if enemy is CharacterBody2D and not enemy is BattlefieldBoss and health.health > 0:
        var away := player.global_position.direction_to(enemy.global_position)
        if away == Vector2.ZERO:
            away = player.facing_direction
        enemy.move_and_collide(away * parameter("push", 8.0))
    return true

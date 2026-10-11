## 玩家敌人接触回归：使用正式玩家、士兵与 Boss 场景验证区域检测和实际物理击退。
## 测试禁用敌人 AI 与玩家输入处理，避免子弹伤害干扰接触伤害断言。
extends Node

var _checks: int = 0
var _failures: int = 0


## 等 AutoLoad 完成后进入异步物理测试。
func _ready() -> void:
    _run.call_deferred()


## 等待物理服务器刷新重叠区域，再读取结果。
func _sync_overlap() -> void:
    for frame: int in range(3):
        await get_tree().physics_frame
        await get_tree().process_frame


## 重置玩家位置与接触状态，隔离每个测试场景。
func _reset_player(player: Player) -> void:
    player.position = Vector2(4000, 4000)
    player.node_health.health = player.health_max
    player._contact_cooldown_remaining = 0.0
    player._contact_knockback_remaining = 0.0
    player._clear_equipment()


## 覆盖敌我过滤、持续接触、盾与闪避、完全重叠、Boss 及墙体阻挡。
func _run() -> void:
    var world := Node2D.new()
    add_child(world)
    var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
    world.add_child(player)
    player.set_process(false)
    player.set_physics_process(false)
    _reset_player(player)
    var enemy := load("res://Prefab/EnemySoilder/enemy_soilder.tscn").instantiate() as EnemySoilder
    world.add_child(enemy)
    enemy.set_physics_process(false)
    enemy.position = player.position + Vector2(8, 0)
    await _sync_overlap()
    player._update_enemy_contact(0.0)
    _check(player.health_current == 90, "真实士兵接触扣 10 血")
    _check(player._contact_knockback_direction == Vector2.LEFT, "击退方向远离敌人")
    player._update_enemy_contact(0.1)
    _check(player.health_current == 90, "间隔内不会重复扣血")
    player._update_enemy_contact(0.65)
    _check(player.health_current == 80, "保持重叠达到间隔后再次扣血")

    var start := player.position
    Input.action_press("move_right")
    player.set_physics_process(true)
    for frame: int in range(16):
        await get_tree().physics_frame
        await get_tree().process_frame
    player.set_physics_process(false)
    Input.action_release("move_right")
    # 只在击退期间按反方向输入；击退结束后会正常向右移动，因此单独验证完整距离。
    _check(player.position.x < start.x - 30.0, "反向移动输入不能抵消击退")
    _reset_player(player)
    await _sync_overlap()
    player._update_enemy_contact(0.0)
    start = player.position
    player.set_physics_process(true)
    while player._contact_knockback_remaining > 0.0:
        await get_tree().physics_frame
        await get_tree().process_frame
    player.set_physics_process(false)
    _check(absf(start.x - player.position.x - 48.0) < 0.1, "无障碍时实际击退 48 像素")

    _reset_player(player)
    player.obtain_equipment_from_loot(LootItem.Type.EquipmentShield, 1)
    player.use_equipment()
    await _sync_overlap()
    player._update_enemy_contact(0.0)
    _check(player.health_current == 100 and player.shield_health == 0, "护盾吸收翻倍接触伤害后破碎")
    _check(player._contact_knockback_remaining > 0.0, "护盾吸收后仍击退")
    player._skill_cooldown_remaining = 0.0
    player._start_dodge()
    player._update_enemy_contact(1.0)
    _check(player.health_current == 100 and player.shield_health == 0, "闪避期间免接触伤害")
    _check(player._contact_knockback_remaining == 0.0, "闪避取消残余击退")
    player.dodge_active = false
    player._dodge_time_remaining = 0.0
    player.anim.self_modulate.a = player._dodge_sprite_alpha

    _reset_player(player)
    enemy.remove_from_group("enemies")
    await _sync_overlap()
    player._update_enemy_contact(0.0)
    _check(player.health_current == 100, "友军区域不会触发接触伤害")
    enemy.add_to_group("enemies")
    enemy.health_component.health = 0
    player._update_enemy_contact(0.0)
    _check(player.health_current == 100, "死亡敌人不会触发接触伤害")
    enemy.health_component.health = 8
    enemy.position = player.position
    player.facing_direction = Vector2.DOWN
    await _sync_overlap()
    player._update_enemy_contact(0.0)
    _check(player._contact_knockback_direction == Vector2.UP, "完全重叠时仍有有效击退方向")
    enemy.queue_free()

    _reset_player(player)
    var boss := load("res://Prefab/BossExpedition/Canal.tscn").instantiate() as ExpeditionBoss
    boss.position = player.position + Vector2(8, 0)
    world.add_child(boss)
    boss.set_physics_process(false)
    await _sync_overlap()
    player._update_enemy_contact(0.0)
    _check(boss.collision_layer == 0 and player.health_current == 90, "实体层为零的 Boss 也触发接触伤害")
    boss.queue_free()

    _reset_player(player)
    var wall := StaticBody2D.new()
    wall.collision_layer = Definition.PHYSICS_LAYER_TERRAIN
    wall.position = player.position - Vector2(20, 0)
    var wall_shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(10, 100)
    wall_shape.shape = rectangle
    wall.add_child(wall_shape)
    world.add_child(wall)
    await _sync_overlap()
    player._contact_knockback_direction = Vector2.LEFT
    player._contact_knockback_remaining = player.contact_knockback_duration
    start = player.position
    player.set_physics_process(true)
    while player._contact_knockback_remaining > 0.0:
        await get_tree().physics_frame
        await get_tree().process_frame
    player.set_physics_process(false)
    _check(start.x - player.position.x > 0 and start.x - player.position.x < 11, "击退被墙体阻挡，不穿墙")

    world.queue_free()
    await get_tree().process_frame
    print("PLAYER_ENEMY_CONTACT_TEST checks=%d failures=%d" % [_checks, _failures])
    get_tree().quit(1 if _failures > 0 else 0)


## 记录每项契约，失败时以非零退出码供自动回归识别。
func _check(condition: bool, message: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error(message)

## 遗体契约测试：真实死亡信号、无交互静态节点、预算回收与 Boss 阶段边界。
## 结算不写账户；测试只使用内存中的角色和临时的战报路径。
extends Node

## 轻量房间替身只提供预算作用域，不引入敌人或物理。
class BudgetRoom extends Node2D:
    func is_room_safe() -> bool:
        return true

var _checks := 0
var _failures := 0
var _world: Node2D


## 测试观察者在终局暂停时仍可检查演出状态。
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _run.call_deferred()


## 使用实际预制体击杀，避免只验证遗体本身而漏掉死亡入口。
func _run() -> void:
    get_tree().current_scene = null
    _world = Node2D.new()
    add_child(_world)
    var enemy := load("res://Prefab/EnemySoilder/enemy_soilder.tscn").instantiate() as EnemySoilder
    _world.add_child(enemy)
    enemy.position = Vector2(50, 80)
    var visual_position := enemy.animated_sprite.global_position
    enemy.health_component.damage(enemy.health_component.health, Definition.Faction.Player)
    var corpse := enemy.get_meta(CharacterRemains.ACTOR_META).get_ref() as CharacterRemains
    _check(corpse != null and not enemy.visible, "死亡当帧视觉交接且原角色隐藏")
    _check(not enemy.is_in_group("enemies"), "逻辑死亡立即离开敌人组，不阻挡清场")
    _check(corpse.global_position.is_equal_approx(visual_position), "倒地位置与原贴图世界位置一致")
    _check(CharacterRemains.spawn_for_actor(enemy, CharacterRemains.Appearance.SOLDIER) == corpse, "重复死亡入口不生成第二份遗体")
    await get_tree().process_frame
    _check(not is_instance_valid(enemy), "完整敌人实例在帧末释放")
    get_tree().paused = true
    await get_tree().create_timer(0.6, true).timeout
    _check(corpse.is_settled and corpse.sprite.texture.region.position.x == 192, "世界暂停仍播完三帧并保留末帧")
    _check(not corpse.is_processing() and not corpse.is_physics_processing(), "静态遗体没有逐帧脚本")
    _check(corpse.find_children("*", "CollisionObject2D", true, false).is_empty(), "遗体没有碰撞、感知或伤害组件")
    get_tree().paused = false
    var mercenary := load("res://Prefab/Mercenary/mercenary.tscn").instantiate() as HiredMercenary
    _world.add_child(mercenary)
    var deaths := [0]
    mercenary.sig_permanently_died.connect(func(): deaths[0] += 1)
    mercenary.health_component.damage(10000, Definition.Faction.Enemy)
    var merc_body := mercenary.get_meta(CharacterRemains.ACTOR_META).get_ref() as CharacterRemains
    _check(merc_body.appearance == CharacterRemains.Appearance.MERCENARY and deaths[0] == 1, "佣兵专属倒地与永久死亡只触发一次")
    await get_tree().process_frame
    var boss := load("res://Prefab/BossGeneral/boss_general.tscn").instantiate() as BattlefieldBoss
    _world.add_child(boss)
    boss.health_component.damage(100000, Definition.Faction.Player)
    _check(not boss.has_meta(CharacterRemains.ACTOR_META), "Boss 换阶段不产生遗体")
    boss.health_component.damage(100000, Definition.Faction.Player)
    _check(boss.has_meta(CharacterRemains.ACTOR_META), "Boss 最终死亡产生独立遗体")
    await get_tree().process_frame
    for body: Node in get_tree().get_nodes_in_group("character_remains"):
        body.free()
    var profile := CharacterRemains.DEFAULT_CONFIG.duplicate() as DeathVisualConfig
    profile.room_limit = 2
    profile.level_limit = 3
    var budget_bodies: Array[CharacterRemains] = []
    for index: int in range(4):
        var actor := Node2D.new()
        _world.add_child(actor)
        budget_bodies.append(CharacterRemains.spawn_for_actor(actor, CharacterRemains.Appearance.SOLDIER, profile))
        actor.free()
    _check(get_tree().get_nodes_in_group("character_remains").size() == 2, "可配置房间上限淘汰最早遗体")
    await get_tree().create_timer(0.3, true).timeout
    _check(not is_instance_valid(budget_bodies[0]) and not is_instance_valid(budget_bodies[1]), "超预算遗体淡出后释放")
    for body: Node in get_tree().get_nodes_in_group("character_remains"):
        body.free()
    var rooms: Array[Node2D] = [BudgetRoom.new(), BudgetRoom.new()]
    for room: Node2D in rooms:
        _world.add_child(room)
        for index: int in range(2):
            var actor := Node2D.new()
            room.add_child(actor)
            CharacterRemains.spawn_for_actor(actor, CharacterRemains.Appearance.SOLDIER, profile)
            actor.free()
    _check(get_tree().get_nodes_in_group("character_remains").size() == 3, "跨房间遗体受整关总预算限制")
    for room: Node2D in rooms:
        room.free()
    _check(get_tree().get_nodes_in_group("character_remains").is_empty(), "房间销毁一并回收遗体")
    var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
    _world.add_child(player)
    var player_body := player.play_outcome_pose(false)
    await get_tree().process_frame
    _check(is_instance_valid(player) and not player.visible and player.collision_layer == 0, "玩家数据保留，原身体隐藏并禁用碰撞")
    _check(player_body.appearance == CharacterRemains.Appearance.PLAYER, "玩家使用死亡动作行")
    _world.free()
    print("DEATH_OUTCOME_TEST checks=%d failures=%d" % [_checks, _failures])
    get_tree().quit(0 if _failures == 0 else 1)


## 每项记录中文契约，失败时继续收集其余问题。
func _check(condition: bool, message: String) -> void:
    _checks += 1
    if condition:
        print("PASS ", message)
    else:
        _failures += 1
        push_error(message)

## 新 Boss 集成测试：验证真实节点、阶段、预警时序、补员、可射毁地雷与房间绑定。
## 通过场景入口运行，避免 --script 的 AutoLoad 编译时序问题，不改写研究存档。
extends Node

## 测试宿主保留生产生成和清场逻辑，跳过玩家/HUD 的启动副作用。
class Host extends FortressLevelController:
    ## 测试按需调用 start_level，避免父类自动开始正式对局。
    func _ready() -> void:
        pass

var checks: int = 0
var failures: int = 0
var world: Node2D
var target: Node2D


## 延迟至自动加载完成后执行测试。
func _ready() -> void:
    run.call_deferred()


## 覆盖五种策略与跨房清理隔离，并在完成后返回非零失败码。
func run() -> void:
    world = Node2D.new()
    add_child(world)
    target = Node2D.new()
    target.add_to_group("combat_targets")
    var target_health := HealthComponent.new()
    target_health.name = "Health"
    target.add_child(target_health)
    world.add_child(target)
    target.position = Vector2(200, 0)
    await get_tree().physics_frame
    var mobilizer := make_boss("Mobilizer")
    mobilizer._update_mobilizer(0.5, target)
    check(count_bullets() == 0, "动员兵第一阶段本体不攻击")
    mobilizer._update_mobilizer(0.5, target)
    check(mobilizer._guards.filter(func(g): return is_instance_valid(g)).size() == 4, "四个固定槽位生成护卫")
    for guard: Node2D in mobilizer._guards:
        guard.set_physics_process(false)
        check(guard.get_meta("suppress_death_rewards", false), "护卫关闭重复击杀收益")
    var dead := mobilizer._guards[0]
    dead.get_node("Health").damage(8)
    await get_tree().process_frame
    mobilizer._update_mobilizer(7.0, target)
    check(not is_instance_valid(mobilizer._guards[0]), "死亡七秒不提前补员")
    mobilizer._update_mobilizer(1.0, target)
    check(is_instance_valid(mobilizer._guards[0]), "死亡八秒补充空位")
    mobilizer.health_component.damage(999)
    check(mobilizer.current_phase == 2 and not mobilizer._defeated, "第一管生命只切换第二阶段")
    mobilizer._attack_remaining = 0
    mobilizer._update_mobilizer(0, target)
    var grenade_count := count_hazards()
    check(grenade_count == 1 and mobilizer.state == "throw", "第二阶段创建锁定落点并停步投雷")
    var grenade := world.get_children().filter(func(n): return n is BossHazard)[0] as BossHazard
    var landing := grenade.global_position
    target.position += Vector2(50, 0)
    check(grenade.global_position == landing and grenade.delay == mobilizer.grenade_warning, "手雷不追踪移动后的目标")
    mobilizer._guards[1].get_node("Health").damage(8)
    await get_tree().process_frame
    mobilizer._update_mobilizer(5.0, target)
    check(not is_instance_valid(mobilizer._guards[1]), "第二阶段五秒不提前补员")
    mobilizer._update_mobilizer(1.0, target)
    check(is_instance_valid(mobilizer._guards[1]), "第二阶段六秒补员")
    mobilizer.health_component.damage(999)
    await get_tree().process_frame
    check(not is_instance_valid(mobilizer), "最终死亡回收本体")
    clear_effects()

    var shield := make_boss("Shield")
    shield.facing = Vector2.RIGHT
    shield.health_component.damage(20, Definition.Faction.Player, shield.global_position + Vector2(30, 0))
    check(shield.health_component.health == 105, "正面护盾仅承受四分之一伤害")
    shield.health_component.damage(20, Definition.Faction.Player, shield.global_position - Vector2(30, 0))
    check(shield.health_component.health == 85, "背面正常受伤")
    shield.state = "reload"
    shield.health_component.damage(20, Definition.Faction.Player, Vector2(30, 0))
    check(shield.health_component.health == 65, "装填时正面放盾")
    shield._begin_charge(target)
    var fixed := shield.locked_direction
    target.position = Vector2(-200, 100)
    shield._update_shield(0, target)
    check(shield.locked_direction == fixed, "冲刺预警锁向后不跟踪玩家")
    shield.queue_free()

    var sniper := make_boss("Sniper")
    sniper.state = "aim"
    sniper.state_remaining = 0
    sniper._update_sniper(0, target)
    check(sniper.state == "locked" and sniper.state_remaining == 0.5, "狙击锁定后保留半秒躲避窗口")
    var direction := sniper.locked_direction
    target.position = Vector2(300, 200)
    sniper._update_sniper(0, target)
    check(sniper.locked_direction == direction, "锁定射线不跟踪目标")
    sniper.current_phase = 2
    sniper.state_remaining = 0
    var before := count_bullets()
    sniper._update_sniper(0, target)
    check(count_bullets() == before + 1 and sniper.state == "bolt", "狙击真实创建弹丸并进入拉栓")
    sniper.state_remaining = 0
    sniper._update_sniper(0, target)
    check(sniper.state == "aim", "第二枪重新完整预警")
    sniper.queue_free()
    clear_effects()

    var flamer := make_boss("Flamer")
    flamer.current_phase = 2
    flamer.state = "flame"
    flamer.state_remaining = 1
    flamer._update_flamer(0.1, target)
    check(count_bullets() == 3, "喷火扇形使用三条真实火焰弹")
    for child: Node in world.get_children():
        if child is ProjectileBullet and not child.is_queued_for_deletion():
            check(child.projectile_style == "flamethrower", "火焰使用已有减速碰撞规则")
    for index: int in range(10):
        flamer._leave_fire(Vector2(index * 40, -100))
    check(flamer._fires.size() <= flamer.max_fire_patches, "火区数量受限")
    flamer.state_remaining = 0
    flamer._update_flamer(0, target)
    check(flamer.state == "charge_warning", "第二阶段喷射后预警突进")
    flamer.queue_free()
    clear_effects()

    var engineer := make_boss("Engineer")
    var mine := engineer._new_hazard(Vector2(-100, -100), true)
    engineer._mines.append(mine)
    check(not mine.armed and mine.get_node_or_null("HurtBox") != null, "地雷延迟启动且具备可射毁碰撞")
    mine._physics_process(1.1)
    check(mine.armed, "一秒后启动地雷")
    mine.get_node("Health").damage(4, Definition.Faction.Player)
    await get_tree().process_frame
    check(not is_instance_valid(mine), "射毁地雷立即回收且不爆炸")
    engineer._prune(engineer._mines)
    engineer._mines.append(engineer._new_hazard(Vector2(-120, -100), true))
    engineer._mines.append(engineer._new_hazard(Vector2(-220, -100), true))
    engineer.current_phase = 2
    engineer._attack_remaining = 0
    engineer._update_engineer(0, target)
    check(engineer.state == "detonate", "第二阶段遥控引爆现有雷")
    check(engineer._mines[0].detonation_remaining < engineer._mines[1].detonation_remaining, "地雷顺序引爆且有预警")
    check(not engineer._safe_mine_position(target.global_position), "不能在玩家脚下布雷")
    engineer.queue_free()
    clear_effects()
    await get_tree().process_frame
    await test_bindings_and_cleanup()
    check(checks >= 260, "全部主题集成检查执行完成，未因脚本异常提前返回")
    world.queue_free()
    await get_tree().process_frame
    # 等待音频混音器释放已回收节点的短音效，避免测试退出时残留播放资源。
    await get_tree().create_timer(0.12).timeout
    print("[tactical_boss_test] checks=%d failures=%d" % [checks, failures])
    get_tree().quit(0 if failures == 0 else 1)


## 所有主题、不同种子和兜底路线都固定绑定同一首领与 2×2 竞技场。
func test_bindings_and_cleanup() -> void:
    for theme: String in ["Village", "Jungle", "Valley", "Metropolis", "MineShaft", "Fortress", "UndergroundFortress"]:
        var host := Host.new()
        add_child(host)
        host.battlefield_theme = load("res://Scene/Level%s/theme.tres" % theme)
        for seed: int in range(12):
            check(host._select_boss_scene(seed) == host.battlefield_theme.boss_scene, "主题固定绑定 Boss：" + theme)
            var map := FortressRoomGenerator.generate_level(1, seed)
            check(map.rooms[map.boss_room_id].size == Vector2i(2, 2), "Boss 地图占地固定 2×2")
        host.start_level(1, 20261010)
        var generated_arena := host._room_nodes[int(host.level_map.boss_room_id)] as FortressRoomTemplate
        check(generated_arena.scene_file_path == host.battlefield_theme.boss_room_scene.resource_path, "正式生成器使用独立 Boss 场景")
        check(generated_arena.get_node_or_null("BossSpawn") != null, "独立场景保留手工出生点")
        host._clear_generated_level()
        await get_tree().process_frame
        var arena := host.battlefield_theme.boss_room_scene.instantiate() as FortressRoomTemplate
        host.add_child(arena)
        check(not arena.populate_on_first_entry and arena.room_size_units == Vector2i(2, 2), "独立竞技场禁止随机人口与地形")
        host.current_room_id = 8
        host.level_map = {"boss_room_id": 8}
        host._room_nodes[8] = arena
        arena.room_id = 8
        arena.activate_room()
        check(not arena._clear_signal_sent, "入场等待 Boss 生成，不提前清场")
        host._spawn_boss_for_current_room()
        var boss := arena.get_node("Boss") as BattlefieldBoss
        boss.set_physics_process(false)
        var guard := GUARD_FOR_TEST(arena)
        var other := GUARD_FOR_TEST(world)
        var friend := Node2D.new()
        friend.add_to_group("combat_targets")
        arena.add_child(friend)
        var hazard := BossHazard.new()
        arena.add_child(hazard)
        for stage: int in range(3 if theme == "UndergroundFortress" else 2):
            boss.health_component.damage(999)
        await get_tree().process_frame
        await get_tree().process_frame
        check(host.boss_defeated and not is_instance_valid(guard), "最终死亡杀死房间其余敌人")
        check(is_instance_valid(other) and is_instance_valid(friend), "其他房间敌人与佣兵不受影响")
        check(not is_instance_valid(hazard), "最终死亡清理残留危害")
        check(arena.is_room_safe(), "清场后可以退出")
        host._on_boss_defeated()
        check(host.total_score == 500, "重复最终死亡不会重复结算")
        other.queue_free()
        host.queue_free()
        await get_tree().process_frame
    var fallback := FortressRoomGenerator._make_fallback_level(1, 1, 3)
    check(fallback.rooms[fallback.boss_room_id].size == Vector2i(2, 2), "兜底地图也固定竞技场尺寸")


## 创建真实士兵以验证生命死亡回调和敌人分组清理。
func GUARD_FOR_TEST(parent: Node2D) -> EnemySoilder:
    var guard := load("res://Prefab/EnemySoilder/enemy_soilder.tscn").instantiate() as EnemySoilder
    parent.add_child(guard)
    guard.set_physics_process(false)
    return guard


## 实例化生产 Boss 并关闭自动物理帧，测试显式推进状态时序。
func make_boss(name: String) -> TacticalBoss:
    var boss := load("res://Prefab/BossSquad/%s.tscn" % name).instantiate() as TacticalBoss
    world.add_child(boss)
    boss.set_physics_process(false)
    return boss


## 统计真实弹丸，避免只验证状态字段。
func count_bullets() -> int:
    return world.get_children().filter(func(n): return n is ProjectileBullet and not n.is_queued_for_deletion()).size()


## 统计真实落点节点。
func count_hazards() -> int:
    return world.get_children().filter(func(n): return n is BossHazard and not n.is_queued_for_deletion()).size()


## 在策略测试之间回收真实效果，避免上一策略的弹丸污染下一策略断言。
func clear_effects() -> void:
    for node: Node in world.get_children():
        if node is ProjectileBullet or node is BossHazard or node is BurningEffect or node is ProjectileExplosion:
            node.queue_free()


## 失败保留可读场景语义并累积，运行结束统一返回错误码。
func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)

## 八主题生产集成测试：阶段、实际攻击、同伴死亡、危险区、公开奖励和模板绑定。
## 通过场景执行以等待 AutoLoad，不修改钱包和研究存档。
extends Node

## 测试宿主保留生产生成器，禁止自动启动玩家与 HUD 流程。
class Host extends FortressLevelController:
    func _ready() -> void:
        pass

const IDS: Array[String] = ["OldTown", "Neon", "Park", "Chemical", "Route66", "Swamp", "Canal", "Hospital"]
var checks: int = 0
var failures: int = 0
var world: Node2D
var target: Node2D


## 延迟至全局管理器就绪，再执行真实节点测试。
func _ready() -> void:
    run.call_deferred()


## 累积可读失败信息，失败进程返回非零退出码。
func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)


## 创建可受伤敌对目标，手动推进 Boss 状态避免随机帧干扰。
func make_boss(id: String) -> ExpeditionBoss:
    var boss := load("res://Prefab/BossExpedition/%s.tscn" % id).instantiate() as ExpeditionBoss
    world.add_child(boss)
    boss.set_physics_process(false)
    return boss


## 回收测试生成的效果，避免阶段之间互相污染。
func clear_world() -> void:
    for node: Node in world.get_children():
        if node != target:
            node.queue_free()


## 覆盖每一阶段的全部实际招式，并验证三管生命不会提前结束房间。
func run() -> void:
    world = Node2D.new()
    add_child(world)
    target = Node2D.new()
    target.add_to_group("combat_targets")
    var health := HealthComponent.new()
    health.name = "Health"
    health.health_max = 10000
    health.health = 10000
    target.add_child(health)
    world.add_child(target)
    target.position = Vector2(180, 60)
    await get_tree().physics_frame
    for id: String in IDS:
        var boss := make_boss(id)
        var deaths := [0]
        boss.sig_defeated.connect(func(): deaths[0] += 1)
        boss._action_start_delay_remaining = 0
        boss._companion_pending = false
        for phase: int in range(1, 4):
            check(boss.current_phase == phase, id + " 正确阶段")
            for attack: String in boss._actions():
                boss.action = attack
                boss.locked_direction = Vector2.RIGHT
                boss.locked_point = target.global_position
                boss.facing = Vector2.RIGHT
                boss.state = "warning"
                boss.state_remaining = 0.6
                boss._physics_process(0.1)
                check(boss.state == "warning", id + " 预警期间不提前执行 " + attack)
                boss.state_remaining = 0
                boss._physics_process(0)
                check(boss.state in ["recover", "dash", "spray"], id + " 招式执行 " + attack)
                if boss.state == "dash":
                    boss.state_remaining = 0
                    boss._update_dash(0)
                    check(boss.state == "recover", id + " 冲撞结束恢复")
                elif boss.state == "spray":
                    boss._update_spray(0.1, target)
                    check(not boss._fields.is_empty(), id + " 喷流创建真实酸区")
                boss._clear_owned_effects(false)
            boss.health_component.damage(9999)
            if phase < 3:
                check(deaths[0] == 0 and boss.health_component.health > 0, id + " 中间阶段不结算")
        check(deaths[0] == 1, id + " 最终死亡一次结算")
        await get_tree().process_frame
        clear_world()
        await get_tree().process_frame
    await test_companions()
    await test_fields()
    await test_generation()
    await test_live_combat()
    check(checks > 350, "完整测试未因运行时异常提前退出")
    world.queue_free()
    await get_tree().process_frame
    print("[expedition_boss_test] checks=%d failures=%d" % [checks, failures])
    get_tree().quit(0 if failures == 0 else 1)


## 独立同伴真实受伤死亡推动最终阶段；首领先倒下时搭档继承主体。
func test_companions() -> void:
    for id: String in ["Neon", "Park"]:
        var boss := make_boss(id)
        boss._spawn_initial_companion()
        check(boss._companions.size() == 1, id + " 创建独立同伴")
        var member := boss._companions[0]
        member.set_physics_process(false)
        check(member.get_node("HurtBox") != null, id + " 同伴可被射击")
        check(member.get_meta("suppress_death_rewards", false), id + " 同伴不刷收益")
        member.get_node("Health").damage(999)
        check(boss.current_phase == 3, id + " 同伴死亡进入最后形态")
        check(not boss._survivor, id + " 同伴先死保留主角身份")
        boss.queue_free()
        await get_tree().process_frame
    var twins := make_boss("Neon")
    twins._spawn_initial_companion()
    twins._enter_phase(2)
    twins.health_component.damage(999)
    check(twins.current_phase == 3 and twins._survivor, "主枪手先死由黑衣搭档接战")
    twins.queue_free()
    await get_tree().process_frame
    var road := make_boss("Route66")
    road._enter_phase(3)
    await get_tree().process_frame
    check(road._survivor and road.get_node("CollisionShape2D").shape.radius == 12, "驾驶员下车更新身体碰撞")
    check(road.get_node("HurtBox/CollisionShape2D").shape.radius == 18, "驾驶员下车更新实际受击范围")
    road.queue_free()
    await get_tree().process_frame
    var swamp := make_boss("Swamp")
    swamp._enter_phase(3)
    var point := swamp.position
    swamp._keep_distance(target, 100, 100)
    check(swamp.position == point and swamp.velocity == Vector2.ZERO, "搁浅艇第三阶段固定炮座")
    swamp.queue_free()
    await get_tree().process_frame


## 危险区预警无伤、停留间隔、离开重入、射毁、数量上限和阶段清理。
func test_fields() -> void:
    var boss := make_boss("Chemical")
    var field := boss._spawn_field(target.global_position, 30, 1, 4, 3, true)
    field.set_physics_process(false)
    var health := target.get_node("Health") as HealthComponent
    var before := health.health
    field._physics_process(0.5)
    check(health.health == before, "预警期间不造成伤害")
    field._physics_process(0.5)
    check(health.health == before - 3, "危险区激活立即伤害")
    field._physics_process(0.1)
    check(health.health == before - 3, "持续停留不逐帧伤害")
    target.position += Vector2(100, 0)
    field._physics_process(0.1)
    target.position -= Vector2(100, 0)
    field._physics_process(0.1)
    check(health.health == before - 6, "离开重入立即重新判定")
    field.get_node("Health").damage(6, Definition.Faction.Player)
    check(field._spent, "射毁陷阱立即失效")
    await get_tree().process_frame
    for index: int in range(12):
        boss._spawn_field(Vector2(index * 40, -100), 20, 1, 3, 2)
    check(boss._fields.size() <= 6, "危险区同时最多六个")
    var fields := boss._fields.duplicate()
    boss._enter_phase(2)
    check(boss._fields.is_empty(), "阶段转换清空危险区引用")
    await get_tree().process_frame
    for item in fields:
        check(not is_instance_valid(item), "阶段转换回收实际危险节点")
    boss.queue_free()
    await get_tree().process_frame


## 生产地图生成、主题池、独立竞技场、入口与最终清场使用真实集成路径。
func test_generation() -> void:
    var pool := load("res://Script/Level/run_level_pool.tres") as BattlefieldCampaign
    check(pool.themes.size() == 15, "原七主题与新八主题共十五项")
    for id: String in IDS:
        var theme := load("res://Scene/Level%s/theme.tres" % id) as BattlefieldTheme
        check(theme in pool.themes, id + " 已加入正式抽取池")
        check(theme.background_music != null and theme.cover_texture != null, id + " 音画资源可加载")
        check(ResourceLoader.exists("res://Scene/Level%s/%sLevel.tscn" % [id,id]), id + " 独立 F6 入口")
        var host := Host.new()
        add_child(host)
        host.battlefield_theme = theme
        for seed: int in range(10):
            check(host._select_boss_scene(seed) == theme.boss_scene, id + " 固定首领绑定")
        host.start_level(1, 20261010)
        var arena := host._room_nodes[int(host.level_map.boss_room_id)] as FortressRoomTemplate
        check(arena.scene_file_path == theme.boss_room_scene.resource_path, id + " 生产独立竞技场")
        host.current_room_id = int(host.level_map.boss_room_id)
        arena.activate_room()
        host._spawn_boss_for_current_room()
        var boss := arena.get_node("Boss") as ExpeditionBoss
        boss.set_physics_process(false)
        for phase: int in range(3):
            boss.health_component.damage(9999)
        await get_tree().process_frame
        await get_tree().process_frame
        check(host.boss_defeated and arena.is_room_safe(), id + " 最终死亡解锁房间")
        check(host.total_score == 500, id + " 只结算一次首领分数")
        host._on_boss_defeated()
        check(host.total_score == 500, id + " 重复回调不重复结算")
        host.queue_free()
        await get_tree().process_frame


## 真实物理帧推进所有新首领，覆盖自动创建伙伴、状态执行和事件音频节点上限。
func test_live_combat() -> void:
    var bosses: Array[ExpeditionBoss] = []
    for id: String in IDS:
        var boss := make_boss(id)
        boss.set_physics_process(true)
        bosses.append(boss)
    await get_tree().create_timer(5.5).timeout
    for boss: ExpeditionBoss in bosses:
        check(boss._event_audio.has("attack"), boss.audio_key + " 真实物理帧完成首次攻击")
        check(boss._event_audio.size() <= 5, boss.audio_key + " 音频播放器数量有界")
    clear_world()
    await get_tree().process_frame

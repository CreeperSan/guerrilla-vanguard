## 最终关胜利与真实玩家死亡的集成测试；临时战报与测试宿主隔离所有账户写入。
## --visual-preview 使用相同流程输出真实游戏画面，便于审视字幕和临时动作的大小。
extends Node

var _checks := 0
var _failures := 0


## 保留跨场景的测试观察者，让终局演出和结果切换均可被观察。
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _run.call_deferred()


## 分别完成最终 Boss 清场和玩家生命归零；每次检查一次性路由及三秒标题停留。
func _run() -> void:
    get_tree().current_scene = null
    RunStats.report_path = "/private/tmp/gv-final-outcome-report.json"
    GameManager.reset_run()
    var counterattack := "--counterattack" in OS.get_cmdline_user_args()
    var original_unlock := CurrencyManager._airborne_completed
    CurrencyManager._airborne_completed = true
    GameManager.start_run(RogueRunManager.AttackMode.COUNTERATTACK if counterattack else RogueRunManager.AttackMode.AIRBORNE, 611)
    CurrencyManager._airborne_completed = original_unlock
    # 直接进入最后一关以缩短测试，不伪造最终清场、Boss 击杀或通关提交。
    GameManager.current_stage_index = GameManager.get_run_snapshot().total - 1
    GameManager.completed_level_count = GameManager.current_stage_index
    var level := _make_level()
    await _wait_active()
    _check(level._is_final_run_stage() and not is_instance_valid(level._boss_exit), "最后一关生成时没有下一关入口")
    var boss_id := int(level.level_map.boss_room_id)
    var room := level._room_nodes[boss_id] as FortressRoomTemplate
    level.current_room_id = boss_id
    level._player.global_position = room.global_position + Vector2(0, 140)
    level._set_room_visibility(boss_id)
    level._set_camera_room(room, false)
    level._activate_room_contents(boss_id)
    level._spawn_boss_for_current_room()
    var boss := room.get_node("Boss") as BattlefieldBoss
    for phase: int in range(4):
        if not boss.is_queued_for_deletion():
            boss.health_component.damage(100000, Definition.Faction.Player)
    await get_tree().process_frame
    await get_tree().process_frame
    _check(GameManager.run_state == RogueRunManager.RunState.COMPLETED, "最终 Boss 房清场自动提交通关")
    _check(not room.has_meta("tactical_reward_spawned") and room.find_children("*", "TacticalReward", true, false).is_empty(), "最终关不生成战术装备奖励")
    _check(level.total_score == 500 and int(RunStats.last_report.score) == 500, "终局演出前已记录最后一击积分")
    _check(int(RunStats.last_report.rooms.get("首领房", 0)) == 1, "最后首领房计入结算")
    _check(not get_tree().paused and not level._player.visible, "胜利保持场景运行并接管玩家视觉")
    var pose := level._player.get_meta(CharacterRemains.ACTOR_META).get_ref() as CharacterRemains
    _check(pose.appearance == CharacterRemains.Appearance.VICTORY, "胜利使用三帧举拳动作")
    await _verify_banner(level, "Victory", "victory")
    _check(bool(RunStats.last_report.won), "胜利自动进入成功结算")
    await _wait_transition()
    get_tree().current_scene.queue_free()
    await get_tree().process_frame
    get_tree().current_scene = null
    GameManager.reset_run()
    GameManager.start_run(RogueRunManager.AttackMode.AIRBORNE, 612)
    level = _make_level()
    await _wait_active()
    _check(is_instance_valid(level._boss_exit), "中间关卡仍生成正常出口")
    var intermediate_room := level._room_nodes[int(level.level_map.boss_room_id)] as FortressRoomTemplate
    level._create_tactical_reward(intermediate_room)
    _check(intermediate_room.has_meta("tactical_reward_spawned"), "中间关卡保留战术奖励")
    (level.controlled_player as Player).node_health.damage(100000, Definition.Faction.Enemy)
    await get_tree().process_frame
    _check(GameManager.run_state == RogueRunManager.RunState.FAILED, "玩家真实死亡进入失败状态")
    pose = level._player.get_meta(CharacterRemains.ACTOR_META).get_ref() as CharacterRemains
    _check(pose.appearance == CharacterRemains.Appearance.PLAYER, "战败使用玩家三帧倒地动作")
    await _verify_banner(level, "Defeated", "defeated")
    _check(not bool(RunStats.last_report.won), "战败自动进入失败结算")
    await _wait_transition()
    print("FINAL_OUTCOME_FLOW_TEST checks=%d failures=%d" % [_checks, _failures])
    get_tree().quit(0 if _failures == 0 else 1)


## 替换账户隔离脚本，其他节点、场景参数和死亡信号连接保持与正式宿主相同。
func _make_level() -> FortressLevelController:
    var level := load("res://Scene/GameRun/GameRun.tscn").instantiate() as FortressLevelController
    level.set_script(load("res://tests/outcome_test_level.gd"))
    level.managed_run = true
    level.player_path = ^"Player"
    level.hud_path = ^"HUD"
    level.camera_path = ^"FollowCamera"
    get_tree().root.add_child(level)
    get_tree().current_scene = level
    return level


## 等待正式入场完成，超时报告失败，避免脚本错误导致无限挂起。
func _wait_active() -> void:
    for step: int in range(300):
        if GameManager.run_state == RogueRunManager.RunState.ACTIVE:
            return
        await get_tree().create_timer(0.05, true).timeout
    _check(false, "关卡入场超时")


## 字幕必须在角色动作后出现，并保持三秒；等待真实 SceneTransition 进入战报。
func _verify_banner(level: FortressLevelController, expected: String, capture_name: String) -> void:
    var banner: Control
    for step: int in range(100):
        banner = level.controlled_hud.get_node_or_null("UIRoot/RunOutcome")
        if banner != null:
            break
        await get_tree().create_timer(0.02, true).timeout
    _check(banner != null and banner.get_node("Title").text == expected, expected + " 字幕在角色动作后显现")
    var heartbeat := [0]
    var timer := Timer.new()
    timer.wait_time = 0.05
    timer.process_mode = Node.PROCESS_MODE_PAUSABLE
    timer.timeout.connect(func(): heartbeat[0] += 1)
    level.add_child(timer)
    timer.start()
    var health := (level._player as Player).node_health.health
    var elapsed_before := RunStats.elapsed
    # 真实敌军子弹穿过玩家原身体，验证关闭物理受击而不只是隐藏贴图。
    var bullet := PrefabManager.create_bullet(Definition.Faction.Enemy, 100, Vector2.RIGHT) as ProjectileBullet
    bullet.bullet_speed = 300.0
    bullet.bullet_range = 100.0
    level.add_child(bullet)
    bullet.global_position = level._player.global_position - Vector2(20, 0)
    await get_tree().create_timer(0.5, true).timeout
    _check(heartbeat[0] > 0 and not get_tree().paused, expected + " 演出期间普通场景计时持续运行")
    var hurtbox := level._player.get_node("EnemyContact") as Area2D
    _check(not hurtbox.monitoring and not hurtbox.monitorable and hurtbox.collision_layer == 0 and level._player.collision_layer == 0 and (level._player as Player).node_health.health == health, expected + " 玩家受击区域关闭且生命稳定")
    _check(is_equal_approx(RunStats.elapsed, elapsed_before), expected + " 场景继续运行但作战计时已冻结")
    timer.queue_free()
    var lingering_pop := false
    for node: Node in level.find_children("*", "Sprite2D", true, false):
        lingering_pop = lingering_pop or node is DamagePop
    _check(not lingering_pop, expected + " 字幕期间伤害飘字已消散")
    if "--visual-preview" in OS.get_cmdline_user_args():
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("/private/tmp/gv-outcome-" + capture_name + ".png")
    await get_tree().create_timer(2.5, true).timeout
    _check(get_tree().current_scene == level and not SceneTransition.busy, expected + " 显现后未满三秒不跳转")
    for step: int in range(150):
        if get_tree().current_scene != null and get_tree().current_scene.name == "RunResult":
            _check(true, expected + " 自动进入结算页")
            return
        await get_tree().create_timer(0.02, true).timeout
    _check(false, expected + " 自动结算超时")


## 场景完成揭幕后再开始下一用例，避免转场导航的互斥保护影响测试。
func _wait_transition() -> void:
    while SceneTransition.busy:
        await get_tree().process_frame


## 汇总所有并行契约的结果，不因一个普通断言失败而遗漏后续检查。
func _check(condition: bool, message: String) -> void:
    _checks += 1
    if condition:
        print("PASS ", message)
    else:
        _failures += 1
        push_error(message)

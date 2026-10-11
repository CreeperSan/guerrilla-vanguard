## 覆盖真实首页启动链、规划同源路线、三秒停留、两种入场和装备冷却 HUD 同步。
## 测试节点脱离 current_scene，允许真实跨场景导航；不会修改账户或结算存档。
extends Node

var _failures := 0
var _visual := false

## 延迟到入口场景注册完成后开始，避免引擎覆盖 current_scene 引用。
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _visual = "--visual-preview" in OS.get_cmdline_user_args()
    _run.call_deferred()


## 使用固定路线种子以外的真实菜单入口，按状态等待而非依赖机器加载速度。
func _run() -> void:
    get_tree().current_scene = null
    GameManager.reset_run()
    var counterattack := "--counterattack" in OS.get_cmdline_user_args()
    var original_unlock := CurrencyManager._airborne_completed
    # 七关分支只临时改变内存解锁条件，提交请求后立即恢复，不保存账户。
    if counterattack:
        CurrencyManager._airborne_completed = true
    var mode: int = RogueRunManager.AttackMode.COUNTERATTACK if counterattack else RogueRunManager.AttackMode.AIRBORNE
    _check(GameManager.start_from_menu(mode), "首页接受所选模式")
    CurrencyManager._airborne_completed = original_unlock
    var route := GameManager.get_run_snapshot()["levels"] as Array
    var planning: Control
    for frame: int in range(600):
        if get_tree().current_scene != null and get_tree().current_scene.name == "BattlePlanning":
            planning = get_tree().current_scene as Control
            break
        await get_tree().process_frame
    _check(planning != null, "首页先进入独立规划场景")
    if planning == null:
        get_tree().quit(1)
        return
    _check(planning._cards.size() == route.size(), "规划卡片数量等于真实路线")
    while planning._locked < route.size():
        await get_tree().process_frame
    var reveal_done := Time.get_ticks_msec()
    _check(get_tree().paused, "规划期间暂停作战统计")
    await get_tree().create_timer(0.25, true).timeout
    await _capture("planning")
    while is_instance_valid(planning) and get_tree().current_scene == planning:
        await get_tree().process_frame
    _check(Time.get_ticks_msec() - reveal_done >= 2950, "最后一张锁定后至少停留三秒")
    # change_scene 在帧末先清空 current_scene，再安装宿主，需等待实际实例。
    for frame: int in range(600):
        if get_tree().current_scene is FortressLevelController:
            break
        await get_tree().process_frame
    var level := get_tree().current_scene as FortressLevelController
    _check(level != null, "规划自动进入正式宿主")
    if level == null:
        get_tree().quit(1)
        return
    var player := level.controlled_player as Player
    var visible_under_reveal := false
    while SceneTransition.busy:
        visible_under_reveal = visible_under_reveal or player.visible
        await get_tree().process_frame
    _check(not visible_under_reveal, "揭幕期间不提前显示落点上的玩家")
    await get_tree().create_timer(0.2, true).timeout
    var first_sample := player.global_position.y
    await get_tree().create_timer(0.2, true).timeout
    var second_sample := player.global_position.y
    await get_tree().create_timer(0.2, true).timeout
    var third_sample := player.global_position.y
    _check(absf((third_sample - second_sample) - (second_sample - first_sample)) < 4.0, "空降动画以线性速度进入")
    _check(get_tree().paused, "降落期间暂停敌人和玩家输入")
    _check(player.get_child_count() > 0 and player.global_position.y < level._room_nodes[level.current_room_id].global_position.y + 205, "降落从可编辑落点上方开始")
    await _capture("parachute")
    while GameManager.run_state == RogueRunManager.RunState.TRANSITIONING:
        await get_tree().process_frame
    var spawn := level.get_node("LevelEntry/PlayerSpawn") as Marker2D
    var room := level._room_nodes[level.current_room_id] as Node2D
    _check(player.global_position.distance_to(room.global_position + spawn.position) < 1, "降落结束精准抵达 Marker")
    _check(room.room_size_units.y * FortressRoomTemplate.UNIT_SIZE * 0.5 - spawn.position.y <= 50.0, "默认落点距底部不超过50世界单位")
    _check(GameManager.get_run_snapshot()["levels"] == route, "实际路线与规划一致")
    _check(not get_tree().paused, "落地后恢复战斗")
    var hud := level.controlled_hud
    var panel := hud.get_node("UIRoot/RunProgressPanel") as Control
    _check(panel.anchor_top == 1.0 and panel.size.y <= 48, "路线栏位于底部且高度不超过48")
    player.obtain_equipment_from_loot(LootItem.Type.EquipmentGrenade, 1)
    player.use_equipment()
    for effect: Node in level.get_children():
        if effect is ProjectileBullet:
            effect.queue_free()
    var cooldown := hud.get_node("UIRoot/ItemPanel/ItemContents/IconVisual/EquipmentCooldownBar") as ProgressBar
    _check(cooldown.value < 0.05, "真实投掷后冷却条清空")
    await get_tree().create_timer(0.3, true).timeout
    _check(cooldown.value > 0.1 and cooldown.value < 0.8, "冷却条随玩家真实冷却推进")
    get_tree().paused = true
    var frozen := cooldown.value
    await get_tree().create_timer(0.2, true).timeout
    _check(is_equal_approx(frozen, cooldown.value), "暂停不会推进装备冷却")
    await _capture("hud")
    if "--touch-preview" in OS.get_cmdline_user_args():
        hud._set_control_mode(GameHUD.ControlMode.TOUCH)
        await get_tree().process_frame
        await _capture("touch-hud")
    get_tree().paused = false
    await get_tree().create_timer(0.85, true).timeout
    _check(is_equal_approx(cooldown.value, 1.0), "冷却恢复后显示就绪")
    # 只解除本次测试的首领安全门槛，以实际推进接口验证后续关入场，不写结算。
    var weapons := player.node_weapon_manager
    weapons.unlock_smg()
    weapons.slot1.ammo_magazine_cur = 1
    weapons.slot1.ammo_back_cur = 5
    weapons.slotDefault.ammo_magazine_cur = 1
    level.boss_defeated = true
    _check(GameManager.report_level_cleared(level, 1), "首关通过正式接口推进")
    var second_spawn_flash := false
    while level.level_number != 2 or SceneTransition.busy:
        if level.level_number == 2:
            second_spawn_flash = second_spawn_flash or player.visible
        await get_tree().process_frame
    _check(not second_spawn_flash, "后续关揭幕期间也不闪现落点上的角色")
    _check(weapons.slot1.ammo_magazine_cur == 6 and weapons.slot1.ammo_back_cur == 0, "真实 Level 切换完成携带武器装填且不增加弹药总量")
    _check(weapons.slotDefault.ammo_magazine_cur == weapons.slotDefault.ammo_magazine_max, "新 Level 入场前备用手枪已装填完成")
    await get_tree().create_timer(0.2, true).timeout
    var second_room := level._room_nodes[level.current_room_id] as Node2D
    _check(get_tree().paused and player.global_position.y > second_room.global_position.y + spawn.position.y, "后续关从落点下方跑入且冻结战斗")
    var run_first_sample := player.global_position.y
    await get_tree().create_timer(0.2, true).timeout
    var run_second_sample := player.global_position.y
    await get_tree().create_timer(0.2, true).timeout
    var run_third_sample := player.global_position.y
    _check(absf((run_third_sample - run_second_sample) - (run_second_sample - run_first_sample)) < 4.0, "跑入动画以线性速度进入")
    await _capture("run-entry")
    while GameManager.run_state == RogueRunManager.RunState.TRANSITIONING:
        await get_tree().process_frame
    _check(player.global_position.distance_to(second_room.global_position + spawn.position) < 1, "跑入结束抵达同一 Marker")
    print("BATTLE_PLANNING_ENTRY_TEST failures=", _failures)
    RunStats.recording = false
    get_tree().quit(0 if _failures == 0 else 1)


## 图形预览参数可输出同一条真实流程的截图，普通 headless 测试无需渲染等待。
func _capture(label: String) -> void:
    if _visual:
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("/private/tmp/gv-entry-" + ("counter-" if "--counterattack" in OS.get_cmdline_user_args() else "") + label + ".png")


## 每个断言独立报告，失败保留后续证据。
func _check(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)
    else:
        print("PASS ", message)

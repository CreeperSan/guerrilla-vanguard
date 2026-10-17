## 触控配置回归：持久化、坏配置、半屏限制、真实 HUD 多指输入和编辑草稿生命周期。
## 所有设置写入临时路径，既不删除账户也不覆盖玩家音量/剧情偏好。
extends Node

var checks := 0
var failures := 0

## 仅取消开局倒计时，保留正式 HUD 初始化、容器布局与多指事件处理。
class TestHUD extends GameHUD:
    ## 自动测试直接进入可交互状态，不让倒计时暂停测试观察者。
    func _start_game_countdown() -> void:
        _game_started = true

## 自动加载完成后换用临时路径再运行验证。
func _ready() -> void:
    GameSettings.settings_path = "/private/tmp/gv-touch-settings-test.cfg"
    _run.call_deferred()

## 真实场景与输入共同验证；每条检查汇总失败，不因首条失败漏掉其他释放分支。
func _run() -> void:
    get_window().size = Vector2i(1280, 720)
    var clean := TouchLayout.sanitize({"move": {"center": Vector2(0.9, -1), "scale": 99}, "aim": {"center": Vector2(0.1, 0.5)}, "reload": "bad"})
    _check(clean.move.center.x <= 0.5 and clean.aim.center.x >= 0.5, "坏配置保持摇杆半屏约束")
    _check(clean.move.scale == 1.6 and clean.reload.scale == 1.0, "倍率限幅与坏类型回退")
    for viewport_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 720), Vector2(960, 720), Vector2(720, 1280)]:
        for id: String in clean:
            var rect := TouchLayout.rect_for(id, clean, viewport_size, 1.5)
            var base_size: Vector2 = TouchLayout.DEFAULTS[id].size
            _check(is_equal_approx(rect.size.x / rect.size.y, base_size.x / base_size.y), "放大或窄屏约束仍保留按钮比例：%s" % id)
            _check(Rect2(Vector2.ZERO, viewport_size).encloses(rect), "%s 按钮位于视口内 %s" % [id, viewport_size])
            if id == "move":
                _check(rect.end.x <= viewport_size.x * 0.5, "移动区完整位于左半屏")
            if id == "aim":
                _check(rect.position.x >= viewport_size.x * 0.5, "瞄准区完整位于右半屏")
    var legacy := {"weapon": {"center": Vector2(0.47, 0.17), "scale": 1.0}, "map": {"center": Vector2(0.84, 0.17), "scale": 1.0}, "reload": {"center": Vector2(0.91, 0.42), "scale": 1.0}}
    var migrated: Dictionary = TouchLayout.migrate_legacy_layout(legacy)
    _check(migrated.weapon.center == TouchLayout.DEFAULTS.weapon.center and migrated.map.center == TouchLayout.DEFAULTS.map.center, "旧默认布局升级为右上武器与下方小地图")
    legacy.weapon.center = Vector2(0.7, 0.25)
    migrated = TouchLayout.migrate_legacy_layout(legacy)
    _check(migrated.weapon.center == legacy.weapon.center, "布局升级保留手动设置过的位置")
    var weapon_rect := TouchLayout.rect_for("weapon", TouchLayout.DEFAULTS, Vector2(1280, 720))
    var map_rect := TouchLayout.rect_for("map", TouchLayout.DEFAULTS, Vector2(1280, 720))
    _check(weapon_rect.get_center().x > 960 and weapon_rect.get_center().y < 150, "默认武器面板位于右上角")
    _check(map_rect.position.y > weapon_rect.end.y, "缩小后的小地图位于武器面板下方")
    var ids := TouchLayout.DEFAULTS.keys()
    for i: int in range(ids.size()):
        for j: int in range(i + 1, ids.size()):
            var first := TouchLayout.rect_for(ids[i], TouchLayout.DEFAULTS, Vector2(1280, 720))
            var second := TouchLayout.rect_for(ids[j], TouchLayout.DEFAULTS, Vector2(1280, 720))
            _check(not first.intersects(second), "默认按钮互不重叠：%s / %s" % [ids[i], ids[j]])
    GameSettings.story_intro_seen = false
    var story = load("res://Scene/StoryIntro/StoryIntro.tscn").instantiate()
    add_child(story)
    _check(GameSettings.story_intro_seen, "进入真实剧情场景即标记已展示")
    await get_tree().create_timer(0.25).timeout
    story.free()
    GameSettings.set_movement_options(true, 1.25)
    clean.reload.center = Vector2(0.75, 0.35)
    GameSettings.set_touch_layout(clean)
    GameSettings.mark_story_intro_seen()
    GameSettings.floating_movement = false
    GameSettings.movement_scale = 1.0
    GameSettings.story_intro_seen = false
    GameSettings.touch_layout = TouchLayout.DEFAULTS.duplicate(true)
    GameSettings._load_settings()
    _check(GameSettings.story_intro_seen, "已进入剧情标记跨加载保留")
    _check(GameSettings.floating_movement and GameSettings.movement_scale == 1.25, "移动方式与大小持久化")
    _check(GameSettings.touch_layout.reload.center == clean.reload.center, "自定义位置持久化")
    var config := ConfigFile.new()
    config.load(GameSettings.settings_path)
    _check(not config.has_section_key("presentation", "skip_story_intro"), "保存不再写入旧跳过开关")
    GameSettings.reset_touch_layout()
    GameSettings.set_movement_options(false, 1.0)
    var menu = load("res://Scene/MainMenu/MainMenu.tscn").instantiate()
    add_child(menu)
    var settings_scroll: ScrollContainer = menu.get_node("%SettingsScroll")
    _check(settings_scroll.get_child(0).get_child_count() == 4, "设置列表保留四个分组")
    _check(menu._settings_page.find_children("*", "TabContainer", true, false).is_empty(), "设置无需切换 Tab")
    _check(menu.get_node("%MusicSlider").get_parent().name == "音效", "音量在音效栏")
    _check(menu.get_node("%DeleteSaveButton").get_parent().name == "其他", "删除存档在其他栏")
    _check(menu.get_node_or_null("%SkipStoryIntro") == null, "旧跳过开关移除")
    menu._show_page(menu._settings_page)
    await get_tree().process_frame
    var music_before_scroll := GameSettings.music_volume
    var sfx_before_scroll := GameSettings.sfx_volume
    var movement_before_scroll := GameSettings.movement_scale
    var point: Vector2 = menu.get_node("%操控/SectionTitle").get_global_rect().get_center()
    var settings_press := InputEventScreenTouch.new()
    settings_press.index = 31
    settings_press.pressed = true
    settings_press.position = point
    get_viewport().push_input(settings_press, true)
    _check(menu._settings_touch_index == 31, "设置分组标题触摸由列表手势捕获")
    var settings_drag := InputEventScreenDrag.new()
    settings_drag.index = 31
    settings_drag.position = point - Vector2(0, 160)
    get_viewport().push_input(settings_drag, true)
    _check(settings_scroll.scroll_vertical > 0, "设置纵向列表支持真实视口触摸滑动")
    settings_press = settings_press.duplicate()
    settings_press.pressed = false
    settings_press.position = settings_drag.position
    get_viewport().push_input(settings_press, true)
    _check(menu._settings_touch_index == -1, "设置列表松手后释放触点")
    _check(GameSettings.music_volume == music_before_scroll and GameSettings.sfx_volume == sfx_before_scroll, "列表滑动不改变音量")
    _check(GameSettings.movement_scale == movement_before_scroll, "列表滑动不改变移动区大小")
    await _capture("settings")
    menu._open_touch_layout()
    await get_tree().process_frame
    var editor = menu.get_node("TouchLayoutEditor")
    await _capture("editor")
    _check(Rect2(Vector2.ZERO, editor._root.size).encloses(editor._footer.get_rect()), "编辑器坐标面板完整位于视口内")
    editor._toggle_inspector()
    _check(not editor._footer.visible, "可隐藏坐标面板完整预览底部控件")
    editor._toggle_inspector()
    _check(editor._markers.size() == 10, "编辑器包含全部十个控件")
    var move_preview_rect := TouchLayout.rect_for("move", editor.draft, editor._root.size)
    editor._begin_drag(move_preview_rect.position + Vector2(2, 2), 20)
    _check(editor._drag_index == -2, "布局编辑器圆形移动区不响应外接矩形四角")
    var initial_move := move_preview_rect.get_center()
    var press := InputEventScreenTouch.new()
    press.index = 11
    press.position = initial_move
    press.pressed = true
    editor._input(press)
    var editor_drag := InputEventScreenDrag.new()
    editor_drag.index = 11
    editor_drag.position = initial_move + Vector2(60, -30)
    editor._input(editor_drag)
    _check(editor.draft.move.center != GameSettings.touch_layout.move.center, "真实触摸拖动更新编辑草稿")
    press.index = 12
    editor._input(press)
    _check(editor._drag_index == 11, "编辑器第二根手指不抢占拖动")
    press.index = 11
    press.pressed = false
    editor._input(press)
    _check(editor._drag_index == -2, "编辑器松手结束拖动")
    editor._select("move")
    editor._set_center(Vector2(0.95, 0.5))
    _check(editor.draft.move.center.x < 0.5, "编辑器移动摇杆不能拖过半屏")
    _check(GameSettings.touch_layout.move.center != editor.draft.move.center, "编辑草稿不提前提交")
    editor._select("aim")
    editor._set_center(Vector2(0.01, 0.5))
    _check(editor.draft.aim.center.x > 0.5, "编辑器瞄准摇杆不能拖过半屏")
    editor._select("reload")
    editor._resize_selected(130)
    editor._set_center(Vector2(0.8, 0.4))
    editor._save()
    await get_tree().process_frame
    _check(GameSettings.touch_layout.reload.scale == 1.3, "编辑器保存大小")
    GameSettings.reset_touch_layout()
    menu.free()
    var world := Node2D.new()
    add_child(world)
    var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
    world.add_child(player)
    player.set_process(false)
    player.set_physics_process(false)
    var hud := load("res://Scene/UI/HUD/HUD.tscn").instantiate() as GameHUD
    hud.set_script(TestHUD)
    add_child(hud)
    await get_tree().process_frame
    hud._set_control_mode(GameHUD.ControlMode.TOUCH)
    await get_tree().process_frame
    hud._refresh_touch_layout()
    await get_tree().process_frame
    for overlay: String in ["StartOverlay", "RunModeOverlay", "PauseOverlay", "DefeatOverlay", "VictoryOverlay"]:
        hud.get_node("UIRoot/" + overlay).hide()
    await _capture("hud")
    for id: String in hud._touch_controls:
        var control: Control = hud._touch_controls[id]
        var expected := TouchLayout.rect_for(id, GameSettings.touch_layout, hud.get_node("UIRoot").size)
        _check(control.get_global_rect().is_equal_approx(expected), "真实 HUD 与预览矩形一致：%s actual=%s expected=%s" % [id, control.get_global_rect(), expected])
    _check(is_equal_approx(hud._movement_panel.modulate.a, 0.22), "左侧移动摇杆使用更低不透明度")
    _check(is_equal_approx(hud._attack_panel.modulate.a, 0.55), "右侧触摸按钮为半透明")
    _check(is_equal_approx(hud._room_minimap.modulate.a, 0.45), "小地图同步降低不透明度")
    var move_rect := hud._movement_panel.get_global_rect()
    var move_style: StyleBoxFlat = hud._movement_panel.get_theme_stylebox("panel")
    _check(move_style.corner_radius_top_left >= hud._movement_panel.size.x * 0.5, "移动区圆角半径等于半边长，保持圆形")
    _touch(hud, 9, move_rect.position + Vector2(2, 2), true)
    _check(hud._movement_touch_index == -1, "固定圆形移动区四角不触发移动")
    _check(TouchLayout.contains_point("move", move_rect, move_rect.get_center() + Vector2(move_rect.size.x * 0.49, 0)), "圆形移动区轴向边缘仍能命中")
    var move_center := move_rect.get_center()
    _touch(hud, 0, move_center, true)
    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = move_center + Vector2(90, 0)
    hud._handle_touch_event(drag)
    _check(Input.is_action_pressed("move_right"), "固定摇杆拖动向右移动")
    _touch(hud, 1, hud._attack_panel.get_global_rect().get_center(), true)
    var aim_drag := InputEventScreenDrag.new()
    aim_drag.index = 1
    aim_drag.position = hud._attack_panel.get_global_rect().get_center() + Vector2(60, 0)
    hud._handle_touch_event(aim_drag)
    _check(player.facing_direction == Vector2.RIGHT, "右瞄准摇杆拖动更新真实玩家朝向")
    _touch(hud, 2, hud._fire_panel.get_global_rect().get_center(), true)
    _check(Input.is_action_pressed("fire"), "移动与瞄准射击可同时按住")
    _touch(hud, 1, Vector2.ZERO, false)
    _check(Input.is_action_pressed("fire"), "松开瞄准时独立射击继续保持")
    _touch(hud, 2, Vector2.ZERO, false)
    _check(not Input.is_action_pressed("fire"), "最后一根射击手指释放后停止开火")
    _touch(hud, 0, Vector2.ZERO, false)
    _check(not Input.is_action_pressed("move_right"), "松开摇杆后停止移动")
    GameSettings.set_movement_options(true, 1.0)
    _touch(hud, 3, (hud._touch_controls.tactical as Control).get_global_rect().get_center(), true)
    _check(hud._movement_touch_index == -1, "左侧战术按钮不会被活动移动区抢占")
    var first_point := Vector2(70, 330)
    _touch(hud, 4, first_point, true)
    _check(hud._movement_touch_index == 4 and hud._movement_origin == first_point, "活动摇杆使用左半屏首次落点")
    _check(hud._movement_panel.get_global_rect().get_center().is_equal_approx(first_point), "活动摇杆图形中心精确对应首次触点")
    _check(not Input.is_action_pressed("move_right"), "活动摇杆靠边按下不引起漂移")
    _touch(hud, 5, Vector2(400, 330), true)
    _check(hud._movement_touch_index == 4, "第二根手指不能抢占移动摇杆")
    drag.index = 4
    drag.position = first_point + Vector2(90, 0)
    hud._handle_touch_event(drag)
    _check(Input.is_action_pressed("move_right"), "活动摇杆拖动生效")
    hud._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
    _check(hud._movement_touch_index == -1 and not Input.is_action_pressed("move_right"), "失焦释放所有触控输入")
    _touch(hud, 8, hud._attack_panel.get_global_rect().get_center(), true)
    hud._set_control_mode(GameHUD.ControlMode.KEYBOARD_MOUSE)
    _check(hud._movement_panel.modulate == hud._touch_original_modulates.move, "切回桌面恢复原始透明度")
    _check(not hud._fire_panel.visible and not Input.is_action_pressed("fire"), "切回键鼠隐藏射击按钮并释放输入")
    hud.free()
    world.free()
    GameSettings.reset_touch_layout()
    GameSettings.set_movement_options(false, 1.0)
    GameSettings.save_now()
    print("TOUCH_SETTINGS_TEST checks=%d failures=%d" % [checks, failures])
    get_tree().quit(1 if failures else 0)

## 合成多指事件走正式触控处理入口，不依赖桌面是否连接触摸设备。
func _touch(hud: GameHUD, index: int, point: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = point
    event.pressed = pressed
    hud._handle_touch_event(event)

## 输出具体失败信息，便于定位几何、持久化或输入生命周期问题。
func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)


## 可选图形模式输出实际渲染截图；无头回归不调用渲染纹理。
func _capture(name_suffix: String) -> void:
    if not "--capture" in OS.get_cmdline_user_args():
        return
    await get_tree().create_timer(0.3).timeout
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("/private/tmp/gv-touch-%s.png" % name_suffix)

## 战斗 HUD：场景文件负责布局，本脚本更新玩家生命值和当前武器状态。
class_name GameHUD
extends CanvasLayer

## 模式菜单只提交玩家选择，不在 HUD 内随机生成或推进路线。
signal sig_run_mode_selected(mode: int)

## 当前操作设备；HUD 会按最后一次真实输入即时切换提示与屏幕控件。
enum ControlMode { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

const COLOR_HEALTH_NORMAL := Color("#bdd28a")
const COLOR_HEALTH_LOW := Color("#e57b68")
## 统一军事像素素材同时用于 HUD 与拾取物；这里只切换贴图，不改变槽位状态。
const WEAPON_ICON_PISTOL: Texture2D = preload("res://Assets/Art/MilitaryArcade/pistol.png")
const WEAPON_ICON_SMG: Texture2D = preload("res://Assets/Art/MilitaryArcade/smg.png")
const WEAPON_ICON_SHORTGUN: Texture2D = preload("res://Assets/Art/MilitaryArcade/shotgun.png")
const EQUIPMENT_ICON_GRENADE: Texture2D = preload("res://Assets/Art/MilitaryArcade/grenade.png")
const EQUIPMENT_ICON_MOLOTOV: Texture2D = preload("res://Assets/Art/MilitaryArcade/molotov.png")
const EQUIPMENT_ICON_SHIELD: Texture2D = preload("res://Assets/Art/MilitaryArcade/shield.png")
const SUPPORT_ICON_MORTAR: Texture2D = preload("res://Assets/Art/MilitaryArcade/mortar.png")
const SUPPORT_ICON_BOMBING: Texture2D = preload("res://Assets/Art/MilitaryArcade/bombing.png")
const SKILL_ICON_SPRINT: Texture2D = preload("res://Assets/Art/MilitaryArcade/sprint.png")
const SKILL_ICON_DODGE: Texture2D = preload("res://Assets/Art/MilitaryArcade/dodge.png")
const WEAPON_NAME_PISTOL := "手枪 / PISTOL"
const WEAPON_NAME_SMG := "冲锋枪 / SMG"
const WEAPON_NAME_SHORTGUN := "霰弹枪 / SHOTGUN"

@onready var _health_bar: ProgressBar = %HealthBar
## 体力条的布局与样式由 HUD 场景配置，数值由玩家信号提供。
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _stamina_fill_style: StyleBoxFlat = _stamina_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
@onready var _enemy_hints: EnemyDirectionHints = %EnemyDirectionHints
@onready var _health_value_label: Label = %HealthValueLabel
@onready var _health_fill_style: StyleBoxFlat = _health_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
@onready var _weapon_icon: TextureRect = %WeaponIcon
@onready var _weapon_name: Label = %WeaponName
@onready var _ammo_value: Label = %AmmoValue
@onready var _reload_progress: ProgressBar = %ReloadProgressBar
@onready var _switch_progress: ProgressBar = %SwitchProgressBar
@onready var _secondary_icon: TextureRect = %SecondaryWeaponIcon
@onready var _secondary_name: Label = %SecondaryWeaponName
@onready var _secondary_ammo: Label = %SecondaryAmmoValue
@onready var _battle_support_icon: TextureRect = %BattleSupportIcon
@onready var _battle_support_name: Label = %BattleSupportName
@onready var _skill_icon: TextureRect = %SkillIcon
@onready var _skill_name: Label = %SkillName
@onready var _skill_cooldown: ProgressBar = %SkillCooldownBar
@onready var _skill_hint: Label = %SkillHint
@onready var _equipment_icon: TextureRect = %EquipmentIcon
@onready var _equipment_value: Label = %EquipmentValueLabel
@onready var _score_value: Label = $UIRoot/ScorePanel/ScoreContents/ScoreValue
@onready var _pause_overlay: Control = $UIRoot/PauseOverlay
@onready var _defeat_overlay: Control = $UIRoot/DefeatOverlay
@onready var _start_overlay: Control = $UIRoot/StartOverlay
@onready var _countdown_label: Label = %CountdownLabel
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_label: Label = %VolumeLabel
@onready var _defeat_score_label: Label = %ScoreLabel
@onready var _menu_panel: PanelContainer = $UIRoot/MenuPanel
@onready var _boss_health_panel: PanelContainer = %BossHealthPanel
@onready var _boss_name_label: Label = %BossNameLabel
@onready var _boss_health_bar: ProgressBar = %BossHealthBar
@onready var _room_minimap: FortressRoomMinimap = %RoomMinimap
@onready var _movement_panel: Control = $UIRoot/MovementPanel
@onready var _attack_panel: Control = $UIRoot/AttackPanel
@onready var _reload_panel: Control = $UIRoot/ReloadPanel
@onready var _item_panel: Control = $UIRoot/ItemPanel
@onready var _support_panel: Control = $UIRoot/BattleSupportPanel
@onready var _skill_panel: Control = $UIRoot/SkillPanel
@onready var _weapon_panel: Control = $UIRoot/WeaponPanel
@onready var _weapon_previous_hint: Control = $UIRoot/WeaponPanel/WeaponContents/WeaponRow/PreviousWeapon
@onready var _weapon_next_hint: Control = $UIRoot/WeaponPanel/WeaponContents/WeaponRow/NextWeapon
@onready var _input_hint_panel: Control = $UIRoot/InputHintPanel
@onready var _input_hint_label: Label = %InputHintLabel
@onready var _movement_hint: Label = $UIRoot/MovementPanel/MovementContents/MovementHint
@onready var _movement_title: Label = $UIRoot/MovementPanel/MovementContents/MovementTitle
@onready var _movement_contents: BoxContainer = $UIRoot/MovementPanel/MovementContents
@onready var _attack_hint: Label = $UIRoot/AttackPanel/AttackContents/AttackHint
@onready var _attack_title: Label = $UIRoot/AttackPanel/AttackContents/AttackTitle
@onready var _attack_contents: BoxContainer = $UIRoot/AttackPanel/AttackContents
@onready var _reload_hint: Label = $UIRoot/ReloadPanel/ReloadContents/ReloadHint
@onready var _reload_title: Label = $UIRoot/ReloadPanel/ReloadContents/ReloadTitle
@onready var _reload_contents: BoxContainer = $UIRoot/ReloadPanel/ReloadContents
@onready var _item_hint: Label = $UIRoot/ItemPanel/ItemContents/ItemHint
@onready var _item_contents: BoxContainer = $UIRoot/ItemPanel/ItemContents
@onready var _item_title: Label = $UIRoot/ItemPanel/ItemContents/ItemTitle
@onready var _support_hint: Label = $UIRoot/BattleSupportPanel/BattleSupportContents/BattleSupportHint
@onready var _support_contents: BoxContainer = $UIRoot/BattleSupportPanel/BattleSupportContents
@onready var _support_title: Label = $UIRoot/BattleSupportPanel/BattleSupportContents/BattleSupportTitle
@onready var _skill_contents: BoxContainer = $UIRoot/SkillPanel/SkillContents
@onready var _skill_title: Label = $UIRoot/SkillPanel/SkillContents/SkillTitle
@onready var _run_progress_panel: PanelContainer = %RunProgressPanel
## 上方资源区域同步局内金钱、待结算研究和已经持久化的研究账户。
@onready var _currency_value: Label = %ResourceValue
@onready var _run_progress_label: Label = %RunProgressLabel
@onready var _run_progress_bar: ProgressBar = %RunProgressBar
@onready var _run_route: HBoxContainer = %RunRoute
@onready var _run_mode_overlay: Control = %RunModeOverlay
@onready var _run_mode_error: Label = %RunModeError
@onready var _airborne_button: Button = %AirborneButton
@onready var _assault_button: Button = %AssaultButton
@onready var _victory_overlay: Control = %VictoryOverlay
@onready var _victory_title: Label = %VictoryTitle
@onready var _victory_score: Label = %VictoryScore
@onready var _defeat_restart_button: Button = %DefeatRestartButton

var _game_started: bool = false
var _game_over: bool = false
var _control_mode: ControlMode = ControlMode.KEYBOARD_MOUSE
var _movement_touch_index: int = -1
var _touch_action_indices: Dictionary = {}
var _touch_action_release_at: Dictionary = {}
var _last_touch_event_msec: int = -1000
var _primary_weapon: PlayerWeaponSlot
var _secondary_weapon_slot: PlayerWeaponSlot
var _control_mode_initialized: bool = false
var _player: Player
var _run_ui_enabled: bool = false
var _waiting_run_selection: bool = false
var _mode_choice_pending: bool = false
var _start_sequence_id: int = 0


## 复制场景中的血条样式，避免运行时改色影响其他 HUD 实例。
func _ready() -> void:
    _health_bar.add_theme_stylebox_override("fill", _health_fill_style)
    $UIRoot/PauseOverlay/CenterContainer/MenuCard/Contents/ContinueButton.pressed.connect(resume_game)
    $UIRoot/PauseOverlay/CenterContainer/MenuCard/Contents/ExitButton.pressed.connect(_exit_game)
    $UIRoot/DefeatOverlay/CenterContainer/MenuCard/Contents/ExitButton.pressed.connect(_exit_game)
    _volume_slider.value_changed.connect(_on_volume_changed)
    _menu_panel.gui_input.connect(_on_menu_panel_gui_input)
    _airborne_button.pressed.connect(_choose_run_mode.bind(RogueRunManager.AttackMode.AIRBORNE))
    _assault_button.pressed.connect(_choose_run_mode.bind(RogueRunManager.AttackMode.FULL_ASSAULT))
    _defeat_restart_button.pressed.connect(GameManager.restart_run)
    %VictoryRestartButton.pressed.connect(GameManager.restart_run)
    %VictoryExitButton.pressed.connect(_exit_game)
    %DefeatHomeButton.pressed.connect(GameManager.return_to_main_menu)
    %VictoryHomeButton.pressed.connect(GameManager.return_to_main_menu)
    GameSettings.sig_audio_changed.connect(_sync_volume_slider)
    CurrencyManager.sig_currency_changed.connect(_on_currency_changed)
    _on_currency_changed(CurrencyManager.get_snapshot())
    _configure_gamepad_bindings()
    _set_control_mode(_get_initial_control_mode())
    call_deferred("_cache_player")
    set_score(0)
    _sync_volume_slider()
    call_deferred("_start_game_countdown")


## 按 Escape 或点击右上角菜单按钮时切换暂停状态。
func _input(event: InputEvent) -> void:
    _detect_control_mode(event)
    _handle_touch_event(event)
    var is_key_echo: bool = event is InputEventKey and (event as InputEventKey).echo
    var is_pause_input := event.is_action_pressed("ui_cancel") and not is_key_echo
    # 手柄 B 键用于装备，暂停统一使用 Start，避免同一次按键触发两个动作。
    if event is InputEventJoypadButton:
        is_pause_input = (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
    if is_pause_input:
        toggle_pause()
        get_viewport().set_input_as_handled()


## HUD 始终运行，以便暂停时也能释放触控按键并清理模拟输入。
func _process(_delta: float) -> void:
    _enemy_hints.visible = _game_started and not _game_over and not get_tree().paused
    var now_msec := Time.get_ticks_msec()
    for action_name: String in _touch_action_release_at.keys().duplicate():
        if now_msec >= int(_touch_action_release_at[action_name]):
            Input.action_release(action_name)
            _touch_action_release_at.erase(action_name)


## 失去窗口焦点时清除虚拟摇杆和按住的触控动作，避免恢复后角色持续移动或开火。
func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _clear_touch_input()


## 首次启动在触屏设备显示大号触控区，桌面设备显示紧凑角落状态面板。
func _get_initial_control_mode() -> ControlMode:
    if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
        return ControlMode.TOUCH
    return ControlMode.KEYBOARD_MOUSE


## 按最后一次实际输入设备切换 HUD；模拟触控动作通过 Input.action_press 注入，不会误切设备。
func _detect_control_mode(event: InputEvent) -> void:
    if event is InputEventScreenTouch or event is InputEventScreenDrag:
        _last_touch_event_msec = Time.get_ticks_msec()
        _set_control_mode(ControlMode.TOUCH)
    elif event is InputEventJoypadButton:
        if (event as InputEventJoypadButton).pressed:
            _set_control_mode(ControlMode.GAMEPAD)
    elif event is InputEventJoypadMotion:
        if absf((event as InputEventJoypadMotion).axis_value) >= 0.2:
            _set_control_mode(ControlMode.GAMEPAD)
    elif event is InputEventKey:
        if not (event as InputEventKey).echo and (event as InputEventKey).pressed:
            _set_control_mode(ControlMode.KEYBOARD_MOUSE)
    elif event is InputEventMouseButton or event is InputEventMouseMotion:
        # 部分触屏设备会把同一次触摸额外模拟成鼠标事件，短暂忽略以免提示马上跳回键鼠。
        if Time.get_ticks_msec() - _last_touch_event_msec < 500:
            return
        # 鼠标仅用于菜单点击，避免移动鼠标时覆盖方向键、手柄或触控的战斗提示。
        return


## 按输入设备切换操作区布局；键鼠和手柄保留完整状态信息并压缩到屏幕边角。
func _set_control_mode(mode: ControlMode) -> void:
    if _control_mode_initialized and _control_mode == mode:
        return
    if _control_mode == ControlMode.TOUCH and mode != ControlMode.TOUCH:
        _clear_touch_input()
    _control_mode = mode
    _control_mode_initialized = true
    var is_touch := mode == ControlMode.TOUCH
    for control: Control in [_movement_panel, _attack_panel, _reload_panel, _item_panel, _support_panel, _skill_panel]:
        control.visible = true
    _weapon_previous_hint.visible = is_touch
    _weapon_next_hint.visible = is_touch
    _input_hint_panel.visible = not is_touch
    _apply_control_hud_layout(is_touch)
    _movement_hint.text = "触摸拖动" if is_touch else ("左摇杆" if mode == ControlMode.GAMEPAD else "WASD")
    _attack_title.text = "瞄 准" if is_touch else "攻 击"
    _attack_hint.text = "按住·拖动" if is_touch else ("RB·右摇杆" if mode == ControlMode.GAMEPAD else "↑↓←→")
    _reload_hint.text = "点按" if is_touch else ("X" if mode == ControlMode.GAMEPAD else "R")
    _item_hint.text = "点按" if is_touch else ("B" if mode == ControlMode.GAMEPAD else "F")
    _support_hint.text = "点按" if is_touch else ("Y" if mode == ControlMode.GAMEPAD else "E")
    _update_skill_hint()
    match mode:
        ControlMode.KEYBOARD_MOUSE:
            _input_hint_label.text = "键盘 / ESC"
        ControlMode.GAMEPAD:
            _input_hint_label.text = "手柄 / START"
    if _primary_weapon != null:
        set_weapon_slots(_primary_weapon, _secondary_weapon_slot)


## 触控继续使用大按钮；桌面布局按场景中的紧凑尺寸排列，只覆盖内容方向和触控专属尺寸。
func _apply_control_hud_layout(is_touch: bool) -> void:
    for contents: BoxContainer in [_movement_contents, _attack_contents, _reload_contents, _item_contents, _support_contents, _skill_contents]:
        contents.vertical = is_touch
    _item_title.visible = is_touch
    _support_title.visible = is_touch
    _skill_title.visible = is_touch

    if is_touch:
        _movement_title.add_theme_font_size_override("font_size", 17)
        _movement_hint.add_theme_font_size_override("font_size", 10)
        _attack_title.add_theme_font_size_override("font_size", 16)
        _attack_hint.add_theme_font_size_override("font_size", 10)
        _reload_title.add_theme_font_size_override("font_size", 12)
        _reload_hint.add_theme_font_size_override("font_size", 10)
        _set_bottom_panel_rect(_movement_panel, false, 26.0, -180.0, 180.0, -26.0, Vector2(154.0, 154.0))
        _set_bottom_panel_rect(_attack_panel, true, -174.0, -172.0, -32.0, -30.0, Vector2(142.0, 142.0))
        _set_bottom_panel_rect(_reload_panel, true, -218.0, -282.0, -140.0, -204.0, Vector2(78.0, 78.0))
        _set_bottom_panel_rect(_item_panel, true, -352.0, -252.0, -252.0, -152.0, Vector2(100.0, 100.0))
        _set_bottom_panel_rect(_support_panel, true, -462.0, -252.0, -362.0, -152.0, Vector2(100.0, 100.0))
        _set_bottom_panel_rect(_skill_panel, true, -352.0, -134.0, -264.0, -34.0, Vector2(88.0, 100.0))
        _equipment_icon.custom_minimum_size = Vector2(30.0, 30.0)
        _battle_support_icon.custom_minimum_size = Vector2(34.0, 34.0)
        _skill_icon.custom_minimum_size = Vector2(30.0, 30.0)
        _skill_cooldown.custom_minimum_size = Vector2(54.0, 4.0)
    else:
        _movement_title.add_theme_font_size_override("font_size", 10)
        _movement_hint.add_theme_font_size_override("font_size", 9)
        _attack_title.add_theme_font_size_override("font_size", 10)
        _attack_hint.add_theme_font_size_override("font_size", 9)
        _reload_title.add_theme_font_size_override("font_size", 10)
        _reload_hint.add_theme_font_size_override("font_size", 9)
        _equipment_icon.custom_minimum_size = Vector2(24.0, 24.0)
        _battle_support_icon.custom_minimum_size = Vector2(24.0, 24.0)
        _skill_icon.custom_minimum_size = Vector2(22.0, 22.0)
        _skill_cooldown.custom_minimum_size = Vector2(28.0, 4.0)


## 给触控布局统一设置底边锚点；紧凑桌面尺寸由 HUD.tscn 配置，触控尺寸在此恢复。
func _set_bottom_panel_rect(control: Control, right_anchored: bool, left: float, top: float, right: float, bottom: float, minimum_size: Vector2) -> void:
    var anchor_x := 1.0 if right_anchored else 0.0
    control.anchor_left = anchor_x
    control.anchor_right = anchor_x
    control.anchor_top = 1.0
    control.anchor_bottom = 1.0
    control.offset_left = left
    control.offset_top = top
    control.offset_right = right
    control.offset_bottom = bottom
    control.custom_minimum_size = minimum_size


## 为常用操作添加标准手柄映射；键盘方向键独立射击，手柄动作在不同设备间即时生效。
func _configure_gamepad_bindings() -> void:
    _bind_joypad_button("fire", JOY_BUTTON_RIGHT_SHOULDER)
    _bind_joypad_button("reload", JOY_BUTTON_X)
    _bind_joypad_button("switch_weapon", JOY_BUTTON_LEFT_SHOULDER)
    _bind_joypad_button("use_equipment", JOY_BUTTON_B)
    _bind_joypad_button("battle_support", JOY_BUTTON_Y)
    _bind_joypad_button("use_skill", JOY_BUTTON_A)
    _bind_joypad_button("ui_cancel", JOY_BUTTON_START)
    _bind_joypad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
    _bind_joypad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
    _bind_joypad_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
    _bind_joypad_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)


## 将指定鼠标按键加入动作；当前纯键盘战斗不调用这个扩展入口。
func _bind_mouse_button(action_name: String, button_index: int) -> void:
    if not InputMap.has_action(action_name):
        return
    var event := InputEventMouseButton.new()
    event.button_index = button_index
    if not InputMap.action_has_event(action_name, event):
        InputMap.action_add_event(action_name, event)


## 避免 HUD 重复实例化时向同一输入动作添加重复手柄按钮。
func _bind_joypad_button(action_name: String, button_index: int) -> void:
    if not InputMap.has_action(action_name):
        return
    var event := InputEventJoypadButton.new()
    event.button_index = button_index
    if not InputMap.action_has_event(action_name, event):
        InputMap.action_add_event(action_name, event)


## 将左摇杆四个方向分别映射到既有移动动作，继续复用玩家的标准移动逻辑。
func _bind_joypad_axis(action_name: String, axis: int, axis_direction: float) -> void:
    if not InputMap.has_action(action_name):
        return
    var event := InputEventJoypadMotion.new()
    event.axis = axis
    event.axis_value = axis_direction
    if not InputMap.action_has_event(action_name, event):
        InputMap.action_add_event(action_name, event)


## 触控摇杆和动作按钮都复用 InputMap，玩家脚本无需维护第二套战斗状态。
func _handle_touch_event(event: InputEvent) -> void:
    if _control_mode != ControlMode.TOUCH:
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if _menu_panel.get_global_rect().has_point(touch.position):
                toggle_pause()
                return
            if not _game_started or _game_over or get_tree().paused:
                return
            if _movement_panel.get_global_rect().has_point(touch.position):
                _movement_touch_index = touch.index
                _update_touch_movement(touch.position)
                return
            var action_name := _touch_action_at(touch.position)
            if action_name.is_empty():
                return
            if action_name in ["fire", "use_skill"]:
                _touch_action_indices[action_name] = touch.index
                Input.action_press(action_name)
                if action_name == "fire":
                    _update_touch_aim(touch.position)
            else:
                _pulse_touch_action(action_name)
        else:
            if touch.index == _movement_touch_index:
                _movement_touch_index = -1
                _set_touch_movement(Vector2.ZERO)
            for action_name: String in _touch_action_indices.keys().duplicate():
                if int(_touch_action_indices[action_name]) == touch.index:
                    Input.action_release(action_name)
                    _touch_action_indices.erase(action_name)
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _movement_touch_index:
            _update_touch_movement(drag.position)
        for action_name: String in _touch_action_indices.keys():
            if action_name == "fire" and int(_touch_action_indices[action_name]) == drag.index:
                _update_touch_aim(drag.position)


## 按屏幕坐标命中 HUD 控件，支持连续开火、按住奔跑和点按型操作。
func _touch_action_at(screen_position: Vector2) -> String:
    if _attack_panel.get_global_rect().has_point(screen_position):
        return "fire"
    if _reload_panel.get_global_rect().has_point(screen_position):
        return "reload"
    if _item_panel.get_global_rect().has_point(screen_position):
        return "use_equipment"
    if _support_panel.get_global_rect().has_point(screen_position):
        return "battle_support"
    if _skill_panel.get_global_rect().has_point(screen_position):
        return "use_skill"
    if _weapon_previous_hint.get_global_rect().has_point(screen_position):
        return "weapon_slot_1"
    if _weapon_next_hint.get_global_rect().has_point(screen_position):
        return "switch_weapon"
    if _weapon_panel.get_global_rect().has_point(screen_position):
        return "switch_weapon"
    return ""


## 把触控摇杆位置换算为四个有强度的移动动作，中心小范围作为死区防止漂移。
func _update_touch_movement(screen_position: Vector2) -> void:
    var local_position := _movement_panel.get_global_transform_with_canvas().affine_inverse() * screen_position
    var center := _movement_panel.size * 0.5
    var max_radius := minf(_movement_panel.size.x, _movement_panel.size.y) * 0.36
    var offset := (local_position - center) / maxf(max_radius, 1.0)
    var strength := clampf(offset.length(), 0.0, 1.0)
    if strength <= 0.12:
        _set_touch_movement(Vector2.ZERO)
        return
    var movement := offset.normalized() * ((strength - 0.12) / 0.88)
    _set_touch_movement(movement)


## 触控开火区兼作右摇杆；拖动方向优先作为射击方向，中心小范围不改变上次瞄准。
func _update_touch_aim(screen_position: Vector2) -> void:
    var player := _get_player()
    if player == null:
        return
    var local_position := _attack_panel.get_global_transform_with_canvas().affine_inverse() * screen_position
    var offset := local_position - _attack_panel.size * 0.5
    var deadzone_radius := minf(_attack_panel.size.x, _attack_panel.size.y) * 0.08
    if offset.length() <= deadzone_radius:
        return
    player.set_touch_aim_direction(offset.normalized())


## HUD 与玩家是关卡控制器管理的兄弟节点，延迟缓存以等待玩家完成分组初始化。
func _cache_player() -> void:
    _player = get_tree().get_first_node_in_group("player") as Player


## 玩家重生或关卡替换后刷新缓存，触控瞄准不会依赖固定场景路径。
func _get_player() -> Player:
    if not is_instance_valid(_player):
        _cache_player()
    return _player


## 以摇杆向量更新四个 InputMap 方向，支持斜向移动和渐进强度。
func _set_touch_movement(movement: Vector2) -> void:
    _set_touch_axis_action("move_left", maxf(-movement.x, 0.0))
    _set_touch_axis_action("move_right", maxf(movement.x, 0.0))
    _set_touch_axis_action("move_up", maxf(-movement.y, 0.0))
    _set_touch_axis_action("move_down", maxf(movement.y, 0.0))


## 方向强度归零时释放动作，非零时保持动作按下供玩家持续移动。
func _set_touch_axis_action(action_name: String, strength: float) -> void:
    if strength > 0.01:
        Input.action_press(action_name, strength)
    else:
        Input.action_release(action_name)


## 触控点按动作保持短暂按下，确保玩家逐帧输入能读到 just_pressed。
func _pulse_touch_action(action_name: String) -> void:
    Input.action_press(action_name)
    _touch_action_release_at[action_name] = Time.get_ticks_msec() + 120


## 清理所有虚拟输入状态，包括切换到其他设备时仍按住的触控操作。
func _clear_touch_input() -> void:
    _movement_touch_index = -1
    _set_touch_movement(Vector2.ZERO)
    for action_name: String in _touch_action_indices.keys().duplicate():
        Input.action_release(action_name)
    _touch_action_indices.clear()
    for action_name: String in _touch_action_release_at.keys():
        Input.action_release(action_name)
    _touch_action_release_at.clear()


## 播放开场 3、2、1 倒计时；倒计时期间暂停游戏场景但保持 HUD 可交互。
func _start_game_countdown() -> void:
    if _game_over or _waiting_run_selection:
        return
    _start_sequence_id += 1
    var sequence := _start_sequence_id
    get_tree().paused = true
    _start_overlay.visible = true
    for count: int in [3, 2, 1]:
        _countdown_label.text = str(count)
        await get_tree().create_timer(1.0, true).timeout
        if _game_over or sequence != _start_sequence_id:
            return
    _countdown_label.text = "开始"
    await get_tree().create_timer(0.65, true).timeout
    if _game_over or sequence != _start_sequence_id:
        return
    _start_overlay.visible = false
    _game_started = true
    get_tree().paused = false


## 在游戏运行和暂停菜单之间切换；战败或开场倒计时期间不允许暂停。
func toggle_pause() -> void:
    if _game_over or not _game_started:
        return
    if get_tree().paused:
        resume_game()
    else:
        _pause_overlay.visible = true
        get_tree().paused = true


## 关闭暂停菜单并恢复游戏运行。
func resume_game() -> void:
    if _game_over:
        return
    _pause_overlay.visible = false
    get_tree().paused = false


## 显示战败结果并冻结关卡，避免角色死亡后继续操作。
func show_defeat(total_score: int) -> void:
    if _game_over:
        return
    _game_over = true
    _start_sequence_id += 1
    _game_started = false
    _clear_touch_input()
    _pause_overlay.visible = false
    _start_overlay.visible = false
    _defeat_score_label.text = "总积分  %s" % _format_score(total_score)
    if _run_ui_enabled:
        var snapshot := GameManager.get_run_snapshot()
        _defeat_score_label.text += "\n%s · 已完成 %d / %d 关" % [snapshot["mode_name"], snapshot["completed"], snapshot["total"]]
    _defeat_overlay.visible = true
    get_tree().paused = true
    if _run_ui_enabled:
        _defeat_restart_button.grab_focus()


## 正式对局由宿主启用流程界面；单关场景不显示全局路线和重新开始入口。
func enable_run_ui() -> void:
    _run_ui_enabled = true
    _waiting_run_selection = true
    _defeat_restart_button.visible = true
    %DefeatHomeButton.visible = true
    if not GameManager.sig_run_changed.is_connected(_on_run_changed):
        GameManager.sig_run_changed.connect(_on_run_changed)
    _on_run_changed(GameManager.get_run_snapshot())


## 在开场倒计时前选择进攻模式；暂停场景但 HUD 始终可以接收键盘、手柄和触控。
func show_run_mode_selection() -> void:
    _waiting_run_selection = true
    _mode_choice_pending = false
    _run_mode_error.text = ""
    _airborne_button.disabled = false
    _assault_button.disabled = not CurrencyManager.is_assault_unlocked()
    _run_mode_overlay.visible = true
    get_tree().paused = true
    _airborne_button.grab_focus()


## 防止连按按钮重复创建路线；配置失败时由 show_run_start_error 恢复菜单。
func _choose_run_mode(mode: int) -> void:
    if _mode_choice_pending:
        return
    _mode_choice_pending = true
    _airborne_button.disabled = true
    _assault_button.disabled = true
    sig_run_mode_selected.emit(mode)


## 抽取配置不完整时留在模式菜单，玩家可以查看错误而不是进入空关卡。
func show_run_start_error(message: String) -> void:
    show_run_mode_selection()
    _run_mode_error.text = message


## 开始生成下一关前冻结战斗并清理虚拟按键，避免切关期间继续发射或使用道具。
func prepare_run_stage(stage_number: int, theme_name: String) -> void:
    _start_sequence_id += 1
    _game_started = false
    _clear_touch_input()
    _run_mode_overlay.visible = false
    _pause_overlay.visible = false
    _start_overlay.visible = true
    _countdown_label.text = "第 %d 关\n%s" % [stage_number, theme_name]
    get_tree().paused = true


## 首关播放既有 3、2、1 倒计时，其余关卡短暂显示主题后恢复同一个玩家和 HUD。
func start_run_stage(stage_number: int, theme_name: String) -> void:
    _waiting_run_selection = false
    if stage_number == 1:
        _start_game_countdown.call_deferred()
        return
    _start_sequence_id += 1
    var sequence := _start_sequence_id
    _countdown_label.text = "第 %d 关\n%s" % [stage_number, theme_name]
    await get_tree().create_timer(0.65, true).timeout
    if _game_over or sequence != _start_sequence_id:
        return
    _start_overlay.visible = false
    _game_started = true
    get_tree().paused = false


## 最后一个 Level 的安全出口完成后显示胜利；单关测试也可以使用同一结果页。
func show_run_victory(total_score: int, title: String = "任务完成") -> void:
    _game_over = true
    _game_started = false
    _start_sequence_id += 1
    _clear_touch_input()
    _start_overlay.visible = false
    _pause_overlay.visible = false
    _run_mode_overlay.visible = false
    _victory_title.text = title
    _victory_score.text = "总积分  %s" % _format_score(total_score)
    if _run_ui_enabled:
        var snapshot := GameManager.get_run_snapshot()
        _victory_score.text += "\n%s · 完成 %d / %d 关" % [snapshot["mode_name"], snapshot["completed"], snapshot["total"]]
    %VictoryRestartButton.visible = _run_ui_enabled
    %VictoryHomeButton.visible = _run_ui_enabled
    _victory_overlay.visible = true
    get_tree().paused = true
    if _run_ui_enabled:
        %VictoryRestartButton.grab_focus()
    else:
        %VictoryExitButton.grab_focus()


## 从全局快照更新整局直线路线，完成节点绿色、当前黄色、失败红色，固定终点额外标记。
func _on_run_changed(snapshot: Dictionary) -> void:
    if not _run_ui_enabled:
        return
    var total := int(snapshot.get("total", 0))
    _run_progress_panel.visible = total > 0
    _run_progress_bar.max_value = maxi(total, 1)
    _run_progress_bar.value = int(snapshot.get("completed", 0))
    for child: Node in _run_route.get_children():
        _run_route.remove_child(child)
        child.queue_free()
    if total == 0:
        return
    var levels: Array = snapshot.get("levels", [])
    var current := int(snapshot["current"])
    var current_name := str(levels[clampi(current - 1, 0, levels.size() - 1)]["name"])
    _run_progress_label.text = "%s · 第 %d / %d 关 · %s · 已完成 %d" % [snapshot["mode_name"], current, total, current_name, snapshot["completed"]]
    for index: int in range(levels.size()):
        var level: Dictionary = levels[index]
        if index > 0:
            var arrow := Label.new()
            arrow.text = "→"
            arrow.add_theme_font_size_override("font_size", 10)
            arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
            _run_route.add_child(arrow)
        var panel := PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var color := Color(0.6, 0.66, 0.61)
        var marker := "○"
        match str(level["status"]):
            "completed":
                color = Color(0.64, 0.78, 0.47)
                marker = "✓"
            "current":
                color = Color(0.96, 0.79, 0.35)
                marker = "▶"
            "failed":
                color = Color(0.86, 0.4, 0.35)
                marker = "×"
        var style := StyleBoxFlat.new()
        style.bg_color = Color(color.r, color.g, color.b, 0.14)
        style.border_color = color
        style.set_border_width_all(1)
        style.set_corner_radius_all(4)
        style.content_margin_left = 4.0
        style.content_margin_right = 4.0
        style.content_margin_top = 3.0
        style.content_margin_bottom = 3.0
        panel.add_theme_stylebox_override("panel", style)
        var label := Label.new()
        label.text = "%s %s" % [marker, level["name"]]
        if bool(level.get("fixed", false)):
            label.text += "\n固定终点"
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_color_override("font_color", color)
        label.add_theme_font_size_override("font_size", 10)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(label)
        _run_route.add_child(panel)


## 同步关卡总积分到 HUD 顶部得分栏。
## 货币与积分分开显示，积分不会作为可消费余额。
func set_score(total_score: int) -> void:
    _score_value.text = _format_score(total_score)


## 钱包变更直接推送到 HUD；结果页也显示本局带出的研究与账户累计数。
func _on_currency_changed(snapshot: Dictionary) -> void:
    _currency_value.text = "金钱 $ %s\n研究 ◆ %s\n已存 ◆ %s" % [_format_score(int(snapshot["money"])), _format_score(int(snapshot["research_run"])), _format_score(int(snapshot["research_bank"]))]
    var result := "带出研究 +%s\n研究账户 %s · 金钱不带出" % [_format_score(int(snapshot["research_run"])), _format_score(int(snapshot["research_bank"]))]
    if bool(snapshot["settlement_failed"]):
        result = "研究 +%s 尚未保存\n请点重新开始重试，或检查存档目录权限" % _format_score(int(snapshot["research_run"]))
    %DefeatCurrency.text = result
    %VictoryCurrency.text = result


## 保留当前 Boss 名称，使坦克阶段切换后血条不会恢复为 GENERAL。
var _boss_display_name: String = "GENERAL"


## 首次显示 Boss 血条，并设置 Boss 名称、阶段和当前生命值。
func show_boss_health(boss_name: String, current_health: int, max_health: int, phase: int) -> void:
    _boss_display_name = boss_name
    _boss_name_label.text = "%s  /  PHASE %02d" % [boss_name, phase]
    set_boss_health(current_health, max_health)
    _boss_health_panel.visible = true


## 更新 Boss 血条；阶段切换时最大值和当前值会一起重置。
func set_boss_health(current_health: int, max_health: int) -> void:
    var safe_max_health := maxi(max_health, 1)
    _boss_health_bar.max_value = safe_max_health
    _boss_health_bar.value = clampi(current_health, 0, safe_max_health)


## 阶段切换时同步血条标题和生命值。
func set_boss_phase(phase: int, current_health: int, max_health: int) -> void:
    _boss_name_label.text = "%s  /  PHASE %02d" % [_boss_display_name, phase]
    set_boss_health(current_health, max_health)
    _boss_health_panel.visible = true


## Boss 最终被击败时隐藏魂类风格血条。
func hide_boss_health() -> void:
    _boss_health_panel.visible = false


## 使用关卡生成器提供的同一份地图数据更新路线小地图和访问状态。
func set_room_map(level_map: Dictionary, current_room_id: int, visited_room_ids: Array[int]) -> void:
    _enemy_hints.current_room_id = current_room_id
    _enemy_hints.refresh_hints()
    _room_minimap.set_map_data(level_map, current_room_id, visited_room_ids)


## 将积分转换为带千位分隔符的展示文本。
func _format_score(value: int) -> String:
    var digits := str(maxi(value, 0))
    var formatted := ""
    for index: int in range(digits.length()):
        if index > 0 and (digits.length() - index) % 3 == 0:
            formatted += ","
        formatted += digits[index]
    return formatted


## 从统一音效设置读取音量并同步菜单滑块；音乐由首页独立控制。
func _sync_volume_slider() -> void:
    _volume_slider.set_value_no_signal(GameSettings.sfx_volume * 100.0)
    _update_volume_label(_volume_slider.value)


## 将滑块百分比应用到 SFX 总线，不再同时改变音乐。
func _on_volume_changed(value: float) -> void:
    GameSettings.set_sfx_volume(value / 100.0)
    _update_volume_label(value)


## 显示音量百分比。
func _update_volume_label(value: float) -> void:
    _volume_label.text = "音效音量  %d%%" % roundi(value)
    if GameSettings.sfx_muted:
        _volume_label.text += "（静音）"


## 点击 HUD 右上角圆形菜单时打开暂停菜单。
func _on_menu_panel_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        toggle_pause()
        _menu_panel.accept_event()


## 退出当前游戏进程，并先解除暂停状态。
func _exit_game() -> void:
    GameSettings.save_now()
    get_tree().paused = false
    get_tree().quit()


## 关卡绑定玩家后将相同引用传给方位提示，避免 UI 猜测玩家所在场景。
func set_enemy_hint_player(player: Node2D) -> void:
    _enemy_hints.player = player


## 更新体力条；满体力为冷蓝色，体力低于四分之一时转为琥珀色。
func set_stamina(current: float, maximum: float) -> void:
    _stamina_bar.max_value = maxf(maximum, 1.0)
    _stamina_bar.value = clampf(current, 0.0, maximum)
    _stamina_fill_style.bg_color = Color("edb666") if current < maximum * 0.25 else Color("66bac7")
    _stamina_bar.add_theme_stylebox_override("fill", _stamina_fill_style)


## 根据玩家当前生命值和上限更新血条与数值。
func set_health(current_health: int, max_health: int) -> void:
    var safe_max_health := maxi(max_health, 1)
    var safe_current_health := clampi(current_health, 0, safe_max_health)

    _health_bar.max_value = safe_max_health
    _health_bar.value = safe_current_health
    _health_value_label.text = "%d / %d" % [safe_current_health, safe_max_health]
    _health_fill_style.bg_color = COLOR_HEALTH_LOW if safe_current_health * 4 <= safe_max_health else COLOR_HEALTH_NORMAL


## 更新武器图标和名称；显示内容由当前武器槽类型决定。
func set_weapon(weapon: PlayerWeaponSlot) -> void:
    if weapon == null:
        return

    if weapon.weapon_icon != null:
        _weapon_icon.texture = weapon.weapon_icon
        _weapon_name.text = weapon.display_name
    elif weapon is PlayerWeaponPistol:
        _weapon_icon.texture = WEAPON_ICON_PISTOL
        _weapon_name.text = WEAPON_NAME_PISTOL
    elif weapon is PlayerWeaponSMG:
        _weapon_icon.texture = WEAPON_ICON_SMG
        _weapon_name.text = WEAPON_NAME_SMG
    elif weapon is PlayerWeaponShortgun:
        _weapon_icon.texture = WEAPON_ICON_SHORTGUN
        _weapon_name.text = WEAPON_NAME_SHORTGUN


## 同步主副武器栏；主栏突出当前武器，副栏以紧凑信息提示下一件可用武器。
func set_weapon_slots(primary: PlayerWeaponSlot, secondary: PlayerWeaponSlot) -> void:
    _primary_weapon = primary
    _secondary_weapon_slot = secondary
    set_weapon(primary)
    var switch_hint := "触控切换" if _control_mode == ControlMode.TOUCH else ("LB 切换" if _control_mode == ControlMode.GAMEPAD else "Q 切换")
    _secondary_icon.visible = secondary != null
    if secondary == null:
        _secondary_name.text = "%s · 未解锁" % switch_hint
        _secondary_ammo.text = ""
        return
    if secondary.weapon_icon != null:
        _secondary_icon.texture = secondary.weapon_icon
        _secondary_name.text = "%s · %s" % [switch_hint, secondary.display_name]
    elif secondary is PlayerWeaponPistol:
        _secondary_icon.texture = WEAPON_ICON_PISTOL
        _secondary_name.text = "%s · 手枪" % switch_hint
    elif secondary is PlayerWeaponSMG:
        _secondary_icon.texture = WEAPON_ICON_SMG
        _secondary_name.text = "%s · 冲锋枪" % switch_hint
    elif secondary is PlayerWeaponShortgun:
        _secondary_icon.texture = WEAPON_ICON_SHORTGUN
        _secondary_name.text = "%s · 霰弹枪" % switch_hint
    var back_text: String = "∞" if secondary.ammo_back_cur < 0 else str(secondary.ammo_back_cur)
    _secondary_ammo.text = "%d / %s" % [secondary.ammo_magazine_cur, back_text]


## 更新武器切换等待进度条，填满后当前武器可以开火。
func set_switch_progress(progress: float) -> void:
    _switch_progress.value = clampf(progress, 0.0, 1.0) * 100.0


## 显示战场支援槽内容；支援被使用后同步为空槽状态。
func set_battle_support(support_type: LootItem.Type) -> void:
    _battle_support_icon.visible = support_type != LootItem.Type.Empty
    match support_type:
        LootItem.Type.SupportMortarStriker:
            _battle_support_icon.texture = SUPPORT_ICON_MORTAR
            _battle_support_name.text = "迫击炮"
        LootItem.Type.SupportTacticalBombing:
            _battle_support_icon.texture = SUPPORT_ICON_BOMBING
            _battle_support_name.text = "战术轰炸"
        _:
            _battle_support_name.text = "无支援"


## 更新当前武器弹匣与备弹数量；负数备弹值按无限弹药显示。
func set_ammo(current: int, back: int) -> void:
    var back_text: String = "∞" if back < 0 else str(back)
    _ammo_value.text = "%d  /  %s" % [current, back_text]


## 更新背景换弹条；ProgressBar 默认从左向右填充。
func set_reload_progress(progress: float) -> void:
    var safe_progress: float = clampf(progress, 0.0, 1.0)
    _reload_progress.value = safe_progress * 100.0
    _reload_progress.visible = safe_progress < 1.0


## 更新唯一技能槽图标、提示和冷却进度；奔跑/闪避状态会即时反馈在名称上。
func set_skill(skill_type: LootItem.Type, cooldown_remaining: float, cooldown_duration: float, is_active: bool) -> void:
    _skill_icon.visible = skill_type != LootItem.Type.Empty
    _skill_cooldown.visible = cooldown_remaining > 0.0
    _skill_cooldown.value = (1.0 - clampf(cooldown_remaining / maxf(cooldown_duration, 0.01), 0.0, 1.0)) * 100.0
    match skill_type:
        LootItem.Type.SkillSprint:
            _skill_icon.texture = SKILL_ICON_SPRINT
            _skill_name.text = "奔跑中" if is_active else "奔跑"
        LootItem.Type.SkillDodge:
            _skill_icon.texture = SKILL_ICON_DODGE
            _skill_name.text = "闪避中" if is_active else "闪避"
        _:
            _skill_name.text = "未装备"
    _update_skill_hint()


## 技能提示随输入设备更新；触控奔跑保持按住，闪避点按触发。
func _update_skill_hint() -> void:
    if _skill_name.text == "未装备":
        _skill_hint.text = "拾取技能"
        return
    var action_hint := "触控" if _control_mode == ControlMode.TOUCH else ("A" if _control_mode == ControlMode.GAMEPAD else "空格")
    if _skill_name.text.begins_with("奔跑"):
        _skill_hint.text = "按住%s" % action_hint
    else:
        _skill_hint.text = "按下%s" % action_hint


## 显示当前装备图标、数量或护盾耐久，并标记护盾启用状态。
func set_equipment(equipment_type: Player.EquipmentType, amount: int, shield_active: bool) -> void:
    _equipment_icon.visible = equipment_type != Player.EquipmentType.NONE
    match equipment_type:
        Player.EquipmentType.GRENADE:
            _equipment_icon.texture = EQUIPMENT_ICON_GRENADE
            _equipment_value.text = "手雷  × %d" % amount
        Player.EquipmentType.MOLOTOV:
            _equipment_icon.texture = EQUIPMENT_ICON_MOLOTOV
            _equipment_value.text = "燃烧瓶  × %d" % amount
        Player.EquipmentType.SHIELD:
            _equipment_icon.texture = EQUIPMENT_ICON_SHIELD
            _equipment_value.text = "护盾%s  %d / 50" % ["已启用" if shield_active else "待命", amount]
        _:
            _equipment_value.text = "未装备"

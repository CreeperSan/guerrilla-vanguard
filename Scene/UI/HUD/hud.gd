## 战斗 HUD：场景文件负责布局，本脚本更新玩家生命值和当前武器状态。
class_name GameHUD
extends CanvasLayer

const COLOR_HEALTH_NORMAL := Color("#bdd28a")
const COLOR_HEALTH_LOW := Color("#e57b68")
const WEAPON_ICON_PISTOL: Texture2D = preload("res://Prefab/Player/player_weapon_pistol.png")
const WEAPON_ICON_SMG: Texture2D = preload("res://Prefab/Player/player_weapon_smg.png")
const WEAPON_ICON_SHORTGUN: Texture2D = preload("res://Prefab/Player/player_weapon_shortgun.png")
const EQUIPMENT_ICON_GRENADE: Texture2D = preload("res://Prefab/grenade/grenade.png")
const EQUIPMENT_ICON_MOLOTOV: Texture2D = preload("res://Prefab/molotov/molotov.png")
const EQUIPMENT_ICON_SHIELD: Texture2D = preload("res://Prefab/shield/shield.png")
const SUPPORT_ICON_MORTAR: Texture2D = preload("res://Prefab/MortarStriker/mortar_strike.png")
const SUPPORT_ICON_BOMBING: Texture2D = preload("res://Prefab/TactialBoming/tactial_boming.png")
const SKILL_ICON_SPRINT: Texture2D = preload("res://Assets/UI/skill_sprint.svg")
const SKILL_ICON_DODGE: Texture2D = preload("res://Assets/UI/skill_dodge.svg")
const WEAPON_NAME_PISTOL := "手枪 / PISTOL"
const WEAPON_NAME_SMG := "冲锋枪 / SMG"
const WEAPON_NAME_SHORTGUN := "霰弹枪 / SHOTGUN"

@onready var _health_bar: ProgressBar = %HealthBar
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

var _game_started: bool = false
var _game_over: bool = false


## 复制场景中的血条样式，避免运行时改色影响其他 HUD 实例。
func _ready() -> void:
    _health_bar.add_theme_stylebox_override("fill", _health_fill_style)
    $UIRoot/PauseOverlay/CenterContainer/MenuCard/Contents/ContinueButton.pressed.connect(resume_game)
    $UIRoot/PauseOverlay/CenterContainer/MenuCard/Contents/ExitButton.pressed.connect(_exit_game)
    $UIRoot/DefeatOverlay/CenterContainer/MenuCard/Contents/ExitButton.pressed.connect(_exit_game)
    _volume_slider.value_changed.connect(_on_volume_changed)
    _menu_panel.gui_input.connect(_on_menu_panel_gui_input)
    set_score(0)
    _sync_volume_slider()
    call_deferred("_start_game_countdown")


## 按 Escape 或点击右上角菜单按钮时切换暂停状态。
func _input(event: InputEvent) -> void:
    var is_key_echo: bool = event is InputEventKey and (event as InputEventKey).echo
    if event.is_action_pressed("ui_cancel") and not is_key_echo:
        toggle_pause()
        get_viewport().set_input_as_handled()


## 播放开场 3、2、1 倒计时；倒计时期间暂停游戏场景但保持 HUD 可交互。
func _start_game_countdown() -> void:
    if _game_over:
        return
    get_tree().paused = true
    _start_overlay.visible = true
    for count: int in [3, 2, 1]:
        _countdown_label.text = str(count)
        await get_tree().create_timer(1.0, true).timeout
    _countdown_label.text = "开始"
    await get_tree().create_timer(0.65, true).timeout
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
    _game_started = false
    _pause_overlay.visible = false
    _start_overlay.visible = false
    _defeat_score_label.text = "总积分  %s" % _format_score(total_score)
    _defeat_overlay.visible = true
    get_tree().paused = true


## 同步关卡总积分到 HUD 顶部得分栏。
func set_score(total_score: int) -> void:
    _score_value.text = _format_score(total_score)


## 首次显示 Boss 血条，并设置 Boss 名称、阶段和当前生命值。
func show_boss_health(boss_name: String, current_health: int, max_health: int, phase: int) -> void:
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
    _boss_name_label.text = "GENERAL  /  PHASE %02d" % phase
    set_boss_health(current_health, max_health)
    _boss_health_panel.visible = true


## Boss 最终被击败时隐藏魂类风格血条。
func hide_boss_health() -> void:
    _boss_health_panel.visible = false


## 将积分转换为带千位分隔符的展示文本。
func _format_score(value: int) -> String:
    var digits := str(maxi(value, 0))
    var formatted := ""
    for index: int in range(digits.length()):
        if index > 0 and (digits.length() - index) % 3 == 0:
            formatted += ","
        formatted += digits[index]
    return formatted


## 从 Master 音频总线读取音量并同步菜单滑块。
func _sync_volume_slider() -> void:
    var master_bus := AudioServer.get_bus_index("Master")
    if master_bus < 0:
        push_warning("找不到 Master 音频总线，音量滑块无法同步。")
        return
    var volume_db := AudioServer.get_bus_volume_db(master_bus)
    var volume_linear := db_to_linear(volume_db)
    _volume_slider.value = clampf(volume_linear * 100.0, 0.0, 100.0)
    _update_volume_label(_volume_slider.value)


## 将滑块百分比应用到 Master 总线，并更新可读音量数值。
func _on_volume_changed(value: float) -> void:
    var master_bus := AudioServer.get_bus_index("Master")
    if master_bus < 0:
        return
    AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(value / 100.0, 0.0001)))
    if value <= 0.0:
        AudioServer.set_bus_mute(master_bus, true)
    else:
        AudioServer.set_bus_mute(master_bus, false)
    _update_volume_label(value)


## 显示音量百分比。
func _update_volume_label(value: float) -> void:
    _volume_label.text = "音效音量  %d%%" % roundi(value)


## 点击 HUD 右上角圆形菜单时打开暂停菜单。
func _on_menu_panel_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        toggle_pause()
        _menu_panel.accept_event()


## 退出当前游戏进程，并先解除暂停状态。
func _exit_game() -> void:
    get_tree().paused = false
    get_tree().quit()


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

    if weapon is PlayerWeaponPistol:
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
    set_weapon(primary)
    _secondary_icon.visible = secondary != null
    if secondary == null:
        _secondary_name.text = "Q 切换 · 未解锁"
        _secondary_ammo.text = ""
        return
    if secondary is PlayerWeaponPistol:
        _secondary_icon.texture = WEAPON_ICON_PISTOL
        _secondary_name.text = "Q 切换 · 手枪"
    elif secondary is PlayerWeaponSMG:
        _secondary_icon.texture = WEAPON_ICON_SMG
        _secondary_name.text = "Q 切换 · 冲锋枪"
    elif secondary is PlayerWeaponShortgun:
        _secondary_icon.texture = WEAPON_ICON_SHORTGUN
        _secondary_name.text = "Q 切换 · 霰弹枪"
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
            _skill_hint.text = "按住 K"
        LootItem.Type.SkillDodge:
            _skill_icon.texture = SKILL_ICON_DODGE
            _skill_name.text = "闪避中" if is_active else "闪避"
            _skill_hint.text = "按下 K"
        _:
            _skill_name.text = "未装备"
            _skill_hint.text = "拾取技能"


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

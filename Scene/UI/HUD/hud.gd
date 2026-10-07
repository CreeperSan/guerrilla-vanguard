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


## 复制场景中的血条样式，避免运行时改色影响其他 HUD 实例。
func _ready() -> void:
    _health_bar.add_theme_stylebox_override("fill", _health_fill_style)


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

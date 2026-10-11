## 常驻战斗规则服务：读取外部资源与可选 CFG，开局固定参数，跨关不重复叠乘。
extends Node
const DEFAULT_CONFIG: CombatBalanceConfig = preload("res://Script/Balance/combat_balance.tres")
const USER_OVERRIDE_PATH := "user://combat_balance.cfg"
const CLI_CONFIG_PREFIX := "--combat-balance-config="
@export var config: CombatBalanceConfig = DEFAULT_CONFIG
var _profile: BattleModeProfile
var _base_damage_multiplier := 1.0

## 命令行 -- 后可指定 CFG；未指定时读取用户目录同名文件，缺省使用项目资源。
func _ready() -> void:
	config = config.duplicate(true) as CombatBalanceConfig
	var path := USER_OVERRIDE_PATH
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(CLI_CONFIG_PREFIX):
			path = argument.trim_prefix(CLI_CONFIG_PREFIX)
	var error := config.load_overrides(path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("战斗配置覆盖无效，继续使用默认资源：%s（错误码 %s）" % [path, error])
	if not config.is_valid():
		config = DEFAULT_CONFIG.duplicate(true) as CombatBalanceConfig
	configure_mode(BattleModeProfile.Mode.AIRBORNE)

## 每次新局或回首页设置模式，参数快照隔离后续配置编辑；重复调用不会缩放已有数值。
func configure_mode(mode: int) -> bool:
	if not config.is_valid():
		return false
	var selected := config.get_profile(mode)
	if selected == null:
		return false
	_profile = selected.duplicate(true) as BattleModeProfile
	_base_damage_multiplier = config.base_enemy_damage_multiplier
	return true

## 生命输入始终是角色/阶段的原始配置值，向上取整且至少为 1。
func scale_enemy_health(base_health: int) -> int:
	var factor := _profile.enemy_health_multiplier if _profile != null else 1.0
	return maxi(1, ceili(maxi(base_health, 1) * factor))

## 敌军伤害仅在生命组件结算入口放大一次，涵盖所有攻击类型和持续效果。
func scale_enemy_damage(base_damage: int) -> int:
	var factor := _profile.enemy_damage_multiplier if _profile != null else 1.0
	return maxi(0, ceili(maxi(base_damage, 0) * _base_damage_multiplier * factor))

## 界面读取同一份名称配置，旧模式 ID 无需迁移。
func get_mode_name(mode: int) -> String:
	var profile := config.get_profile(mode)
	return profile.display_name if profile != null else "未知模式"

## 平衡参数集合：全局基础难度与各模式倍率分层，支持资源和外部 CFG 覆盖。
class_name CombatBalanceConfig
extends Resource
@export_range(0.0, 100.0, 0.01, "or_greater") var base_enemy_damage_multiplier := 1.0
@export var modes: Array[BattleModeProfile] = []

## 根据稳定模式 ID 查找资源；不存在时返回 null，由启动入口拒绝该模式。
func get_profile(mode: int) -> BattleModeProfile:
	for profile: BattleModeProfile in modes:
		if profile != null and profile.mode_id == mode:
			return profile
	return null

## 资源必须覆盖现有两种正式模式，并拒绝重复 ID/外部节名。
func is_valid() -> bool:
	if not is_finite(base_enemy_damage_multiplier) or base_enemy_damage_multiplier < 0.0:
		return false
	var ids := {}
	var keys := {}
	for profile: BattleModeProfile in modes:
		if profile == null or not profile.is_valid() or ids.has(profile.mode_id) or keys.has(profile.config_key):
			return false
		ids[profile.mode_id] = true
		keys[profile.config_key] = true
	return get_profile(BattleModeProfile.Mode.AIRBORNE) != null and get_profile(BattleModeProfile.Mode.COUNTERATTACK) != null

## 在副本上应用可选覆盖，全部验证成功后才提交；错误文件不会只改动一半配置。
func load_overrides(path: String) -> Error:
	var file := ConfigFile.new()
	var error := file.load(path)
	if error != OK:
		return error
	var candidate := duplicate(true) as CombatBalanceConfig
	var base: Variant = file.get_value("base", "enemy_damage_multiplier", candidate.base_enemy_damage_multiplier)
	if not (base is float or base is int):
		return ERR_INVALID_DATA
	candidate.base_enemy_damage_multiplier = float(base)
	for profile: BattleModeProfile in candidate.modes:
		for field: String in ["enemy_health_multiplier", "enemy_damage_multiplier"]:
			var value: Variant = file.get_value(profile.config_key, field, profile.get(field))
			if not (value is float or value is int):
				return ERR_INVALID_DATA
			profile.set(field, float(value))
	if not candidate.is_valid():
		return ERR_INVALID_DATA
	base_enemy_damage_multiplier = candidate.base_enemy_damage_multiplier
	modes = candidate.modes
	return OK

## 战场升级配置读取器：UI、购买校验和战斗效果共用同一份数值资源，避免数值不同步。
## 修改 battlefield_upgrades.tres 后重新启动游戏；倍率始终相对武器原始属性。
class_name BattlefieldUpgradeConfig
extends RefCounted

const CONFIG_PATH := "res://Script/Config/battlefield_upgrades.tres"
const BALANCE: Resource = preload("res://Script/Config/battlefield_upgrades.tres")
const MAX_LEVEL := 3
static var _config: Dictionary = {}


## 延迟读取并验证可调配置；非法项目不开放购买，避免扣款后没有有效效果。
static func get_config() -> Dictionary:
	if not _config.is_empty():
		return _config
	var parsed: Dictionary = {"upgrades": BALANCE.get("upgrades"), "shotgun": {"pellets": BALANCE.get("shotgun_pellets"), "spread_degrees": BALANCE.get("shotgun_spread_degrees")}}
	if not parsed is Dictionary or not parsed.get("upgrades") is Dictionary:
		push_error("战场升级配置格式无效：" + CONFIG_PATH)
		return {}
	for id: String in parsed["upgrades"]:
		var entry: Variant = parsed["upgrades"][id]
		if not entry is Dictionary or not entry.get("costs") is Array or not entry.get("multipliers") is Array:
			push_error("升级配置字段无效：" + id)
			return {}
		if entry["costs"].size() != MAX_LEVEL or entry["multipliers"].size() != MAX_LEVEL:
			push_error("升级项目必须有三级费用和倍率：" + id)
			return {}
		var previous := 1.0
		for level: int in range(MAX_LEVEL):
			var cost: Variant = entry["costs"][level]
			var multiplier: Variant = entry["multipliers"][level]
			if not (cost is int or cost is float) or not (multiplier is int or multiplier is float):
				push_error("升级费用和倍率必须为数值：" + id)
				return {}
			if not is_finite(float(cost)) or cost <= 0 or float(cost) != floorf(float(cost)) or not is_finite(float(multiplier)) or multiplier <= previous:
				push_error("升级费用须为正整数，倍率须逐级增加：" + id)
				return {}
			previous = float(multiplier)
	_config = parsed
	return _config


## 返回指定项目；未知 ID 返回空字典，由购买入口拒绝处理。
static func get_entry(id: String) -> Dictionary:
	return get_config().get("upgrades", {}).get(id, {})


## 零级是原始能力，一级至三级使用各自的累计倍率，不进行连乘。
static func get_multiplier(id: String, level: int) -> float:
	var entry := get_entry(id)
	if entry.is_empty() or level <= 0:
		return 1.0
	return float(entry["multipliers"][clampi(level, 1, MAX_LEVEL) - 1])

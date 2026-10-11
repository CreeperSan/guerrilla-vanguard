## 单一模式的外部平衡参数：稳定 ID 与显示名称分离，改名不会影响存档。
class_name BattleModeProfile
extends Resource

## FULL_ASSAULT 保留为旧脚本兼容别名，实际模式 ID 始终为 1。
enum Mode { AIRBORNE = 0, COUNTERATTACK = 1, FULL_ASSAULT = COUNTERATTACK }
@export_enum("空降:0", "反击:1") var mode_id: int = Mode.AIRBORNE
@export var config_key: String = "airborne"
@export var display_name: String = "空降模式"
@export_range(0.01, 100.0, 0.01, "or_greater") var enemy_health_multiplier := 1.0
@export_range(0.0, 100.0, 0.01, "or_greater") var enemy_damage_multiplier := 1.0

## 拒绝非有限数、空标识和非正生命倍率，避免坏配置令整局敌人失效。
func is_valid() -> bool:
	return not config_key.is_empty() and not display_name.is_empty() and is_finite(enemy_health_multiplier) and enemy_health_multiplier > 0.0 and is_finite(enemy_damage_multiplier) and enemy_damage_multiplier >= 0.0

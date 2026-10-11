## 佣兵房：每个房间按独立内容种子选一种佣兵，预览、招募和肖像共用同一实例。
extends FortressRoomTemplate

const MERCENARY_VARIANTS: Array[PackedScene] = [
	preload("res://Prefab/Mercenary/mercenary.tscn"),
	preload("res://Prefab/Mercenary/mercenary_grenadier.tscn"),
	preload("res://Prefab/Mercenary/mercenary_fearless.tscn"),
]
## -1 为种子随机；固定值便于编辑器预览与回归测试，不改变随机房间出现概率。
@export_range(-1, 2, 1) var recruitment_role: int = -1


## 子节点就绪后替换展示角色；激活为盟友仍由关卡控制器统一扣费和接管。
func _ready() -> void:
	super._ready()
	var rng := RandomNumberGenerator.new()
	rng.seed = (population_seed if population_seed != 0 else (room_id + 1) * 7919) ^ 0x4D455243
	var role := recruitment_role if recruitment_role >= 0 else rng.randi_range(0, MERCENARY_VARIANTS.size() - 1)
	var candidate := get_node("HireableMercenary") as HiredMercenary
	if role != 0:
		var preview_position := candidate.position
		remove_child(candidate)
		candidate.free()
		candidate = MERCENARY_VARIANTS[role].instantiate() as HiredMercenary
		candidate.name = "HireableMercenary"
		candidate.position = preview_position
		candidate.starts_hired = false
		add_child(candidate)
	var recruitment := get_node("RecruitmentPoint") as MercenaryRecruitment
	recruitment.configure_candidate(candidate)

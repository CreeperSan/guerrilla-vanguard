## 可破坏木箱：承受子弹伤害，破碎时按概率生成随机拾取物。
class_name TerrainBoxCrate
extends StaticBody2D

## 木箱生命值；按需求默认设置为 10。
@export_range(1, 999, 1) var health_points: int = 10
## 木箱破碎时生成拾取物的概率。
@export_range(0.0, 1.0, 0.01) var loot_drop_probability: float = 0.35
## 关卡可以指定补给箱外观，生命和掉落规则仍复用同一预制体。
@export var appearance_texture: Texture2D

@onready var health_component: HealthComponent = $Health

## 箱子可掉落的既有物品类型；图标和拾取效果复用 LootItem。
const DROP_TYPES: Array = [
	LootItem.Type.WeaponSMG,
	LootItem.Type.WeaponShortgun,
	LootItem.Type.EquipmentGrenade,
	LootItem.Type.EquipmentMolotov,
	LootItem.Type.EquipmentShield,
	LootItem.Type.SupportMortarStriker,
	LootItem.Type.SupportTacticalBombing,
	LootItem.Type.SkillSprint,
	LootItem.Type.SkillDodge,
]


## 初始化生命值并在箱子生命耗尽后生成掉落、清除箱体。
func _ready() -> void:
	if appearance_texture != null:
		$Sprite2D.texture = appearance_texture
	add_to_group("damageable_terrain")
	collision_layer = Definition.PHYSICS_LAYER_TERRAIN
	health_component.health_max = maxi(health_points, 1)
	health_component.health = health_component.health_max
	health_component.sig_die.connect(_on_broken)


## 木箱破碎时只触发一次概率掉落，然后移除箱子节点。
func _on_broken() -> void:
	_try_drop_loot()
	queue_free()


## 按随机物品种类生成对应数量的可拾取场景。
func _try_drop_loot() -> void:
	if randf() >= clampf(loot_drop_probability, 0.0, 1.0):
		return

	var loot_type: LootItem.Type = DROP_TYPES[randi_range(0, DROP_TYPES.size() - 1)]
	var amount: int = 1
	if loot_type in [LootItem.Type.WeaponSMG, LootItem.Type.WeaponShortgun]:
		amount = 24
	var loot_item: LootItem = PrefabManager.create_loot_item(loot_type, amount)
	if loot_item == null:
		return

	# 掉落物保留在箱子所属房间内，随房间一起淡出和卸载，避免切房后仍显示旧补给。
	var world: Node = get_parent()
	if world == null:
		return
	world.add_child(loot_item)
	loot_item.global_position = global_position + Vector2(randf_range(-8.0, 8.0), -8.0)

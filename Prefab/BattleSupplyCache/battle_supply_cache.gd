## 战斗补给房的锁定箱；清场后打开并一次性释放各类奖励。
class_name BattleSupplyCache
extends Node2D

const REWARD_OFFSETS: Array[Vector2] = [
	Vector2(-76.0, 0.0),
	Vector2(-38.0, 72.0),
	Vector2(0.0, 94.0),
	Vector2(38.0, 72.0),
	Vector2(76.0, 0.0),
]

@onready var _sprite: Sprite2D = $Sprite2D

var _opened: bool = false


## 向房间逻辑和契约测试公开当前箱体状态，不暴露内部 Sprite2D。
func is_opened() -> bool:
	return _opened


## 清场后切换到开箱画面，按房间种子稳定生成武器、装备、医疗包、金钱和研究奖励。
func open_and_release_rewards(reward_parent: Node2D, seed_value: int) -> void:
	if _opened or not is_instance_valid(reward_parent):
		return
	_opened = true
	_sprite.frame = 1

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else get_instance_id()
	var weapon_types: Array[LootItem.Type] = [LootItem.Type.WeaponSMG, LootItem.Type.WeaponShortgun, LootItem.Type.WeaponSniper, LootItem.Type.WeaponRPG, LootItem.Type.WeaponFlamethrower]
	var equipment_types: Array[LootItem.Type] = [
		LootItem.Type.EquipmentGrenade,
		LootItem.Type.EquipmentMolotov,
		LootItem.Type.EquipmentShield,
	]
	var rewards: Array = [
		PrefabManager.create_loot_item(weapon_types[rng.randi_range(0, weapon_types.size() - 1)]),
		PrefabManager.create_loot_item(equipment_types[rng.randi_range(0, equipment_types.size() - 1)]),
		PrefabManager.create_loot_item(LootItem.Type.MedicalKit, 35),
		PrefabManager.create_currency(RunCurrencyWallet.Kind.MONEY, rng.randi_range(35, 50)),
		PrefabManager.create_currency(RunCurrencyWallet.Kind.RESEARCH, rng.randi_range(3, 5)),
	]
	for reward_index: int in range(rewards.size()):
		var reward := rewards[reward_index] as Node2D
		if reward == null:
			continue
		reward.name = "BattleSupplyReward%d" % reward_index
		reward_parent.add_child(reward)
		reward.position = position + REWARD_OFFSETS[reward_index]

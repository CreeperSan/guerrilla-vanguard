## 燃烧伤害契约测试：首次进入立即受伤，持续停留按间隔受伤，离开后重入立即重置。
extends Node

var _checks: int = 0
var _failures: int = 0


## 延迟到 AutoLoad 初始化后启动物理接触测试。
func _ready() -> void:
	_run.call_deferred()


## 使用真实敌人士兵与燃烧 Area2D 验证首次接触、持续伤害和离开重入。
func _run() -> void:
	var world := Node2D.new()
	add_child(world)
	var enemy := load("res://Prefab/EnemySoilder/enemy_soilder.tscn").instantiate() as EnemySoilder
	enemy.health = 100
	world.add_child(enemy)
	var fire := load("res://Prefab/burning/burning.tscn").instantiate() as BurningEffect
	fire.burining_faction = Definition.Faction.Player
	fire.burning_duration = 3.0
	fire.burning_damage_gap = 0.1
	fire.bruning_damage = 1
	world.add_child(fire)
	await _physics_frames(2)
	_check(enemy.health_component.health == 99, "第一次进入燃烧范围立即受到伤害")
	await _physics_frames(8)
	_check(enemy.health_component.health <= 98, "持续停留时按固定间隔受到后续伤害")
	var health_before_exit: int = enemy.health_component.health
	enemy.position = Vector2(400.0, 0.0)
	await _physics_frames(8)
	_check(enemy.health_component.health == health_before_exit, "离开燃烧范围后不再受到伤害")
	enemy.position = Vector2.ZERO
	await _physics_frames(2)
	_check(enemy.health_component.health == health_before_exit - 1, "离开后重新进入会立即受到伤害")
	world.queue_free()
	await get_tree().process_frame
	print("BURNING_DAMAGE_TEST checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## 等待指定数量物理帧，给 Area2D 的重叠状态和伤害循环完成同步。
func _physics_frames(frame_count: int) -> void:
	for frame_index: int in range(frame_count):
		await get_tree().physics_frame


## 统计契约断言并输出失败原因。
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[BurningDamageTest] " + message)

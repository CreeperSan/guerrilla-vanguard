## 所有战场 Boss 的最小公共契约：阶段、生命组件、展示名称和最终死亡信号。
## 房间、奖励、HUD 与出口只依赖此接口，各 Boss 保留自己的战斗状态机。
class_name BattlefieldBoss
extends CharacterBody2D

signal sig_phase_changed(phase: int, current_health: int, max_health: int)
signal sig_defeated

## 稳定的展示名称，不随阶段重置成 General。
@export var boss_display_name: String = "GENERAL"
## 各 Boss 可定义自己的阶段枚举；公共消费者只读取序号。
var current_phase: int = 1
@onready var health_component: HealthComponent = $Health

## 所有 Boss 在房间激活后统一等待半秒，再允许各自的战斗逻辑推进。
var _action_start_delay_remaining: float = 0.5


## Boss 与普通士兵一样选择最近的存活敌对目标，包含玩家和已签约佣兵。
func _find_combat_target() -> Node2D:
	var closest: Node2D
	var closest_distance := INF
	for candidate: Node in get_tree().get_nodes_in_group("combat_targets"):
		var target := candidate as Node2D
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			continue
		var health := target.get_node_or_null("Health") as HealthComponent
		if health == null or health.health <= 0:
			continue
		var distance := global_position.distance_squared_to(target.global_position)
		if distance < closest_distance:
			closest = target
			closest_distance = distance
	return closest


## 倒计时未结束时阻止 Boss 移动、瞄准和攻击。
func _wait_for_action_start(delta: float) -> bool:
	if _action_start_delay_remaining <= 0.0:
		return false
	_action_start_delay_remaining = maxf(_action_start_delay_remaining - delta, 0.0)
	return true

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

class_name HealthComponent
extends Node

## 当前生命值
@export var health: int = 100

## 最大生命正
@export var health_max: int = 100

## 信号 - 死亡
signal sig_die

## 信号 - 生命值变化
## @params 生命值变化，治疗为正数，伤害为负数
signal sig_health_change(health: int)


## 收到伤害的统一逻辑处理
## 
## @params damage: 收到的伤害值（正数）
func damage(damage: int):
	var damage_take = damage if (health > damage) else health
	health -= damage_take
	sig_health_change.emit(-damage_take)
	if health <= 0 :
		sig_die.emit()


## 收到治疗的统一处理
##
## @params heal: 治疗点数（正数）
func heal(heal: int):
	var health_take = heal if (health + heal < health_max) else (health_max - health)
	sig_health_change.emit(health_take)

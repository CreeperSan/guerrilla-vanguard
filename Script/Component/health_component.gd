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

## 信号 - 生命值状态更新，参数为当前生命值和最大生命值。
signal sig_health_updated(current_health: int, max_health: int)

## 可选伤害过滤器；返回实际进入生命值结算的伤害，供护盾等机制拦截。
var damage_filter: Callable


## 场景启动时校正生命值范围，避免初始数据超出最大值。
func _ready() -> void:
    health_max = maxi(health_max, 0)
    health = clampi(health, 0, health_max)


## 收到伤害的统一逻辑处理
## @params value: 收到的伤害值（正数）
func damage(value: int):
    var incoming_damage: int = maxi(value, 0)
    if damage_filter.is_valid():
        incoming_damage = maxi(int(damage_filter.call(incoming_damage)), 0)

    var damage_take: int = mini(incoming_damage, health)
    if damage_take <= 0:
        return

    health -= damage_take
    sig_health_change.emit(-damage_take)
    sig_health_updated.emit(health, health_max)
    if health == 0:
        sig_die.emit()


## 收到治疗的统一处理
## @params value: 治疗点数（正数）
func heal(value: int):
    var health_take: int = mini(maxi(value, 0), health_max - health)
    if health_take <= 0:
        return

    health += health_take
    sig_health_change.emit(health_take)
    sig_health_updated.emit(health, health_max)

## 单件战术能力基类；装备组件分发事件，子类独占自己的状态与计时。
class_name TacticalAbility
extends RefCounted

var equipment: Node
var definition: TacticalDefinition


## 绑定本轮组件与只读数值，再由独立能力安装所需修正或传感器。
func attach(component: Node, config: TacticalDefinition) -> void:
    equipment = component
    definition = config
    install()


## 可选生命周期接口，简单属性能力只需实现 install。
func install() -> void:
    pass


## 组件销毁前释放能力私有物理节点；公共信号由组件统一解除。
func uninstall() -> void:
    pass


## 暂停时组件不运行，所有能力使用游戏时间而非墙钟时间。
func tick(_delta: float) -> void:
    pass


## 查询本次射击的倍率，不消耗状态；成功生成弹丸后才发射 shot_committed。
func shot_multiplier(_weapon: PlayerWeaponSlot) -> float:
    return 1.0


## 一次扣弹对应一次成功射击，霰弹枪的多枚弹丸不会重复调用。
func shot_committed(_weapon: PlayerWeaponSlot) -> void:
    pass


## 切枪事件由管理器转发，初始化武器不算切枪。
func weapon_changed() -> void:
    pass


## 首伤等防御只处理主动盾与闪避之后剩余的正伤害。
func filter_damage(value: int) -> int:
    return value


## 实际扣血事件；治疗、护盾吸收及上限截断不触发。
func damaged() -> void:
    pass


## 房间实例键在组件层去重，安全房也会收到进入事件供清除旧状态。
func room_entered(_combat: bool) -> void:
    pass


## 仅首次清场的战斗房收到此事件。
func room_cleared() -> void:
    pass


## 回力类能力在闪避真正结束后触发。
func dodge_finished() -> void:
    pass


## 接触攻击倍率独立于枪械倍率，并在实际命中后单独提交。
func contact_multiplier() -> float:
    return 1.0


## 成功命中才消耗下一次接触攻击状态。
func contact_committed() -> void:
    pass


## 从定义读取参数；数值只在配置中维护，不在描述和效果内各存一份。
func parameter(key: String, fallback: float = 0.0) -> float:
    return float(definition.parameters.get(key, fallback))


## 按装备 ID 登记本能力的乘法修正，可重复更新而不会累计乘到基础值。
func modify(stat: StringName, value: float) -> void:
    equipment.set_modifier(definition.id, stat, value)

## 战术装备只读配置：显示与数值和运行时能力实例分离，资源不保存本轮状态。
class_name TacticalDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var price: int = 40
@export var icon: Texture2D
@export var ability_script: Script
@export var parameters: Dictionary = {}


## 所有入口统一校验，避免售出无法实例化的装备。
func is_valid() -> bool:
    return not id.is_empty() and not display_name.is_empty() and price > 0 and icon != null and ability_script != null and ability_script.can_instantiate()

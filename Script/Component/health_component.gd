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
## 记录最后一次实际扣血的来源，用于区分佣兵击杀与玩家得分。
var last_damage_faction: Definition.Faction = Definition.Faction.Enemy

## 闪白材质仅覆盖 RGB，沿用纹理和节点的透明度，避免矩形底色遮住角色轮廓。
const HIT_FLASH_SHADER: Shader = preload("res://Script/Component/hit_flash.gdshader")
const HIT_FLASH_DURATION: float = 0.1

## 保存每个精灵的原材质，确保闪白结束后恢复原有外观。
var _hit_flash_materials: Dictionary[CanvasItem, Material] = {}
var _hit_flash_tween: Tween


## 场景启动时校正生命值范围，避免初始数据超出最大值。
func _ready() -> void:
    health_max = maxi(health_max, 0)
    health = clampi(health, 0, health_max)


## 收到伤害的统一逻辑处理
## @params value: 收到的伤害值（正数）
func damage(value: int, source_faction: Definition.Faction = Definition.Faction.Enemy) -> void:
    var incoming_damage: int = maxi(value, 0)
    if damage_filter.is_valid():
        incoming_damage = maxi(int(damage_filter.call(incoming_damage)), 0)

    var damage_take: int = mini(incoming_damage, health)
    if damage_take <= 0:
        return

    last_damage_faction = source_faction
    _flash_damageable_sprites()
    health -= damage_take
    sig_health_change.emit(-damage_take)
    sig_health_updated.emit(health, health_max)
    if health == 0:
        sig_die.emit()


## 实际生命值减少时，将实体下的精灵短暂渲染为纯白；护盾拦截的伤害不会到达这里。
func _flash_damageable_sprites() -> void:
    var entity: Node = get_parent()
    if entity == null:
        return

    # 连续命中时重置计时，并先还原上一次闪白的材质，避免闪白永久残留。
    if _hit_flash_tween != null and _hit_flash_tween.is_running():
        _hit_flash_tween.kill()
        _restore_hit_flash_materials()

    var sprites: Array[CanvasItem] = []
    _collect_damageable_sprites(entity, sprites)
    if sprites.is_empty():
        return

    var flash_material := ShaderMaterial.new()
    flash_material.shader = HIT_FLASH_SHADER
    for sprite: CanvasItem in sprites:
        _hit_flash_materials[sprite] = sprite.material
        sprite.material = flash_material

    _hit_flash_tween = create_tween()
    _hit_flash_tween.tween_callback(_restore_hit_flash_materials).set_delay(HIT_FLASH_DURATION)


## 递归收集实体的 Sprite2D 和 AnimatedSprite2D，支持包含多个可见部件的 Boss。
func _collect_damageable_sprites(node: Node, sprites: Array[CanvasItem]) -> void:
    if node is Sprite2D or node is AnimatedSprite2D:
        sprites.append(node as CanvasItem)
    for child: Node in node.get_children():
        _collect_damageable_sprites(child, sprites)


## 恢复命中前的材质；节点可能已在闪白期间被移除，因此先检查实例有效性。
func _restore_hit_flash_materials() -> void:
    for sprite: CanvasItem in _hit_flash_materials:
        if is_instance_valid(sprite):
            sprite.material = _hit_flash_materials[sprite]
    _hit_flash_materials.clear()


## 收到治疗的统一处理
## @params value: 治疗点数（正数）
func heal(value: int):
    var health_take: int = mini(maxi(value, 0), health_max - health)
    if health_take <= 0:
        return

    health += health_take
    sig_health_change.emit(health_take)
    sig_health_updated.emit(health, health_max)

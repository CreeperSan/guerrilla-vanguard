## 统一生命结算组件：原有防御过滤后接通用修正链，治疗独立处理。
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
## 通用修正链由外部组件登记，不覆盖既有护盾/闪避防御；先后顺序固定。
var damage_modifiers: Array[Callable] = []
## 治疗修正只作用于正治疗，不影响生命上限调整。
var heal_modifiers: Array[Callable] = []
## 本次攻击的世界来源位置；无空间来源的伤害使用 INF，方向盾不拦截。
var damage_origin: Vector2 = Vector2.INF

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


## 敌军出生或 Boss 切阶段时，从基础生命配置重新计算，不在当前生命上叠乘。
## 玩家、佣兵、地形仍使用自己的生命配置，不调用此入口。
func reset_enemy_health(base_health: int) -> void:
    health_max = BattleBalance.scale_enemy_health(base_health)
    health = health_max
    sig_health_updated.emit(health, health_max)


## 收到伤害的统一逻辑处理
## @params value: 收到的伤害值（正数）；origin 为方向防御使用的世界来源位置，可省略。
## 返回本次实际扣血量；Boss 同步换阶段回血也不会改变这一结果。
func damage(value: int, source_faction: Definition.Faction = Definition.Faction.Enemy, origin: Vector2 = Vector2.INF) -> int:
    damage_origin = origin
    var incoming_damage: int = maxi(value, 0)
    # 只在实际扣血入口应用配置倍率；弹丸转爆炸/燃烧时不提前放大。
    if source_faction == Definition.Faction.Enemy:
        incoming_damage = BattleBalance.scale_enemy_damage(incoming_damage)
    if damage_filter.is_valid():
        incoming_damage = maxi(int(damage_filter.call(incoming_damage)), 0)

    for modifier: Callable in damage_modifiers:
        if modifier.is_valid() and incoming_damage > 0:
            incoming_damage = maxi(int(modifier.call(incoming_damage)), 0)

    var damage_take: int = mini(incoming_damage, health)
    if damage_take <= 0:
        return 0

    last_damage_faction = source_faction
    _flash_damageable_sprites()
    health -= damage_take
    sig_health_change.emit(-damage_take)
    sig_health_updated.emit(health, health_max)
    if health == 0:
        sig_die.emit()
    return damage_take


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
    for modifier: Callable in heal_modifiers:
        if modifier.is_valid() and value > 0:
            value = maxi(int(modifier.call(value)), 0)
    var health_take: int = mini(maxi(value, 0), health_max - health)
    if health_take <= 0:
        return

    health += health_take
    sig_health_change.emit(health_take)
    sig_health_updated.emit(health, health_max)


## 更新最大生命只截断当前值，不产生伤害/治疗事件，不凭空回血。
func set_max_health(value: int) -> void:
    health_max = maxi(value, 1)
    health = mini(health, health_max)
    sig_health_updated.emit(health, health_max)

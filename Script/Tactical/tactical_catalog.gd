## 战术目录资源：装备数值、图标与独立能力可在 Inspector 配置，运行时不保存本轮状态。
class_name TacticalCatalog
extends Resource

const DEFAULT_PATH := "res://Script/Tactical/tactical_catalog.tres"
@export var definitions: Array[TacticalDefinition] = []
@export var reward_texture: Texture2D

static var _definitions: Dictionary = {}
static var _catalog: TacticalCatalog


## 延迟加载统一配置并缓存只读定义；新增装备只需增加资源与能力脚本。
static func get_all() -> Array[TacticalDefinition]:
    if _catalog == null:
        _catalog = load(DEFAULT_PATH) as TacticalCatalog
        if _catalog == null:
            return []
        for config: TacticalDefinition in _catalog.definitions:
            if config == null or _definitions.has(config.id):
                push_error("战术目录包含空定义或重复 ID。")
                continue
            _definitions[config.id] = config
    var result: Array[TacticalDefinition] = []
    for value: TacticalDefinition in _definitions.values():
        result.append(value)
    return result


## 所有购买/拾取入口以稳定 ID 解析，不依赖显示名称和枚举编号。
static func get_definition(id: StringName) -> TacticalDefinition:
    get_all()
    return _definitions.get(id) as TacticalDefinition


## 独立 RNG 保持奖励可复现，过滤已拥有物品，最多返回 count 件且不重复。
static func select(seed_value: int, owned: Array[StringName], count: int = 3) -> Array[TacticalDefinition]:
    var pool: Array[TacticalDefinition] = []
    for config: TacticalDefinition in get_all():
        if config.is_valid() and config.id not in owned:
            pool.append(config)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value ^ 0x54414354
    var result: Array[TacticalDefinition] = []
    for index: int in range(mini(count, pool.size())):
        var selected := rng.randi_range(0, pool.size() - 1)
        result.append(pool.pop_at(selected))
    return result


## 奖励箱与装备共享图集显存，具体图集映射同样由资源配置。
static func reward_icon() -> Texture2D:
    get_all()
    return _catalog.reward_texture if _catalog != null else null

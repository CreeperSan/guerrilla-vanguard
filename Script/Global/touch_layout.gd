## 触控布局的唯一默认表与几何规则。中心为 1280×720 参考屏幕比例，尺寸为逻辑像素。
## 修改 DEFAULTS 即可调整首次安装/重置布局；运行时与编辑预览共用相同边界和尺寸算法。
class_name TouchLayout
extends RefCounted

const LABELS := {"move": "十字移动", "aim": "十字瞄准", "fire": "射击", "reload": "换弹", "equipment": "装备", "support": "战场支援", "skill": "奔跑 / 闪避", "map": "小地图", "weapon": "武器切换", "tactical": "战术装备"}
## 移动区由 154 翻倍到 308；原右侧操作按钮按边长放大 30%，默认四周至少留 48 像素。
const DEFAULTS := {
    "move": {"center": Vector2(0.17, 0.70), "size": Vector2(308, 308), "scale": 1.0},
    "aim": {"center": Vector2(0.87, 0.76), "size": Vector2(184.6, 184.6), "scale": 1.0},
    "fire": {"center": Vector2(0.81, 0.47), "size": Vector2(104, 104), "scale": 1.0},
    "reload": {"center": Vector2(0.91, 0.48), "size": Vector2(101.4, 101.4), "scale": 1.0},
    "equipment": {"center": Vector2(0.69, 0.57), "size": Vector2(130, 130), "scale": 1.0},
    "support": {"center": Vector2(0.57, 0.57), "size": Vector2(130, 130), "scale": 1.0},
    "skill": {"center": Vector2(0.68, 0.81), "size": Vector2(114.4, 130), "scale": 1.0},
    "map": {"center": Vector2(0.87, 0.30), "size": Vector2(176, 112), "scale": 1.0},
    "weapon": {"center": Vector2(0.82, 0.14), "size": Vector2(304, 104), "scale": 1.0},
    "tactical": {"center": Vector2(0.20, 0.28), "size": Vector2(238, 60), "scale": 1.0},
}
const EDGE_MARGIN := 48.0
## 战斗触控按钮透明度：移动区占地最大，因此比其他操作按钮更透明。
const BUTTON_OPACITY := 0.55
const MOVEMENT_OPACITY := 0.22
## 小地图位于右上武器面板下方，进一步淡化对战场的遮挡。
const MAP_OPACITY := 0.45
const LAYOUT_VERSION := 2

## 首次升级只移动旧版本未经自定义的三个默认位置；玩家拖动过的布局保持原样。
static func migrate_legacy_layout(raw: Variant) -> Variant:
    if not raw is Dictionary:
        return raw
    var migrated: Dictionary = raw.duplicate(true)
    var previous := {"weapon": Vector2(0.47, 0.17), "map": Vector2(0.84, 0.17), "reload": Vector2(0.91, 0.42)}
    for id: String in previous:
        var entry: Variant = migrated.get(id, {})
        if entry is Dictionary and entry.get("center") == previous[id] and entry.get("scale", 1.0) == 1.0:
            entry["center"] = DEFAULTS[id].center
    return migrated


## 丢弃未知字段和坏类型，补齐新增按钮；存档只存中心和倍率，不覆盖代码中的基准尺寸。
static func sanitize(raw: Variant) -> Dictionary:
    var result := DEFAULTS.duplicate(true)
    if not raw is Dictionary:
        return result
    for id: String in DEFAULTS:
        var entry: Variant = raw.get(id, {})
        if not entry is Dictionary:
            continue
        var center: Variant = entry.get("center")
        var factor: Variant = entry.get("scale")
        if center is Vector2 and is_finite(center.x) and is_finite(center.y):
            result[id].center = Vector2(clampf(center.x, 0, 1), clampf(center.y, 0, 1))
        if (factor is float or factor is int) and is_finite(float(factor)):
            result[id].scale = clampf(float(factor), 0.5, 1.6)
    result.move.center.x = minf(result.move.center.x, 0.5)
    result.aim.center.x = maxf(result.aim.center.x, 0.5)
    return result

## 按实际逻辑视口等比缩放尺寸，屏幕比例改变时仍保留归一化中心与半屏约束。
static func rect_for(id: String, layout: Dictionary, viewport_size: Vector2, movement_scale: float = 1.0) -> Rect2:
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return Rect2()
    var entry: Dictionary = layout[id]
    var unit := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
    var margin := EDGE_MARGIN * unit
    var dimensions: Vector2 = DEFAULTS[id].size * float(entry.scale) * unit
    if id == "move":
        dimensions *= movement_scale
    var low := Vector2(margin, margin)
    var high := viewport_size - Vector2.ONE * margin
    if id == "move":
        high.x = viewport_size.x * 0.5 - margin
    elif id == "aim":
        low.x = viewport_size.x * 0.5 + margin
    # 极大倍率与窄屏按同一系数收缩宽高，避免圆形摇杆被半屏约束压成椭圆。
    var available := high - low
    var fit := minf(1.0, minf(available.x / dimensions.x, available.y / dimensions.y))
    dimensions *= fit
    var center: Vector2 = entry.center * viewport_size
    center = center.clamp(low + dimensions * 0.5, high - dimensions * 0.5)
    return Rect2(center - dimensions * 0.5, dimensions)

## 消除容器最小尺寸对命中区域的影响；缩放控件内容，使视觉范围和编辑器几何保持一致。
static func apply(control: Control, rect: Rect2) -> void:
    control.set_anchors_preset(Control.PRESET_TOP_LEFT)
    control.custom_minimum_size = Vector2.ZERO
    control.scale = Vector2.ONE
    control.position = rect.position
    control.size = rect.size
    var natural := control.size
    control.scale = rect.size / natural.max(Vector2.ONE)


## 移动摇杆按圆形命中，排除外接矩形四角；其他布局按钮继续沿用矩形命中。
static func contains_point(id: String, rect: Rect2, point: Vector2) -> bool:
    if id == "move":
        var radius := minf(rect.size.x, rect.size.y) * 0.5
        return point.distance_squared_to(rect.get_center()) <= radius * radius
    return rect.has_point(point)

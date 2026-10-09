## 剩余敌人方位提示：只提示当前房间屏幕外的存活敌人，同方向合并，最多四个淡色箭头。
## 箭头围绕玩家显示，不画地图坐标、连线或敌人标签；HUD 暂停/结算时将控件隐藏。
class_name EnemyDirectionHints
extends Control

## 半径和透明度可在 HUD 场景 Inspector 调整，避免提示遮挡角色与近身战斗。
@export_range(48.0, 180.0, 1.0) var hint_radius: float = 96.0
@export_range(0.1, 0.8, 0.01) var hint_opacity: float = 0.28
@export_range(1, 8, 1) var maximum_hints: int = 4
@export_range(0.05, 0.5, 0.01) var refresh_interval: float = 0.12

## 敌人距离屏幕边缘小于此像素数时渐隐；平滑速度使用每秒响应系数，不受帧率影响。
@export_range(24.0, 240.0, 1.0) var fade_distance: float = 120.0
@export_range(4.0, 30.0, 1.0) var smoothing_speed: float = 14.0

var player: Node2D
var current_room_id: int = -1
var hints: Array[Dictionary] = []
var _refresh_remaining: float = 0.0
## 候选提示保留真实目标引用；绘制状态独立保存，避免低频扫描覆盖平滑结果。
var _visual_hints: Dictionary = {}
var _display_center: Vector2
var _center_initialized: bool = false
var _display_room_id: int = -1


## 低频扫描敌人组，切房或隐藏时清空提示；不对未访问房间执行敌人生成。
func _process(delta: float) -> void:
    if get_tree().paused or not is_visible_in_tree() or not is_instance_valid(player):
        hints.clear()
        _visual_hints.clear()
        _center_initialized = false
        queue_redraw()
        return
    if _display_room_id != current_room_id:
        _visual_hints.clear()
        _center_initialized = false
        _display_room_id = current_room_id
        _refresh_remaining = 0.0
    _refresh_remaining -= delta
    if _refresh_remaining <= 0.0:
        _refresh_remaining = refresh_interval
        refresh_hints()
    _update_visual_hints(delta)
    queue_redraw()


## 每帧读取目标位置，并使用指数平滑消除方向采样、相机与物理帧之间的跳变。
## 淡出状态短暂保留，使进入视野或方向分组切换时也不会突然消失。
func _update_visual_hints(delta: float) -> void:
    var center := player.get_global_transform_with_canvas().origin
    var weight := 1.0 - exp(-smoothing_speed * delta)
    _display_center = _display_center.lerp(center, weight) if _center_initialized else center
    _center_initialized = true
    var selected: Dictionary = {}
    for hint: Dictionary in hints:
        var enemy := hint["enemy"] as Node2D
        if not is_instance_valid(enemy):
            continue
        var id := enemy.get_instance_id()
        selected[id] = true
        if not _visual_hints.has(id):
            _visual_hints[id] = {"enemy": enemy, "angle": (enemy.get_global_transform_with_canvas().origin - center).angle(), "alpha": 0.0}
    var screen := get_viewport_rect()
    for id: int in _visual_hints.keys():
        var state: Dictionary = _visual_hints[id]
        var enemy := state["enemy"] as Node2D
        # 死亡、切房或释放立即移除；仅正常接近和筛选切换使用渐隐。
        if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not _belongs_to_current_room(enemy):
            _visual_hints.erase(id)
            continue
        var health := enemy.get_node_or_null("Health") as HealthComponent
        if health != null and health.health <= 0:
            _visual_hints.erase(id)
            continue
        var target := enemy.get_global_transform_with_canvas().origin
        state["angle"] = lerp_angle(float(state["angle"]), (target - center).angle(), weight)
        var target_alpha := _edge_visibility(target, screen) if selected.has(id) else 0.0
        state["alpha"] = lerpf(float(state["alpha"]), target_alpha, weight)
        if target_alpha <= 0.0 and float(state["alpha"]) < 0.005:
            _visual_hints.erase(id)


## 以目标到可见屏幕矩形的距离渐隐，适配不同分辨率、相机缩放和接近方向。
## 屏幕外 120 像素以上完整显示，接近边缘时平滑降至零，屏幕内不显示。
func _edge_visibility(target: Vector2, screen: Rect2) -> float:
    var nearest := target.clamp(screen.position, screen.end)
    var distance := target.distance_to(nearest)
    return smoothstep(0.0, maxf(fade_distance, 1.0), distance)


## 按八个方向分组，每组选择最近目标，再从这些方向中显示最近的四组。
func refresh_hints() -> void:
    hints.clear()
    if not is_instance_valid(player):
        queue_redraw()
        return
    var screen := get_viewport_rect()
    var player_screen := player.get_global_transform_with_canvas().origin
    var sectors: Dictionary = {}
    for node: Node in get_tree().get_nodes_in_group("enemies"):
        var enemy := node as Node2D
        if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not _belongs_to_current_room(enemy):
            continue
        var health := enemy.get_node_or_null("Health") as HealthComponent
        if health != null and health.health <= 0:
            continue
        var enemy_screen := enemy.get_global_transform_with_canvas().origin
        if screen.has_point(enemy_screen):
            continue
        var offset := enemy_screen - player_screen
        var distance := offset.length_squared()
        if distance <= 0.001:
            continue
        var sector := posmod(roundi(offset.angle() / (TAU / 8.0)), 8)
        if not sectors.has(sector) or distance < float(sectors[sector]["distance"]):
            sectors[sector] = {"direction": offset.normalized(), "distance": distance, "enemy": enemy}
    for hint: Dictionary in sectors.values():
        hints.append(hint)
    hints.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["distance"]) < float(b["distance"]))
    if hints.size() > maximum_hints:
        hints.resize(maximum_hints)
    queue_redraw()


## 正式关卡只提示当前房间；独立测试关卡没有房间 ID 时使用场景中的敌人。
func _belongs_to_current_room(enemy: Node2D) -> bool:
    if current_room_id < 0:
        return true
    var ancestor: Node = enemy.get_parent()
    while ancestor != null:
        if ancestor is FortressRoomTemplate:
            return ancestor.room_id == current_room_id
        ancestor = ancestor.get_parent()
    return false


## 在玩家周围画小三角，不添加闪烁与文字；极靠边时把标记限制在可见屏幕内。
func _draw() -> void:
    if not is_instance_valid(player):
        return
    var center := _display_center
    var safe_rect := get_viewport_rect().grow(-14.0)
    for hint: Dictionary in _visual_hints.values():
        var visibility_factor := float(hint["alpha"])
        var direction := Vector2.from_angle(float(hint["angle"]))
        var tangent := Vector2(-direction.y, direction.x)
        var point := center + direction * hint_radius
        point = point.clamp(safe_rect.position, safe_rect.end)
        # 小范围暗底在复杂地面上提供对比；只占箭头周围，不绘制整圈或大面积遮罩。
        draw_circle(point, 12.0, Color(0.025, 0.045, 0.035, 0.16 * visibility_factor))
        var triangle := PackedVector2Array([point + direction * 10.0, point - direction * 6.0 + tangent * 6.0, point - direction * 6.0 - tangent * 6.0])
        draw_colored_polygon(triangle, Color(0.95, 0.92, 0.72, hint_opacity * visibility_factor))

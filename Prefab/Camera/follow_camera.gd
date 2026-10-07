## 可迁移的平滑跟随相机，支持切换目标、屏幕死区和世界边界。
class_name FollowCamera
extends Camera2D

@export_group("跟随目标")
## 场景启动时自动查找的跟随目标路径；也可以留空并在运行时调用 set_target。
@export_node_path("Node2D") var target_path: NodePath

@export_group("屏幕死区")
## 启用后，目标在屏幕中心的死区范围内移动时相机保持不动。
@export var dead_zone_enabled: bool = true
## 死区占视口宽高的比例；例如 0.2 表示死区宽高各占屏幕的 20%。
@export var dead_zone_ratio: Vector2 = Vector2(0.2, 0.2)

@export_group("跟随边界")
## 启用后，相机可见区域会被限制在 follow_bounds 矩形范围内。
@export var bounds_enabled: bool = false
## 世界坐标中的相机活动范围；矩形边缘始终不会被相机视口越过。
@export var follow_bounds: Rect2 = Rect2(0.0, 0.0, 1024.0, 768.0)

@export_group("平滑跟随")
## 相机追赶目标的速度；设为 0 时立即跟随，数值越大响应越快。
@export_range(0.0, 50.0, 0.1) var follow_smooth_speed: float = 8.0

## 当前正在跟随的对象，可通过 set_target 在运行时切换。
var tracking_target: Node2D


## 初始化相机状态，并按配置路径绑定初始目标。
func _ready() -> void:
    # 使用自定义死区和平滑逻辑，避免 Camera2D 内建拖拽与本脚本叠加。
    position_smoothing_enabled = false
    drag_horizontal_enabled = false
    drag_vertical_enabled = false
    make_current()

    if not target_path.is_empty():
        var initial_target := get_node_or_null(target_path) as Node2D
        if initial_target != null:
            set_target(initial_target, true)


## 设置新的跟随对象；snap_to_target 为 true 时立即移动到目标位置。
func set_target(new_target: Node2D, snap_to_target: bool = false) -> void:
    tracking_target = new_target
    if not is_instance_valid(tracking_target):
        return

    if snap_to_target:
        global_position = tracking_target.global_position
        global_position = _clamp_position_to_bounds(global_position, get_viewport_rect().size)


## 清除跟随对象，相机将停留在当前位置。
func clear_target() -> void:
    tracking_target = null


## 更新相机世界边界；传入 enabled=false 可临时关闭边界限制。
func set_follow_bounds(bounds: Rect2, enabled: bool = true) -> void:
    follow_bounds = bounds.abs()
    bounds_enabled = enabled
    global_position = _clamp_position_to_bounds(global_position, get_viewport_rect().size)


## 每帧根据屏幕死区计算相机目标位置，再应用平滑和世界边界限制。
func _process(delta: float) -> void:
    if not is_instance_valid(tracking_target):
        return

    var viewport_size := get_viewport_rect().size
    var safe_zoom := Vector2(maxf(absf(zoom.x), 0.001), maxf(absf(zoom.y), 0.001))
    var screen_center := viewport_size * 0.5
    var target_screen_position := screen_center + (tracking_target.global_position - global_position) * safe_zoom
    var dead_zone_half_size := Vector2.ZERO
    if dead_zone_enabled:
        dead_zone_half_size = viewport_size * dead_zone_ratio.clamp(Vector2.ZERO, Vector2.ONE) * 0.5

    # 只有目标越过死区边缘时才移动相机，且只补足越界的屏幕距离。
    var screen_correction := Vector2.ZERO
    var dead_zone_left := screen_center.x - dead_zone_half_size.x
    var dead_zone_right := screen_center.x + dead_zone_half_size.x
    var dead_zone_top := screen_center.y - dead_zone_half_size.y
    var dead_zone_bottom := screen_center.y + dead_zone_half_size.y
    if target_screen_position.x < dead_zone_left:
        screen_correction.x = target_screen_position.x - dead_zone_left
    elif target_screen_position.x > dead_zone_right:
        screen_correction.x = target_screen_position.x - dead_zone_right
    if target_screen_position.y < dead_zone_top:
        screen_correction.y = target_screen_position.y - dead_zone_top
    elif target_screen_position.y > dead_zone_bottom:
        screen_correction.y = target_screen_position.y - dead_zone_bottom

    var desired_position := global_position + screen_correction / safe_zoom
    desired_position = _clamp_position_to_bounds(desired_position, viewport_size)
    if follow_smooth_speed <= 0.0:
        global_position = desired_position
    else:
        # 指数衰减让平滑速度在不同帧率下保持接近一致。
        var smoothing_weight := 1.0 - exp(-follow_smooth_speed * delta)
        global_position = global_position.lerp(desired_position, smoothing_weight)


## 将相机中心限制在边界内，并考虑当前视口尺寸和缩放。
func _clamp_position_to_bounds(camera_position: Vector2, viewport_size: Vector2) -> Vector2:
    if not bounds_enabled:
        return camera_position

    var normalized_bounds := follow_bounds.abs()
    var safe_zoom := Vector2(maxf(absf(zoom.x), 0.001), maxf(absf(zoom.y), 0.001))
    var half_view_size := viewport_size / safe_zoom * 0.5
    var minimum := normalized_bounds.position + half_view_size
    var maximum := normalized_bounds.end - half_view_size

    # 边界小于视口时将相机固定在边界中心，避免出现反向 clamp 区间。
    if maximum.x < minimum.x:
        minimum.x = normalized_bounds.get_center().x
        maximum.x = minimum.x
    if maximum.y < minimum.y:
        minimum.y = normalized_bounds.get_center().y
        maximum.y = minimum.y

    return Vector2(
        clampf(camera_position.x, minimum.x, maximum.x),
        clampf(camera_position.y, minimum.y, maximum.y)
    )

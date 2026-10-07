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
## 启用后，根据当前视口自动放大缩放值，确保整个视口不会超出跟随边界。
@export var fit_bounds_to_viewport: bool = false

@export_group("平滑跟随")
## 相机追赶目标的速度；设为 0 时立即跟随，数值越大响应越快。
@export_range(0.0, 50.0, 0.1) var follow_smooth_speed: float = 8.0

## 当前正在跟随的对象，可通过 set_target 在运行时切换。
var tracking_target: Node2D
var _room_transition_tween: Tween
var _default_zoom: Vector2 = Vector2.ONE


## 初始化相机状态，并按配置路径绑定初始目标。
func _ready() -> void:
    _default_zoom = zoom
    get_viewport().size_changed.connect(_on_viewport_size_changed)
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
    if snap_to_target and is_instance_valid(_room_transition_tween):
        _room_transition_tween.kill()
    tracking_target = new_target
    if not is_instance_valid(tracking_target):
        return

    if snap_to_target:
        global_position = tracking_target.global_position
        global_position = _clamp_position_to_bounds(global_position, get_viewport_rect().size)
        force_update_scroll()


## 清除跟随对象，相机将停留在当前位置。
func clear_target() -> void:
    tracking_target = null


## 更新相机世界边界；传入 enabled=false 可临时关闭边界限制。
func set_follow_bounds(bounds: Rect2, enabled: bool = true) -> void:
    follow_bounds = bounds.abs()
    bounds_enabled = enabled
    _sync_engine_limits()
    if bounds_enabled and fit_bounds_to_viewport:
        zoom = _get_fit_zoom(follow_bounds)
    global_position = _clamp_position_to_bounds(global_position, get_viewport_rect().size)
    force_update_scroll()
    _log_room_view_state()


## 切换房间时更新边界并平滑移到玩家落点；房间内跟随仍由死区和边界控制。
func transition_to_room(new_target: Node2D, room_bounds: Rect2, duration: float = 0.45) -> void:
    if not is_instance_valid(new_target):
        return
    if is_instance_valid(_room_transition_tween):
        _room_transition_tween.kill()
    tracking_target = new_target
    follow_bounds = room_bounds.abs()
    bounds_enabled = true
    _sync_engine_limits()
    var target_zoom := _get_fit_zoom(follow_bounds) if fit_bounds_to_viewport else zoom
    var transition_position := _clamp_position_to_bounds(new_target.global_position, get_viewport_rect().size, target_zoom)
    _room_transition_tween = create_tween().set_parallel(true)
    _room_transition_tween.set_trans(Tween.TRANS_CUBIC)
    _room_transition_tween.set_ease(Tween.EASE_IN_OUT)
    _room_transition_tween.tween_property(self, "global_position", transition_position, maxf(duration, 0.0))
    if fit_bounds_to_viewport:
        _room_transition_tween.tween_property(self, "zoom", target_zoom, maxf(duration, 0.0))
    _log_room_view_state(target_zoom)


## 屏幕尺寸或方向改变后重新适配房间视口，并立即把相机收回房间边界内。
func _on_viewport_size_changed() -> void:
    if not bounds_enabled or not fit_bounds_to_viewport:
        return
    if is_instance_valid(_room_transition_tween) and _room_transition_tween.is_running():
        _room_transition_tween.kill()
    zoom = _get_fit_zoom(follow_bounds)
    global_position = _clamp_position_to_bounds(global_position, get_viewport_rect().size)
    force_update_scroll()
    _log_room_view_state()


## 同步 Camera2D 内建硬边界，避免脚本逐帧跟随和相机变换间出现边界漏出。
func _sync_engine_limits() -> void:
    limit_enabled = bounds_enabled
    limit_smoothed = false
    if not bounds_enabled:
        return
    var normalized_bounds := follow_bounds.abs()
    limit_left = floori(normalized_bounds.position.x)
    limit_top = floori(normalized_bounds.position.y)
    limit_right = ceili(normalized_bounds.end.x)
    limit_bottom = ceili(normalized_bounds.end.y)


## 输出当前视口、缩放和世界可视范围，便于核对不同屏幕下的房间硬边界。
func _log_room_view_state(camera_zoom: Vector2 = Vector2.ZERO) -> void:
    if not bounds_enabled:
        return
    var active_zoom := zoom if camera_zoom == Vector2.ZERO else camera_zoom
    var viewport_size := get_viewport_rect().size
    var visible_world_size := Vector2(
        viewport_size.x / maxf(absf(active_zoom.x), 0.001),
        viewport_size.y / maxf(absf(active_zoom.y), 0.001)
    )
    print("[FollowCamera] bounds=%s viewport=%s zoom=%s world_view=%s" % [follow_bounds, viewport_size, active_zoom, visible_world_size])


## 计算同时满足房间宽高的最小缩放值，保留场景配置的基准缩放级别。
func _get_fit_zoom(bounds: Rect2) -> Vector2:
    var viewport_size := get_viewport_rect().size
    var safe_bounds_size := Vector2(maxf(bounds.size.x, 1.0), maxf(bounds.size.y, 1.0))
    var width_scale := viewport_size.x / (safe_bounds_size.x * maxf(_default_zoom.x, 0.001))
    var height_scale := viewport_size.y / (safe_bounds_size.y * maxf(_default_zoom.y, 0.001))
    var fit_scale := maxf(1.0, maxf(width_scale, height_scale))
    return _default_zoom * fit_scale


## 每帧根据屏幕死区计算相机目标位置，再应用平滑和世界边界限制。
func _process(delta: float) -> void:
    if is_instance_valid(_room_transition_tween) and _room_transition_tween.is_running():
        return
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
func _clamp_position_to_bounds(camera_position: Vector2, viewport_size: Vector2, camera_zoom: Vector2 = Vector2.ZERO) -> Vector2:
    if not bounds_enabled:
        return camera_position

    var normalized_bounds := follow_bounds.abs()
    var active_zoom := zoom if camera_zoom == Vector2.ZERO else camera_zoom
    var safe_zoom := Vector2(maxf(absf(active_zoom.x), 0.001), maxf(absf(active_zoom.y), 0.001))
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

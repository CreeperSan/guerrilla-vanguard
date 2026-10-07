## 迫击炮支援：以启动位置为固定中心，在半径范围内连续生成爆炸炮弹。
class_name MortarStriker
extends Node2D

## Inspector 调参：打击区域、总持续时间、投弹间隔与最大炮弹数量。
@export_group("打击范围与节奏")
@export_range(1.0, 1200.0, 1.0) var strike_radius: float = 360.0
@export_range(0.1, 120.0, 0.1) var strike_duration: float = 12.0
@export_range(0.01, 10.0, 0.01) var strike_interval: float = 0.3
@export_range(0, 500, 1) var shell_count: int = 40

## Inspector 调参：爆炸伤害及炮弹下落表现。
@export_group("炮弹参数")
@export_range(0, 1000, 1) var explosion_damage: int = 12
@export_range(0.0, 1000.0, 1.0) var shell_fall_height: float = 48.0
@export_range(0.01, 10.0, 0.01) var shell_fall_duration: float = 0.32

var _strike_center: Vector2


## 记录固定坐标并启动持续打击；范围圈不会跟随玩家移动。
func start_strike(_facing: Vector2 = Vector2.ZERO) -> void:
    _strike_center = global_position
    queue_redraw()
    _run_strike()


## 按配置的间隔和数量在固定圆形范围内随机生成爆炸炮弹。
func _run_strike() -> void:
    var elapsed: float = 0.0
    var shells_dropped: int = 0
    while is_inside_tree() and elapsed < strike_duration and shells_dropped < shell_count:
        var angle: float = randf_range(0.0, TAU)
        var radius: float = sqrt(randf()) * strike_radius
        var impact_position: Vector2 = _strike_center + Vector2.from_angle(angle) * radius
        _drop_shell(impact_position)
        shells_dropped += 1

        var interval: float = minf(maxf(strike_interval, 0.01), strike_duration - elapsed)
        await get_tree().create_timer(interval).timeout
        elapsed += interval
    if is_inside_tree():
        queue_free()


## 生成带下落表现和音效的炮弹，并应用本支援的可调参数。
func _drop_shell(impact_position: Vector2) -> void:
    var shell: IncomingShell = PrefabManager.create_incoming_shell()
    if shell == null:
        return
    shell.explosion_damage = explosion_damage
    shell.fall_height = shell_fall_height
    shell.fall_duration = shell_fall_duration
    get_tree().current_scene.add_child(shell)
    shell.start_drop(impact_position, Definition.BulletType.Explosion, Definition.Faction.Player)


## 绘制半透明浅红打击范围，圆心对应迫击炮启动时的位置。
func _draw() -> void:
    draw_circle(Vector2.ZERO, strike_radius, Color(1.0, 0.25, 0.25, 0.18), true)
    draw_arc(Vector2.ZERO, strike_radius, 0.0, TAU, 96, Color(1.0, 0.35, 0.35, 0.5), 2.0, true)

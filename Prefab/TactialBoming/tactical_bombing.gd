## 战术轰炸：从玩家脚下沿面朝方向依序打击六个点，先爆炸后燃烧。
class_name TacticalBombing
extends Node2D

## Inspector 调参：以玩家脚下为基准的起始偏移、落点数量、间距和轰炸节奏。
@export_group("打击轨迹与节奏")
@export var player_foot_offset: Vector2 = Vector2(0.0, 14.0)
@export_range(0.0, 2000.0, 1.0) var start_offset: float = 120.0
@export_range(0.0, 2000.0, 1.0) var strike_spacing: float = 60.0
@export_range(1, 100, 1) var strike_count: int = 6
@export_range(0.0, 10.0, 0.01) var strike_interval: float = 0.3
@export_range(0.0, 10.0, 0.01) var round_gap: float = 0.6

## Inspector 调参：爆炸、燃烧伤害以及炮弹下落表现。
@export_group("炮弹参数")
@export_range(0, 1000, 1) var explosion_damage: int = 12
@export_range(0, 1000, 1) var burning_damage: int = 2
@export_range(0.1, 120.0, 0.1) var burning_duration: float = 4.0
@export_range(0.01, 10.0, 0.01) var burning_damage_gap: float = 0.5
@export_range(0.0, 1000.0, 1.0) var shell_fall_height: float = 48.0
@export_range(0.01, 10.0, 0.01) var shell_fall_duration: float = 0.32
@export_range(0.0, 5.0, 0.1) var cleanup_delay: float = 1.0


## 将玩家脚下、起始偏移和面朝方向固化为打击轨迹，支援不会跟随玩家移动。
func start_strike(facing: Vector2 = Vector2.DOWN) -> void:
    var direction: Vector2 = facing.normalized()
    if direction == Vector2.ZERO:
        direction = Vector2.DOWN
    var foot_position: Vector2 = global_position + player_foot_offset
    var first_impact_position: Vector2 = foot_position + direction * start_offset
    _run_bombing(first_impact_position, direction)


## 沿面朝方向按固定间距打击；第二轮在首轮开始后按间隔并行启动。
func _run_bombing(first_impact_position: Vector2, direction: Vector2) -> void:
    # 首轮立即启动并在后台按间隔落弹，不等待整轮结束。
    _run_strike_round(first_impact_position, direction, Definition.BulletType.Explosion)
    await get_tree().create_timer(maxf(round_gap, 0.0)).timeout

    # 第二轮按配置间隔启动；两轮落弹流程会在时间上重叠。
    await _run_strike_round(first_impact_position, direction, Definition.BulletType.Burning)
    await get_tree().create_timer(maxf(cleanup_delay, 0.0)).timeout
    if is_inside_tree():
        queue_free()


## 按 0.3 秒间隔推进单轮落点，轮次类型决定生成爆炸或燃烧效果。
func _run_strike_round(
    first_impact_position: Vector2,
    direction: Vector2,
    effect_type: Definition.BulletType
) -> void:
    for strike_index: int in range(maxi(strike_count, 1)):
        var impact_position: Vector2 = first_impact_position + direction * strike_spacing * strike_index
        _drop_shell(impact_position, effect_type)
        if strike_index < strike_count - 1:
            await get_tree().create_timer(maxf(strike_interval, 0.0)).timeout


## 在指定落点创建炮弹，并将本轮可调伤害与下落参数写入炮弹实例。
func _drop_shell(impact_position: Vector2, effect_type: Definition.BulletType) -> void:
    var shell: IncomingShell = PrefabManager.create_incoming_shell()
    if shell == null:
        return
    shell.explosion_damage = explosion_damage
    shell.burning_damage = burning_damage
    shell.burning_duration = burning_duration
    shell.burning_damage_gap = burning_damage_gap
    shell.fall_height = shell_fall_height
    shell.fall_duration = shell_fall_duration
    get_tree().current_scene.add_child(shell)
    shell.start_drop(impact_position, effect_type, Definition.Faction.Player)

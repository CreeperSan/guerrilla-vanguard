## 五名战术 Boss 的两阶段公共宿主：共享生命周期、移动、弹丸和预警，策略独立推进。
## 复用 BattlefieldBoss 合约，使房间、HUD 和奖励只依赖最终死亡信号。
class_name TacticalBoss
extends BattlefieldBoss

enum Kind { MOBILIZER, SHIELD, SNIPER, FLAMER, ENGINEER }

## 每个预制体固定一种策略；图集列顺序与枚举一致。
@export var kind: Kind = Kind.MOBILIZER
@export_group("生命与移动")
## 两阶段独立血量；进入第二阶段不触发最终死亡。
@export var first_health: int = 100
@export var second_health: int = 80
@export var move_speed: float = 42.0
@export var preferred_distance: float = 160.0
@export_group("动员兵")
## 护卫死亡起独立倒计时，最后一秒显示召集圈；每个槽位最多一个实例。
@export var guard_respawn_first: float = 8.0
@export var guard_respawn_second: float = 6.0
@export var grenade_interval: float = 5.0
@export var grenade_warning: float = 1.5
@export_group("铁壁卫士")
## 举盾仅对当前朝向前方的攻击减伤；装填和冲刺恢复时放盾。
@export_range(0.0, 1.0) var shield_damage_multiplier: float = 0.25
@export var charge_warning: float = 1.0
@export var charge_speed: float = 180.0
@export var charge_duration: float = 0.8
@export_group("猎隼狙击手")
## 瞄准跟随和固定射线是独立状态，锁定后不再追踪玩家。
@export var aim_duration: float = 1.0
@export var lock_duration: float = 0.5
@export var sniper_damage: int = 10
@export_group("焚城喷火兵")
## 火焰扇形有可见边界；地面火区限制数量和寿命，不封满竞技场。
@export var flame_range: float = 125.0
@export var flame_duration: float = 2.0
@export var flame_cooldown: float = 3.0
@export var max_fire_patches: int = 5
@export_group("爆破工兵")
## 地雷可被玩家射毁，放置后延迟启动，遥控逐颗引爆。
@export var max_mines: int = 4
@export var mine_interval: float = 3.0

const GUARD_SCENE: PackedScene = preload("res://Prefab/EnemySoilder/enemy_soilder.tscn")
const GUARD_SCRIPT: Script = preload("res://Prefab/BossSquad/boss_guard.gd")
const HAZARD_SCRIPT: Script = preload("res://Prefab/BossSquad/boss_hazard.gd")
const OFFSETS: Array[Vector2] = [Vector2(-48, -48), Vector2(-48, 48), Vector2(48, -48), Vector2(48, 48)]

@onready var body_sprite: Sprite2D = $Sprite2D
## 状态计时器仅在房间激活期间推进；没有 Timer 回调在死亡后补员。
var state: String = "approach"
var state_remaining: float = 1.0
var facing: Vector2 = Vector2.DOWN
var locked_direction: Vector2 = Vector2.DOWN
var _defeated: bool = false
var _attack_remaining: float = 2.0
var _shot_remaining: float = 0.0
var _shots: int = 0
var _move_target: Vector2
var _guards: Array[Node2D] = [null, null, null, null]
var _guard_timers: Array[float] = [1.0, 1.0, 1.0, 1.0]
var _mines: Array[Node2D] = []
var _fires: Array[Node2D] = []
var _audio: AudioStreamPlayer2D
var _rng := RandomNumberGenerator.new()


## 配置碰撞、血量、音频与独立随机流；首轮攻击留出至少一秒准备。
func _ready() -> void:
    add_to_group("enemies")
    collision_mask = Definition.PHYSICS_LAYER_TERRAIN | Definition.PHYSICS_LAYER_WATER
    health_component.health_max = first_health
    health_component.health = first_health
    health_component.sig_die.connect(_on_phase_depleted)
    if kind == Kind.SHIELD:
        health_component.damage_filter = _filter_shield_damage
    elif kind == Kind.FLAMER:
        health_component.damage_filter = _filter_fuel_damage
    _rng.seed = int(get_parent().get("population_seed")) if get_parent() is FortressRoomTemplate else 1040 + kind
    _audio = AudioStreamPlayer2D.new()
    _audio.bus = &"SFX"
    _audio.volume_db = -8.0
    add_child(_audio)
    _move_target = global_position
    _update_sprite()


## 每帧选择有效目标并推进对应策略；无目标和死亡时停止所有攻击。
func _physics_process(delta: float) -> void:
    if _defeated or _wait_for_action_start(delta):
        return
    var target := _find_combat_target()
    if not is_instance_valid(target):
        velocity = Vector2.ZERO
        return
    state_remaining = maxf(0.0, state_remaining - delta)
    _attack_remaining = maxf(0.0, _attack_remaining - delta)
    _shot_remaining = maxf(0.0, _shot_remaining - delta)
    match kind:
        Kind.MOBILIZER: _update_mobilizer(delta, target)
        Kind.SHIELD: _update_shield(delta, target)
        Kind.SNIPER: _update_sniper(delta, target)
        Kind.FLAMER: _update_flamer(delta, target)
        Kind.ENGINEER: _update_engineer(delta, target)
    _update_sprite()
    queue_redraw()


## 第一管生命耗尽只重置阶段；最终死亡先禁用动作再通知房间，确保不会继续补员。
func _on_phase_depleted() -> void:
    if _defeated:
        return
    if current_phase == 1:
        current_phase = 2
        health_component.health_max = second_health
        health_component.health = second_health
        state = "approach"
        state_remaining = 1.0
        _attack_remaining = 1.5
        _shots = 0
        body_sprite.modulate = Color(1, 0.78, 0.68)
        _play("phase")
        sig_phase_changed.emit(2, second_health, second_health)
        return
    _defeated = true
    velocity = Vector2.ZERO
    set_physics_process(false)
    for guard: Node2D in _guards:
        if is_instance_valid(guard):
            guard.set_physics_process(false)
            var health := guard.get_node("Health") as HealthComponent
            health.damage(health.health)
    sig_defeated.emit()
    queue_free()


## 以碰撞移动保持距离；靠墙受阻后沿侧面尝试，不直接修改位置穿墙。
func _keep_distance(target: Node2D, distance: float, speed: float) -> void:
    var difference := target.global_position - global_position
    facing = difference.normalized()
    var direction := Vector2.ZERO
    if difference.length() > distance + 20.0:
        direction = facing
    elif difference.length() < distance - 20.0:
        direction = -facing
    _walk(direction, speed)


## 通用受碰撞约束的移动；冲刺使用独立函数，避免被自动绕墙改变锁向。
func _walk(direction: Vector2, speed: float) -> void:
    if direction != Vector2.ZERO and test_move(global_transform, direction * 20.0):
        for angle: float in [PI / 2.0, -PI / 2.0]:
            var candidate := direction.rotated(angle)
            if not test_move(global_transform, candidate * 20.0):
                direction = candidate
                break
    velocity = direction * speed
    move_and_slide()


## 四槽独立补员并同步房间敌人追踪；第一阶段本体完全不射击。
func _update_mobilizer(delta: float, target: Node2D) -> void:
    for index: int in range(4):
        if is_instance_valid(_guards[index]) and not _guards[index].is_queued_for_deletion():
            continue
        _guard_timers[index] = maxf(0, _guard_timers[index] - delta)
        if _guard_timers[index] <= 0:
            _spawn_guard(index)
    if state == "throw":
        _walk(Vector2.ZERO, 0)
        if state_remaining <= 0:
            state = "approach"
        return
    _keep_distance(target, preferred_distance, move_speed * 0.65)
    if current_phase == 2 and _attack_remaining <= 0:
        var hazard := _new_hazard(target.global_position, false)
        hazard.delay = grenade_warning
        _attack_remaining = grenade_interval
        state = "throw"
        state_remaining = 0.7
        _play("mine")


## 出生点只选择可用槽位；槽位位于墙内时推迟重试，保持最大数量为四。
func _spawn_guard(index: int) -> void:
    var point := global_position + OFFSETS[index]
    if not _point_free(point, 14.0) or not _line_clear(point):
        _guard_timers[index] = 1.0
        return
    var guard := GUARD_SCENE.instantiate() as EnemySoilder
    guard.set_script(GUARD_SCRIPT)
    guard.set("commander", self)
    guard.set("formation_offset", OFFSETS[index])
    guard.health = 8
    guard.weapon_damage = 2
    guard.fire_duration = 0.65
    guard.fire_pause_duration = 1.4
    guard.magazine_size = 3
    guard.weapon_range = 300.0
    guard.move_speed = 65.0
    guard.position = get_parent().to_local(point)
    _guards[index] = guard
    get_parent().add_child(guard)
    guard.set("_action_start_delay_remaining", 0.5 + index * 0.35)
    guard.health_component.sig_die.connect(_guard_died.bind(index))
    var room := get_parent() as FortressRoomTemplate
    if room != null:
        room.track_enemy(guard)
        var controller := room.get_parent() as LevelController
        if controller != null:
            controller.register_enemy(guard)
    _play("rally")


## 从死亡时开始倒计时，阶段变化后新死亡的护卫采用对应时长。
func _guard_died(index: int) -> void:
    _guard_timers[index] = guard_respawn_first if current_phase == 1 else guard_respawn_second


## 使用实际弹丸/爆炸来源位置计算盾面夹角；无位置来源的伤害不拦截。
func _filter_shield_damage(value: int) -> int:
    if state in ["reload", "recover"] or _defeated or not health_component.damage_origin.is_finite():
        return value
    var incoming := global_position.direction_to(health_component.damage_origin)
    if incoming.dot(facing) > 0.5:
        var multiplier := shield_damage_multiplier if current_phase == 1 else maxf(0.5, shield_damage_multiplier)
        return maxi(1, ceili(value * multiplier))
    return value


## 背部燃料罐是可选输出优势；其他方向仍正常受伤，不依赖特殊武器。
func _filter_fuel_damage(value: int) -> int:
    if health_component.damage_origin.is_finite():
        var direction := global_position.direction_to(health_component.damage_origin)
        if direction.dot(facing) < -0.65:
            return ceili(value * 1.5)
    return value


## 举盾推进、霰弹射击、放盾装填；第二阶段每轮追加锁定方向的冲刺。
func _update_shield(_delta: float, target: Node2D) -> void:
    if state == "charge_warning":
        _walk(Vector2.ZERO, 0)
        if state_remaining <= 0:
            state = "charge"
            state_remaining = charge_duration
            _play("charge")
    elif state == "charge":
        _dash(target)
    elif state in ["reload", "recover"]:
        _walk(Vector2.ZERO, 0)
        if state_remaining <= 0:
            if current_phase == 2 and state == "reload":
                _begin_charge(target)
            else:
                state = "approach"
    elif state == "shot_warning":
        _walk(Vector2.ZERO, 0)
        if state_remaining <= 0:
            _play("sniper")
            for spread: float in [-0.22, 0.0, 0.22]:
                _fire(locked_direction.rotated(spread), 4, 230.0, 340.0)
            state = "reload"
            state_remaining = 2.4
    else:
        _keep_distance(target, 100, move_speed * 0.7)
        if global_position.distance_to(target.global_position) < 260 and state_remaining <= 0:
            locked_direction = facing
            state = "shot_warning"
            state_remaining = 0.7


## 记录一次方向并在起跑前显示路径；预警不会随着玩家移动更新。
func _begin_charge(target: Node2D) -> void:
    locked_direction = global_position.direction_to(target.global_position)
    facing = locked_direction
    state = "charge_warning"
    state_remaining = charge_warning
    _play("charge")


## 冲刺期间一次近身伤害，碰墙或计时结束进入恢复；普通身体接触不伤害。
func _dash(target: Node2D) -> void:
    velocity = locked_direction * charge_speed
    move_and_slide()
    if global_position.distance_to(target.global_position) < 26 and _shot_remaining <= 0:
        var health := target.get_node_or_null("Health") as HealthComponent
        if health != null:
            health.damage(6, Definition.Faction.Enemy)
        _shot_remaining = charge_duration + 1.0
    if get_slide_collision_count() > 0 or state_remaining <= 0:
        state = "recover"
        state_remaining = 2.5 if get_slide_collision_count() > 0 else 1.7
        velocity = Vector2.ZERO


## 瞄准时跟随，锁定时冻结方向；两发狙击均重新完整预警，射击后真实换位。
func _update_sniper(_delta: float, target: Node2D) -> void:
    facing = global_position.direction_to(target.global_position)
    if state == "aim":
        _walk(Vector2.ZERO, 0)
        locked_direction = facing
        if state_remaining <= 0:
            state = "locked"
            state_remaining = lock_duration
            _play("lock")
    elif state == "locked":
        _walk(Vector2.ZERO, 0)
        if state_remaining <= 0:
            _fire(locked_direction, sniper_damage, 700.0, 900.0)
            _play("sniper")
            _shots += 1
            state = "bolt"
            state_remaining = 1.1
    elif state == "bolt":
        if state_remaining <= 0:
            if current_phase == 2 and _shots < 2:
                state = "aim"
                state_remaining = aim_duration
            else:
                _shots = 0
                _choose_move_target()
                state = "reposition"
                state_remaining = 3.0
    elif state == "reposition":
        _walk(global_position.direction_to(_move_target), move_speed * 1.4)
        if state_remaining <= 0 or global_position.distance_to(_move_target) < 12:
            state = "approach"
            state_remaining = 0.8
    else:
        _keep_distance(target, preferred_distance * 1.5, move_speed)
        if global_position.distance_to(target.global_position) < 85:
            if _shot_remaining <= 0:
                _fire(facing, 2, 230, 200)
                _shot_remaining = 0.8
        elif state_remaining <= 0 and _line_clear(target.global_position):
            state = "aim"
            state_remaining = aim_duration
            _play("lock")


## 点火后沿有限角速度扫射，冷却时停步；二阶段在喷射后锁向突进。
func _update_flamer(delta: float, target: Node2D) -> void:
    if state == "ignite":
        _walk(Vector2.ZERO, 0)
        if state_remaining <= 0:
            state = "flame"
            state_remaining = flame_duration
            _play("flame")
    elif state == "flame":
        var desired := global_position.direction_to(target.global_position).angle()
        facing = Vector2.from_angle(rotate_toward(facing.angle(), desired, delta * 0.65))
        if _shot_remaining <= 0:
            for spread: float in [-0.24, 0, 0.24]:
                _fire(facing.rotated(spread), 1, 220, flame_range, true)
            _shot_remaining = 0.16
        if current_phase == 2 and _attack_remaining <= 0:
            _leave_fire(global_position + facing * 70)
            _attack_remaining = 0.8
        if state_remaining <= 0:
            if current_phase == 2:
                _begin_charge(target)
            else:
                state = "recover"
                state_remaining = flame_cooldown
    elif state == "charge_warning":
        if state_remaining <= 0:
            state = "charge"
            state_remaining = charge_duration
            _play("charge")
    elif state == "charge":
        _dash(target)
        if _attack_remaining <= 0:
            _leave_fire(global_position)
            _attack_remaining = 0.25
        if state == "recover":
            state_remaining = flame_cooldown + 1.0
    elif state == "recover":
        _walk(Vector2.ZERO, 0)
        if state_remaining <= 0:
            state = "approach"
    else:
        _keep_distance(target, 85, move_speed)
        if global_position.distance_to(target.global_position) < flame_range + 20 and state_remaining <= 0:
            state = "ignite"
            state_remaining = 0.8
            _play("flame")


## 保留有限数量短时火区；墙内不创建火焰，所有效果继承房间暂停和清场。
func _leave_fire(point: Vector2) -> void:
    _prune(_fires)
    if _fires.size() >= max_fire_patches or not _point_free(point, 18) or not _line_clear(point):
        return
    var fire := PrefabManager.create_burning(Definition.Faction.Enemy, 1, 3.0, 0.5)
    if fire != null:
        fire.position = get_parent().to_local(point)
        fire.scale = Vector2.ONE * 0.7
        fire.add_to_group("boss_hazards")
        get_parent().add_child(fire)
        _fires.append(fire)


## 分段游走、低频手枪和限量布雷；第二阶段预警后逐颗引爆，随后停止行动。
func _update_engineer(_delta: float, target: Node2D) -> void:
    _prune(_mines)
    if state == "detonate":
        _walk(Vector2.ZERO, 0)
        if state_remaining <= 0:
            state = "recover"
            state_remaining = 2.5
        return
    if state == "recover":
        _walk(Vector2.ZERO, 0)
        if state_remaining <= 0:
            state = "approach"
        return
    facing = global_position.direction_to(target.global_position)
    if state_remaining <= 0 or global_position.distance_to(_move_target) < 12:
        _choose_move_target()
        state_remaining = 2.5
    _walk(global_position.direction_to(_move_target), move_speed)
    if _shot_remaining <= 0 and _line_clear(target.global_position):
        _fire(facing, 2, 230, 500)
        _shot_remaining = 1.4
    if _attack_remaining <= 0:
        if current_phase == 2 and _mines.size() >= 2:
            for index: int in range(_mines.size()):
                (_mines[index] as BossHazard).schedule_detonation(1.2 + index * 0.45)
            state = "detonate"
            state_remaining = 1.5 + _mines.size() * 0.45
            _play("detonate")
        elif _mines.size() < max_mines and _safe_mine_position(global_position):
            _mines.append(_new_hazard(global_position, true))
            _play("mine")
        _attack_remaining = mine_interval


## 避开玩家脚下、其他地雷及房间边缘门口，保障至少一条宽阔移动路线。
func _safe_mine_position(point: Vector2) -> bool:
    var room := get_parent() as FortressRoomTemplate
    if room != null:
        var local := room.to_local(point).abs()
        var limit := Vector2(room.room_size_units) * 250 - Vector2.ONE * 140
        if local.x > limit.x or local.y > limit.y:
            return false
    for target: Node in get_tree().get_nodes_in_group("combat_targets"):
        if target is Node2D and point.distance_to(target.global_position) < 90:
            return false
    for mine: Node2D in _mines:
        if point.distance_to(mine.global_position) < 90:
            return false
    return _point_free(point, 15)


## 生成可读的独立落点节点；初始化参数在进树前设置。
func _new_hazard(point: Vector2, mine: bool) -> BossHazard:
    var hazard := Node2D.new()
    hazard.set_script(HAZARD_SCRIPT)
    hazard.set("is_mine", mine)
    hazard.set("delay", 1.0 if mine else grenade_warning)
    hazard.set("throw_origin", global_position - point)
    hazard.position = get_parent().to_local(point)
    get_parent().add_child(hazard)
    return hazard as BossHazard


## 只保留尚未销毁的效果引用，防止失效引用占用数量上限。
func _prune(items: Array[Node2D]) -> void:
    for index: int in range(items.size() - 1, -1, -1):
        if not is_instance_valid(items[index]) or items[index].is_queued_for_deletion():
            items.remove_at(index)


## 随机换位使用房间内可直线到达的点，失败时留在原地等待下一轮。
func _choose_move_target() -> void:
    var room := get_parent() as FortressRoomTemplate
    var half := Vector2(room.room_size_units) * 250 - Vector2.ONE * 100 if room != null else Vector2(260, 260)
    var center := room.global_position if room != null else Vector2.ZERO
    for attempt: int in range(20):
        var point := center + Vector2(_rng.randf_range(-half.x, half.x), _rng.randf_range(-half.y, half.y))
        if _point_free(point, 18) and _line_clear(point):
            _move_target = point
            return
    _move_target = global_position


## 地形与水体占位查询，用于补员和换位，不与玩家及友军实体发生互卡。
func _point_free(point: Vector2, radius: float) -> bool:
    var shape := CircleShape2D.new()
    shape.radius = radius
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = shape
    query.transform = Transform2D(0, point)
    query.collision_mask = Definition.PHYSICS_LAYER_TERRAIN | Definition.PHYSICS_LAYER_WATER
    return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## 墙体阻断视线；预警射线也采用此查询截断，不穿墙宣告攻击。
func _line_clear(point: Vector2) -> bool:
    var query := PhysicsRayQueryParameters2D.create(global_position, point, Definition.PHYSICS_LAYER_TERRAIN)
    return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## 创建真实阵营弹丸；近距火焰使用既有减速、墙壁反弹和命中逻辑。
func _fire(direction: Vector2, damage: int, speed: float, distance: float, flame: bool = false) -> void:
    var bullet := PrefabManager.create_bullet(Definition.Faction.Enemy, damage, direction)
    if bullet == null:
        return
    bullet.bullet_speed = speed
    bullet.bullet_range = distance
    bullet.collision_layer = 4
    bullet.collision_mask = 3
    if flame:
        bullet.projectile_style = "flamethrower"
        bullet.bullet_size = 7
    bullet.position = position + direction * 15
    get_parent().add_child(bullet)


## 按四方向切换图集行，保留身体碰撞方向，避免旋转整个人物。
func _update_sprite() -> void:
    var row := 0
    if absf(facing.x) > absf(facing.y):
        row = 1 if facing.x > 0 else 3
    elif facing.y < 0:
        row = 2
    body_sprite.frame = row * 5 + kind


## 专用声音走既有 SFX 总线和位置衰减，切换状态不会创建无限播放器。
func _play(sound: String) -> void:
    _audio.stream = load("res://Assets/Audio/SFX/Bosses/%s.wav" % sound)
    _audio.play()


## 绘制与攻击状态一致的预警：护卫槽位、狙击线、冲刺路径、盾面及喷火扇形。
func _draw() -> void:
    if _defeated:
        return
    var warning := Color(1, 0.25, 0.12, 0.8)
    if kind == Kind.MOBILIZER:
        for index: int in range(4):
            if not is_instance_valid(_guards[index]) and _guard_timers[index] <= 1.0:
                draw_arc(OFFSETS[index], 15, 0, TAU, 24, Color(1, 0.8, 0.2), 2)
    if kind == Kind.SHIELD and state not in ["reload", "recover"]:
        draw_arc(Vector2.ZERO, 23, facing.angle() - PI / 3, facing.angle() + PI / 3, 18, Color(0.4, 0.8, 1), 4)
    if state in ["aim", "locked", "charge_warning", "shot_warning"]:
        var length := 900.0 if kind == Kind.SNIPER else charge_speed * charge_duration
        var end := locked_direction * length
        var query := PhysicsRayQueryParameters2D.create(global_position, global_position + end, Definition.PHYSICS_LAYER_TERRAIN)
        var hit := get_world_2d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():
            end = to_local(hit.position)
        draw_line(Vector2.ZERO, end, warning, 2 if state == "locked" else 1)
    if kind == Kind.FLAMER and state in ["ignite", "flame"]:
        draw_arc(Vector2.ZERO, flame_range, facing.angle() - 0.3, facing.angle() + 0.3, 20, warning, 2)
        for side: float in [-0.3, 0.3]:
            draw_line(Vector2.ZERO, facing.rotated(side) * flame_range, warning, 1)

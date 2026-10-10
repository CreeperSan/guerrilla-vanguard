## 八个远征主题的三阶段首领：共享预警执行骨架，每种首领配置独立招式序列。
## 继承既有真实弹丸、受地形约束移动和目标选择；不改动旧首领策略。
class_name ExpeditionBoss
extends TacticalBoss

enum Encounter { OLD_TOWN, NEON, PARK, CHEMICAL, ROUTE_66, SWAMP, CANAL, HOSPITAL }

## 主题编号与图集、音效目录一致；三管生命只在最终死亡时通知房间。
@export var encounter: Encounter = Encounter.OLD_TOWN
@export var third_health: int = 80
@export var audio_key: String = "OldTown"
@export var companion_art: Texture2D
@export var survivor_art: Texture2D

const COMPANION_SCRIPT: Script = preload("res://Prefab/BossExpedition/expedition_companion.gd")
const FIELD_SCRIPT: Script = preload("res://Prefab/BossExpedition/expedition_field.gd")

## 招式在预警开始时锁定方向和落点，之后移动目标不会改变攻击落点。
var action: String = "volley"
var locked_point: Vector2
var _sequence_index: int = 0
var _dash_hit: Dictionary = {}
var _companions: Array[ExpeditionCompanion] = []
var _fields: Array[ExpeditionField] = []
var _companion_pending: bool = true
var _survivor: bool = false
## 每类事件复用一个播放器，避免同帧恢复提示覆盖实际攻击音；最多五个节点。
var _event_audio: Dictionary = {}


## 复用公共初始化后改用当前主题防御规则；首次攻击保留完整预警。
func _ready() -> void:
    kind = Kind.MOBILIZER
    super._ready()
    collision_layer = 0
    if encounter == Encounter.SWAMP:
        collision_mask = Definition.PHYSICS_LAYER_TERRAIN
    health_component.damage_filter = _filter_encounter_damage
    state = "recover"
    state_remaining = 1.5
    _play("intro")


## 只在激活房间推进状态；无存活目标时停止移动，伙伴创建延迟到物理查询外。
func _physics_process(delta: float) -> void:
    if _defeated or _wait_for_action_start(delta):
        return
    var target := _find_combat_target()
    if target == null:
        velocity = Vector2.ZERO
        return
    if _companion_pending:
        _companion_pending = false
        _spawn_initial_companion.call_deferred()
    state_remaining = maxf(0, state_remaining - delta)
    _shot_remaining = maxf(0, _shot_remaining - delta)
    if state == "warning":
        velocity = Vector2.ZERO
        if state_remaining <= 0:
            _execute_action(target)
    elif state == "dash":
        _update_dash(delta)
    elif state == "spray":
        _update_spray(delta, target)
    elif state == "recover":
        velocity = Vector2.ZERO
        if state_remaining <= 0:
            state = "approach"
            state_remaining = 1.0
    else:
        _keep_distance(target, _preferred_range(), move_speed * (1.35 if current_phase == 3 else 1))
        if state_remaining <= 0:
            _begin_action(target)
    _update_sprite()
    queue_redraw()


## 同伴只创建一次；窗口援军在第二阶段创建，避免无限刷怪与无限奖励。
func _spawn_initial_companion() -> void:
    if _defeated or is_queued_for_deletion() or current_phase >= 3:
        return
    if encounter == Encounter.NEON or encounter == Encounter.PARK:
        _spawn_companion(0 if encounter == Encounter.NEON else 1, Vector2(-100, -30))


## 安全出生点必须不占墙且能直线到达；失败时尝试其他方向而不穿墙传送。
func _spawn_companion(role: int, offset: Vector2) -> void:
    var point := global_position + offset
    var found := false
    for angle: float in [0.0, PI / 2, PI, -PI / 2]:
        point = global_position + offset.rotated(angle)
        if _point_free(point, 18) and _line_clear(point):
            found = true
            break
    if not found:
        return
    var member := CharacterBody2D.new()
    member.set_script(COMPANION_SCRIPT)
    member.set("commander", self)
    member.set("role", role)
    member.set("art", companion_art)
    member.position = get_parent().to_local(point)
    get_parent().add_child(member)
    var companion := member as ExpeditionCompanion
    _companions.append(companion)
    companion.defeated.connect(_on_companion_defeated.bind(role))
    var room := get_parent() as FortressRoomTemplate
    if room != null:
        room.track_enemy(companion)
        var controller := room.get_parent() as LevelController
        if controller != null:
            controller.register_enemy(companion)


## 犬或搭档死亡立即进入最终形态；窗口护卫死亡不会改变楼城督军阶段。
func _on_companion_defeated(role: int) -> void:
    if role != 2 and not _defeated and current_phase < 3:
        _enter_phase(3)


## 前两管耗尽切换阶段；只有第三管耗尽发出一次最终死亡和结算信号。
func _on_phase_depleted() -> void:
    if _defeated:
        return
    if current_phase < 3:
        _enter_phase(current_phase + 1)
        return
    _defeated = true
    velocity = Vector2.ZERO
    set_physics_process(false)
    _clear_owned_effects(true)
    sig_defeated.emit()
    queue_free()


## 阶段转换取消旧攻击并留出安全窗口；损毁载具实际更换为驾驶员图集。
func _enter_phase(next_phase: int) -> void:
    var partner_alive := _companions.any(func(member): return is_instance_valid(member) and not member.is_queued_for_deletion() and not member._dead)
    current_phase = next_phase
    health_component.health_max = second_health if next_phase == 2 else third_health
    health_component.health = health_component.health_max
    _clear_owned_effects(next_phase == 3 and encounter in [Encounter.NEON, Encounter.PARK])
    _sequence_index = 0
    _shots = 0
    state = "recover"
    state_remaining = 1.8
    velocity = Vector2.ZERO
    if encounter == Encounter.OLD_TOWN and next_phase == 2:
        _spawn_window_guards.call_deferred()
    if next_phase == 3 and encounter == Encounter.ROUTE_66:
        _survivor = true
        body_sprite.texture = survivor_art
        body_sprite.scale = Vector2.ONE * 0.24
        # 驾驶员与车体使用不同实际受击尺寸，避免下车后仍保留巨型车身判定。
        var body_shape := CircleShape2D.new()
        body_shape.radius = 12
        $CollisionShape2D.set_deferred("shape", body_shape)
        var hurt_shape := CircleShape2D.new()
        hurt_shape.radius = 18
        $HurtBox/CollisionShape2D.set_deferred("shape", hurt_shape)
    elif next_phase == 3 and encounter == Encounter.NEON:
        # 主枪手先倒下时由黑衣搭档接战；若搭档先倒下则保留白衣枪手。
        if partner_alive:
            _survivor = true
            body_sprite.texture = companion_art
        _clear_owned_effects(true)
    body_sprite.modulate = Color(1, 0.9, 0.82) if next_phase == 3 else Color.WHITE
    _play("phase")
    sig_phase_changed.emit(current_phase, health_component.health, health_component.health_max)


## 固定两个窗口护卫，无补员；领袖已经死亡时忽略延迟创建请求。
func _spawn_window_guards() -> void:
    if _defeated or is_queued_for_deletion():
        return
    _spawn_companion(2, Vector2(-160, -110))
    _spawn_companion(2, Vector2(160, -110))


## 清理只处理当前首领持有的节点，不影响其他房间或友军。
func _clear_owned_effects(include_companions: bool) -> void:
    for field: ExpeditionField in _fields:
        if is_instance_valid(field):
            field._disarm()
    _fields.clear()
    if include_companions:
        for member: ExpeditionCompanion in _companions:
            if is_instance_valid(member):
                member.set_physics_process(false)
                member.queue_free()
        # 保留一帧引用供双人战判断存活身份，创建前会验证实例有效性。


## 前盾和工业装甲只减伤；恢复窗口与背面始终可打，不要求特定枪械。
func _filter_encounter_damage(value: int) -> int:
    if state == "recover" or not health_component.damage_origin.is_finite():
        return value
    var incoming := global_position.direction_to(health_component.damage_origin)
    if encounter == Encounter.OLD_TOWN and current_phase == 1 and incoming.dot(facing) > 0.5:
        return maxi(1, ceili(value * 0.3))
    if encounter in [Encounter.CHEMICAL, Encounter.CANAL] and incoming.dot(facing) < -0.5:
        return ceili(value * 1.5)
    if encounter == Encounter.ROUTE_66 and current_phase == 1:
        return maxi(1, ceili(value * 0.65))
    if encounter == Encounter.ROUTE_66 and current_phase == 2 and incoming.dot(facing) < -0.5:
        return ceili(value * 1.5)
    return value


## 每个主题使用独立阶段序列；新阶段既换招也改变战斗距离或行动形态。
func _actions() -> Array:
    match encounter:
        Encounter.OLD_TOWN:
            return ["shotgun", "volley", "dash"] if current_phase == 3 else (["volley", "firebomb", "shotgun"] if current_phase == 2 else ["shotgun", "shotgun", "dash"])
        Encounter.NEON:
            return ["volley", "dash", "shotgun"] if current_phase == 3 else (["crossfire", "volley", "flash"] if current_phase == 2 else ["volley", "crossfire"])
        Encounter.PARK:
            return ["shotgun", "dash"] if current_phase == 3 else (["snipe", "trap", "snipe"] if current_phase == 2 else ["snipe", "volley"])
        Encounter.CHEMICAL:
            return ["spray", "vent", "spray"] if current_phase == 3 else (["spray", "vent", "acid"] if current_phase == 2 else ["acid", "spray"])
        Encounter.ROUTE_66:
            return ["volley", "grenade", "volley"] if current_phase == 3 else (["dash", "volley", "firebomb"] if current_phase == 2 else ["dash", "volley"])
        Encounter.SWAMP:
            return ["salvo", "harpoon", "salvo"] if current_phase == 3 else (["dash", "harpoon", "salvo"] if current_phase == 2 else ["dash", "salvo"])
        Encounter.CANAL:
            return ["hammer", "dash", "hammer"] if current_phase == 3 else (["hammer", "flood", "volley"] if current_phase == 2 else ["hammer", "volley"])
        Encounter.HOSPITAL:
            return ["dash", "hammer", "lucid"] if current_phase == 3 else (["hammer", "growth", "dash"] if current_phase == 2 else ["hammer", "dash", "sedate"])
    return ["volley"]


## 场景身份决定有效交战距离；搁浅艇固定炮座不再移动。
func _preferred_range() -> float:
    if encounter == Encounter.PARK and current_phase < 3:
        return 230
    return 90 if encounter in [Encounter.CANAL, Encounter.HOSPITAL] else 150


## 每轮只选一个动作；方向和落点在预警开始时冻结，避免无提示追踪伤害。
func _begin_action(target: Node2D) -> void:
    var sequence := _actions()
    action = sequence[_sequence_index % sequence.size()]
    _sequence_index += 1
    locked_direction = global_position.direction_to(target.global_position)
    if locked_direction == Vector2.ZERO:
        locked_direction = Vector2.DOWN
    facing = locked_direction
    locked_point = target.global_position
    state = "warning"
    state_remaining = 1.2 if action == "snipe" else (1.0 if action in ["dash", "hammer", "flood"] else 0.8)
    _play("warning")


## 将预警转换为真实弹丸、物理冲撞或范围节点；每种动作都有确定恢复时间。
func _execute_action(_target: Node2D) -> void:
    _play("attack")
    match action:
        "dash":
            state = "dash"
            state_remaining = 1.0 if encounter in [Encounter.ROUTE_66, Encounter.SWAMP] else 0.65
            _dash_hit.clear()
            return
        "spray":
            state = "spray"
            state_remaining = 1.8
            _shot_remaining = 0
            return
        "snipe":
            _fire(locked_direction, 10, 600, 850)
        "shotgun":
            for spread: float in [-0.3, -0.15, 0, 0.15, 0.3]:
                _fire(locked_direction.rotated(spread), 3, 240, 380)
        "volley", "salvo", "crossfire":
            var count := 5 if action == "salvo" else 3
            for index: int in range(count):
                _fire(locked_direction.rotated((index - (count - 1) * 0.5) * 0.18), 3, 250, 650)
            if action == "crossfire":
                _spawn_field(locked_point, 28, 0.8, 0.5, 4)
        "grenade", "firebomb", "acid", "flash":
            var color := Color(0.6, 0.9, 0.2) if action == "acid" else (Color(1, 0.3, 0.6) if action == "flash" else Color(1, 0.5, 0.15))
            _spawn_field(locked_point, 44, 0.5, 3.0 if action in ["acid", "firebomb"] else 0.3, 4, false, color)
        "trap":
            # 已锁定落点之外侧放陷阱，启动前可射毁；不会直接在脚下瞬时生效。
            _spawn_field(locked_point + locked_direction.orthogonal() * 70, 25, 1.0, 9, 4, true)
        "harpoon":
            var field := _spawn_field(locked_point, 30, 0.6, 3.5, 3, true, Color(0.7, 0.85, 0.7))
            if field != null:
                field.pull_origin = global_position
        "hammer":
            _spawn_field(global_position + locked_direction * 65, 65, 0.25, 0.25, 7, false, Color(1, 0.65, 0.2))
        "vent":
            for side: float in [-1, 1]:
                _spawn_field(global_position + locked_direction.orthogonal() * 125 * side, 55, 1, 2, 3)
        "flood":
            # 两侧积水带电，中央至少留 180 单位宽安全通道。
            var room := get_parent() as FortressRoomTemplate
            var center := room.global_position if room != null else global_position
            for side: float in [-1, 1]:
                _spawn_field(center + Vector2(240 * side, 80), 100, 1.4, 4, 2, false, Color(0.3, 0.75, 0.95))
        "growth":
            for side: float in [-1, 1]:
                _spawn_field(locked_point + locked_direction.orthogonal() * 90 * side, 38, 1.0, 3.0, 3, false, Color(0.75, 0.4, 0.8))
        "sedate", "lucid":
            state = "recover"
            state_remaining = 3.4 if action == "lucid" else 2.8
            _play("recover")
            return
    state = "recover"
    state_remaining = 2.0 if encounter in [Encounter.CHEMICAL, Encounter.CANAL] else 1.4
    _play("recover")


## 冲撞只对每个目标造成一次伤害；碰墙立刻停下并延长恢复，禁止穿越地形。
func _update_dash(_delta: float) -> void:
    velocity = locked_direction * (220 if encounter == Encounter.ROUTE_66 else 180)
    move_and_slide()
    for candidate: Node in get_tree().get_nodes_in_group("combat_targets"):
        if not candidate is Node2D or _dash_hit.has(candidate.get_instance_id()):
            continue
        if global_position.distance_to(candidate.global_position) < 34:
            var health := candidate.get_node_or_null("Health") as HealthComponent
            if health != null:
                health.damage(7, Definition.Faction.Enemy, global_position)
                _dash_hit[candidate.get_instance_id()] = true
    if state_remaining <= 0 or get_slide_collision_count() > 0:
        state = "recover"
        state_remaining = 2.6
        velocity = Vector2.ZERO
        _play("recover")


## 喷流转向有限，逐次留下真实短时酸区；玩家可绕到背部攻击压力罐。
func _update_spray(delta: float, target: Node2D) -> void:
    facing = Vector2.from_angle(rotate_toward(facing.angle(), global_position.direction_to(target.global_position).angle(), delta * 0.5))
    if _shot_remaining <= 0:
        _fire(facing, 2, 190, 170)
        _spawn_field(global_position + facing * 100, 27, 0.3, 1.3, 2)
        _shot_remaining = 0.4
    if state_remaining <= 0:
        state = "recover"
        state_remaining = 2.8 if current_phase == 3 else 2.0
        _play("recover")


## 所有危险区共享数量上限，避免积累封路；点位超出房间或墙内时取消生成。
func _spawn_field(point: Vector2, area_radius: float, warning: float, duration: float, hit_damage: int, shootable: bool = false, color: Color = Color(0.6, 0.9, 0.2)) -> ExpeditionField:
    for index: int in range(_fields.size() - 1, -1, -1):
        if not is_instance_valid(_fields[index]) or _fields[index].is_queued_for_deletion():
            _fields.remove_at(index)
    if _fields.size() >= 6 or not _point_free(point, minf(area_radius, 20)):
        return null
    var room := get_parent() as FortressRoomTemplate
    if room != null:
        var bounds := Vector2(room.room_size_units) * 250 - Vector2.ONE * (area_radius + 35)
        var local := room.to_local(point).abs()
        if local.x > bounds.x or local.y > bounds.y:
            return null
    var field := Node2D.new()
    field.set_script(FIELD_SCRIPT)
    field.set("radius", area_radius)
    field.set("delay", warning)
    field.set("lifetime", duration)
    field.set("damage", hit_damage)
    field.set("destructible", shootable)
    field.set("tint", color)
    field.position = get_parent().to_local(point)
    get_parent().add_child(field)
    _fields.append(field as ExpeditionField)
    return field as ExpeditionField


## 搁浅艇第三阶段固定炮座；其余首领保留基类的沿墙移动。
func _keep_distance(target: Node2D, distance: float, speed: float) -> void:
    if encounter == Encounter.SWAMP and current_phase == 3:
        velocity = Vector2.ZERO
        facing = global_position.direction_to(target.global_position)
        return
    super._keep_distance(target, distance, speed)


## 四方向图集按 DOWN/RIGHT/UP/LEFT 排列，不旋转整个人物或载具。
func _update_sprite() -> void:
    if body_sprite == null:
        return
    body_sprite.frame = 1 if absf(facing.x) > absf(facing.y) and facing.x > 0 else (3 if absf(facing.x) > absf(facing.y) else (2 if facing.y < 0 else 0))


## 每个主题有独立的入场、预警、攻击、恢复和阶段音色，走既有 SFX 总线。
func _play(sound: String) -> void:
    if _audio == null:
        return
    var path := "res://Assets/Audio/SFX/Expedition/%s/%s.wav" % [audio_key, sound]
    if ResourceLoader.exists(path):
        if not _event_audio.has(sound):
            var player := AudioStreamPlayer2D.new()
            player.bus = &"SFX"
            player.volume_db = -10
            player.stream = load(path)
            add_child(player)
            _event_audio[sound] = player
        var event_player := _event_audio[sound] as AudioStreamPlayer2D
        event_player.play()


## 只绘制当前动作的真实锁向与落点；前盾和药物抑制窗口有独立反馈。
func _draw() -> void:
    if _defeated:
        return
    if encounter == Encounter.OLD_TOWN and current_phase == 1 and state != "recover":
        draw_arc(Vector2.ZERO, 28, facing.angle() - PI / 3, facing.angle() + PI / 3, 20, Color(0.4, 0.8, 1), 4)
    if state == "warning":
        var color := Color(1, 0.35, 0.12, 0.85)
        if action in ["dash", "snipe", "shotgun", "volley", "salvo", "crossfire", "spray"]:
            var length := 850.0 if action == "snipe" else (220.0 if action == "dash" else 160.0)
            var end := global_position + locked_direction * length
            var query := PhysicsRayQueryParameters2D.create(global_position, end, Definition.PHYSICS_LAYER_TERRAIN)
            var hit := get_world_2d().direct_space_state.intersect_ray(query)
            if not hit.is_empty():
                end = hit.position
            draw_line(Vector2.ZERO, to_local(end), color, 2)
        elif action == "hammer":
            draw_arc(locked_direction * 65, 65, 0, TAU, 32, color, 2)
        elif action == "vent":
            for side: float in [-1, 1]:
                draw_arc(locked_direction.orthogonal() * 125 * side, 55, 0, TAU, 32, color, 2)
        elif action == "growth":
            for side: float in [-1, 1]:
                draw_arc(to_local(locked_point) + locked_direction.orthogonal() * 90 * side, 38, 0, TAU, 32, color, 2)
        elif action == "flood":
            var room := get_parent() as FortressRoomTemplate
            var center := room.global_position if room != null else global_position
            for side: float in [-1, 1]:
                draw_arc(to_local(center + Vector2(240 * side, 80)), 100, 0, TAU, 32, color, 2)
        elif action == "trap":
            draw_arc(to_local(locked_point) + locked_direction.orthogonal() * 70, 25, 0, TAU, 32, color, 2)
        elif action == "harpoon":
            draw_arc(to_local(locked_point), 30, 0, TAU, 32, color, 2)
        else:
            draw_arc(to_local(locked_point), 44, 0, TAU, 32, color, 2)
    if state == "recover" and action in ["lucid", "sedate"]:
        draw_arc(Vector2.ZERO, 32, 0, TAU, 32, Color(0.3, 0.85, 1), 2)

## 管理一局中的房间布局、玩家当前房间、小地图和 Boss 出口关卡推进。
class_name FortressLevelController
extends LevelController

signal sig_room_changed(room_id: int, room_type: String)
signal sig_boss_room_entered(boss: BattlefieldBoss)
signal sig_level_completed(completed_level: int, next_level: int)

const ROOM_TEMPLATE_ROOT := "res://Scene/LevelFortress"
const MIN_ROOM_STYLE_VARIANTS := 2
## 房间切换时使用短暂交叉淡化，避免传送后房间内容突然闪现。
const ROOM_FADE_DURATION := 0.32
## Boss 池由场景配置；默认 General 与坦克等概率抽取。
@export var boss_scenes: Array[PackedScene] = [
    preload("res://Prefab/BossGeneral/boss_general.tscn"),
    preload("res://Prefab/BossTank/boss_tank.tscn"),
]

## 以指定种子开始关卡；未指定时使用系统随机种子。
@export var level_number: int = 1
@export var random_seed: int = 0
## 为空时沿用原要塞关卡；新主题场景通过配置复用同一套房间和战斗管理。
@export var battlefield_theme: BattlefieldTheme
## 保留旧主题场景的资源字段；正式对局推进由 GameManager 随机流程统一管理。
@export var campaign: BattlefieldCampaign

@export_group("对局流程")
## 正式 GameRun 场景开启，单独 F6 运行主题场景时只测试当前 Level。
@export var managed_run: bool = false
@export var show_run_mode_selection: bool = true
@export_enum("空降模式", "总攻模式") var initial_run_mode: int = 0
## 0 表示每局随机；固定整数同时复现主题顺序和房间布局。
@export var run_seed: int = 0

var level_map: Dictionary = {}
var current_room_id: int = -1
var visited_room_ids: Array[int] = []
var boss_defeated: bool = false
var _level_completed: bool = false
var _room_nodes: Dictionary = {}
var _room_visibility_tween: Tween
var _world_room_origins: Dictionary = {}
var _room_scene_variants: Dictionary = {}
var _door_data: Dictionary = {}
var _door_transition_locked: bool = false
var _boss_exit: Area2D
var _player: Node2D
var _hud: GameHUD
## 异步清理时记录加载版本；重开后的新请求可替换旧请求，不会卡在等待状态。
var _run_stage_revision: int = -1


## 解析玩家和 HUD 并生成第一关；外部也可稍后调用 start_level 切换关卡。
func _ready() -> void:
    super._ready()
    _player = controlled_player
    _hud = controlled_hud
    if is_instance_valid(controlled_camera):
        controlled_camera.follow_smooth_speed = 0.0
        controlled_camera.dead_zone_enabled = true
        controlled_camera.fit_bounds_to_viewport = true
    if managed_run:
        if _hud == null:
            push_error("正式对局缺少 HUD，无法选择进攻模式。")
            return
        _hud.enable_run_ui()
        _hud.sig_run_mode_selected.connect(_on_run_mode_selected)
        GameManager.sig_run_finished.connect(_on_run_finished)
        if not GameManager.attach_level_host(self):
            return
        if GameManager.run_state not in [RogueRunManager.RunState.ACTIVE, RogueRunManager.RunState.TRANSITIONING]:
            var requested_mode := GameManager.consume_menu_mode()
            if requested_mode >= 0:
                _on_run_mode_selected(requested_mode)
            elif show_run_mode_selection:
                _hud.show_run_mode_selection()
            else:
                _on_run_mode_selected(initial_run_mode)
        return
    start_level(level_number, random_seed if random_seed != 0 else randi())


## 菜单只提交模式，真正的抽取、种子和加载请求由全局管理器创建。
func _on_run_mode_selected(mode: int) -> void:
    if not GameManager.start_run(mode, run_seed):
        _hud.show_run_start_error("无法开始对局，请检查主题池配置和输出日志。")


## 接收全局关卡请求：暂停战斗，清理上一关，保留玩家与 HUD，再按本局序号生成地图。
func _on_run_stage_requested(stage_number: int, theme: BattlefieldTheme, stage_seed: int, revision: int) -> void:
    if not managed_run or revision == _run_stage_revision or not GameManager.is_stage_request_current(self, stage_number, revision):
        return
    _run_stage_revision = revision
    _hud.prepare_run_stage(stage_number, theme.display_name)
    _clear_generated_level()
    # 等到旧房间和效果真正释放后再生成，避免同帧节点重名与旧子弹命中新关角色。
    await get_tree().process_frame
    if _run_stage_revision != revision or not GameManager.is_stage_request_current(self, stage_number, revision):
        return
    battlefield_theme = theme
    start_level(stage_number, stage_seed)
    if GameManager.confirm_stage_ready(self, stage_number, revision):
        _hud.start_run_stage(stage_number, theme.display_name)


## 胜利由全局路线完成触发；失败画面仍沿用通用控制器的玩家死亡处理。
func _on_run_finished(won: bool) -> void:
    if won:
        CurrencyManager.settle_run(GameManager.attack_mode == RogueRunManager.AttackMode.AIRBORNE)
        if is_instance_valid(_hud):
            _hud.show_run_victory(total_score)


## 玩家死亡时同时关闭全局推进，避免排队中的下一关请求在战败后继续运行。
func _on_player_died() -> void:
    if managed_run:
        GameManager.fail_run(self)
    super._on_player_died()


## 退出宿主时解除全局关联；单关调试场景不会参与正式对局的信号管理。
func _exit_tree() -> void:
    if managed_run:
        GameManager.detach_level_host(self)


## 清除旧布局，按同一随机种子生成房间物理占地和路线 UI。
func start_level(new_level_number: int, seed: int) -> void:
    level_number = new_level_number
    random_seed = seed
    # 配乐随主题而非难度编号选择；切换房间不会重播同一首曲。
    GameSettings.play_level_music(battlefield_theme)
    # 主题由 GameManager 或独立测试场景指定；关卡编号只用于既有房间生成规则。
    _room_scene_variants.clear()
    boss_defeated = false
    _level_completed = false
    current_room_id = -1
    visited_room_ids.clear()
    _door_data.clear()
    _door_transition_locked = false
    _clear_generated_level()
    level_map = FortressRoomGenerator.generate_level(level_number, random_seed)
    _calculate_world_room_origins()
    _build_room_door_data()
    _build_rooms()
    current_room_id = int(level_map.get("start_room_id", 0))
    visited_room_ids.append(current_room_id)
    _activate_room_contents(current_room_id)
    _set_room_visibility(current_room_id)
    _move_player_to_room(current_room_id)
    _update_minimap()
    _emit_room_state(current_room_id)


## 只清理上次生成的房间与临时战斗内容，保留关卡场景中的玩家、HUD 和相机节点。
func _clear_generated_level() -> void:
    if _room_visibility_tween != null and _room_visibility_tween.is_running():
        _room_visibility_tween.kill()
    if is_instance_valid(_boss_exit):
        _boss_exit.queue_free()
    _boss_exit = null
    for room_value: Variant in _room_nodes.values():
        var old_room := room_value as Node
        if is_instance_valid(old_room):
            old_room.queue_free()
    _room_nodes.clear()
    _world_room_origins.clear()
    _registered_enemy_ids.clear()
    for effect: Node in get_children():
        if effect is ProjectileBullet or effect is ProjectileExplosion or effect is BurningEffect or effect is IncomingShell or effect is MortarStriker or effect is TacticalBombing or effect is DamagePop or effect is LootItem:
            effect.queue_free()


## 根據相鄰矩形邊界，為每間房匯總各方向真實開啟的門槽。
func _build_room_door_data() -> void:
    for room: Dictionary in level_map.get("rooms", []):
        _door_data[int(room.id)] = {"north": [], "east": [], "south": [], "west": []}
    for connection: Dictionary in level_map.get("connections", []):
        var first_doors: Dictionary = _door_data[int(connection.from)]
        var second_doors: Dictionary = _door_data[int(connection.to)]
        first_doors[connection.from_side].append_array(connection.from_slots)
        second_doors[connection.to_side].append_array(connection.to_slots)


## 实例化每个尺寸模板并按 500 单位网格与房间间隔放置；Boss 房单独监听其出口。
func _build_rooms() -> void:
    for room_data: Dictionary in level_map.get("rooms", []):
        var room_size: Vector2i = room_data.get("size", Vector2i.ONE)
        var room_variants: Array[PackedScene] = _get_room_scene_variants(room_size)
        if room_variants.is_empty():
            push_error("找不到房间尺寸模板：%s" % room_size)
            continue
        var style_rng := RandomNumberGenerator.new()
        style_rng.seed = int(level_map.get("seed", 0)) + (int(room_data.id) + 1) * 7919
        var style_index := style_rng.randi_range(1, room_variants.size())
        room_data["style_index"] = style_index
        var room_scene: PackedScene = room_variants[style_index - 1]
        if room_scene == null:
            push_error("房间样式资源无效：尺寸 %s，样式 %d" % [room_size, style_index])
            continue
        var room := room_scene.instantiate() as FortressRoomTemplate
        if room == null:
            push_error("房间模板根节点必须挂载 FortressRoomTemplate。")
            continue
        room_data["content_seed"] = int(level_map.get("seed", 0)) + (int(room_data.id) + 1) * 7919
        room.population_seed = int(room_data["content_seed"])
        room.battlefield_theme = battlefield_theme
        room.configure_room(room_data, _door_data[int(room_data.id)])
        var world_origin: Vector2 = _world_room_origins.get(int(room_data.id), Vector2.ZERO)
        room.position = world_origin + Vector2(room_size) * FortressRoomGenerator.ROOM_UNIT_SIZE * 0.5
        room.sig_door_entered.connect(_on_door_entered)
        room.sig_room_cleared.connect(_on_room_cleared)
        add_child(room)
        # 新房间先保持完全透明，首次进入时再由可见性管理统一显示。
        var initial_modulate := room.modulate
        initial_modulate.a = 0.0
        room.modulate = initial_modulate
        _room_nodes[int(room_data.id)] = room
        if str(room_data.get("type", "")) == "boss":
            _boss_exit = _create_boss_exit(room, room_data)


## 扫描 Room_尺寸_编号 文件夹加载全部样式；已有第三种及更多样式会自动保留并参与随机。
func _get_room_scene_variants(room_size: Vector2i) -> Array[PackedScene]:
    if _room_scene_variants.has(room_size):
        return _room_scene_variants[room_size]
    var prefix := "Room_%dx%d_" % [room_size.x, room_size.y]
    var template_root := ROOM_TEMPLATE_ROOT
    if battlefield_theme != null and not battlefield_theme.room_template_root.is_empty():
        template_root = battlefield_theme.room_template_root
    var room_directories := DirAccess.get_directories_at(template_root)
    room_directories.sort()
    var variants: Array[PackedScene] = []
    for directory_name: String in room_directories:
        if not directory_name.begins_with(prefix):
            continue
        var scene_path := "%s/%s/%s.tscn" % [template_root, directory_name, directory_name]
        var room_scene := ResourceLoader.load(scene_path) as PackedScene
        if room_scene != null:
            variants.append(room_scene)
    if variants.size() < MIN_ROOM_STYLE_VARIANTS:
        push_warning("房间 %s 目前只有 %d 种有效样式，至少需要 %d 种。" % [room_size, variants.size(), MIN_ROOM_STYLE_VARIANTS])
    _room_scene_variants[room_size] = variants
    return variants


## 玩家穿越路线中已开放的门位时更新当前房间并同步地图。
func _on_door_entered(room_id: int, side: String, slot: int, body: Node2D) -> void:
    if _door_transition_locked or body != _player or room_id != current_room_id:
        return
    var current_room := _room_nodes.get(room_id) as FortressRoomTemplate
    if current_room == null or not current_room.is_room_safe():
        return
    var destination := _find_door_destination(room_id, side, slot)
    if destination.is_empty():
        return
    _door_transition_locked = true
    _complete_room_transition.call_deferred(
        int(destination.room_id),
        str(destination.side),
        int(destination.slot)
    )
    _unlock_door_transition.call_deferred()


## 通过路线连接将玩家传送到相邻房间入口，并只在房间切换时平滑移动摄像机。
func _complete_room_transition(room_id: int, entry_side: String, entry_slot: int) -> void:
    var room := _room_nodes.get(room_id) as FortressRoomTemplate
    if room == null or not is_instance_valid(_player):
        _door_transition_locked = false
        return
    var previous_room_id := current_room_id
    _activate_room_contents(room_id)
    _player.global_position = room.global_position + _door_landing_position(room, entry_side, entry_slot)
    current_room_id = room_id
    _transition_room_visibility(previous_room_id, room_id)
    if not visited_room_ids.has(room_id):
        visited_room_ids.append(room_id)
    if int(level_map.get("boss_room_id", -1)) == current_room_id:
        _spawn_boss_for_current_room()
    _set_camera_room(room, true)
    _update_minimap()
    _emit_room_state(current_room_id)


## 从当前房间门槽查找路线另一端的房间、入口方向和对应门槽。
func _find_door_destination(room_id: int, side: String, slot: int) -> Dictionary:
    for connection: Dictionary in level_map.get("connections", []):
        if int(connection.from) == room_id and str(connection.from_side) == side:
            var from_slot_index: int = connection.from_slots.find(slot)
            if from_slot_index >= 0:
                return {"room_id": int(connection.to), "side": str(connection.to_side), "slot": int(connection.to_slots[from_slot_index])}
        if int(connection.to) == room_id and str(connection.to_side) == side:
            var to_slot_index: int = connection.to_slots.find(slot)
            if to_slot_index >= 0:
                return {"room_id": int(connection.from), "side": str(connection.from_side), "slot": int(connection.from_slots[to_slot_index])}
    return {}


## 根据入口所在边和门槽计算安全落点，避免传送后立刻再次触发门区。
func _door_landing_position(room: FortressRoomTemplate, side: String, slot: int) -> Vector2:
    var half_size := Vector2(room.room_size_units) * FortressRoomGenerator.ROOM_UNIT_SIZE * 0.5
    # 落点比边缘出口再深入 64 单位，与收窄后的触发区保持间隔，避免立即返回。
    var inset := room.entrance_inset + 64.0
    match side:
        "north": return Vector2(-half_size.x + (float(slot) + 0.5) * FortressRoomGenerator.ROOM_UNIT_SIZE, -half_size.y + inset)
        "east": return Vector2(half_size.x - inset, -half_size.y + (float(slot) + 0.5) * FortressRoomGenerator.ROOM_UNIT_SIZE)
        "south": return Vector2(-half_size.x + (float(slot) + 0.5) * FortressRoomGenerator.ROOM_UNIT_SIZE, half_size.y - inset)
        _: return Vector2(-half_size.x + inset, -half_size.y + (float(slot) + 0.5) * FortressRoomGenerator.ROOM_UNIT_SIZE)


## 延迟解除同一门洞的触发锁，防止门两侧 Area 在同一帧内造成往返切换。
func _unlock_door_transition() -> void:
    await get_tree().create_timer(0.55).timeout
    _door_transition_locked = false


## 玩家进入 Boss 房时才创建 Boss；普通房间不会实例化首领。
func _spawn_boss_for_current_room() -> void:
    var boss_room: FortressRoomTemplate = _room_nodes.get(current_room_id) as FortressRoomTemplate
    if boss_room == null or boss_defeated or boss_room.has_meta("boss_spawned"):
        return
    var scene := _select_boss_scene(boss_room.population_seed)
    if scene == null:
        return
    var instance := scene.instantiate()
    var boss := instance as BattlefieldBoss
    if boss == null:
        instance.free()
        push_error("Boss 场景根节点必须挂载 BattlefieldBoss 的子类。")
        return
    boss_room.set_meta("boss_spawned", true)
    boss.name = "Boss"
    boss.position = Vector2.ZERO
    boss.sig_defeated.connect(_on_boss_defeated)
    boss_room.add_child(boss)
    boss_room.track_enemy(boss)
    register_enemy(boss)
    sig_boss_room_entered.emit(boss)
    print("[Boss] seed=%d room=%d scene=%s" % [boss_room.population_seed, current_room_id, scene.resource_path])


## 独立随机流只依赖房间种子，重复进入不重抽，且不改变路线与房间内容随机序列。
func _select_boss_scene(room_seed: int) -> PackedScene:
    var candidates: Array[PackedScene] = []
    for scene: PackedScene in boss_scenes:
        if scene != null:
            candidates.append(scene)
    if candidates.is_empty():
        push_error("Boss 场景池为空，无法生成首领。")
        return null
    var rng := RandomNumberGenerator.new()
    rng.seed = room_seed ^ 0x54414E4B
    return candidates[rng.randi_range(0, candidates.size() - 1)]


## Boss 被击败后启用 Boss 房内独立出口点。
func _on_boss_defeated() -> void:
    boss_defeated = true
    _open_boss_exit.call_deferred()


## 创建位于 Boss 房内部且初始关闭的出口触发器。
func _create_boss_exit(room: FortressRoomTemplate, room_data: Dictionary) -> Area2D:
    var exit_area := Area2D.new()
    exit_area.name = "BossExit"
    exit_area.collision_layer = 0
    exit_area.collision_mask = 1 << 0
    exit_area.monitoring = false
    exit_area.modulate = Color(1.0, 1.0, 1.0, 0.35)
    var collision := CollisionShape2D.new()
    # 通关出口也贴边，选择返回门的对侧，避免清场后站在房间中心直接切关。
    var exit_side := "south"
    var opposite: Dictionary = {"north": "south", "east": "west", "south": "north", "west": "east"}
    for side: String in opposite:
        if not room.opened_doors.get(side, []).is_empty():
            exit_side = str(opposite[side])
            break
    var shape := RectangleShape2D.new()
    shape.size = Vector2(FortressRoomTemplate.DOOR_WIDTH, 16.0) if exit_side in ["north", "south"] else Vector2(16.0, FortressRoomTemplate.DOOR_WIDTH)
    collision.shape = shape
    exit_area.add_child(collision)
    var marker := Polygon2D.new()
    marker.color = Color(0.95, 0.73, 0.28, 0.9)
    marker.polygon = PackedVector2Array([Vector2(0, -22), Vector2(22, 0), Vector2(0, 22), Vector2(-22, 0)])
    exit_area.add_child(marker)
    exit_area.body_entered.connect(_on_boss_exit_entered)
    var half_size := Vector2(room.room_size_units) * FortressRoomTemplate.UNIT_SIZE * 0.5
    match exit_side:
        "north": exit_area.position = Vector2(0, -half_size.y + room.entrance_inset)
        "east": exit_area.position = Vector2(half_size.x - room.entrance_inset, 0)
        "south": exit_area.position = Vector2(0, half_size.y - room.entrance_inset)
        "west": exit_area.position = Vector2(-half_size.x + room.entrance_inset, 0)
    room.add_child(exit_area)
    return exit_area


## 仅在 Boss 已被击败且玩家实际触碰出口时请求全局推进，单关调试则显示本关完成。
func _on_boss_exit_entered(body: Node2D) -> void:
    if _level_completed or body != _player or not is_current_level_cleared():
        return
    var completed_level := level_number
    if managed_run:
        if not GameManager.report_level_cleared(self, completed_level):
            return
        _level_completed = true
        var next_level := GameManager.get_current_stage_number() if GameManager.run_state != RogueRunManager.RunState.COMPLETED else 0
        sig_level_completed.emit(completed_level, next_level)
    else:
        _level_completed = true
        sig_level_completed.emit(completed_level, 0)
        CurrencyManager.settle_run()
        if _hud != null:
            _hud.show_run_victory(total_score, "本关完成")


## 全局管理器复核安全出口条件，防止其他系统在未清场时绕过房间规则推进。
func is_current_level_cleared() -> bool:
    var boss_room := _room_nodes.get(int(level_map.get("boss_room_id", -1))) as FortressRoomTemplate
    return boss_defeated and boss_room != null and boss_room.is_room_safe()


## 把玩家移至新关起点房中心，保持玩家节点由外部场景拥有。
func _move_player_to_room(room_id: int) -> void:
    if not is_instance_valid(_player):
        return
    var room := _room_nodes.get(room_id) as FortressRoomTemplate
    if room == null:
        return
    _player.global_position = room.global_position
    _set_camera_room(room, false)


## 由房间 ID 查找生成器记录，避免 UI、玩家出生点各自维护一份拓扑。
func _get_room_data(room_id: int) -> Dictionary:
    for room: Dictionary in level_map.get("rooms", []):
        if int(room.id) == room_id:
            return room
    return {}


## 同步真实路线、当前房间和本局已访问房间到 HUD 小地图。
func _update_minimap() -> void:
    if is_instance_valid(_hud):
        _hud.set_room_map(level_map, current_room_id, visited_room_ids)


## 按地图路线递归放置房间，并在相邻房间之间保留固定空间供传送切换。
func _calculate_world_room_origins() -> void:
    var rooms: Array = level_map.get("rooms", [])
    var room_by_id: Dictionary = {}
    for room: Dictionary in rooms:
        room_by_id[int(room.id)] = room
    for room: Dictionary in rooms:
        var room_id := int(room.id)
        var room_origin: Vector2i = room.get("origin", Vector2i.ZERO)
        var room_size: Vector2i = room.get("size", Vector2i.ONE)
        var parent_id := int(room.get("parent_id", -1))
        if parent_id < 0 or not _world_room_origins.has(parent_id) or not room_by_id.has(parent_id):
            _world_room_origins[room_id] = Vector2(room_origin) * FortressRoomGenerator.ROOM_UNIT_SIZE
            continue
        var parent: Dictionary = room_by_id[parent_id]
        var parent_origin: Vector2i = parent.origin
        var parent_size: Vector2i = parent.size
        var parent_world_origin: Vector2 = _world_room_origins[parent_id]
        var direction := _attachment_direction(room_origin, room_size, parent_origin, parent_size)
        var candidate := _attached_room_origin(
            parent_world_origin,
            parent_origin,
            parent_size,
            room_origin,
            room_size,
            direction
        )
        var adjustment_count := 0
        while _overlaps_placed_room(candidate, room_size, room_id, rooms) and adjustment_count < 64:
            candidate += direction * FortressRoomGenerator.ROOM_GAP
            adjustment_count += 1
        _world_room_origins[room_id] = candidate


## 判断逻辑网格上的父子房间相对方向。
func _attachment_direction(child_origin: Vector2i, child_size: Vector2i, parent_origin: Vector2i, parent_size: Vector2i) -> Vector2:
    if child_origin.x >= parent_origin.x + parent_size.x:
        return Vector2.RIGHT
    if child_origin.x + child_size.x <= parent_origin.x:
        return Vector2.LEFT
    if child_origin.y >= parent_origin.y + parent_size.y:
        return Vector2.DOWN
    return Vector2.UP


## 沿父房间共享的门边摆放子房间，门槽相对位置保持一致。
func _attached_room_origin(parent_world: Vector2, parent_grid: Vector2i, parent_size: Vector2i, child_grid: Vector2i, child_size: Vector2i, direction: Vector2) -> Vector2:
    var unit := float(FortressRoomGenerator.ROOM_UNIT_SIZE)
    var gap := FortressRoomGenerator.ROOM_GAP
    if direction == Vector2.RIGHT:
        return Vector2(parent_world.x + float(parent_size.x) * unit + gap, parent_world.y + float(child_grid.y - parent_grid.y) * unit)
    if direction == Vector2.LEFT:
        return Vector2(parent_world.x - float(child_size.x) * unit - gap, parent_world.y + float(child_grid.y - parent_grid.y) * unit)
    if direction == Vector2.DOWN:
        return Vector2(parent_world.x + float(child_grid.x - parent_grid.x) * unit, parent_world.y + float(parent_size.y) * unit + gap)
    return Vector2(parent_world.x + float(child_grid.x - parent_grid.x) * unit, parent_world.y - float(child_size.y) * unit - gap)


## 检查新房间与已放置房间的外扩矩形，必要时沿父子方向继续错开。
func _overlaps_placed_room(candidate: Vector2, size: Vector2i, room_id: int, rooms: Array) -> bool:
    var candidate_rect := Rect2(candidate, Vector2(size) * FortressRoomGenerator.ROOM_UNIT_SIZE).grow(FortressRoomGenerator.ROOM_GAP * 0.5)
    for room: Dictionary in rooms:
        var existing_id := int(room.id)
        if existing_id == room_id or not _world_room_origins.has(existing_id):
            continue
        var existing_origin: Vector2 = _world_room_origins[existing_id]
        var existing_size: Vector2i = room.size
        var existing_rect := Rect2(existing_origin, Vector2(existing_size) * FortressRoomGenerator.ROOM_UNIT_SIZE).grow(FortressRoomGenerator.ROOM_GAP * 0.5)
        if candidate_rect.intersects(existing_rect):
            return true
    return false


## 只显示当前房间内部；宽高比扩展后自动调整缩放，避免相机看到房间外。
func _set_camera_room(room: FortressRoomTemplate, smooth_transition: bool) -> void:
    if not is_instance_valid(controlled_camera):
        return
    var room_bounds := _room_camera_bounds(room)
    if smooth_transition:
        controlled_camera.transition_to_room(_player, room_bounds, 0.45)
    else:
        controlled_camera.set_follow_bounds(room_bounds, true)
        controlled_camera.set_target(_player, true)


## 初始进入或重开关卡时只显示起始房间，其余房间保持完全透明。
func _set_room_visibility(visible_room_id: int) -> void:
    if _room_visibility_tween != null and _room_visibility_tween.is_running():
        _room_visibility_tween.kill()
    for room_id_value: Variant in _room_nodes.keys():
        var room := _room_nodes[int(room_id_value)] as FortressRoomTemplate
        if room == null:
            continue
        var room_modulate := room.modulate
        room_modulate.a = 1.0 if int(room_id_value) == visible_room_id else 0.0
        room.modulate = room_modulate


## 房间传送时淡出原房间并淡入目标房间，过渡期间仅这两间房可见。
func _transition_room_visibility(previous_room_id: int, next_room_id: int) -> void:
    if _room_visibility_tween != null and _room_visibility_tween.is_running():
        _room_visibility_tween.kill()
    var previous_room := _room_nodes.get(previous_room_id) as FortressRoomTemplate
    var next_room := _room_nodes.get(next_room_id) as FortressRoomTemplate
    if previous_room == null or next_room == null:
        _set_room_visibility(next_room_id)
        return

    # 清除其他房间可能残留的透明度，确保视野中只有当前房间和过渡两端。
    for room_id_value: Variant in _room_nodes.keys():
        var room := _room_nodes[int(room_id_value)] as FortressRoomTemplate
        if room == null or room == previous_room or room == next_room:
            continue
        var hidden_modulate := room.modulate
        hidden_modulate.a = 0.0
        room.modulate = hidden_modulate

    var previous_color := previous_room.modulate
    previous_color.a = 1.0
    previous_room.modulate = previous_color
    var next_color := next_room.modulate
    next_color.a = 0.0
    next_room.modulate = next_color

    _room_visibility_tween = create_tween().set_parallel(true)
    var faded_previous_color := previous_color
    faded_previous_color.a = 0.0
    var visible_next_color := next_color
    visible_next_color.a = 1.0
    _room_visibility_tween.tween_property(previous_room, "modulate", faded_previous_color, ROOM_FADE_DURATION)
    _room_visibility_tween.tween_property(next_room, "modulate", visible_next_color, ROOM_FADE_DURATION)


## 房间首次清场后通知 HUD 控制状态；实际换房仍必须由玩家触发门区。
func _on_room_cleared(room_id: int) -> void:
    if room_id == current_room_id:
        _emit_room_state(room_id)
    if room_id == int(level_map.get("boss_room_id", -1)) and boss_defeated:
        _open_boss_exit()


## 相机边界包含外墙厚度，玩家靠近边缘时可以看到墙体，同时不越过外墙外沿。
func _room_camera_bounds(room: FortressRoomTemplate) -> Rect2:
    # 在外墙外沿内留 1 单位余量，避免视口取整露出背景；出口位于房间内部。
    var wall_margin := FortressRoomTemplate.WALL_THICKNESS - 1.0
    var bounds_size := Vector2(room.room_size_units) * FortressRoomGenerator.ROOM_UNIT_SIZE + Vector2.ONE * wall_margin * 2.0
    bounds_size = bounds_size.max(Vector2.ONE)
    return Rect2(room.global_position - bounds_size * 0.5, bounds_size)


## Boss 和房间内所有守卫清除后才开启 Boss 房出口。
func _open_boss_exit() -> void:
    var boss_room := _room_nodes.get(int(level_map.get("boss_room_id", -1))) as FortressRoomTemplate
    if boss_room == null or not boss_room.is_room_safe() or not is_instance_valid(_boss_exit):
        return
    _boss_exit.set_deferred("monitoring", true)
    _boss_exit.modulate = Color(1.0, 1.0, 1.0, 1.0)


## 首次进入房间时实例化该房间的遭遇内容，并交由通用控制器接管敌人状态。
func _activate_room_contents(room_id: int) -> void:
    var room := _room_nodes.get(room_id) as FortressRoomTemplate
    if room == null:
        return
    room.activate_room()
    for enemy: Node in room.find_children("*", "Node", true, false):
        if enemy.is_in_group("enemies"):
            register_enemy(enemy as Node2D)


## 通知关卡外部的敌群、遭遇与 Boss 血条控制器当前进入的房间类型。
func _emit_room_state(room_id: int) -> void:
    var room_data := _get_room_data(room_id)
    sig_room_changed.emit(room_id, str(room_data.get("type", "combat")))

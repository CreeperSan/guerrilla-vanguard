## 按固定世界网格生成不重叠的矩形房间图，并从同一份数据导出门位和小地图路线。
class_name FortressRoomGenerator
extends RefCounted

const ROOM_UNIT_SIZE := 500
## 相邻房间的可视间隔；路线图仍以连续的 500 单位网格记录拓扑。
const ROOM_GAP := 72.0
const MAX_GENERATION_ATTEMPTS := 8
## 每一关独立抽取一次；命中后只尝试放置一间佣兵支路房。
const MERCENARY_ROOM_CHANCE := 0.2
const ROOM_SIZES: Array[Vector2i] = [
    Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3),
    Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3),
    Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3),
]

## 按关卡范围生成主路径、可选分支和普通房之间的闭环；seed 可用于复现同一布局。
static func generate_level(level_number: int, seed: int) -> Dictionary:
    var limits := _get_path_limits(level_number)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var mercenary_rng := RandomNumberGenerator.new()
    mercenary_rng.seed = seed ^ 0x4D455243
    var include_mercenary_room := mercenary_rng.randf() < MERCENARY_ROOM_CHANCE
    for attempt: int in range(MAX_GENERATION_ATTEMPTS):
        var attempt_seed := seed + attempt * 104729
        rng.seed = attempt_seed
        var path_steps := rng.randi_range(limits.x, limits.y)
        var main_room_count := path_steps + 1
        var rooms: Array[Dictionary] = []
        rooms.append(_make_room(0, Vector2i.ZERO, Vector2i(1, 1), "start"))
        var placed := true
        for path_index: int in range(1, main_room_count):
            var previous: Dictionary = rooms.back()
            var room_type := "boss" if path_index == main_room_count - 1 else "combat"
            var next_room := _place_adjacent_room(rooms, previous, path_index, room_type, rng)
            if next_room.is_empty():
                placed = false
                break
            rooms.append(next_room)
        if not placed:
            continue

        # 分支仅从普通房生长；房间相邻关系之后统一从真实矩形边界计算。
        var branch_count := rng.randi_range(1, maxi(2, int(path_steps / 2)))
        var placed_branch_count := 0
        for branch_index: int in range(branch_count):
            var parent_candidates: Array[int] = []
            for room_index: int in range(rooms.size()):
                if str(rooms[room_index].get("type", "")) != "boss":
                    parent_candidates.append(room_index)
            if parent_candidates.is_empty():
                break
            var parent_index: int = parent_candidates[rng.randi_range(0, parent_candidates.size() - 1)]
            var branch := _place_adjacent_room(rooms, rooms[parent_index], rooms.size(), "combat", rng)
            if not branch.is_empty():
                rooms.append(branch)
                placed_branch_count += 1
        if placed_branch_count == 0:
            continue

        # 商人只占用一个独立支路格，不允许形成绕过主路线的捷径或连接 Boss。
        if not _append_merchant_room(rooms, rng):
            continue
        # 每关额外生成一间单入口战斗补给房；失败时重试整张布局以保证房间唯一且存在。
        if not _append_battle_supply_room(rooms, rng):
            continue
        if include_mercenary_room:
            var room_rng := RandomNumberGenerator.new()
            room_rng.seed = (seed + attempt * 130363) ^ 0x4D455243
            if not _append_optional_service_room(rooms, room_rng, "mercenary"):
                continue
        var connections := _build_connections(rooms)
        if _shortest_path_length(rooms.size(), connections, 0, main_room_count - 1) < path_steps:
            continue
        if _room_degree(main_room_count - 1, connections) != 1:
            continue
        if not _all_rooms_reachable(rooms.size(), connections):
            continue
        return {
            "level": level_number,
            "seed": seed,
            "rooms": rooms,
            "connections": connections,
            "start_room_id": 0,
            "boss_room_id": main_room_count - 1,
            "main_path": _make_main_path(main_room_count),
        }

    # 生成失败时返回已验证的直线路径兜底；兜底仍遵守本关步数上下限且 Boss 位于末端。
    var fallback := _make_fallback_level(level_number, seed, limits.x + 1)
    if include_mercenary_room:
        var fallback_rooms: Array[Dictionary] = fallback["rooms"]
        var mercenary := _make_room(fallback_rooms.size(), Vector2i(0, 2), Vector2i.ONE, "mercenary")
        mercenary["parent_id"] = int(fallback["boss_room_id"]) + 1
        fallback_rooms.append(mercenary)
        fallback["connections"] = _build_connections(fallback_rooms)
    return fallback


## 返回该关起点至 Boss 的最小和最大移动次数。
static func _get_path_limits(level_number: int) -> Vector2i:
    if level_number <= 2:
        return Vector2i(2, 4)
    if level_number <= 4:
        return Vector2i(2, 5)
    return Vector2i(3, 6)


## 创建统一结构的房间记录，origin 和 size 均使用 500 单位网格。
static func _make_room(room_id: int, origin: Vector2i, size: Vector2i, room_type: String) -> Dictionary:
    return {"id": room_id, "origin": origin, "size": size, "type": room_type, "visited": room_id == 0, "parent_id": room_id - 1}


## 在父房间的一侧随机选择尺寸和对齐方式；相交或未真正贴边时放弃候选。
static func _place_adjacent_room(rooms: Array[Dictionary], parent: Dictionary, room_id: int, room_type: String, rng: RandomNumberGenerator) -> Dictionary:
    # 尺寸先独立抽取，再尝试四侧放置；失败交给整图重试，不把大房悄悄替换成小房。
    var size := Vector2i(2, 2) if room_type == "boss" else _pick_room_size(rng)
    var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
    _shuffle_vector2i_array(directions, rng)
    for direction: Vector2i in directions:
        var origin := _adjacent_origin(parent, size, direction, rng)
        var candidate := _make_room(room_id, origin, size, room_type)
        if _overlaps_any(candidate, rooms):
            continue
        if not _shares_edge(candidate, parent):
            continue
        candidate["parent_id"] = int(parent.id)
        return candidate
    return {}


## 按面积类别抽取房间尺寸：1×1 占 60%，其他面积 ≤4 合计 30%，面积 >4 合计 10%。
## 组内尺寸均匀；起点与商人保持固定 1×1，不参与战斗/分支房的随机尺寸抽取。
static func _pick_room_size(rng: RandomNumberGenerator) -> Vector2i:
    var roll := rng.randf()
    if roll < 0.6:
        return Vector2i.ONE
    var pool: Array[Vector2i] = []
    for size: Vector2i in ROOM_SIZES:
        var area := size.x * size.y
        if (roll < 0.9 and area > 1 and area <= 4) or (roll >= 0.9 and area > 4):
            pool.append(size)
    return pool[rng.randi_range(0, pool.size() - 1)]


## 使用当前布局的随机数生成器打乱 Vector2i 数组，保证同种子得到相同选择顺序。
static func _shuffle_vector2i_array(values: Array[Vector2i], rng: RandomNumberGenerator) -> void:
    for index: int in range(values.size() - 1, 0, -1):
        var swap_index := rng.randi_range(0, index)
        var previous_value: Vector2i = values[index]
        values[index] = values[swap_index]
        values[swap_index] = previous_value


## 生成与父房间共享至少一个完整网格单元边界的候选坐标。
static func _adjacent_origin(parent: Dictionary, size: Vector2i, direction: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
    var parent_origin: Vector2i = parent.origin
    var parent_size: Vector2i = parent.size
    if direction == Vector2i.UP:
        return Vector2i(_aligned_offset(parent_origin.x, parent_size.x, size.x, rng), parent_origin.y - size.y)
    if direction == Vector2i.DOWN:
        return Vector2i(_aligned_offset(parent_origin.x, parent_size.x, size.x, rng), parent_origin.y + parent_size.y)
    if direction == Vector2i.LEFT:
        return Vector2i(parent_origin.x - size.x, _aligned_offset(parent_origin.y, parent_size.y, size.y, rng))
    return Vector2i(parent_origin.x + parent_size.x, _aligned_offset(parent_origin.y, parent_size.y, size.y, rng))


## 让新房间沿接触轴随机错位，同时保证与父房间有正长度的边界重合。
static func _aligned_offset(parent_start: int, parent_length: int, child_length: int, rng: RandomNumberGenerator) -> int:
    return parent_start + rng.randi_range(-child_length + 1, parent_length - 1)


## 矩形占地相交时拒绝候选；边界贴合不算相交。
static func _overlaps_any(candidate: Dictionary, rooms: Array[Dictionary]) -> bool:
    var candidate_rect := Rect2i(candidate.origin, candidate.size)
    for room: Dictionary in rooms:
        if candidate_rect.intersects(Rect2i(room.origin, room.size)):
            return true
    return false


## 判断两个房间是否共享长度至少为一个网格单元的边。
static func _shares_edge(first: Dictionary, second: Dictionary) -> bool:
    var a: Rect2i = Rect2i(first.origin, first.size)
    var b: Rect2i = Rect2i(second.origin, second.size)
    var vertical_overlap := mini(a.end.y, b.end.y) - maxi(a.position.y, b.position.y)
    var horizontal_overlap := mini(a.end.x, b.end.x) - maxi(a.position.x, b.position.x)
    return (vertical_overlap > 0 and (a.end.x == b.position.x or b.end.x == a.position.x)) or (horizontal_overlap > 0 and (a.end.y == b.position.y or b.end.y == a.position.y))


## 扫描矩形房间对，生成对称的真实边界连接和双方对应门位。
static func _build_connections(rooms: Array[Dictionary]) -> Array[Dictionary]:
    var connections: Array[Dictionary] = []
    for first_index: int in range(rooms.size()):
        for second_index: int in range(first_index + 1, rooms.size()):
            var first: Dictionary = rooms[first_index]
            var second: Dictionary = rooms[second_index]
            var connection := _make_connection(first, second)
            if not connection.is_empty():
                connections.append(connection)
    return connections


## 将共享边界换算成两侧局部门槽；门位只在真实相邻时出现。
static func _make_connection(first: Dictionary, second: Dictionary) -> Dictionary:
    var a_origin: Vector2i = first.origin
    var a_size: Vector2i = first.size
    var b_origin: Vector2i = second.origin
    var b_size: Vector2i = second.size
    var a_rect := Rect2i(a_origin, a_size)
    var b_rect := Rect2i(b_origin, b_size)
    if a_rect.end.x == b_rect.position.x or b_rect.end.x == a_rect.position.x:
        var low := maxi(a_rect.position.y, b_rect.position.y)
        var high := mini(a_rect.end.y, b_rect.end.y)
        if high > low:
            var a_side := "east" if a_rect.end.x == b_rect.position.x else "west"
            var b_side := "west" if a_side == "east" else "east"
            return {"from": first.id, "to": second.id, "from_side": a_side, "to_side": b_side,
                "from_slots": _range_array(low - a_origin.y, high - a_origin.y),
                "to_slots": _range_array(low - b_origin.y, high - b_origin.y)}
    if a_rect.end.y == b_rect.position.y or b_rect.end.y == a_rect.position.y:
        var low := maxi(a_rect.position.x, b_rect.position.x)
        var high := mini(a_rect.end.x, b_rect.end.x)
        if high > low:
            var a_side := "south" if a_rect.end.y == b_rect.position.y else "north"
            var b_side := "north" if a_side == "south" else "south"
            return {"from": first.id, "to": second.id, "from_side": a_side, "to_side": b_side,
                "from_slots": _range_array(low - a_origin.x, high - a_origin.x),
                "to_slots": _range_array(low - b_origin.x, high - b_origin.x)}
    return {}


## 将左闭右开区间转换为门位索引数组。
static func _range_array(start: int, end: int) -> Array[int]:
    var slots: Array[int] = []
    for index: int in range(start, end):
        slots.append(index)
    return slots


## 计算起点到 Boss 的最短房间移动次数，用于确保闭环不会绕过设计路径长度。
static func _shortest_path_length(room_count: int, connections: Array[Dictionary], start_id: int, goal_id: int) -> int:
    var distances: Array[int] = []
    distances.resize(room_count)
    distances.fill(-1)
    distances[start_id] = 0
    var queue: Array[int] = [start_id]
    while not queue.is_empty():
        var current: int = queue.pop_front()
        if current == goal_id:
            return distances[current]
        for edge: Dictionary in connections:
            var next_id := -1
            if edge.from == current:
                next_id = edge.to
            elif edge.to == current:
                next_id = edge.from
            if next_id >= 0 and distances[next_id] < 0:
                distances[next_id] = distances[current] + 1
                queue.append(next_id)
    return -1


## 确认生成图中的每个房间均可从起点到达。
static func _all_rooms_reachable(room_count: int, connections: Array[Dictionary]) -> bool:
    for room_id: int in range(room_count):
        if _shortest_path_length(room_count, connections, 0, room_id) < 0:
            return false
    return true


## 返回指定房间的连接数量；Boss 房必须保持单入口终点属性。
static func _room_degree(room_id: int, connections: Array[Dictionary]) -> int:
    var degree := 0
    for edge: Dictionary in connections:
        if edge.from == room_id or edge.to == room_id:
            degree += 1
    return degree


## 生成可用于 UI 展示的有序主路径房间 ID。
static func _make_main_path(path_length: int) -> Array[int]:
    var path: Array[int] = []
    for room_id: int in range(path_length):
        path.append(room_id)
    return path


## 枚举所有非 Boss 房间的外边缘，随机选取一个仅连接父房的 1×1 商人分支。
## 无合法位置时交由上层重试布局；不缩小已有房间，也不改变原主路线 ID。
static func _append_merchant_room(rooms: Array[Dictionary], rng: RandomNumberGenerator) -> bool:
    var candidates: Array[Dictionary] = []
    for parent: Dictionary in rooms:
        if str(parent.type) == "boss":
            continue
        var origin: Vector2i = parent.origin
        var room_size: Vector2i = parent.size
        var edge_cells: Array[Vector2i] = []
        for x: int in range(room_size.x):
            edge_cells.append(origin + Vector2i(x, -1))
            edge_cells.append(origin + Vector2i(x, room_size.y))
        for y: int in range(room_size.y):
            edge_cells.append(origin + Vector2i(-1, y))
            edge_cells.append(origin + Vector2i(room_size.x, y))
        for cell: Vector2i in edge_cells:
            var candidate := _make_room(rooms.size(), cell, Vector2i.ONE, "merchant")
            if _overlaps_any(candidate, rooms):
                continue
            var neighbors := 0
            for existing: Dictionary in rooms:
                if _shares_edge(candidate, existing):
                    neighbors += 1
            if neighbors == 1:
                candidate["parent_id"] = int(parent.id)
                candidates.append(candidate)
    if candidates.is_empty():
        return false
    rooms.append(candidates[rng.randi_range(0, candidates.size() - 1)])
    return true


## 从普通战斗房边缘增加唯一补给支路；确保新房只与一间非 Boss 房相邻。
static func _append_battle_supply_room(rooms: Array[Dictionary], rng: RandomNumberGenerator) -> bool:
    return _append_optional_service_room(rooms, rng, "combat_supply")


## 将可选服务房放到非 Boss 房外侧的单入口支路，保证不会绕过关卡主路线。
static func _append_optional_service_room(rooms: Array[Dictionary], rng: RandomNumberGenerator, room_type: String) -> bool:
    var candidates: Array[Dictionary] = []
    for parent: Dictionary in rooms:
        if str(parent.type) != "combat":
            continue
        var origin: Vector2i = parent.origin
        var room_size: Vector2i = parent.size
        var edge_cells: Array[Vector2i] = []
        for x: int in range(room_size.x):
            edge_cells.append(origin + Vector2i(x, -1))
            edge_cells.append(origin + Vector2i(x, room_size.y))
        for y: int in range(room_size.y):
            edge_cells.append(origin + Vector2i(-1, y))
            edge_cells.append(origin + Vector2i(room_size.x, y))
        for cell: Vector2i in edge_cells:
            var candidate := _make_room(rooms.size(), cell, Vector2i.ONE, room_type)
            if _overlaps_any(candidate, rooms):
                continue
            var neighbors := 0
            for existing: Dictionary in rooms:
                if _shares_edge(candidate, existing):
                    neighbors += 1
            if neighbors == 1:
                candidate["parent_id"] = int(parent.id)
                candidates.append(candidate)
    if candidates.is_empty():
        return false
    rooms.append(candidates[rng.randi_range(0, candidates.size() - 1)])
    return true


## 生成布局重试耗尽时使用的直线房间兜底图。
static func _make_fallback_level(level_number: int, seed: int, path_length: int) -> Dictionary:
    var rooms: Array[Dictionary] = []
    for room_id: int in range(path_length):
        var room_type := "start" if room_id == 0 else ("boss" if room_id == path_length - 1 else "combat")
        rooms.append(_make_room(room_id, Vector2i(room_id, 0), Vector2i(2, 2) if room_type == "boss" else Vector2i.ONE, room_type))
    # 在起点和第一间普通房下方放置横跨两格的支路，形成不经过 Boss 的闭环。
    var branch := _make_room(path_length, Vector2i(0, 1), Vector2i(2, 1), "combat")
    branch["parent_id"] = 0
    rooms.append(branch)
    # 直线兜底的起点左侧始终空闲，只连接起点，确保每个 Level 都有商人。
    var merchant := _make_room(rooms.size(), Vector2i(-1, 0), Vector2i.ONE, "merchant")
    merchant["parent_id"] = 0
    rooms.append(merchant)
    # 固定兜底战斗补给房位于第一间普通房上方，保持唯一单入口且不触碰 Boss。
    var battle_supply := _make_room(rooms.size(), Vector2i(1, -1), Vector2i.ONE, "combat_supply")
    battle_supply["parent_id"] = 1
    rooms.append(battle_supply)
    return {"level": level_number, "seed": seed, "rooms": rooms, "connections": _build_connections(rooms),
        "start_room_id": 0, "boss_room_id": path_length - 1, "main_path": _make_main_path(path_length)}

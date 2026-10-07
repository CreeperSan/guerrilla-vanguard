## 按固定世界网格生成不重叠的矩形房间图，并从同一份数据导出门位和小地图路线。
class_name FortressRoomGenerator
extends RefCounted

const ROOM_UNIT_SIZE := 500
## 相邻房间的可视间隔；路线图仍以连续的 500 单位网格记录拓扑。
const ROOM_GAP := 72.0
const MAX_GENERATION_ATTEMPTS := 8
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
    return _make_fallback_level(level_number, seed, limits.x + 1)


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
    var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
    _shuffle_vector2i_array(directions, rng)
    for direction: Vector2i in directions:
        var candidate_sizes: Array[Vector2i] = ROOM_SIZES.duplicate()
        _shuffle_vector2i_array(candidate_sizes, rng)
        for size: Vector2i in candidate_sizes:
            var origin := _adjacent_origin(parent, size, direction, rng)
            var candidate := _make_room(room_id, origin, size, room_type)
            if _overlaps_any(candidate, rooms):
                continue
            if not _shares_edge(candidate, parent):
                continue
            candidate["parent_id"] = int(parent.id)
            return candidate
    return {}


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


## 生成布局重试耗尽时使用的直线房间兜底图。
static func _make_fallback_level(level_number: int, seed: int, path_length: int) -> Dictionary:
    var rooms: Array[Dictionary] = []
    for room_id: int in range(path_length):
        var room_type := "start" if room_id == 0 else ("boss" if room_id == path_length - 1 else "combat")
        rooms.append(_make_room(room_id, Vector2i(room_id, 0), Vector2i(1, 1), room_type))
    # 在起点和第一间普通房下方放置横跨两格的支路，形成不经过 Boss 的闭环。
    var branch := _make_room(path_length, Vector2i(0, 1), Vector2i(2, 1), "combat")
    branch["parent_id"] = 0
    rooms.append(branch)
    return {"level": level_number, "seed": seed, "rooms": rooms, "connections": _build_connections(rooms),
        "start_room_id": 0, "boss_room_id": path_length - 1, "main_path": _make_main_path(path_length)}

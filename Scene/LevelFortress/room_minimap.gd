## 绘制当前关卡生成器提供的房间占地、路线、访问状态和 Boss 位置。
class_name FortressRoomMinimap
extends Control

## 小地图直接绘制文字，不经过 Label 主题继承，因此显式使用统一的游戏像素字体。
const MAP_FONT: Font = preload("res://Font/fusion-pixel-12-zh-hans.ttf")

const COLOR_PANEL := Color(0.035, 0.055, 0.06, 0.86)
const COLOR_ROOM := Color(0.32, 0.39, 0.34, 0.95)
const COLOR_VISITED := Color(0.55, 0.68, 0.39, 1.0)
const COLOR_CURRENT := Color(0.94, 0.78, 0.34, 1.0)
const COLOR_BOSS := Color(0.75, 0.23, 0.22, 1.0)
## 商人支路使用青绿色，与战斗房和 Boss 房区分。
const COLOR_MERCHANT := Color(0.22, 0.65, 0.62, 1.0)
## 战斗补给房使用暖金色，便于从普通战斗房和商人房中辨认。
const COLOR_BATTLE_SUPPLY := Color(0.78, 0.52, 0.2, 1.0)
## 雇佣兵房使用友军绿色；访问后仍保留服务房标记，便于地图回找招募点。
const COLOR_MERCENARY := Color(0.34, 0.72, 0.46, 1.0)
const COLOR_ROUTE := Color(0.65, 0.73, 0.62, 0.8)

var _level_map: Dictionary = {}
var _current_room_id: int = -1
var _visited_room_ids: Array[int] = []


## 设置关卡拓扑与当前房间状态；地图拓扑不在 UI 内重新随机计算。
func set_map_data(level_map: Dictionary, current_room_id: int, visited_room_ids: Array[int]) -> void:
	_level_map = level_map
	_current_room_id = current_room_id
	_visited_room_ids = visited_room_ids.duplicate()
	queue_redraw()


## 绘制半透明地图底板、真实房间占地矩形和相邻门连接。
func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	var rooms: Array = _level_map.get("rooms", [])
	var connections: Array = _level_map.get("connections", [])
	if rooms.is_empty():
		draw_string(MAP_FONT, Vector2(12.0, 25.0), "房间路线等待生成")
		return
	var bounds := _get_map_bounds(rooms)
	var map_area := Rect2(Vector2(12.0, 30.0), size - Vector2(24.0, 42.0))
	var scale_factor := minf(map_area.size.x / maxf(float(bounds.size.x), 1.0), map_area.size.y / maxf(float(bounds.size.y), 1.0))
	var drawn_size := Vector2(bounds.size) * scale_factor
	var offset := map_area.position + (map_area.size - drawn_size) * 0.5 - Vector2(bounds.position) * scale_factor
	var room_rects: Dictionary = {}
	for room: Dictionary in rooms:
		var rect := _room_screen_rect(room, offset, scale_factor)
		room_rects[int(room.id)] = rect
	for connection: Dictionary in connections:
		var first_rect: Rect2 = room_rects.get(int(connection.from), Rect2())
		var second_rect: Rect2 = room_rects.get(int(connection.to), Rect2())
		draw_line(first_rect.get_center(), second_rect.get_center(), COLOR_ROUTE, 2.0, true)
	for room: Dictionary in rooms:
		var room_id := int(room.id)
		var rect: Rect2 = room_rects[room_id]
		var room_type := str(room.get("type", "combat"))
		var room_color := COLOR_ROOM
		match room_type:
			"boss": room_color = COLOR_BOSS
			"merchant": room_color = COLOR_MERCHANT
			"combat_supply": room_color = COLOR_BATTLE_SUPPLY
			"mercenary": room_color = COLOR_MERCENARY
		if _visited_room_ids.has(room_id) and room_type not in ["merchant", "combat_supply", "mercenary"]:
			room_color = COLOR_BOSS if room_type == "boss" else COLOR_VISITED
		draw_rect(rect, room_color, true)
		var border_color: Color = COLOR_CURRENT if room_id == _current_room_id else Color(0.82, 0.87, 0.78, 0.9)
		draw_rect(rect, border_color, false, 2.0)
		if rect.size.x >= 16.0 and rect.size.y >= 12.0:
			var room_marker := str(room_id + 1)
			match room_type:
				"boss": room_marker = "B"
				"merchant": room_marker = "商"
				"combat_supply": room_marker = "补"
				"mercenary": room_marker = "佣"
				"start": room_marker = "S"
			draw_string(MAP_FONT, rect.position + Vector2(3.0, minf(rect.size.y - 2.0, 12.0)), room_marker, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10)


## 获取包含所有房间占地的网格范围，用于缩放和居中地图。
func _get_map_bounds(rooms: Array) -> Rect2i:
	var first: Dictionary = rooms[0]
	var bounds := Rect2i(first.origin, first.size)
	for room: Dictionary in rooms.slice(1):
		bounds = bounds.merge(Rect2i(room.origin, room.size))
	return bounds


## 将网格坐标转换为小地图中的像素矩形。
func _room_screen_rect(room: Dictionary, offset: Vector2, scale_factor: float) -> Rect2:
	var origin: Vector2i = room.origin
	var room_size: Vector2i = room.size
	return Rect2(offset + Vector2(origin) * scale_factor, Vector2(room_size) * scale_factor)


## 创建统一的小地图背景样式，不依赖外部主题资源。
func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = Color(0.42, 0.51, 0.43, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

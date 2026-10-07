## 可复用测试房间：使用 TileMapLayer 铺地面，以独立物理对象管理墙、水、木箱和出口。
class_name TerrainRoom
extends Node2D

## 房间宽高以 16 像素地砖为单位；默认房间约为 768 × 512 像素。
@export var room_size_in_tiles: Vector2i = Vector2i(48, 32)
## 水池按房间中心坐标和像素尺寸配置。
@export var water_patches: Array[Rect2] = [
	Rect2(Vector2(-176.0, 72.0), Vector2(96.0, 48.0)),
	Rect2(Vector2(112.0, -112.0), Vector2(80.0, 48.0)),
]
## 木箱按房间中心坐标配置，场景可按需要增减位置。
@export var box_positions: Array[Vector2] = [
	Vector2(-128.0, -88.0),
	Vector2(128.0, 80.0),
	Vector2(-64.0, 144.0),
	Vector2(208.0, -32.0),
]
## 只有本组中所有敌人与 Boss 都被清除后，出口才会开放。
@export var required_enemy_group: StringName = &"enemies"

signal sig_entrance_entered(body: Node2D)

const TILE_SIZE := Vector2i(16, 16)
const GROUND_TEXTURE: Texture2D = preload("res://Scene/LevelFortress/Terrain/ground.png")
const WALL_TEXTURE: Texture2D = preload("res://Scene/LevelFortress/Terrain/wall.png")
const WATER_TEXTURE: Texture2D = preload("res://Scene/LevelFortress/Terrain/water.png")
const BOX_SCENE: PackedScene = preload("res://Prefab/Terrain/box_crate.tscn")
const ENTRANCE_SCENE: PackedScene = preload("res://Prefab/Terrain/room_entrance.tscn")

@onready var ground_layer: TileMapLayer = $Ground

var entrance: RoomEntrance
var _entrance_opened: bool = false


## 初始化地面 TileSet、封闭墙体、水域、木箱和出口。
func _ready() -> void:
	_build_ground_tile_map()
	_build_room_walls()
	_build_water_patches()
	_build_box_crates()
	_build_entrance()


## 房间敌人与 Boss 全部离场后自动开放出口。
func _process(_delta: float) -> void:
	if _entrance_opened or not is_instance_valid(entrance) or not _is_room_safe():
		return
	_entrance_opened = true
	entrance.set_open(true)


## 创建使用单张地面贴图的 TileSet，并覆盖整个房间内部。
func _build_ground_tile_map() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = GROUND_TEXTURE
	atlas_source.texture_region_size = TILE_SIZE
	atlas_source.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas_source, 0)
	ground_layer.tile_set = tile_set
	ground_layer.z_index = -10

	var start_x: int = -int(room_size_in_tiles.x / 2)
	var start_y: int = -int(room_size_in_tiles.y / 2)
	for cell_y: int in range(start_y, start_y + room_size_in_tiles.y):
		for cell_x: int in range(start_x, start_x + room_size_in_tiles.x):
			ground_layer.set_cell(Vector2i(cell_x, cell_y), 0, Vector2i.ZERO)


## 用四面 StaticBody2D 墙体封闭房间，并在东侧留出出口通道。
func _build_room_walls() -> void:
	var room_size := Vector2(
		room_size_in_tiles.x * TILE_SIZE.x,
		room_size_in_tiles.y * TILE_SIZE.y
	)
	var half_size := room_size * 0.5
	var wall_thickness := 16.0
	var opening_height := 48.0
	_add_wall_segment("NorthWall", Vector2(0.0, -half_size.y - wall_thickness * 0.5), Vector2(room_size.x + wall_thickness * 2.0, wall_thickness))
	_add_wall_segment("SouthWall", Vector2(0.0, half_size.y + wall_thickness * 0.5), Vector2(room_size.x + wall_thickness * 2.0, wall_thickness))
	_add_wall_segment("WestWall", Vector2(-half_size.x - wall_thickness * 0.5, 0.0), Vector2(wall_thickness, room_size.y))

	var side_segment_height := maxf((room_size.y - opening_height) * 0.5, 1.0)
	var side_center_y := opening_height * 0.5 + side_segment_height * 0.5
	var east_wall_x := half_size.x + wall_thickness * 0.5
	_add_wall_segment("EastWallNorth", Vector2(east_wall_x, -side_center_y), Vector2(wall_thickness, side_segment_height))
	_add_wall_segment("EastWallSouth", Vector2(east_wall_x, side_center_y), Vector2(wall_thickness, side_segment_height))


## 创建可重复平铺贴图与矩形碰撞体组成的墙段。
func _add_wall_segment(wall_name: String, center: Vector2, size: Vector2) -> void:
	_add_textured_block(wall_name, center, size, WALL_TEXTURE, Definition.PHYSICS_LAYER_TERRAIN)


## 创建指定物理层的重复贴图障碍，可供墙和水域复用。
func _add_textured_block(block_name: String, center: Vector2, size: Vector2, texture: Texture2D, physics_layer: int) -> void:
	var block := StaticBody2D.new()
	block.name = block_name
	block.position = center
	block.collision_layer = physics_layer
	block.collision_mask = 0
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	block.add_child(shape_node)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, size)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	block.add_child(sprite)
	add_child(block)


## 按导出列表生成阻挡玩家和敌人、但不阻挡子弹的水池。
func _build_water_patches() -> void:
	for index: int in range(water_patches.size()):
		var patch: Rect2 = water_patches[index]
		if patch.size.x <= 0.0 or patch.size.y <= 0.0:
			continue
		_add_textured_block(
			"WaterPatch%d" % index,
			patch.position,
			patch.size,
			WATER_TEXTURE,
			Definition.PHYSICS_LAYER_WATER
		)


## 按导出列表实例化可破坏木箱。
func _build_box_crates() -> void:
	for index: int in range(box_positions.size()):
		var crate := BOX_SCENE.instantiate() as TerrainBoxCrate
		if crate == null:
			push_error("木箱场景根节点未挂载 TerrainBoxCrate 脚本。")
			return
		crate.name = "BoxCrate%d" % index
		crate.position = box_positions[index]
		add_child(crate)


## 在东侧墙洞放置关闭状态出口，并转发玩家进入事件。
func _build_entrance() -> void:
	entrance = ENTRANCE_SCENE.instantiate() as RoomEntrance
	if entrance == null:
		push_error("出口场景根节点未挂载 RoomEntrance 脚本。")
		return
	entrance.position = Vector2(room_size_in_tiles.x * TILE_SIZE.x * 0.5 + 8.0, 0.0)
	entrance.sig_entered.connect(_on_entrance_entered)
	add_child(entrance)


## 检查指定敌人组；正在队列删除的敌人视为已被清除。
func _is_room_safe() -> bool:
	for enemy: Node in get_tree().get_nodes_in_group(required_enemy_group):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			return false
	return true


## 转发已开启出口的玩家进入信号，供后续房间切换接入。
func _on_entrance_entered(body: Node2D) -> void:
	sig_entrance_entered.emit(body)

## 友军抛物手雷：落点在投掷时固定，飞行结束或碰墙时只生成一次友军爆炸。
class_name MercenaryGrenade
extends Node2D

const FLIGHT_DURATION := 0.75
const ARC_HEIGHT := 32.0
var landing_position := Vector2.ZERO
var damage: int = 6
var blast_radius: float = 44.0
var _start_position := Vector2.ZERO
var _elapsed: float = 0.0
var _finished: bool = false
var _sprite: Sprite2D


## 复用游戏手雷形状；角色和兵种肖像由独立生成的美术图集提供。
func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://Assets/Art/MilitaryArcade/World/grenade_flight.png")
	_sprite.scale = Vector2(0.14, 0.14)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	z_index = 4


## 加入场景树后设置起点，世界落点不再随角色或敌人移动而变化。
func begin_throw(origin: Vector2) -> void:
	_start_position = origin
	global_position = origin


## 地面投影检测墙体，精灵单独抬高形成弧线；水面不阻断投掷。
func _physics_process(delta: float) -> void:
	if _finished:
		return
	_elapsed = minf(_elapsed + delta, FLIGHT_DURATION)
	var progress := _elapsed / FLIGHT_DURATION
	var next_position := _start_position.lerp(landing_position, progress)
	var ray := PhysicsRayQueryParameters2D.create(global_position, next_position, Definition.PHYSICS_LAYER_TERRAIN)
	var collision := get_world_2d().direct_space_state.intersect_ray(ray)
	if not collision.is_empty():
		global_position = collision["position"]
		_detonate()
		return
	global_position = next_position
	_sprite.position.y = -sin(progress * PI) * ARC_HEIGHT
	_sprite.rotation += delta * 8.0
	queue_redraw()
	if _elapsed >= FLIGHT_DURATION:
		_detonate()


## 小阴影标明真实地面位置，飞行精灵高度不影响爆炸结算。
func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(0.05, 0.05, 0.03, 0.35))


## 使用现有范围伤害、一次命中和阵营过滤，避免误伤玩家及其他友军。
func _detonate() -> void:
	if _finished:
		return
	_finished = true
	var explosion := PrefabManager.create_explosion(Definition.Faction.Friend, damage)
	if explosion != null:
		explosion.blast_radius = blast_radius
		var audio := explosion.get_node_or_null("ExplosionAudio") as AudioStreamPlayer2D
		if audio != null:
			audio.stream = preload("res://Assets/Audio/SFX/Mercenary/grenadier_explosion.wav")
		get_parent().add_child(explosion)
		explosion.global_position = global_position
	queue_free()

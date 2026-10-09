## 坦克炮弹：复用现有命中与超时回收流程，过载炮弹同时生成爆炸和持续燃烧。
## 范围效果在物理查询结束后创建，且使用敌方阵营，不伤害坦克或其他敌军。
class_name TankShell
extends ProjectileBullet

@export var blast_radius: float = 42.0
@export var leaves_fire: bool = false
@export var fire_damage: int = 1
@export var fire_duration: float = 4.0
@export var fire_damage_gap: float = 0.5


## 主炮沿飞行方向展示独立弹丸外观；命中逻辑仍由公共弹丸处理。
func _ready() -> void:
	super._ready()
	node_sprite.texture = preload("res://Assets/Art/MilitaryArcade/Tank/shell.tres")
	node_sprite.scale = Vector2(0.06, 0.06)
	node_sprite.rotation = bullet_direction.angle()


## 公共弹丸会在命中或射程耗尽时调用此入口，完成标记阻止重复引爆。
func _spawn_explosion(effect_position: Vector2) -> void:
	_create_impact_effects.call_deferred(effect_position)


## 创建范围伤害与可选燃烧；节点加入父场景前完成位置、阵营和碰撞半径配置。
func _create_impact_effects(effect_position: Vector2) -> void:
	var parent := get_parent() as Node2D
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var explosion := PrefabManager.create_explosion(bullet_from, bullet_damage)
	if explosion != null:
		var shape_node := explosion.get_node("CollisionShape2D") as CollisionShape2D
		var shape := shape_node.shape.duplicate() as CircleShape2D
		if shape != null:
			shape.radius = maxf(blast_radius, 1.0)
			shape_node.shape = shape
		# 爆炸图与碰撞范围同步缩放，避免伤害圈大于可见爆炸。
		(explosion.get_node("AnimatedSprite2D") as AnimatedSprite2D).scale = Vector2.ONE * maxf(blast_radius, 1.0) / 32.0
		explosion.position = parent.to_local(effect_position)
		parent.add_child(explosion)
	if leaves_fire:
		var burning := PrefabManager.create_burning(bullet_from, fire_damage, fire_duration, fire_damage_gap)
		if burning != null:
			burning.position = parent.to_local(effect_position)
			parent.add_child(burning)

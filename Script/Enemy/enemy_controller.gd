extends CharacterBody2D

@onready var node_hitbox: Area2D = $HitBox
@onready var health_component := $Health as HealthComponent

@export var health: int = 8


func _ready() -> void:
	# 碰撞
	node_hitbox.area_entered.connect(_on_area_enter)
	# 生命值
	health_component.health = health
	health_component.health_max = health
	health_component.sig_die.connect(_on_die)
	health_component.sig_health_change.connect(_on_health_change)
	



func _physics_process(delta: float) -> void:
	move_and_slide()


func _on_area_enter(area: Area2D) -> void:
	if area is Bullet:
		if area.bullet_from == Bullet.From.PLAYER or area.bullet_from == Bullet.From.FRIEND:
			health_component.damage(area.bullet_damage) # 受到伤害
			#area.queue_free() # 移除子弹


func _on_die() -> void:
	queue_free()


func _on_health_change(health: int) -> void:
	pass

extends CharacterBody2D

# 移动速度
@export var prop_move_speed: float = 150

# 动画节点
@onready var anim : AnimatedSprite2D = $AnimatedSprite2D

# 预制体 - 玩家子弹
const PREFAB_BULLET: PackedScene = preload("res://Prefab/Item/bullet_player.tscn")


var facing_direction : Vector2


func _ready() -> void:
	facing_direction = Vector2.DOWN


func _physics_process(delta: float) -> void:
	var move_input = Input.get_vector('move_left', 'move_right', 'move_up', 'move_down')
	
	# 玩家朝向
	if move_input:
		facing_direction = move_input
		
	# 玩家移动
	velocity = move_input * prop_move_speed
	move_and_slide()
	
	# 处理移动动画
	var anim_name_state: String = 'move' if velocity.length() > 0 else 'idle'
	var anim_name_direction: String = 'down'
	var facing_direction_degree = rad_to_deg(facing_direction.normalized().angle())
	if facing_direction_degree < 0: # 返回的是 -180 ~ 180，所以这里转换成 0 ~ 360
		facing_direction_degree += 360
	if facing_direction_degree >= 337.5 or facing_direction_degree < 22.5:
		anim_name_direction = 'right'
	elif facing_direction_degree >= 22.5 and facing_direction_degree < 67.5:
		anim_name_direction = 'down_right'
	elif facing_direction_degree >= 67.5 and facing_direction_degree < 112.5:
		anim_name_direction = 'down'
	elif facing_direction_degree >= 112.5 and facing_direction_degree < 157.5:
		anim_name_direction = 'down_left'
	elif facing_direction_degree >= 157.5 and facing_direction_degree < 202.5:
		anim_name_direction = 'left'
	elif facing_direction_degree >= 202.5 and facing_direction_degree < 247.5:
		anim_name_direction = 'up_left'
	elif facing_direction_degree >= 247.5 and facing_direction_degree < 292.5:
		anim_name_direction = 'up'
	elif facing_direction_degree >= 292.5 and facing_direction_degree < 337.5:
		anim_name_direction = 'up_right'
	anim.play(anim_name_state + '_' + anim_name_direction)
		

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("fire"):
		var new_bullet: Bullet = PREFAB_BULLET.instantiate()
		new_bullet.global_position = anim.global_position
		new_bullet.direction = facing_direction
		new_bullet.damage = 10
		new_bullet.from = Bullet.From.PLAYER
		get_parent().add_child(new_bullet)

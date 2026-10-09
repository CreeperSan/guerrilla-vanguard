## 重型坦克三阶段 Boss：主炮、过载并行机枪、驾驶员换位手枪各自管理弹匣计时。
## 中间阶段只重置生命与战斗状态，最终死亡才触发公共奖励/出口契约。
class_name BossTank
extends BattlefieldBoss

enum Phase { TANK = 1, OVERLOAD = 2, DRIVER = 3 }
const OVERLOAD_SFX: AudioStream = preload("res://Assets/Audio/SFX/Tank/overload.wav")
const EJECT_SFX: AudioStream = preload("res://Assets/Audio/SFX/Tank/eject.wav")
const SHELL_SCENE: PackedScene = preload("res://Prefab/BossTank/tank_shell.tscn")

@export_group("阶段生命")
@export var tank_health: int = 120
@export var overload_health: int = 120
@export var driver_health: int = 30
@export_group("坦克移动")
## 两个坦克阶段只沿轴向前进；撞墙立即停下，不沿墙斜向滑动。
@export var tank_move_speed: float = 32.0
@export var overload_move_speed: float = 46.0
@export var tank_move_duration: float = 3.0
@export var tank_rest_duration: float = 5.0
@export var overload_rest_duration: float = 3.0
@export var tank_stop_distance: float = 65.0
@export_group("主炮 / 两阶段共用")
@export var cannon_magazine: int = 1
@export var cannon_reload_duration: float = 3.0
@export var cannon_damage: int = 8
@export var cannon_speed: float = 220.0
@export var cannon_range: float = 850.0
## 与当前炮管末端及视觉枪焰保持一致，调整炮塔尺寸时可同步修改。
@export var cannon_muzzle_distance: float = 54.0
@export var cannon_blast_radius: float = 42.0
## 开战与阶段切换时先给玩家短暂反应时间，之后每发按三秒装填节奏。
@export var opening_fire_delay: float = 0.6
@export_group("过载燃烧")
@export var fire_damage: int = 1
@export var fire_duration: float = 4.0
@export var fire_damage_gap: float = 0.5
@export_group("过载机枪")
@export var machine_magazine: int = 5
@export var machine_reload_duration: float = 5.0
@export var machine_fire_interval: float = 0.3
@export var machine_damage: int = 2
@export var machine_bullet_speed: float = 330.0
@export_group("驾驶员")
@export var driver_move_speed: float = 60.0
@export var driver_min_distance: float = 20.0
@export var driver_attack_distance: float = 110.0
@export var driver_reposition_radius: Vector2 = Vector2(65.0, 120.0)
@export var driver_magazine: int = 3
@export var driver_reload_duration: float = 3.0
@export var driver_fire_interval: float = 0.5
@export var driver_damage: int = 3
@export var driver_bullet_speed: float = 280.0

@onready var visuals: TankBossVisuals = $Visuals
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _hurt_shape: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var _cannon_audio: AudioStreamPlayer2D = $CannonAudio
@onready var _machine_audio: AudioStreamPlayer2D = $MachineAudio
@onready var _pistol_audio: AudioStreamPlayer2D = $PistolAudio
@onready var _reload_audio: AudioStreamPlayer2D = $ReloadAudio
@onready var _transition_audio: AudioStreamPlayer2D = $TransitionAudio
@onready var _track_audio: AudioStreamPlayer2D = $TrackAudio

## 三个弹匣状态互不共享，第二阶段主炮换弹不会阻止机枪射击。
var _cannon: Dictionary = {}
var _machine: Dictionary = {}
var _pistol: Dictionary = {}
var _move_remaining: float = 0.0
var _rest_remaining: float = 0.0
var _is_defeated: bool = false
var _relocating: bool = false
var _has_relocation_target: bool = false
var _relocation_target: Vector2
var _replan_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()


## 初始化碰撞、生命、独立弹匣与房间种子；未进入房间的 Boss 不实例化。
func _ready() -> void:
	add_to_group("enemies")
	collision_mask |= Definition.PHYSICS_LAYER_TERRAIN | Definition.PHYSICS_LAYER_WATER
	_rng.seed = int(get_parent().get("population_seed")) if get_parent() is FortressRoomTemplate else 7142026
	# 循环资源使用实例副本，不改写共享 WAV；22.05 kHz PCM 的循环端点按实际采样率计算。
	var tracks := _track_audio.stream.duplicate() as AudioStreamWAV
	if tracks != null:
		tracks.loop_mode = AudioStreamWAV.LOOP_FORWARD
		tracks.loop_begin = 0
		tracks.loop_end = roundi(tracks.get_length() * tracks.mix_rate)
		_track_audio.stream = tracks
	health_component.sig_die.connect(_on_phase_depleted)
	_apply_phase_settings()


## 只有有效玩家存在时推进战斗；休息只暂停移动，不暂停各武器装填和瞄准。
func _physics_process(delta: float) -> void:
	if _is_defeated:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		_sync_track_audio(false)
		return
	var direction := global_position.direction_to(player.global_position)
	var previous := global_position
	if current_phase == Phase.DRIVER:
		_update_driver_movement(delta, player)
		_update_weapon(_pistol, delta, driver_magazine, driver_reload_duration, driver_fire_interval, "pistol", player)
	else:
		_update_tank_movement(delta, player)
		_update_weapon(_cannon, delta, cannon_magazine, cannon_reload_duration, 0.0, "cannon", player)
		if current_phase == Phase.OVERLOAD:
			_update_weapon(_machine, delta, machine_magazine, machine_reload_duration, machine_fire_interval, "machine", player)
	var moving := global_position.distance_squared_to(previous) > 0.0001
	visuals.update_pose(current_phase, direction, velocity, moving, delta)
	_sync_track_audio(moving and current_phase != Phase.DRIVER)


## 每个阶段独立生命，清除前一阶段所有弹匣和移动计时，不重复发最终死亡信号。
func _on_phase_depleted() -> void:
	if _is_defeated:
		return
	if current_phase < Phase.DRIVER:
		current_phase += 1
		_apply_phase_settings()
		_transition_audio.stream = OVERLOAD_SFX if current_phase == Phase.OVERLOAD else EJECT_SFX
		_transition_audio.play()
		visuals.play_transition(current_phase)
		return
	_is_defeated = true
	velocity = Vector2.ZERO
	_sync_track_audio(false)
	sig_defeated.emit()
	queue_free()


## 更新生命、形态碰撞与三个独立弹匣，切驾驶员时立即收缩形状并开始移动接敌。
func _apply_phase_settings() -> void:
	var phases: Array[int] = [tank_health, overload_health, driver_health]
	health_component.health_max = maxi(phases[current_phase - 1], 1)
	health_component.health = health_component.health_max
	_cannon = _new_weapon_state(cannon_magazine)
	_machine = _new_weapon_state(machine_magazine)
	_pistol = _new_weapon_state(driver_magazine)
	_move_remaining = maxf(tank_move_duration, 0.01)
	_rest_remaining = 0.0
	_relocating = false
	_has_relocation_target = false
	_replan_remaining = 0.0
	velocity = Vector2.ZERO
	var body := CircleShape2D.new()
	body.radius = 8.0 if current_phase == Phase.DRIVER else 26.0
	var hurt := CircleShape2D.new()
	hurt.radius = 11.0 if current_phase == Phase.DRIVER else 31.0
	_body_shape.set_deferred("shape", body)
	_hurt_shape.set_deferred("shape", hurt)
	visuals.update_pose(current_phase, Vector2.RIGHT, Vector2.ZERO, false, 0.0)
	sig_phase_changed.emit(current_phase, health_component.health, health_component.health_max)


## 每轮弹匣从完整容量开始；统一首发延迟不会改变指定的轮内射速。
func _new_weapon_state(capacity: int) -> Dictionary:
	return {"ammo": maxi(capacity, 1), "reload": 0.0, "cooldown": maxf(opening_fire_delay, 0.0)}


## 坦克移动固定三秒后休息；每帧选一个主轴，不采用碰撞滑动或对角向量。
func _update_tank_movement(delta: float, player: Node2D) -> void:
	velocity = Vector2.ZERO
	if _rest_remaining > 0.0:
		_rest_remaining = maxf(_rest_remaining - delta, 0.0)
		return
	var step_time := minf(delta, _move_remaining)
	_move_remaining = maxf(_move_remaining - delta, 0.0)
	var difference := player.global_position - global_position
	var direction := _cardinal_direction(difference)
	var speed := tank_move_speed if current_phase == Phase.TANK else overload_move_speed
	var travel := minf(maxf(speed, 0.0) * step_time, maxf(difference.length() - tank_stop_distance, 0.0))
	if travel > 0.0:
		velocity = direction * maxf(speed, 0.0)
		move_and_collide(direction * travel)
	if _move_remaining <= 0.0:
		_rest_remaining = maxf(tank_rest_duration if current_phase == Phase.TANK else overload_rest_duration, 0.0)
		_move_remaining = maxf(tank_move_duration, 0.01)


## 将追击方向限制为上下左右之一；重合时不移动。
func _cardinal_direction(difference: Vector2) -> Vector2:
	if difference == Vector2.ZERO:
		return Vector2.ZERO
	return Vector2(signf(difference.x), 0.0) if absf(difference.x) >= absf(difference.y) else Vector2(0.0, signf(difference.y))


## 驾驶员先接近、保持安全距离；换位期间允许装填，但抵达前不开始下一轮射击。
func _update_driver_movement(delta: float, player: Node2D) -> void:
	velocity = Vector2.ZERO
	_replan_remaining = maxf(_replan_remaining - delta, 0.0)
	var difference := player.global_position - global_position
	var distance := difference.length()
	var motion := Vector2.ZERO
	if distance < driver_min_distance:
		var retreat := -difference.normalized() if distance > 0.001 else Vector2.RIGHT
		motion = retreat * minf(driver_move_speed * delta, driver_min_distance - distance)
	elif _relocating:
		if not _has_relocation_target:
			if _replan_remaining <= 0.0:
				_choose_relocation(player)
			return
		var to_point := _relocation_target - global_position
		if to_point.length() <= 4.0:
			_relocating = false
		else:
			motion = to_point.limit_length(maxf(driver_move_speed, 0.0) * delta)
	elif distance > driver_attack_distance:
		motion = difference.normalized() * minf(driver_move_speed * delta, distance - maxf(driver_attack_distance, driver_min_distance))
	# 限制主动靠近玩家的位移，确保驾驶员自身移动不会跨过最小间距。
	if motion != Vector2.ZERO:
		var next_difference := player.global_position - (global_position + motion)
		if next_difference.length() < driver_min_distance and distance >= driver_min_distance:
			motion = difference.normalized() * maxf(distance - driver_min_distance, 0.0)
		velocity = motion / maxf(delta, 0.0001)
		var collision := move_and_collide(motion)
		if collision != null and _relocating and _replan_remaining <= 0.0:
			_choose_relocation(player)
	# 目标被移动中的玩家占据时重新选位，避免站在旧目标附近反复进退。
	if _relocating and (_relocation_target.distance_to(player.global_position) < driver_min_distance or motion == Vector2.ZERO) and _replan_remaining <= 0.0:
		_choose_relocation(player)


## 在玩家周围抽取可达位置；整段圆形扫掠避开墙、水和掩体，禁止直接穿墙换位。
func _choose_relocation(player: Node2D) -> void:
	_relocating = true
	_has_relocation_target = false
	_replan_remaining = 0.4
	var space := get_world_2d().direct_space_state
	for attempt: int in range(24):
		var radius := _rng.randf_range(maxf(driver_reposition_radius.x, driver_min_distance + 12.0), maxf(driver_reposition_radius.y, driver_reposition_radius.x + 1.0))
		var candidate := player.global_position + Vector2.from_angle(_rng.randf_range(-PI, PI)) * radius
		if global_position.distance_to(candidate) < 24.0:
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 9.0
		query.shape = shape
		query.transform = Transform2D(0.0, global_position)
		query.motion = candidate - global_position
		query.collision_mask = Definition.PHYSICS_LAYER_TERRAIN | Definition.PHYSICS_LAYER_WATER
		query.exclude = [get_rid()]
		var fractions := space.cast_motion(query)
		query.transform.origin = candidate
		query.motion = Vector2.ZERO
		if fractions[0] >= 1.0 and space.intersect_shape(query, 1).is_empty():
			_has_relocation_target = true
			_relocation_target = candidate
			return
	# 暂时无可达点时保留当前位置并延迟重试；不取消换位状态提前开下一轮。
	_relocation_target = global_position


## 独立推进装填与轮内间隔；最后一发后立刻开始换弹，驾驶员同时开始随机换位。
func _update_weapon(state: Dictionary, delta: float, capacity: int, reload_time: float, interval: float, kind: String, player: Node2D) -> void:
	if float(state["reload"]) > 0.0:
		state["reload"] = maxf(float(state["reload"]) - delta, 0.0)
		if float(state["reload"]) <= 0.000001:
			state["reload"] = 0.0
			state["ammo"] = maxi(capacity, 1)
		return
	state["cooldown"] = maxf(float(state["cooldown"]) - delta, 0.0)
	if float(state["cooldown"]) > 0.0:
		return
	if kind == "pistol" and (_relocating or global_position.distance_to(player.global_position) > maxf(driver_attack_distance, driver_min_distance) + 2.0 or global_position.distance_to(player.global_position) < driver_min_distance):
		return
	if not _fire_weapon(kind, global_position.direction_to(player.global_position)):
		return
	state["ammo"] = int(state["ammo"]) - 1
	state["cooldown"] = maxf(interval, 0.0)
	if int(state["ammo"]) <= 0:
		state["reload"] = maxf(reload_time, 0.01)
		state["cooldown"] = 0.0
		if kind == "cannon":
			_reload_audio.play()
		elif kind == "pistol":
			_choose_relocation(player)


## 在场景树加入前配置弹丸，主炮是独立爆炸弹，机枪与手枪保持普通敌弹。
func _fire_weapon(kind: String, direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false
	var bullet: ProjectileBullet
	if kind == "cannon":
		var shell := SHELL_SCENE.instantiate() as TankShell
		if shell == null:
			push_error("坦克炮弹场景必须挂载 TankShell。")
			return false
		shell.bullet_type = Definition.BulletType.Explosion
		shell.bullet_damage = cannon_damage
		shell.bullet_speed = cannon_speed
		shell.blast_radius = cannon_blast_radius
		shell.leaves_fire = current_phase == Phase.OVERLOAD
		shell.fire_damage = fire_damage
		shell.fire_duration = fire_duration
		shell.fire_damage_gap = fire_damage_gap
		bullet = shell
	else:
		bullet = PrefabManager.create_bullet(Definition.Faction.Enemy, machine_damage if kind == "machine" else driver_damage, direction)
		if bullet == null:
			return false
		bullet.bullet_speed = machine_bullet_speed if kind == "machine" else driver_bullet_speed
	bullet.bullet_from = Definition.Faction.Enemy
	bullet.bullet_direction = direction
	bullet.bullet_range = cannon_range
	bullet.bullet_duration = cannon_range / maxf(bullet.bullet_speed, 1.0) + 0.2
	bullet.position = get_parent().to_local(global_position + direction * (cannon_muzzle_distance if kind == "cannon" else (32.0 if kind == "machine" else 12.0)))
	get_parent().add_child(bullet)
	var audio := _cannon_audio if kind == "cannon" else (_machine_audio if kind == "machine" else _pistol_audio)
	audio.play()
	visuals.play_shot(kind)
	return true


## 履带循环只在坦克真正移动时播放，休息、被墙阻挡、驾驶员和无目标时静音。
func _sync_track_audio(moving: bool) -> void:
	if moving and not _track_audio.playing:
		_track_audio.play()
	elif not moving and _track_audio.playing:
		_track_audio.stop()

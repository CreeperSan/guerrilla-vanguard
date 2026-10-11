## 掷弹手：保持中远距离，以较低频率向敌人当前位置投掷范围伤害手雷。
class_name GrenadierMercenary
extends HiredMercenary

const THROW_INTERVAL := 2.8
const THROW_MIN_RANGE := 100.0
const THROW_MAX_RANGE := 240.0
const GRENADE_DAMAGE := 6
const GRENADE_RADIUS := 44.0
const GRENADE_SCRIPT = preload("res://Prefab/Mercenary/mercenary_grenade.gd")
var _throw_remaining: float = 0.8
@onready var _throw_audio: AudioStreamPlayer2D = $AttackAudio


## 公共宿主负责生命和契约，独立图集负责掷弹手外形与投掷姿势。
func _ready() -> void:
	super._ready()
	_configure_variant_visuals(preload("res://Assets/Art/MilitaryArcade/Mercenary/grenadier_atlas.png"))


## 显示兵种名称，供房间招募提示使用。
func get_display_name() -> String:
	return "掷弹手"


## 肖像来自生成图集的正面角色裁切，与战斗外形保持一致。
func get_portrait() -> Texture2D:
	return preload("res://Assets/Art/MilitaryArcade/Mercenary/grenadier_portrait.png")


## 慢速移动；脱队时仍允许公共追赶速度，避免重选点造成快速闪躲。
func _get_follow_speed(player: Node2D, player_distance: float) -> float:
	var speed := super._get_follow_speed(player, player_distance)
	return speed if _catching_up else 105.0


## 近距离只缓慢后撤，进入投掷距离后停留；脱队时优先返回玩家附近。
func _get_safe_follow_direction(player: Node2D, target: Node2D, follow_target: Vector2) -> Vector2:
	if not is_instance_valid(target) or global_position.distance_to(player.global_position) > 320.0:
		return super._get_safe_follow_direction(player, null, follow_target)
	var distance := global_position.distance_to(target.global_position)
	_retreating = distance < THROW_MIN_RANGE + (20.0 if _retreating else 0.0)
	if _retreating:
		return target.global_position.direction_to(global_position) * 0.45
	if distance > THROW_MAX_RANGE - 20.0:
		return global_position.direction_to(target.global_position) * 0.65
	return Vector2.ZERO


## 冷却就绪且目标仍处于投掷区间时锁定落点，不追踪飞行中的目标。
func _update_attack(delta: float, target: Node2D) -> void:
	_throw_remaining = maxf(_throw_remaining - delta, 0.0)
	if _throw_remaining > 0.0 or not is_instance_valid(target):
		return
	var distance := global_position.distance_to(target.global_position)
	if distance < THROW_MIN_RANGE or distance > THROW_MAX_RANGE:
		return
	var grenade := GRENADE_SCRIPT.new() as MercenaryGrenade
	grenade.landing_position = target.global_position
	grenade.damage = GRENADE_DAMAGE
	grenade.blast_radius = GRENADE_RADIUS
	get_parent().add_child(grenade)
	grenade.begin_throw(global_position)
	_throw_remaining = THROW_INTERVAL
	_attack_pose_remaining = 0.25
	_throw_audio.play()

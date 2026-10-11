## 无畏战士：重甲慢速近战，追击距离受玩家牵引限制，普通士兵受轻微击退。
class_name FearlessMercenary
extends HiredMercenary

const MELEE_RANGE := 32.0
const MELEE_DAMAGE := 4
const MELEE_INTERVAL := 0.9
const COMBAT_LEASH := 320.0
var _melee_remaining: float = 0.0
var _armor_audio_remaining: float = 0.0
@onready var _attack_audio: AudioStreamPlayer2D = $AttackAudio
@onready var _armor_audio: AudioStreamPlayer2D = $ArmorAudio


## 重甲生命由场景配置；独立图集替换普通士兵，受击时播放金属护甲声。
func _ready() -> void:
	super._ready()
	_configure_variant_visuals(preload("res://Assets/Art/MilitaryArcade/Mercenary/fearless_v2_atlas.png"))
	health_component.sig_health_change.connect(_on_armor_health_change)


## 无畏战士名称用于招募点及合约反馈。
func get_display_name() -> String:
	return "无畏战士"


## 使用生成图集对应的重甲角色正面肖像。
func get_portrait() -> Texture2D:
	return preload("res://Assets/Art/MilitaryArcade/Mercenary/fearless_v2_portrait.png")


## 无畏战士平时与作战均缓慢移动，仅远离玩家时有限加速归队。
func _get_follow_speed(player: Node2D, player_distance: float) -> float:
	var speed := super._get_follow_speed(player, player_distance)
	return minf(speed, 160.0) if _catching_up else 85.0


## 玩家附近有敌人时以敌人位置作为抵达点；距离玩家过远立即返回跟随点。
func _get_movement_target(player: Node2D, target: Node2D, follow_target: Vector2) -> Vector2:
	if is_instance_valid(target) and global_position.distance_to(player.global_position) <= COMBAT_LEASH:
		return target.global_position
	return follow_target


## 不后撤和闪躲；在近战距离内停下攻击，距离过远则走向目标。
func _get_safe_follow_direction(player: Node2D, target: Node2D, follow_target: Vector2) -> Vector2:
	_retreating = false
	if is_instance_valid(target) and global_position.distance_to(player.global_position) <= COMBAT_LEASH:
		var distance := global_position.distance_to(target.global_position)
		return global_position.direction_to(target.global_position) if distance > MELEE_RANGE - 6.0 else Vector2.ZERO
	return super._get_safe_follow_direction(player, null, follow_target)


## 单次近身攻击只伤害一个存活敌人；Boss 受伤但不调用普通士兵的击退接口。
func _update_attack(delta: float, target: Node2D) -> void:
	_melee_remaining = maxf(_melee_remaining - delta, 0.0)
	_armor_audio_remaining = maxf(_armor_audio_remaining - delta, 0.0)
	if _melee_remaining > 0.0 or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies") or global_position.distance_to(target.global_position) > MELEE_RANGE:
		return
	var target_health := target.get_node_or_null("Health") as HealthComponent
	if target_health == null or target_health.health <= 0:
		return
	var damage_taken := target_health.damage(MELEE_DAMAGE, Definition.Faction.Friend, global_position)
	if damage_taken <= 0:
		return
	_melee_remaining = MELEE_INTERVAL
	_attack_pose_remaining = 0.22
	_attack_audio.play()
	if target is EnemySoilder and not target is HiredMercenary and target_health.health > 0:
		var direction := global_position.direction_to(target.global_position)
		target.apply_melee_knockback(direction if not direction.is_zero_approx() else Vector2.DOWN)


## 实际扣血触发金属受击声，治疗不播放；短节流避免被连弹击中时声音过密。
func _on_armor_health_change(change: int) -> void:
	if change < 0 and _armor_audio_remaining <= 0.0:
		_armor_audio.play()
		_armor_audio_remaining = 0.15

## 来袭炮弹：播放下落音效和视觉轨迹，落地后生成爆炸或燃烧效果并自动销毁。
class_name IncomingShell
extends Node2D

const SFX_SHELL_FALL: AudioStream = preload("res://Assets/Audio/SFX/shell_fall.wav")

## 炮弹下落和命中效果属性，可由迫击炮/战术轰炸场景覆盖。
@export_group("下落表现")
@export_range(0.0, 1000.0, 1.0) var fall_height: float = 48.0
@export_range(0.01, 10.0, 0.01) var fall_duration: float = 0.32
@export_range(0.01, 1.0, 0.01) var sprite_fade_in_ratio: float = 0.3
@export var landing_shadow_start_scale: Vector2 = Vector2(1.8, 0.9)
@export var landing_shadow_end_scale: Vector2 = Vector2(0.08, 0.08)
@export_range(0.0, 1.0, 0.01) var landing_shadow_opacity: float = 0.6
@export_group("命中效果")
@export_range(0, 1000, 1) var explosion_damage: int = 12
@export_range(0, 1000, 1) var burning_damage: int = 2
@export_range(0.1, 120.0, 0.1) var burning_duration: float = 4.0
@export_range(0.01, 10.0, 0.01) var burning_damage_gap: float = 0.5

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _landing_shadow: Polygon2D = $LandingShadow
@onready var _audio: AudioStreamPlayer2D = $FallAudio

var _effect_type: Definition.BulletType = Definition.BulletType.Explosion
var _faction: Definition.Faction = Definition.Faction.Player
var _impact_position: Vector2


## 配置落点和效果阵营，并开始下落音效与动画。
func start_drop(impact_position: Vector2, effect_type: Definition.BulletType, faction: Definition.Faction) -> void:
    _impact_position = impact_position
    _effect_type = effect_type
    _faction = faction
    global_position = impact_position + Vector2(0.0, -fall_height)
    _sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
    _landing_shadow.top_level = true
    _landing_shadow.global_position = impact_position
    _landing_shadow.scale = landing_shadow_start_scale
    _landing_shadow.modulate = Color(1.0, 1.0, 1.0, 0.0)
    _audio.stream = SFX_SHELL_FALL
    _audio.play()

    # 炮弹以线性速度下落；透明度只在总下落时间的前 30% 内由透明渐显。
    var safe_fall_duration: float = maxf(fall_duration, 0.01)
    var fade_duration: float = safe_fall_duration * clampf(sprite_fade_in_ratio, 0.01, 1.0)
    var fall_tween: Tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
    fall_tween.tween_property(self, "global_position", _impact_position, safe_fall_duration)
    fall_tween.tween_callback(_apply_impact)

    # 落点阴影固定在目标点，随下落逐渐收缩，并从透明渐显至配置的不透明度。
    var shadow_tween: Tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
    shadow_tween.set_parallel(true)
    shadow_tween.tween_property(_sprite, "modulate:a", 1.0, fade_duration)
    shadow_tween.tween_property(_landing_shadow, "scale", landing_shadow_end_scale, safe_fall_duration)
    shadow_tween.tween_property(_landing_shadow, "modulate:a", landing_shadow_opacity, safe_fall_duration)


## 炮弹到达目标点后生成对应范围效果，再释放炮弹节点。
func _apply_impact() -> void:
    if not is_inside_tree():
        return
    match _effect_type:
        Definition.BulletType.Burning:
            var burning: BurningEffect = PrefabManager.create_burning(
                _faction,
                burning_damage,
                burning_duration,
                burning_damage_gap
            )
            if burning != null:
                burning.global_position = _impact_position
                get_tree().current_scene.add_child(burning)
        _:
            var explosion: ProjectileExplosion = PrefabManager.create_explosion(_faction, explosion_damage)
            if explosion != null:
                explosion.global_position = _impact_position
                get_tree().current_scene.add_child(explosion)
    queue_free()

## 可复用的一次性粒子容器：美术参数全部保存在各个 tscn 的 CPUParticles2D 中。
## 粒子在世界坐标独立播放，脱离子弹/爆炸的生命周期；暂停与切关同步清理。
class_name CombatParticleBurst
extends Node2D

## 自动回收的额外裕量，编辑粒子 lifetime 后无需修改脚本中的固定回收时间。
@export_range(0.0, 1.0, 0.05) var cleanup_padding := 0.15


## 启动所有原生粒子节点，按最长生命周期回收，不创建碰撞或参与伤害结算。
func _ready() -> void:
    add_to_group("transient_combat_vfx")
    var longest := 0.0
    for child: Node in get_children():
        var particles := child as CPUParticles2D
        if particles == null:
            continue
        longest = maxf(longest, particles.lifetime)
        particles.emitting = true
        particles.restart()
    await get_tree().create_timer(longest + cleanup_padding, false).timeout
    queue_free()


## 坐标在入树前确定，避免粒子从原点发射；缩放用于不同爆炸半径，方向用于反向扬尘。
static func spawn(scene: PackedScene, parent: Node2D, point: Vector2, direction: Vector2 = Vector2.ZERO, size_factor: float = 1.0) -> CombatParticleBurst:
    if not is_instance_valid(parent) or parent.is_queued_for_deletion():
        return null
    var effect := scene.instantiate() as CombatParticleBurst
    effect.position = parent.to_local(point)
    effect.scale = Vector2.ONE * size_factor
    if direction != Vector2.ZERO:
        effect.rotation = direction.angle()
    parent.add_child(effect)
    return effect

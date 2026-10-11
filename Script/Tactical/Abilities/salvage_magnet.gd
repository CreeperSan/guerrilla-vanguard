## 拾荒磁环：独立扩大货币/弹药拾取传感器，不扩大玩家原始 CollectBox。
extends TacticalAbility

var _sensor: Area2D


## 复制原拾取形状，避免修改场景共享 Shape2D，普通物品拾取距离保持原样。
func install() -> void:
    _sensor = Area2D.new()
    _sensor.name = "TacticalSalvageSensor"
    _sensor.collision_layer = 0
    _sensor.collision_mask = 16
    var collision := CollisionShape2D.new()
    collision.shape = equipment.player.node_collect_box.get_node("CollisionShape2D").shape.duplicate()
    collision.scale = Vector2.ONE * parameter("range", 1.8)
    _sensor.add_child(collision)
    equipment.player.add_child.call_deferred(_sensor)


## 移除能力只释放自己的传感器，无需恢复玩家碰撞形状。
func uninstall() -> void:
    if is_instance_valid(_sensor):
        _sensor.queue_free()


## 持续扫描可处理满弹后才有空间的弹药；只接受显式资源类别。
func tick(_delta: float) -> void:
    if not is_instance_valid(_sensor) or not _sensor.is_inside_tree():
        return
    for area: Area2D in _sensor.get_overlapping_areas():
        if area is LootItem and not area.is_queued_for_deletion() and area.is_magnetic_supply():
            equipment.player.on_collect_item(area)

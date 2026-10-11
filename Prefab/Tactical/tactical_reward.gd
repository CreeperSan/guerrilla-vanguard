## Boss 三选一奖励箱：主动交互、独立种子、一次领取，不混用自动拾取 LootItem。
class_name TacticalReward
extends Area2D

var reward_seed: int = 0
var claimed: bool = false
var _choice_ids: Array[StringName] = []
var _rolled: bool = false
var _nearby_player: Player
var _button: Button
var _ui: CanvasLayer


## 独立箱体、触碰范围和跨设备按钮；场景退出时 UI 随箱体一起释放。
func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    var collision := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = 38.0
    collision.shape = shape
    add_child(collision)
    var sprite := Sprite2D.new()
    sprite.texture = TacticalCatalog.reward_icon()
    if sprite.texture != null:
        sprite.scale = Vector2.ONE * (42.0 / sprite.texture.get_width())
    add_child(sprite)
    var label := Label.new()
    label.text = "战术奖励 · 三选一"
    label.position = Vector2(-70, -46)
    label.add_theme_font_size_override("font_size", 12)
    add_child(label)
    _ui = CanvasLayer.new()
    _ui.layer = 10
    _button = Button.new()
    _button.text = "查看战术奖励 · 回车 / A"
    _button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _button.offset_left = -170
    _button.offset_right = 170
    _button.offset_top = -148
    _button.offset_bottom = -104
    _button.hide()
    _button.pressed.connect(open_choices)
    _ui.add_child(_button)
    add_child(_ui)
    body_entered.connect(func(body: Node2D):
        if body is Player:
            _nearby_player = body
    )
    body_exited.connect(func(body: Node2D):
        if body == _nearby_player:
            _nearby_player = null
    )


## 只有实际邻近、存活、可见且未暂停时显示入口，防止隐藏房间远程领取。
func _process(_delta: float) -> void:
    _button.visible = _can_interact()


## 键盘与手柄共用主动确认，吞掉 A 直至释放，避免同时启动闪避。
func _input(event: InputEvent) -> void:
    if not _can_interact():
        return
    var confirmed: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]
    if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
        confirmed = true
        _nearby_player.consume_shop_confirmation()
    if confirmed:
        open_choices()
        get_viewport().set_input_as_handled()


## 查找当前 HUD 的独立界面，奖励箱本身不拥有战斗能力或暂停状态。
func open_choices() -> void:
    if not _can_interact():
        return
    var interface := get_tree().get_first_node_in_group("tactical_interface") as TacticalInterface
    if interface != null:
        interface.open_reward(self)


## 第一次查看时抽取并缓存，关闭重开不会刷新奖池；后续持有变化只过滤重复。
func get_choices(equipment: TacticalEquipment) -> Array[TacticalDefinition]:
    if not _rolled:
        _rolled = true
        for config: TacticalDefinition in TacticalCatalog.select(reward_seed, equipment.get_ids()):
            _choice_ids.append(config.id)
    var result: Array[TacticalDefinition] = []
    for id: StringName in _choice_ids:
        if not equipment.has_equipment(id):
            result.append(TacticalCatalog.get_definition(id))
    return result


## 严格校验候选和重复，奖励成功后一次消耗；测试也使用正式入口。
func claim(equipment: TacticalEquipment, id: StringName) -> bool:
    if claimed or id not in _choice_ids or not equipment.obtain(id):
        return false
    claimed = true
    if is_instance_valid(_button):
        _button.hide()
    hide()
    set_deferred("monitoring", false)
    queue_free()
    return true


## 房间淡出也检查透明度；独立 CanvasLayer 不继承父房间透明度。
func _can_interact() -> bool:
    if claimed or get_tree().paused or not is_instance_valid(_nearby_player) or _nearby_player.health_current <= 0 or _nearby_player.dodge_active:
        return false
    var ancestor: Node = self
    while ancestor != null:
        if ancestor is CanvasItem and (not ancestor.is_visible_in_tree() or ancestor.modulate.a < 0.01):
            return false
        ancestor = ancestor.get_parent()
    return true

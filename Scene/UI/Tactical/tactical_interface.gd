## 战术装备专用界面：本轮背包、奖励选择与能力反馈，不承担任何战斗效果。
class_name TacticalInterface
extends CanvasLayer

var equipment: TacticalEquipment
var _opened: bool = false
var _reward: TacticalReward
var _cards: VBoxContainer
var _title: Label
var _subtitle: Label
var _close_button: Button
var _last_focus: WeakRef

@onready var _inventory_button: Button = $Root/InventoryButton
@onready var _overlay: Control = $Root/Overlay
@onready var _contents: VBoxContainer = $Root/Overlay/Center/Panel/Margin/Contents
@onready var _feedback: Label = $Root/Feedback


## 布局外壳在场景维护，动态装备列表单独生成，背包入口不会接管 HUD 暂停菜单。
func _ready() -> void:
    add_to_group("tactical_interface")
    _inventory_button.pressed.connect(open_inventory)
    _title = _contents.get_node("Title")
    _subtitle = _contents.get_node("Subtitle")
    _cards = _contents.get_node("Scroll/Cards")
    _close_button = _contents.get_node("Close")
    _close_button.pressed.connect(close)
    _bind_player.call_deferred()


## 延迟绑定正式玩家；关卡切换保留同一组件与界面。
func _bind_player() -> void:
    var player := get_tree().get_first_node_in_group("player") as Player
    if player == null or player.tactical_equipment == null:
        _inventory_button.hide()
        return
    equipment = player.tactical_equipment
    equipment.initialize()
    equipment.inventory_changed.connect(_refresh_count)
    equipment.ability_triggered.connect(_show_trigger)
    _refresh_count()


## 背包仅在战斗可操作期间打开；其他菜单已暂停时不会夺取暂停所有权。
func open_inventory() -> void:
    if not _can_open():
        return
    _begin("战术装备 · 本轮有效", "跨关保留，同名不叠加。死亡、放弃或通关后清空。")
    _reward = null
    for id: StringName in equipment.get_ids():
        _add_card(TacticalCatalog.get_definition(id), false)
    if equipment.get_ids().is_empty():
        _subtitle.text += "\n暂未持有，可从 Boss 奖励或商店获得。"
    _close_button.text = "返回战场"
    _close_button.grab_focus()


## 奖励箱保留固定抽取结果；已有装备在确认前再次检查，选择失败不消耗箱子。
func open_reward(reward: TacticalReward) -> void:
    if not _can_open() or not is_instance_valid(reward) or reward.claimed:
        return
    var choices := reward.get_choices(equipment)
    _begin("Boss 战利品 · 选择一件", "主动领取后本轮生效。可以暂时离开，奖励保留至离开本关。")
    _reward = reward
    for config: TacticalDefinition in choices:
        _add_card(config, true)
    if choices.is_empty():
        _subtitle.text = "你已持有全部战术装备，当前没有新的可领取装备。"
    _close_button.text = "暂不领取"
    if not _cards.get_children().is_empty():
        var buttons := _cards.find_children("Claim", "Button", true, false)
        if not buttons.is_empty():
            buttons[0].grab_focus()
    else:
        _close_button.grab_focus()


## 弹窗统一持有暂停；清理旧焦点与列表，避免隐藏按钮被手柄继续触发。
func _begin(title: String, subtitle: String) -> void:
    var focused := get_viewport().gui_get_focus_owner()
    _last_focus = weakref(focused) if focused != null else null
    for child: Node in _cards.get_children():
        _cards.remove_child(child)
        child.queue_free()
    _title.text = title
    _subtitle.text = subtitle
    _opened = true
    _overlay.show()
    get_tree().paused = true


## 展示完整正负效果，生命代价额外给出玩家实际前后数值。
func _add_card(config: TacticalDefinition, selectable: bool) -> void:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color("26342c")
    style.border_color = Color("9f874f")
    style.set_border_width_all(1)
    style.set_content_margin_all(12)
    panel.add_theme_stylebox_override("panel", style)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    var icon := TextureRect.new()
    icon.texture = config.icon
    icon.custom_minimum_size = Vector2(56, 56)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    row.add_child(icon)
    var words := VBoxContainer.new()
    words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var name_label := Label.new()
    name_label.text = config.display_name
    name_label.add_theme_color_override("font_color", Color("ead899"))
    name_label.add_theme_font_size_override("font_size", 18)
    words.add_child(name_label)
    var detail := Label.new()
    detail.text = config.description
    if selectable and config.parameters.has("health"):
        detail.text += "\n最大生命 %d → %d；当前生命 %d → %d" % [equipment.player.health_max, roundi(equipment.player.health_max * float(config.parameters.health)), equipment.player.health_current, mini(equipment.player.health_current, roundi(equipment.player.health_max * float(config.parameters.health)))]
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.add_theme_font_size_override("font_size", 14)
    words.add_child(detail)
    row.add_child(words)
    if selectable:
        var button := Button.new()
        button.name = "Claim"
        button.text = "领取"
        button.custom_minimum_size = Vector2(72, 44)
        button.pressed.connect(_claim.bind(config.id))
        row.add_child(button)
    panel.add_child(row)
    _cards.add_child(panel)


## 确认入口再次检查生命与重复，成功后才关闭选择并消耗奖励。
func _claim(id: StringName) -> void:
    if is_instance_valid(_reward) and _reward.claim(equipment, id):
        close()


## 只有本界面打开才解除自己的暂停，其他菜单状态不受影响。
func close() -> void:
    if not _opened:
        return
    _opened = false
    _overlay.hide()
    get_tree().paused = false
    _reward = null
    if _last_focus != null:
        var previous := _last_focus.get_ref() as Control
        if previous != null and previous.is_visible_in_tree():
            previous.grab_focus()


## 提前消费 Escape/Start，防止关闭战术面板的同时打开原 HUD 暂停菜单。
func _input(event: InputEvent) -> void:
    var key := event as InputEventKey
    if key != null and key.pressed and not key.echo and key.keycode == KEY_T:
        if _opened:
            close()
        else:
            open_inventory()
        get_viewport().set_input_as_handled()
    elif _opened and ((event.is_action_pressed("ui_cancel") and not event.is_echo()) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)):
        close()
        get_viewport().set_input_as_handled()


## 战斗结束及启动菜单期间禁用背包入口，避免结果页被覆盖。
func _process(_delta: float) -> void:
    _inventory_button.disabled = not _can_open()
    if _opened and (equipment == null or equipment.player.health_current <= 0):
        close()


## 存活、组件存在且当前没有其他暂停界面，才允许打开。
func _can_open() -> bool:
    return is_instance_valid(equipment) and equipment.player.health_current > 0 and not _opened and not get_tree().paused and GameManager.run_state not in [RogueRunManager.RunState.COMPLETED, RogueRunManager.RunState.FAILED]


## 背包计数与成功领取提示共用库存变化事件。
func _refresh_count() -> void:
    _inventory_button.text = "战术装备 %d · T" % equipment.get_ids().size()


## 低频触发显示装备名，独立反馈不改变其他 HUD 状态。
func _show_trigger(id: StringName) -> void:
    var config := TacticalCatalog.get_definition(id)
    if config != null:
        _feedback.text = config.display_name + " · 已触发"
        _feedback.show()
        var text_snapshot := _feedback.text
        get_tree().create_timer(1.2, false).timeout.connect(func():
            if is_instance_valid(_feedback) and _feedback.text == text_snapshot:
                _feedback.hide()
        )

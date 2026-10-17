## 独立触控布局预览：单指/鼠标拖动、坐标微调、大小滑块、草稿重置、明确保存或取消。
## 预览与实战使用 TouchLayout.rect_for；离开前不修改全局配置，避免误触保存半成品。
extends CanvasLayer

var draft: Dictionary
var _root: Control
var _markers: Dictionary = {}
var _selected := "move"
var _drag_index := -2
var _drag_offset := Vector2.ZERO
var _toolbar: HBoxContainer
var _footer: VBoxContainer
var _footer_background: Panel
var _coordinates: Label
var _size_slider: HSlider
var _x_slider: HSlider
var _y_slider: HSlider
var _picker: OptionButton
var _dirty := false
var _exit_confirmation: ConfirmationDialog

## 全屏预览保留实际视口坐标；两条工具栏覆盖于模拟战场上，按钮标记不消费拖动事件。
func _ready() -> void:
    draft = GameSettings.touch_layout.duplicate(true)
    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.theme = Theme.new()
    _root.theme.default_font = FlowUI.FONT
    _root.theme.default_font_size = 16
    add_child(_root)
    var background := ColorRect.new()
    background.color = Color("182a26")
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.add_child(background)
    # 半屏线直观标出两只摇杆的活动边界，实际约束同时保留按钮半径与屏边间距。
    var divider := ColorRect.new()
    divider.color = Color("657d66")
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    divider.anchor_left = 0.5
    divider.anchor_right = 0.5
    divider.anchor_bottom = 1.0
    divider.offset_right = 2
    _root.add_child(divider)
    for id: String in TouchLayout.DEFAULTS:
        var marker := Panel.new()
        marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var label := Label.new()
        label.name = "Caption"
        label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 14)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        marker.add_child(label)
        _root.add_child(marker)
        _markers[id] = marker
    _toolbar = HBoxContainer.new()
    _toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    _toolbar.offset_left = 16
    _toolbar.offset_right = -16
    _toolbar.offset_top = 8
    _toolbar.add_theme_constant_override("separation", 12)
    _root.add_child(_toolbar)
    FlowUI.label(_toolbar, "布局预览 · 拖动按钮调整位置", 18)
    FlowUI.button(_toolbar, "面板", _toggle_inspector)
    FlowUI.button(_toolbar, "重置", _reset_draft)
    FlowUI.button(_toolbar, "取消", _cancel)
    FlowUI.button(_toolbar, "保存", _save)
    _footer_background = Panel.new()
    _footer_background.anchor_top = 1.0
    _footer_background.anchor_bottom = 1.0
    _footer_background.anchor_right = 1.0
    _footer_background.offset_top = -116
    _footer_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var footer_style := StyleBoxFlat.new()
    footer_style.bg_color = Color(0.035, 0.07, 0.06, 0.94)
    _footer_background.add_theme_stylebox_override("panel", footer_style)
    _root.add_child(_footer_background)
    _footer = VBoxContainer.new()
    _footer.anchor_top = 1.0
    _footer.anchor_bottom = 1.0
    _footer.anchor_right = 1.0
    _footer.offset_left = 16
    _footer.offset_right = -16
    _footer.offset_top = -108
    _footer.offset_bottom = -8
    _root.add_child(_footer)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    _footer.add_child(row)
    _picker = OptionButton.new()
    for id: String in TouchLayout.LABELS:
        _picker.add_item(TouchLayout.LABELS[id])
    row.add_child(_picker)
    _picker.item_selected.connect(func(index: int): _select(TouchLayout.LABELS.keys()[index]))
    _coordinates = FlowUI.label(row, "", 16)
    _coordinates.autowrap_mode = TextServer.AUTOWRAP_OFF
    var size_caption := FlowUI.label(row, "大小", 16)
    size_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
    size_caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _size_slider = _slider(row, 50, 160)
    _size_slider.value_changed.connect(_resize_selected)
    var position_row := HBoxContainer.new()
    position_row.add_theme_constant_override("separation", 12)
    _footer.add_child(position_row)
    var x_caption := FlowUI.label(position_row, "X %", 16)
    x_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
    x_caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _x_slider = _slider(position_row, 0, 100)
    var y_caption := FlowUI.label(position_row, "Y %", 16)
    y_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
    y_caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _y_slider = _slider(position_row, 0, 100)
    _x_slider.value_changed.connect(func(value: float): _set_center(Vector2(value / 100.0, draft[_selected].center.y)))
    _y_slider.value_changed.connect(func(value: float): _set_center(Vector2(draft[_selected].center.x, value / 100.0)))
    _exit_confirmation = ConfirmationDialog.new()
    _exit_confirmation.dialog_text = "布局尚未保存，放弃此次修改？"
    _exit_confirmation.confirmed.connect(queue_free)
    _root.add_child(_exit_confirmation)
    _root.resized.connect(_refresh)
    _picker.grab_focus()
    _refresh.call_deferred()

## 折叠坐标面板后可完整预览或拖动靠近底边的控件，不改变任何按钮坐标。
func _toggle_inspector() -> void:
    _footer.visible = not _footer.visible
    _footer_background.visible = _footer.visible

## 大尺寸滑块同时支持触控与键盘方向键，坐标以屏幕比例保存。
func _slider(parent: Node, minimum: float, maximum: float) -> HSlider:
    var slider := HSlider.new()
    slider.min_value = minimum
    slider.max_value = maximum
    slider.step = 1
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.custom_minimum_size = Vector2(160, 36)
    parent.add_child(slider)
    return slider

## 只选中一个标记；当前坐标与大小在拖动、微调和屏幕变化后同步。
func _select(id: String) -> void:
    _selected = id
    _picker.select(TouchLayout.LABELS.keys().find(id))
    _refresh()

## 统一约束实际矩形后再回写中心，使滑块显示值与实际命中范围一致。
func _set_center(center: Vector2) -> void:
    draft[_selected].center = center
    var rect := TouchLayout.rect_for(_selected, draft, _root.size, GameSettings.movement_scale)
    draft[_selected].center = rect.get_center() / _root.size
    _dirty = true
    _refresh()

## 大小变化同样重新约束中心，不允许放大后摇杆跨越半屏或按钮越出屏幕。
func _resize_selected(value: float) -> void:
    draft[_selected].scale = value / 100.0
    _set_center(draft[_selected].center)

## 标记尺寸严格取公共算法；高亮选中框，明确显示中心坐标与相对默认大小。
func _refresh() -> void:
    if _size_slider == null or _root.size.x <= 0:
        return
    for id: String in _markers:
        var marker: Panel = _markers[id]
        var rect := TouchLayout.rect_for(id, draft, _root.size, GameSettings.movement_scale)
        TouchLayout.apply(marker, rect)
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.2, 0.4, 0.33, 0.85)
        style.border_color = Color("ffd77e") if id == _selected else Color("809d8c")
        style.set_border_width_all(3 if id == _selected else 1)
        # 预览同步实战的圆形移动区，其余按钮维持圆角标记。
        style.set_corner_radius_all(ceili(minf(rect.size.x, rect.size.y) * 0.5) if id == "move" else 18)
        style.corner_detail = 32 if id == "move" else 8
        marker.add_theme_stylebox_override("panel", style)
        var label: Label = marker.get_node("Caption")
        label.text = "%s\n(%d, %d)" % [TouchLayout.LABELS[id], roundi(rect.get_center().x), roundi(rect.get_center().y)]
    var selected_rect := TouchLayout.rect_for(_selected, draft, _root.size, GameSettings.movement_scale)
    var center := selected_rect.get_center() / _root.size
    _coordinates.text = "中心 %.0f%% / %.0f%% · 大小 %d%%" % [center.x * 100, center.y * 100, roundi(draft[_selected].scale * 100)]
    _size_slider.set_value_no_signal(draft[_selected].scale * 100)
    _x_slider.set_value_no_signal(center.x * 100)
    _y_slider.set_value_no_signal(center.y * 100)

## 提前拦截预览操作，阻止底层首页收到按键；工具栏区域留给原生 GUI 处理。
func _input(event: InputEvent) -> void:
    if _exit_confirmation.visible:
        return
    if event.is_action_pressed("ui_cancel"):
        _cancel()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            _begin_drag(event.position, event.index)
        elif event.index == _drag_index:
            _drag_index = -2
    elif event is InputEventScreenDrag and event.index == _drag_index:
        _drag_to(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin_drag(event.position, -1)
        elif _drag_index == -1:
            _drag_index = -2
    elif event is InputEventMouseMotion and _drag_index == -1:
        _drag_to(event.position)

## 单指拖动拥有固定触点索引，第二根手指不抢走已选按钮。
func _begin_drag(point: Vector2, index: int) -> void:
    if _drag_index != -2 or _toolbar.get_global_rect().has_point(point) or (_footer.visible and _footer.get_global_rect().has_point(point)):
        return
    var ids := TouchLayout.DEFAULTS.keys()
    ids.reverse()
    for id: String in ids:
        var rect := TouchLayout.rect_for(id, draft, _root.size, GameSettings.movement_scale)
        if TouchLayout.contains_point(id, rect, point):
            _select(id)
            _drag_index = index
            _drag_offset = point - rect.get_center()
            get_viewport().set_input_as_handled()
            return

## 保留按下点相对中心的偏移，避免第一次拖动时按钮突然跳到指尖中心。
func _drag_to(point: Vector2) -> void:
    _set_center((point - _drag_offset) / _root.size)
    get_viewport().set_input_as_handled()

## 重置只作用草稿，保存后才影响实战；取消仍能恢复编辑前布局。
func _reset_draft() -> void:
    draft = TouchLayout.DEFAULTS.duplicate(true)
    _dirty = true
    _refresh()

## 一次提交完整布局，立即落盘，不依赖后续首页退出。
func _save() -> void:
    GameSettings.set_touch_layout(draft)
    queue_free()

## 有修改时确认放弃；未修改可直接返回操控设置。
func _cancel() -> void:
    if _dirty:
        _exit_confirmation.popup_centered()
    else:
        queue_free()

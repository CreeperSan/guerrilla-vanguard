## 反击通关后的滚动制作名单；内容来自独立资源，方便发行前修改。
extends Control
const CONTENT: CreditsData = preload("res://Script/Presentation/credits.tres")
var _text: RichTextLabel
var _window: Control
var _offset := 0.0
var _fast := false

## 文本在裁剪窗口中由下向上滚动，固定操作区始终可见。
func _ready() -> void:
	var page := FlowUI.page(self)
	FlowUI.label(page, "行动完成  /  制作与致谢", 24)
	_window = Control.new()
	_window.clip_contents = true
	_window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_window)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_override("normal_font", FlowUI.FONT)
	_text.add_theme_font_size_override("normal_font_size", 24)
	_text.text = CONTENT.text
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	page.add_child(row)
	FlowUI.button(row, "返回战报", _back_report)
	FlowUI.button(row, "返回首页", GameManager.return_to_main_menu)
	FlowUI.label(row, "按住 Shift / 触摸可加速", 18)
	await get_tree().process_frame
	_offset = _window.size.y

## 文本宽度实时跟随窗口；末尾停在中央，避免滚完后留下空白。
func _process(delta: float) -> void:
	if _text == null:
		return
	_text.size.x = _window.size.x
	var end := -maxf(0.0, _text.get_content_height() - _window.size.y * 0.5)
	_offset = maxf(end, _offset - CONTENT.scroll_speed * delta * (5.0 if _fast or Input.is_physical_key_pressed(KEY_SHIFT) else 1.0))
	_text.position.y = _offset

## 加速不改变已完成对局状态，也不会再次结算账户。
func _input(event: InputEvent) -> void:
	if SceneTransition.busy:
		return
	if event is InputEventScreenTouch:
		_fast = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_fast = event.pressed

## 可返回同一份战报查看，不会重新启动游戏。
func _back_report() -> void:
	GameManager.open_presentation("res://Scene/RunResult/RunResult.tscn", "行动战报")

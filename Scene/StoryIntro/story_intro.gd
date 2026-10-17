## 六格漫画序章；每次按键或触摸推进一格，右上角可直接进入首页。
extends Control
const STORY: StoryIntroData = preload("res://Script/Presentation/story_intro.tres")
var panel_index := -1
var _picture: TextureRect
var _caption: Label
var _progress: Label
var _animating := false
var _leaving := false
var _skip: Button

## 保持图像纵横比，字幕单独排版；跳过按钮不参与普通推进事件。
func _ready() -> void:
	GameSettings.mark_story_intro_seen()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var page := FlowUI.page(self)
	var top := HBoxContainer.new()
	page.add_child(top)
	_progress = FlowUI.label(top, "行动序章", 24)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skip = FlowUI.button(top, "跳过剧情 ›", _leave)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_picture)
	_caption = FlowUI.label(page, "", 26)
	_caption.custom_minimum_size.y = 72
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FlowUI.label(page, "触摸屏幕 / 按任意按钮继续", 18).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 容器留白和字幕不吃掉点击，只有跳过按钮主动处理 GUI 输入。
	for node: Node in [page, top, _caption, _progress]:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_panel()

## AtlasTexture 直接引用生成的六格原图，避免压缩重采样损失。
func next_panel() -> void:
	if _animating or _leaving:
		return
	panel_index += 1
	if panel_index >= STORY.captions.size():
		_leave()
		return
	var cell := STORY.sheet.get_size() / Vector2(STORY.columns, STORY.rows)
	var atlas := AtlasTexture.new()
	atlas.atlas = STORY.sheet
	atlas.region = Rect2(Vector2(panel_index % STORY.columns, floori(float(panel_index) / STORY.columns)) * cell + Vector2.ONE * 4, cell - Vector2.ONE * 8)
	_picture.texture = atlas
	_caption.text = STORY.captions[panel_index]
	_progress.text = "行动序章  /  %02d — %02d" % [panel_index + 1, STORY.captions.size()]
	_animating = true
	_picture.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_picture, "modulate:a", 1.0, 0.22)
	await tween.finished
	_animating = false

## 只响应按下边沿；忽略键盘重复，避免一次长按跳过整段故事。
func _input(event: InputEvent) -> void:
	if SceneTransition.busy:
		return
	# 跳过按钮的命中交给 GUI；其余区域在 GUI 冒泡前处理，留白和字幕也可推进。
	if event is InputEventMouseButton and _skip.get_global_rect().has_point(event.position):
		return
	if event is InputEventScreenTouch and _skip.get_global_rect().has_point(event.position):
		return
	if _skip.has_focus() and event.is_action_pressed("ui_accept"):
		return
	var advance: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if advance:
		get_viewport().set_input_as_handled()
		next_panel()


## 跳过及最后一格共用出口，遮幕期间锁定二次点击。
func _leave() -> void:
	if _leaving or SceneTransition.busy:
		return
	_leaving = true
	await SceneTransition.change_scene("res://Scene/MainMenu/MainMenu.tscn", "准备出发")

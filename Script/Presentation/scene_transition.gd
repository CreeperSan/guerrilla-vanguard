## 全局遮幕负责跨场景及跨 Level 转场，覆盖期间阻止重复导航和输入。
extends CanvasLayer
var busy := false
var _veil: ColorRect
var _caption: Label

## 常驻最高层，暂停战斗时转场动画也能完成。
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer = 1000
	_veil = ColorRect.new()
	_veil.color = Color("101915")
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.hide()
	add_child(_veil)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font", preload("res://Font/fusion-pixel-12-zh-hans.ttf"))
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_color_override("font_color", Color("edc879"))
	_veil.add_child(_caption)

## 半秒淡入遮幕；调用方在完全遮住后才可以清理房间。
func cover(title: String = "准备行动") -> bool:
	if busy:
		return false
	busy = true
	_caption.text = "◆  " + title + "  ◆"
	_veil.modulate.a = 0.0
	_veil.show()
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_veil, "modulate:a", 1.0, 0.32)
	await tween.finished
	return true

## 新场景准备就绪后淡出；输入直到完全显露才恢复。
func reveal() -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_veil, "modulate:a", 0.0, 0.36)
	await tween.finished
	_veil.hide()
	busy = false

## SceneTree 的换场在帧末生效，等待 scene_changed 后才揭幕。
func change_scene(path: String, title: String = "准备行动") -> Error:
	if not await cover(title):
		return ERR_BUSY
	var error := get_tree().change_scene_to_file(path)
	if error == OK:
		await get_tree().scene_changed
		await get_tree().process_frame
	await reveal()
	return error

## 键盘和手柄同样不能穿透遮幕；鼠标由全屏 Control 拦截。
func _input(_event: InputEvent) -> void:
	if busy:
		get_viewport().set_input_as_handled()

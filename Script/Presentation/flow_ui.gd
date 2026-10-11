## 新流程页面共享排版和字体，不改动原有战斗 HUD 或首页主题。
class_name FlowUI
extends RefCounted
const FONT: Font = preload("res://Font/fusion-pixel-12-zh-hans.ttf")
const GOLD := Color("edc879")

## 响应式页边距、背景与垂直内容区；使用容器适应触屏及窗口尺寸。
static func page(root: Control) -> VBoxContainer:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 24
	root.theme = theme
	var bg := ColorRect.new()
	bg.color = Color("101915")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	return box

## 文字独立于图片资源，便于后续编辑和本地化。
static func label(parent: Node, text: String, size: int = 24) -> Label:
	var node := Label.new()
	node.text = text
	# 自动换行文本在横向容器里需要分配剩余宽度，否则会收缩为单字竖排。
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", GOLD)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

## 统一可聚焦按钮，支持手柄、键盘与触摸。
static func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 44
	node.add_theme_font_size_override("font_size", 22)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

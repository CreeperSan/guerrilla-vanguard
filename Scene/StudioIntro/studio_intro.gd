## 每次进程启动必经的工作室开场；没有任何输入可以提前结束。
extends Control
@export var card_duration := 1.8
var _content: VBoxContainer

## 两段工作室信息依次滚动入场、停留、离场，结束后才按剧情偏好导航。
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var page := FlowUI.page(self)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)
	_content = VBoxContainer.new()
	_content.custom_minimum_size.x = 500
	center.add_child(_content)
	await _card("☀", "SUNNY STUDIO", "独立创作 · 用热爱点亮每一次冒险")
	await _card("呈  现", "游击先锋", "GUERRILLA VANGUARD")
	var destination := "res://Scene/MainMenu/MainMenu.tscn" if GameSettings.story_intro_seen else "res://Scene/StoryIntro/StoryIntro.tscn"
	await SceneTransition.change_scene(destination, "Sunny Studio 呈现")

## 内容使用位移和透明度形成滚动切换，不依赖窗口实际像素尺寸。
func _card(mark: String, title: String, subtitle: String) -> void:
	for child: Node in _content.get_children():
		child.free()
	for pair: Array in [[mark, 50], [title, 42], [subtitle, 22]]:
		var text := FlowUI.label(_content, pair[0], pair[1])
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.modulate.a = 0.0
	# 等容器完成居中布局后再取坐标，否则第一帧的零坐标会把动画拉到页顶。
	await get_tree().process_frame
	var resting_y := _content.position.y
	_content.position.y = resting_y + 35
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_content, "modulate:a", 1.0, 0.5)
	tween.tween_property(_content, "position:y", resting_y, 0.5)
	await tween.finished
	await get_tree().create_timer(card_duration).timeout
	tween = create_tween().set_parallel(true)
	tween.tween_property(_content, "modulate:a", 0.0, 0.4)
	tween.tween_property(_content, "position:y", resting_y - 35, 0.4)
	await tween.finished

## 消耗全部按键与触摸，不提供隐藏跳过入口。
func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

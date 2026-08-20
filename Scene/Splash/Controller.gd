extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 等待 2 秒
	await get_tree().create_timer(2.0).timeout
	# 加载主菜单页面
	get_tree().change_scene_to_file("res://Scene/MainMenu/MainMenu.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

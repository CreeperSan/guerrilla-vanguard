extends VBoxContainer

@onready var btnStart = $"Start Button"
@onready var btnSetting = $"Setting Button"
@onready var btnExit = $"Exit Button"


func _ready() -> void:
	# 点击开始游戏
	btnStart.pressed.connect(func():
		get_tree().change_scene_to_file("res://Scene/Level_01/Level_01.tscn")
	)
	# 点击设置
	btnSetting.pressed.connect(func():
		pass	
	)
	# 点击退出游戏
	btnExit.pressed.connect(func(): 
		get_tree().quit()
	)

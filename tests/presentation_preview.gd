## 新流程的图形预览入口；使用构造战报，资源输出到临时目录，不读写研究账户。
extends Node

## 顺序截图四个独立页面，退出前保持结果账本停用。
func _ready() -> void:
	RunStats.recording = false
	RunStats.last_report = {"won": true, "mode": 1, "completed": 7, "total": 7, "mode_name": "反击模式", "finished_at": "2026-10-11 12:00", "elapsed_seconds": 953, "score": 18750, "money_earned": 2480, "money_spent": 1650, "money_remaining": 830, "research_earned": 570, "rooms": {"战斗房": 32, "战斗补给房": 7, "首领房": 7, "商店": 4, "佣兵房": 3}, "enemies": {"固定警戒兵": 46, "游走追击兵": 58, "移动射手": 31, "首领 · 地下要塞": 1}, "items": {"手雷": 18, "医疗补给": 12, "战术轰炸": 3}, "weapons": {"手枪": 128, "冲锋枪": 537, "RPG": 36}, "tactical": {"a": "陶瓷护甲", "b": "快速装填器", "c": "额外弹袋"}, "ally_kills": 39, "projectiles": 932}
	for entry: Array in [["StudioIntro", "studio"], ["StoryIntro", "story"], ["RunResult", "report"], ["Credits", "credits"]]:
		var scene: Control = load("res://Scene/%s/%s.tscn" % [entry[0], entry[0]]).instantiate()
		add_child(scene)
		await get_tree().create_timer(1.6).timeout
		if entry[0] == "Credits":
			scene._offset = 30.0
			scene._process(0.0)
			print("CREDITS_PREVIEW offset=", scene._offset, " text_position=", scene._text.position, " height=", scene._text.get_content_height(), " window=", scene._window.size)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/private/tmp/gv-" + entry[1] + ".png")
		scene.free()
	get_tree().quit()

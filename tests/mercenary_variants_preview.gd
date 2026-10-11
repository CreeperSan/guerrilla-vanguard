## 新兵种资源预览：正式角色场景展示待机、行走与攻击，不开启 AI、不修改存档。
extends Node2D

const FONT: Font = preload("res://Font/fusion-pixel-12-zh-hans.ttf")


## 以正式兵种场景和图集构建预览卡片，--capture 时保存实际渲染截图后退出。
func _ready() -> void:
	# 适配项目 canvas_items 的逻辑视口，保持预览卡片完整落在画面内。
	scale = get_viewport().get_visible_rect().size / Vector2(1280, 720)
	RenderingServer.set_default_clear_color(Color("17211c"))
	_make_label("佣兵增援  /  MERCENARY REINFORCEMENTS", Vector2(48, 34), 28)
	_make_label("护盾耐久 10  ·  招募费用 80 金  ·  场上仅一名佣兵", Vector2(48, 82), 18)
	for kind: int in range(2):
		var x := 48.0 + kind * 616.0
		var panel := ColorRect.new()
		panel.position = Vector2(x, 142)
		panel.size = Vector2(584, 490)
		panel.color = Color("26362c")
		add_child(panel)
		var id := "grenadier" if kind == 0 else "fearless"
		_make_label("掷弹手" if kind == 0 else "无畏战士", Vector2(x + 28, 166), 28)
		_make_label("生命 45  ·  移速 105" if kind == 0 else "生命 120  ·  移速 85", Vector2(x + 28, 218), 18)
		_make_label("远程抛物手雷  ·  爆炸伤害 6" if kind == 0 else "近战伤害 4  ·  轻击退（Boss 免疫）", Vector2(x + 28, 254), 18)
		for pose: int in range(3):
			var actor := load("res://Prefab/Mercenary/mercenary_%s.tscn" % id).instantiate() as HiredMercenary
			actor.starts_hired = false
			add_child(actor)
			actor.position = Vector2(x + 100 + pose * 190, 440)
			actor.scale = Vector2(3.2, 3.2)
			actor.set_physics_process(false)
			actor.animated_sprite.play(["idle_down", "move_down_right", "attack_right"][pose])
			_make_label(["待机", "行走", "投掷" if kind == 0 else "挥击"][pose], Vector2(x + 76 + pose * 190, 500), 18)
		_make_label("八方向美术  ·  独立攻击与音效", Vector2(x + 28, 578), 16)
	_make_label("手雷不会误伤玩家与友军  /  重甲战士以物理方式轻推普通敌人", Vector2(48, 663), 16)
	if "--capture" in OS.get_cmdline_user_args():
		for frame: int in range(20):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png("res://docs/art/mercenary_variants_preview.png")
		print("MERCENARY_VARIANTS_PREVIEW saved=%s" % [result == OK])
		get_tree().quit(0 if result == OK else 1)


## 统一像素字体、字号和浅色文字，预览不依赖系统字体。
func _make_label(text: String, point: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e5e6c6"))
	add_child(label)

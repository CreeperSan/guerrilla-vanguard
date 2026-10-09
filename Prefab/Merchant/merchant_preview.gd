## F6 商人房试购入口：仅开启临时局内钱包，不结算或写入研究账户。
## 命令行传 --capture 可自动保存实际渲染图；默认可自由移动购买，退出清空临时金钱。
extends Node2D


## 使用正式主题和房间模板激活商店，预览中有 100 金与部分生命，方便试购。
func _ready() -> void:
	CurrencyManager.begin_run()
	CurrencyManager.money = 100
	var room := $Room as FortressRoomTemplate
	room.population_seed = 321
	room.configure_room({"id": 0, "size": Vector2i.ONE, "type": "merchant"}, {"north": [], "east": [], "south": [], "west": []})
	room.activate_room()
	$Player.node_health.health = 60
	$Player.sig_health_updated.connect(func(current: int, maximum: int): $UI/Status.text = "金钱 %d  |  生命 %d/%d" % [CurrencyManager.money, current, maximum])
	CurrencyManager.sig_currency_changed.connect(_update_status)
	_update_status(CurrencyManager.get_snapshot())
	if OS.get_cmdline_user_args().has("--capture"):
		# 可选确认预览让玩家站到武器上；触屏预览只切换输入提示，不购买。
		var args := OS.get_cmdline_user_args()
		if args.has("--confirm-preview") or args.has("--touch-preview"):
			for offer: ShopOffer in room.get_node("LazyContent/MerchantRoom/Offers").get_children():
				if offer.requires_confirmation():
					$Player.global_position = offer.global_position
					for frame: int in range(3):
						await get_tree().physics_frame
					if args.has("--touch-preview"):
						var touch := InputEventScreenTouch.new()
						touch.pressed = true
						touch.position = Vector2(1, 1)
						offer._input(touch)
					break
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		var filename := "merchant_touch_purchase_preview.png" if args.has("--touch-preview") else ("merchant_weapon_purchase_preview.png" if args.has("--confirm-preview") else "merchant_room_preview.png")
		var error := screenshot.save_png("res://docs/art/" + filename)
		print("MERCHANT_PREVIEW saved=%s" % (error == OK))
		get_tree().quit(0 if error == OK else 1)


## 同步试购金钱与玩家生命状态；示例 UI 位于场景中，便于 Inspector 调整。
func _update_status(snapshot: Dictionary) -> void:
	$UI/Status.text = "金钱 %d  |  生命 %d/%d" % [snapshot.money, $Player.health_current, $Player.health_max]


## 离开试购场景不带出临时研究或金钱，避免演示商品污染实际游戏进度。
func _exit_tree() -> void:
	CurrencyManager.close_run()

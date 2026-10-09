## 商人房契约测试：真实生成器、场景、钱包、商品效果和物理触碰；不保存研究账户。
extends Node

## 复用正式控制器构建所有主题房间；跳过正式宿主的输入/HUD/对局启动副作用。
class TestController extends FortressLevelController:
	## 测试直接调用 start_level，只跳过宿主自动绑定，不替换房间生成逻辑。
	func _ready() -> void:
		pass

var _checks := 0
var _failures := 0
var _feedbacks := 0


## 场景入口保证自动加载先完成，防止直接 --script 的全局节点编译时序差异。
func _ready() -> void:
	_run.call_deferred()


## 验证每关唯一且可达的商店、三件库存、扣款与各类发放，再验证真实触碰与房间重入。
func _run() -> void:
	for level: int in range(1, 8):
		for seed_value: int in range(100):
			var level_map := FortressRoomGenerator.generate_level(level, seed_value * 7919 + 17)
			_check_map(level_map)
			_check(level_map == FortressRoomGenerator.generate_level(level, seed_value * 7919 + 17), "相同种子复现完整关卡")
		_check_map(FortressRoomGenerator._make_fallback_level(level, 97, 4))
	var catalog := load("res://Script/Shop/shop_catalog.tres") as ShopCatalog
	var seen_types: Dictionary = {}
	for stock_seed: int in range(100):
		var stock := catalog.select_stock(stock_seed)
		_check(stock.size() == 3 and stock == catalog.select_stock(stock_seed), "每关三件且可复现")
		var types: Dictionary = {}
		for product: ShopProduct in stock:
			types[product.loot_type] = true
			seen_types[product.loot_type] = true
		_check(types.size() == 3, "三件商品类型不重复")
	_check(seen_types.size() == 10, "所有十种商品均可抽中")
	var invalid := ShopCatalog.new()
	invalid.products = [catalog.products[0], catalog.products[0], null]
	_check(invalid.select_stock(1).is_empty(), "无效重复商品池拒绝生成，预期错误日志")

	CurrencyManager.begin_run()
	var world := Node2D.new()
	add_child(world)
	var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
	player.position = Vector2(10000, 10000)
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	# 直接设置测试余额和局内状态，不调用结算或改写永久账户。
	CurrencyManager.money = 1000
	for product: ShopProduct in catalog.products:
		var offer := _make_offer(world, product)
		var money_before := CurrencyManager.money
		player.node_health.health = 40
		var research_before := CurrencyManager.run_research
		_check(offer.try_purchase(player), "商品购买成功：" + product.display_name)
		_check(CurrencyManager.money == money_before - product.price, "扣款精确且不受收益倍率影响")
		_check(offer.sold and offer.is_queued_for_deletion() and not offer.visible, "成交后立即消失并等待销毁")
		_check(not offer.try_purchase(player) and CurrencyManager.money == money_before - product.price, "重复触碰不重复扣款")
		match product.loot_type:
			LootItem.Type.WeaponSMG:
				_check(player.node_weapon_manager.smg_unlocked and player.node_weapon_manager.slot1.ammo_back_cur == player.node_weapon_manager.slot1.ammo_back_max, "SMG 备弹补满并解锁")
			LootItem.Type.WeaponShortgun:
				_check(player.node_weapon_manager.shortgun_unlocked and player.node_weapon_manager.slot2.ammo_back_cur == player.node_weapon_manager.slot2.ammo_back_max, "霰弹枪备弹补满并解锁")
			LootItem.Type.MedicalKit:
				_check(player.node_health.health == 75, "医疗包恢复 35 点")
			LootItem.Type.EquipmentGrenade, LootItem.Type.EquipmentMolotov:
				_check(player.equipment_amount == 10, "装备补给为 10 个")
			LootItem.Type.EquipmentShield:
				_check(player.shield_health == 50, "护盾商品发放 50 点")
			LootItem.Type.CurrencyResearch:
				_check(CurrencyManager.run_research > research_before, "研究商品进入本局收益")
	var medkit := catalog.products[2]
	player.node_health.health = player.node_health.health_max
	var full_offer := _make_offer(world, medkit)
	var before_full := CurrencyManager.money
	_check(full_offer.try_purchase(player) and CurrencyManager.money == before_full - medkit.price, "按用户要求满血购买仍扣款消耗")
	player.node_weapon_manager.slot1.set_ammo_from_total(100000)
	var full_weapon := _make_offer(world, catalog.products[0])
	var before_weapon := CurrencyManager.money
	_check(full_weapon.try_purchase(player) and CurrencyManager.money == before_weapon - full_weapon.product.price, "满弹药仍扣款消耗")
	var medical_pickup := load("res://Prefab/Item/medical_kit.tscn").instantiate() as LootItem
	world.add_child(medical_pickup)
	_check(medical_pickup.type == LootItem.Type.MedicalKit and medical_pickup.num == 35 and medical_pickup.sprite.texture != null, "独立医疗包预制体可直接使用")
	medical_pickup.queue_free()

	var physical_offer := _make_offer(world, medkit)
	physical_offer.position = Vector2(6000, 6000)
	physical_offer.sig_purchase_result.connect(func(_success: bool, _message: String): _feedbacks += 1)
	CurrencyManager.money = medkit.price - 1
	player.position = physical_offer.position
	await _physics_frames()
	_check(not physical_offer.sold and CurrencyManager.money == medkit.price - 1 and _feedbacks == 0, "医疗包进入范围只显示提示，不自动购买")
	physical_offer.confirm_purchase()
	_check(not physical_offer.sold and CurrencyManager.money == medkit.price - 1 and _feedbacks == 1, "真实触碰余额不足不扣款、不消失，仅一次提示")
	await _physics_frames()
	_check(_feedbacks == 1, "持续站立不反复触发失败音")
	CurrencyManager.money = medkit.price
	player.position += Vector2(200, 0)
	await _physics_frames()
	player.position = physical_offer.position
	await _physics_frames()
	_check(is_instance_valid(physical_offer) and CurrencyManager.money == medkit.price, "返回商品范围仍需确认")
	physical_offer.confirm_purchase()
	await _physics_frames()
	_check(not is_instance_valid(physical_offer) and CurrencyManager.money == 0 and _feedbacks == 2, "离开再进入确认购买，余额恰好可支付")
	player.position = Vector2(10000, 10000)

	# 武器需确认：真实进入范围不扣款，回声和范围外确认均不得购买。
	var keyboard_offer := _make_offer(world, catalog.products[0])
	keyboard_offer.position = Vector2(6000, 6000)
	CurrencyManager.money = 100
	player.position = keyboard_offer.position
	await _physics_frames()
	_check(not keyboard_offer.sold and CurrencyManager.money == 100 and keyboard_offer.purchase_prompt.visible, "武器触碰仅显示确认提示，不自动扣款")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	enter.echo = true
	keyboard_offer._input(enter)
	_check(not keyboard_offer.sold, "回车长按回声不购买")
	player.position += Vector2(200, 0)
	await _physics_frames()
	enter.echo = false
	keyboard_offer._input(enter)
	_check(not keyboard_offer.purchase_prompt.visible and CurrencyManager.money == 100, "离开武器范围隐藏提示，回车不能远程购买")
	player.position = keyboard_offer.position
	await _physics_frames()
	CurrencyManager.money = 0
	keyboard_offer._input(enter)
	_check(not keyboard_offer.sold and keyboard_offer.purchase_prompt.visible, "确认后钱不够仍保留武器与提示")
	CurrencyManager.money = 100
	keyboard_offer._input(enter)
	_check(keyboard_offer.sold and CurrencyManager.money == 65 and not keyboard_offer.purchase_prompt.visible, "回车确认购买武器并隐藏提示")
	await _physics_frames()

	var gamepad_offer := _make_offer(world, catalog.products[1])
	gamepad_offer.position = Vector2(6000, 6000)
	CurrencyManager.money = 100
	await _physics_frames()
	var a_button := InputEventJoypadButton.new()
	a_button.button_index = JOY_BUTTON_A
	a_button.pressed = true
	var added_binding := not InputMap.action_has_event("use_skill", a_button)
	if added_binding:
		InputMap.action_add_event("use_skill", a_button)
	player.skill_type = LootItem.Type.SkillSprint
	Input.action_press("move_right")
	Input.parse_input_event(a_button.duplicate())
	Input.flush_buffered_events()
	player._update_skill_input(0.0)
	_check(gamepad_offer.sold and CurrencyManager.money == 65 and not player.sprint_active, "手柄 A 购买且不同时触发角色技能")
	Input.action_release("move_right")
	a_button.pressed = false
	Input.parse_input_event(a_button.duplicate())
	Input.flush_buffered_events()
	_check(not player._shop_confirmation_held, "释放 A 恢复技能输入")
	if added_binding:
		InputMap.action_erase_event("use_skill", a_button)
	await _physics_frames()

	var touch_offer := _make_offer(world, catalog.products[0])
	touch_offer.position = Vector2(6000, 6000)
	CurrencyManager.money = 100
	await _physics_frames()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(2, 2)
	touch_offer._input(touch)
	_check(touch_offer.purchase_prompt.visible and touch_offer.purchase_button.visible and not touch_offer.sold, "触屏仅进入商品范围时显示独立购买按钮")
	get_tree().paused = true
	touch_offer.confirm_purchase()
	_check(not touch_offer.sold and CurrencyManager.money == 100, "暂停时无法确认购买")
	get_tree().paused = false
	touch_offer.modulate.a = 0.0
	touch_offer._update_purchase_prompt()
	_check(not touch_offer.purchase_prompt.visible, "房间淡出不残留 CanvasLayer 购买按钮")
	touch_offer.modulate.a = 1.0
	player.position += Vector2(200, 0)
	await _physics_frames()
	_check(not touch_offer.purchase_prompt.visible, "触屏玩家离开商品立即隐藏按钮")
	player.position = touch_offer.position
	await _physics_frames()
	touch.position = touch_offer.purchase_button.get_global_rect().get_center()
	touch_offer._input(touch)
	_check(touch_offer.sold and CurrencyManager.money == 65 and not touch_offer.purchase_prompt.visible, "点击独立触屏按钮只购买一次并隐藏")
	await _physics_frames()
	player.position = Vector2(10000, 10000)

	var dead_offer := _make_offer(world, medkit)
	CurrencyManager.money = 100
	player.node_health.health = 0
	_check(not dead_offer.try_purchase(player) and CurrencyManager.money == 100, "死亡玩家不可购买")
	player.node_health.health = 100
	var reentrant_offer := _make_offer(world, medkit)
	var callback := func(_snapshot: Dictionary): reentrant_offer.try_purchase(player)
	CurrencyManager.sig_currency_changed.connect(callback)
	_check(reentrant_offer.try_purchase(player) and CurrencyManager.money == 100 - medkit.price, "钱包信号同步重入不会重复扣款")
	CurrencyManager.sig_currency_changed.disconnect(callback)

	for theme: BattlefieldTheme in GameManager.level_pool.themes:
		var room_scene := load(theme.room_template_root + "/Room_1x1_01/Room_1x1_01.tscn") as PackedScene
		var room := room_scene.instantiate() as FortressRoomTemplate
		room.battlefield_theme = theme
		room.population_seed = 321
		room.configure_room({"id": 8, "size": Vector2i.ONE, "type": "merchant"}, {"north": [], "east": [], "south": [], "west": [0]})
		world.add_child(room)
		room.activate_room()
		var lazy := room.get_node("LazyContent")
		_check(lazy.get_child_count() == 1 and lazy.get_child(0) is MerchantRoom, "各主题商人房仅生成商店")
		_check(room.is_room_safe() and room._clear_signal_sent, "商人房立即安全开门")
		var shop := lazy.get_child(0) as MerchantRoom
		_check(shop.get_node("Offers").get_child_count() == 3, "各主题商人房包含三件商品")
		_check(shop.feedback_audio.bus == &"SFX" and MerchantRoom.PURCHASE_SOUND.get_class() == "AudioStreamWAV" and MerchantRoom.DENIED_SOUND.get_class() == "AudioStreamWAV", "两种反馈音效接入 SFX 总线")
		var offer := shop.get_node("Offers").get_child(0) as ShopOffer
		CurrencyManager.money = 100
		_check(offer.try_purchase(player), "房间商品可购买")
		await get_tree().process_frame
		room.activate_room()
		_check(shop.get_node("Offers").get_child_count() == 2, "重入商人房不补货")
		room.queue_free()
		await get_tree().process_frame
	# 正式控制器从生成图实例化各主题房间，首次进入商人房时才创建库存。
	for theme: BattlefieldTheme in GameManager.level_pool.themes:
		var controller := TestController.new()
		controller.battlefield_theme = theme
		world.add_child(controller)
		controller.start_level(3, 20261008)
		var merchant_id := -1
		for data: Dictionary in controller.level_map.rooms:
			if str(data.type) == "merchant":
				merchant_id = int(data.id)
		var merchant := controller._room_nodes.get(merchant_id) as FortressRoomTemplate
		_check(merchant != null and merchant.room_size_units == Vector2i.ONE and merchant.room_type == "merchant", "正式控制器构建各主题商人房")
		_check(not merchant.has_node("LazyContent"), "未进入的商人房不提前生成库存")
		controller._activate_room_contents(merchant_id)
		_check(merchant.get_node("LazyContent").get_child(0) is MerchantRoom and merchant.is_room_safe(), "正式控制器激活商人房无怪物")
		controller.queue_free()
		await get_tree().process_frame
	# 等主题切换的原有音乐淡出结束再退出，避免测试中快速换七次主题留下未释放播放器。
	await get_tree().create_timer(1.0).timeout
	CurrencyManager.close_run()
	CurrencyManager.money = 100
	_check(not dead_offer.try_purchase(player) and CurrencyManager.money == 100, "关闭的钱包不可购买")
	CurrencyManager.money = 0
	world.queue_free()
	await get_tree().process_frame
	print("MERCHANT_TEST checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## 创建远离测试玩家的独立商品，避免手动事务检查被物理触碰干扰。
func _make_offer(world: Node2D, product: ShopProduct) -> ShopOffer:
	var offer := load("res://Prefab/Merchant/shop_offer.tscn").instantiate() as ShopOffer
	offer.product = product
	offer.position = Vector2(-10000, -10000)
	world.add_child(offer)
	return offer


## 检查拓扑的唯一性、1×1 尺寸、单入口可达、非必经、不重叠及 Boss 路径约束。
func _check_map(level_map: Dictionary) -> void:
	var rooms: Array[Dictionary] = []
	rooms.assign(level_map.rooms)
	var merchants: Array[Dictionary] = []
	var battle_supply_rooms: Array[Dictionary] = []
	for room: Dictionary in rooms:
		if str(room.type) == "merchant":
			merchants.append(room)
		elif str(room.type) == "combat_supply":
			battle_supply_rooms.append(room)
	_check(merchants.size() == 1, "每关恰好一间商人房")
	_check(battle_supply_rooms.size() == 1, "每关恰好一间战斗补给房")
	if merchants.size() != 1:
		return
	var merchant := merchants[0]
	_check(merchant.size == Vector2i.ONE, "商人房为 1×1")
	_check(FortressRoomGenerator._room_degree(merchant.id, level_map.connections) == 1, "商人为单入口可选分支")
	_check(not level_map.main_path.has(merchant.id) and merchant.parent_id != level_map.boss_room_id, "商人不在主路线且不连接 Boss")
	_check(FortressRoomGenerator._all_rooms_reachable(rooms.size(), level_map.connections), "所有房间包括商人均可达")
	_check(FortressRoomGenerator._room_degree(level_map.boss_room_id, level_map.connections) == 1, "Boss 仍单入口")
	var limits := FortressRoomGenerator._get_path_limits(level_map.level)
	var steps := FortressRoomGenerator._shortest_path_length(rooms.size(), level_map.connections, 0, level_map.boss_room_id)
	_check(steps >= limits.x and steps <= limits.y, "Boss 主路线步数仍符合设计")
	for room: Dictionary in rooms:
		if room.id != merchant.id:
			_check(not Rect2i(merchant.origin, merchant.size).intersects(Rect2i(room.origin, room.size)), "商人不与已有房间重叠")
	if battle_supply_rooms.size() != 1:
		return
	var battle_supply := battle_supply_rooms[0]
	_check(battle_supply.size == Vector2i.ONE, "战斗补给房为 1×1")
	_check(FortressRoomGenerator._room_degree(battle_supply.id, level_map.connections) == 1, "战斗补给房是单入口支路")
	_check(not level_map.main_path.has(battle_supply.id) and battle_supply.parent_id != level_map.boss_room_id, "战斗补给房不在主路线且不连接 Boss")
	_check(FortressRoomGenerator._all_rooms_reachable(rooms.size(), level_map.connections), "战斗补给房可从起点到达")
	for room: Dictionary in rooms:
		if room.id != battle_supply.id:
			_check(not Rect2i(battle_supply.origin, battle_supply.size).intersects(Rect2i(room.origin, room.size)), "战斗补给房不与已有房间重叠")


## 等待物理状态刷新和信号派发，验证 Area2D 的真实进入/离开事件。
func _physics_frames() -> void:
	for index: int in range(4):
		await get_tree().physics_frame


## 统一累计断言，失败输出具体合同，进程末尾返回非零状态。
func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[MerchantTest] " + message)

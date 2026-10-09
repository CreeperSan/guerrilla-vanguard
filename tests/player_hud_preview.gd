## 体力与敌人方位提示的图形检查入口；仅截图，不运行对局或保存研究账户。
extends Node2D

## 预览使用正式 HUD，跳过倒计时/输入配置，固定展示体力与屏幕外方向提示。
class PreviewHUD extends GameHUD:
	## 预览直接设置状态，避免截图时出现开场倒计时。
	func _ready() -> void:
		pass


## 使用真实大房间、玩家、HUD 和摄像机，敌人使用无 AI 的测试目标以稳定截图。
func _ready() -> void:
	var room := load("res://Scene/LevelFortress/Room_2x2_01/Room_2x2_01.tscn").instantiate() as FortressRoomTemplate
	room.populate_on_first_entry = false
	room.configure_room({"id": 7, "size": Vector2i(2, 2), "type": "combat"}, {"north": [0], "east": [0], "south": [], "west": []})
	add_child(room)
	var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.stamina = 45.0
	player.skill_type = LootItem.Type.SkillSprint
	var camera := Camera2D.new()
	add_child(camera)
	camera.force_update_scroll()
	var hud := load("res://Scene/UI/HUD/HUD.tscn").instantiate() as GameHUD
	hud.set_script(PreviewHUD)
	add_child(hud)
	for overlay: String in ["StartOverlay", "PauseOverlay", "DefeatOverlay", "VictoryOverlay", "RunModeOverlay"]:
		hud.get_node("UIRoot/" + overlay).hide()
	hud._game_started = true
	hud.set_score(0)
	hud.set_health(100, 100)
	hud.set_stamina(player.stamina, player.stamina_max)
	hud.set_enemy_hint_player(player)
	hud.set_weapon(player.node_weapon_manager.active_slot)
	hud.set_ammo(12, 0)
	hud.set_equipment(Player.EquipmentType.GRENADE, 10, false)
	hud.set_skill(LootItem.Type.SkillSprint, 0.0, 0.3, false)
	hud.set_room_map({"rooms": [{"id": 7, "origin": Vector2i.ZERO, "size": Vector2i(2, 2), "type": "combat"}], "connections": []}, 7, [7])
	for position_value: Vector2 in [Vector2(700, 0), Vector2(900, 0), Vector2(-700, 100), Vector2(50, -700), Vector2(150, 700)]:
		var enemy := Node2D.new()
		enemy.add_to_group("enemies")
		enemy.position = position_value
		room.add_child(enemy)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	hud._enemy_hints.refresh_hints()
	# 等待渐入和平滑状态稳定后截图，避免把首帧低透明度误当作最终效果。
	for frame: int in range(30):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://docs/art/player_stamina_enemy_hints_preview.png")
	print("PLAYER_HUD_PREVIEW saved=%s hints=%d" % [error == OK, hud._enemy_hints.hints.size()])
	get_tree().quit(0 if error == OK else 1)

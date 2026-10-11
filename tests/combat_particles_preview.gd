## 粒子与 HUD 图形预览：沿用真实关卡背景，冻结 AI，截图不创建战报或结算。
extends Node


## 展示同一场景中的脚边扬尘、弹着点和爆炸碎屑，并预览首页新增入口。
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var level := load("res://Scene/LevelFortress/FortressLevel.tscn").instantiate() as FortressLevelController
    add_child(level)
    var hud := level.controlled_hud
    hud.enable_run_ui()
    # 让 HUD 的初始延迟倒计时在 waiting 状态下退出，再隐藏开场遮罩。
    await get_tree().process_frame
    hud.show_level_entry()
    hud.show_boss_health("装甲指挥官", 420, 600, 2)
    var player := level.controlled_player as Player
    player.set_process(false)
    player.set_physics_process(false)
    player.anim.play("move_right")
    player.global_position = level._room_nodes[level.current_room_id].global_position + Vector2(-65, 50)
    get_tree().paused = true
    # 预览允许效果在暂停世界中播放，正式效果仍遵循世界暂停状态。
    for entry: Array in [["WalkingDust", Vector2(-80, 60), Vector2.LEFT, 1.6], ["BulletImpact", Vector2(25, 10), Vector2.LEFT, 1.6], ["ExplosionDebris", Vector2(105, 50), Vector2.ZERO, 1.2]]:
        var effect := CombatParticleBurst.spawn(load("res://Prefab/Effects/%s.tscn" % entry[0]), level, level._room_nodes[level.current_room_id].global_position + entry[1], entry[2], entry[3])
        effect.process_mode = Node.PROCESS_MODE_ALWAYS
    await get_tree().create_timer(0.17, true).timeout
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("/private/tmp/gv-combat-particles.png")
    level.free()
    get_tree().paused = false
    var menu := load("res://Scene/MainMenu/MainMenu.tscn").instantiate() as Control
    add_child(menu)
    await get_tree().create_timer(0.35, true).timeout
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("/private/tmp/gv-menu-credits.png")
    RunStats.recording = false
    get_tree().quit()

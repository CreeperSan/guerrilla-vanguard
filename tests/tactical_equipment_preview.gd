## 战术装备运行时预览：真实奖励界面与图标，--capture 输出截图后退出。
extends Node2D


## 真实玩家只关闭输入，不替换装备组件或奖励界面代码。
func _ready() -> void:
    RenderingServer.set_default_clear_color(Color("111c17"))
    var player := preload("res://Prefab/Player/player.tscn").instantiate() as Player
    add_child(player)
    player.position = Vector2(640, 360)
    player.set_process(false)
    player.set_physics_process(false)
    player.node_weapon_manager.set_process(false)
    player.tactical_equipment.initialize()
    var interface := preload("res://Scene/UI/Tactical/TacticalInterface.tscn").instantiate() as TacticalInterface
    add_child(interface)
    var reward := TacticalReward.new()
    reward.position = Vector2(640, 460)
    reward._rolled = true
    reward._choice_ids = [&"light_vest", &"holy_crowbar", &"last_round"]
    add_child(reward)
    await get_tree().process_frame
    interface.open_reward(reward)
    if "--capture" in OS.get_cmdline_user_args():
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("res://docs/art/tactical_reward_preview.png")
        interface.close()
        player.tactical_equipment.obtain(&"ancient_coin")
        player.tactical_equipment.obtain(&"quick_hands")
        player.tactical_equipment.obtain(&"light_vest")
        player.tactical_equipment.obtain(&"holy_crowbar")
        interface.open_inventory()
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("res://docs/art/tactical_inventory_preview.png")
        interface.close()
        reward.hide()
        var merchant := preload("res://Prefab/Merchant/merchant_room.tscn").instantiate() as MerchantRoom
        merchant.position = Vector2(640, 360)
        merchant.stock_seed = 20261010
        add_child(merchant)
        player.position = merchant.position + Vector2(150, -105)
        await get_tree().create_timer(0.15).timeout
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("res://docs/art/tactical_shop_preview.png")
        get_tree().quit()

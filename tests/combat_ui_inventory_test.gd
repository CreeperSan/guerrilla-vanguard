## 前台换弹、装备覆盖拾取、圆形 HUD 和战术图标的实际接入测试，不写账户。
extends Node

var _checks := 0
var _failures := 0


## 测试观察者在 T 键弹窗暂停时仍可关闭弹窗并继续检查。
func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    _run.call_deferred()


## 手动推进武器计时，验证切枪不会完成旧枪装填，也不会提前消耗备弹。
func _run() -> void:
    var world := Node2D.new()
    add_child(world)
    var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
    player.position = Vector2(4000, 4000)
    world.add_child(player)
    player.set_process(false)
    player.set_physics_process(false)
    var manager := player.node_weapon_manager
    manager.set_process(false)
    var rpg := PlayerWeaponRPG.new()
    _check(rpg.ammo_magazine_cur == 1 and rpg.ammo_back_cur == 3, "RPG 基础弹药为 1 / 3")
    rpg.free()
    player.obtain_equipment_from_loot(LootItem.Type.EquipmentGrenade, 1)
    player.equipment_amount = 7
    player.obtain_equipment_from_loot(LootItem.Type.EquipmentGrenade, 1)
    _check(player.equipment_amount == 2, "同类手雷拾取覆盖原有数量")
    player.obtain_equipment_from_loot(LootItem.Type.EquipmentMolotov, 1)
    player.equipment_amount = 1
    player.obtain_equipment_from_loot(LootItem.Type.EquipmentMolotov, 1)
    _check(player.equipment_type == Player.EquipmentType.MOLOTOV and player.equipment_amount == 2, "燃烧弹同类覆盖并支持替换装备")
    manager.unlock_smg()
    manager.slot1.ammo_magazine_cur = 0
    manager.slotDefault.ammo_magazine_cur = 0
    var back_before := manager.slot1.ammo_back_cur
    manager._switch_cooldown_remaining = 0.0
    manager.action_reload()
    _check(manager.slot1.is_reloading and not manager.slotDefault.is_reloading, "换弹键只装填当前武器")
    _check(not manager.slotDefault.try_reload(player), "直接调用后台武器也不能装填")
    manager._process(0.2)
    _check(manager.slot1.reload_time_remaining < manager.slot1.active_reload_duration, "前台换弹正常推进")
    manager.action_switch_next_weapon()
    _check(manager.active_slot == manager.slotDefault and not manager.slot1.is_reloading, "切枪立即取消旧枪换弹")
    _check(manager.slotDefault.is_reloading, "切到空弹匣手枪立即自动装填")
    manager._process(10.0)
    _check(manager.slot1.ammo_magazine_cur == 0 and manager.slot1.ammo_back_cur == back_before, "后台不装填且取消时不消耗备弹")
    manager.action_switch_weapon(1)
    manager._switch_cooldown_remaining = 0.0
    _check(manager.slot1.is_reloading, "切回空弹匣旧枪自动重新换弹")
    _check(is_equal_approx(manager.slot1.reload_time_remaining, manager.slot1.active_reload_duration), "切回自动换弹从完整时长开始")
    manager._process(manager.slot1.active_reload_duration)
    _check(manager.slot1.ammo_magazine_cur > 0 and manager.slot1.ammo_back_cur < back_before, "前台完成后才转移备弹")
    var hud := load("res://Scene/UI/HUD/HUD.tscn").instantiate() as GameHUD
    add_child(hud)
    await get_tree().process_frame
    hud.finish_level_entry()
    var equipment_ring := hud.get_node("UIRoot/ItemPanel/ItemContents/IconVisual/EquipmentCooldownBar") as CircularHUDProgress
    var sprint_ring := hud.get_node("UIRoot/SkillPanel/SkillContents/IconVisual/StaminaBar") as CircularHUDProgress
    var dodge_ring := hud.get_node("UIRoot/SkillPanel/SkillContents/IconVisual/SkillCooldownBar") as CircularHUDProgress
    hud.set_equipment(Player.EquipmentType.GRENADE, 2, false)
    hud.set_equipment_cooldown(0.75, 1.0)
    _check(is_equal_approx(equipment_ring.value, 0.25), "装备圆环复用真实冷却比例")
    hud.set_skill(LootItem.Type.SkillSprint, 0, 1, false)
    hud.set_stamina(25, 100)
    _check(sprint_ring.visible and sprint_ring.value == 25, "奔跑体力以圆环显示")
    hud.set_skill(LootItem.Type.SkillDodge, 0.5, 1, false)
    _check(not sprint_ring.visible and dodge_ring.visible and dodge_ring.value == 50, "闪避冷却切换为技能圆环")
    var interface := hud.get_node("TacticalInterface") as TacticalInterface
    var configs := TacticalCatalog.get_all()
    player.tactical_equipment.obtain(configs[0].id)
    player.tactical_equipment.obtain(configs[1].id)
    var icons := interface.get_node("Root/EquippedIcons") as GridContainer
    _check(icons.get_child_count() == 2, "实际战术库存变化生成两个常驻小图标")
    _check(icons.get_child(0).texture == configs[0].icon and icons.get_child(0).tooltip_text.contains(configs[0].display_name), "常驻图标使用装备资源并附带名称说明")
    var key := InputEventKey.new()
    key.keycode = KEY_T
    key.pressed = true
    Input.parse_input_event(key)
    await get_tree().process_frame
    _check(interface._opened and get_tree().paused, "T 键仍能展开完整战术装备列表")
    interface.close()
    hud._set_control_mode(GameHUD.ControlMode.TOUCH)
    await get_tree().process_frame
    _check(equipment_ring.size.x == equipment_ring.size.y and dodge_ring.size.x == dodge_ring.size.y, "触控布局的冷却环保持正圆")
    hud._set_control_mode(GameHUD.ControlMode.KEYBOARD_MOUSE)
    await get_tree().process_frame
    _check(hud._item_panel.offset_left == -476.0 and hud._item_panel.custom_minimum_size.x == 180, "触控切回桌面恢复场景内紧凑布局")
    if "--visual-preview" in OS.get_cmdline_user_args():
        player.position = Vector2.ZERO
        await _capture("desktop")
        hud._set_control_mode(GameHUD.ControlMode.TOUCH)
        await _capture("touch")
    hud.free()
    world.free()
    print("COMBAT_UI_INVENTORY_TEST checks=%d failures=%d" % [_checks, _failures])
    get_tree().quit(0 if _failures == 0 else 1)


## 图形模式输出两种操作布局，检查圆环大小及图标是否被容器挤压。
func _capture(suffix: String) -> void:
    await get_tree().create_timer(0.1, true).timeout
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("/private/tmp/gv-circular-hud-" + suffix + ".png")


## 汇总可读契约，便于将行为变化与原有测试比较。
func _check(condition: bool, message: String) -> void:
    _checks += 1
    if condition:
        print("PASS ", message)
    else:
        _failures += 1
        push_error(message)

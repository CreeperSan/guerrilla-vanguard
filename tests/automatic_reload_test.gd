## 空弹匣自动装填和切关即时装填的契约；只操作临时角色，不写入账户。
extends Node

var _checks := 0
var _failures := 0


## 延迟到 AutoLoad 与角色组件就绪后开始，手动推进武器计时避免输入干扰。
func _ready() -> void:
    _run.call_deferred()


## 验证最后一发、无输入空匣、闪避重试、备弹不足以及切关的弹药守恒。
func _run() -> void:
    var world := Node2D.new()
    add_child(world)
    var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
    player.position = Vector2(8000, 8000)
    world.add_child(player)
    player.set_process(false)
    player.set_physics_process(false)
    var manager := player.node_weapon_manager
    manager.set_process(false)
    var pistol := manager.slotDefault
    pistol.ammo_magazine_cur = 1
    manager.action_fire(player)
    _check(pistol.ammo_magazine_cur == 0 and pistol.is_reloading, "打出最后一发后立即自动换弹，无需再次开火")
    pistol.cancel_reload()
    manager._process(0.0)
    _check(pistol.is_reloading, "不按任何键，当前空弹匣仍自动换弹")
    pistol.cancel_reload()
    player.dodge_active = true
    manager._process(0.0)
    _check(not pistol.is_reloading, "闪避期间保留动作锁，不强行开始换弹")
    player.dodge_active = false
    manager._process(0.0)
    _check(pistol.is_reloading, "闪避结束自动重试，无需手动操作")
    manager._process(pistol.active_reload_duration)
    _check(pistol.ammo_magazine_cur == pistol.ammo_magazine_max, "无限备弹手枪自动装填完成")
    manager.unlock_smg()
    var smg := manager.slot1
    smg.ammo_magazine_cur = 0
    smg.ammo_back_cur = 0
    manager._process(0.0)
    _check(not smg.is_reloading and smg.ammo_magazine_cur == 0, "没有备弹不启动无效装填、不生成免费弹药")
    smg.ammo_back_cur = 2
    manager._process(0.0)
    _check(smg.is_reloading, "空弹匣获得备弹后自动开始装填")
    manager._process(smg.active_reload_duration)
    _check(smg.ammo_magazine_cur == 2 and smg.ammo_back_cur == 0, "备弹不足只装填实际剩余数量")
    manager.obtain_special_weapon("rpg", 1)
    var rpg := manager.active_slot
    rpg.ammo_magazine_cur = 0
    manager._process(0.0)
    _check(rpg.is_reloading, "RPG 单发打空同样自动装填")
    smg.ammo_magazine_cur = 3
    smg.ammo_back_cur = 5
    pistol.ammo_magazine_cur = 0
    var locked := manager.slot2
    locked.ammo_magazine_cur = 0
    locked.ammo_back_cur = 11
    var rpg_total := rpg.ammo_magazine_cur + rpg.ammo_back_cur
    manager.reload_carried_for_level_entry()
    _check(pistol.ammo_magazine_cur == pistol.ammo_magazine_max, "切关立即装好备用手枪")
    _check(smg.ammo_magazine_cur == 8 and smg.ammo_back_cur == 0, "切关装好携带的后台主武器，仍遵守备弹守恒")
    _check(rpg.ammo_magazine_cur == 1 and rpg.ammo_magazine_cur + rpg.ammo_back_cur == rpg_total, "切关完成当前 RPG 装填但不补充备弹总量")
    _check(not rpg.is_reloading and rpg.reload_time_remaining == 0 and not player.node_reload_audio.playing, "切关取消未完成的计时及音效，不带入新关卡")
    _check(locked.ammo_magazine_cur == 0 and locked.ammo_back_cur == 11, "切关不装填未解锁的武器")
    var after := rpg.ammo_back_cur
    manager.reload_carried_for_level_entry()
    _check(rpg.ammo_back_cur == after, "重复切关装填对已满弹匣不再次扣备弹")
    world.free()
    print("AUTOMATIC_RELOAD_TEST checks=%d failures=%d" % [_checks, _failures])
    get_tree().quit(0 if _failures == 0 else 1)


## 汇总所有契约，以非零退出码报告失败。
func _check(condition: bool, message: String) -> void:
    _checks += 1
    if condition:
        print("PASS ", message)
    else:
        _failures += 1
        push_error(message)

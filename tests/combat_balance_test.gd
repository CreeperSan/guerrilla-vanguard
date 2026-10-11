## 本轮平衡回归：真实拾取、投掷、护盾共用冷却、暂停计时及敌军倍率顺序。
extends Node
var _checks := 0
var _failures := 0

## 场景入口保证自动加载已就绪；测试不改变研究账户或永久配置。
func _ready() -> void:
    _run.call_deferred()

## 将玩家放在远离场景地形的位置，手动推进冷却以稳定验证一秒边界。
func _run() -> void:
    var world := Node2D.new()
    add_child(world)
    var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
    player.position = Vector2(4000, 4000)
    player.process_mode = Node.PROCESS_MODE_PAUSABLE
    world.add_child(player)
    player.set_process(false)
    player.set_physics_process(false)
    player.node_weapon_manager.set_process(false)
    var grenade := PrefabManager.create_loot_item(LootItem.Type.EquipmentGrenade, 1)
    var fire := PrefabManager.create_loot_item(LootItem.Type.EquipmentMolotov, 1)
    _check(grenade.apply_to(player) and player.equipment_amount == 2, "每份手雷实际发放两个")
    _check(grenade.apply_to(player) and player.equipment_amount == 4, "重复手雷拾取每份只增加两个")
    player.use_equipment()
    _check(player.equipment_amount == 3 and player._equipment_cooldown_remaining == 1.0, "成功投掷扣一个并开启一秒冷却")
    player.use_equipment()
    _check(player.equipment_amount == 3, "连续使用不能绕过冷却")
    _check(fire.apply_to(player) and player.equipment_amount == 2, "每份燃烧弹实际发放两个并替换装备")
    player.use_equipment()
    _check(player.equipment_amount == 2, "拾取其他装备不会重置共用冷却")
    player._process(0.99)
    player.use_equipment()
    _check(player.equipment_amount == 2, "未满一秒不能使用新装备")
    player._process(0.02)
    player.use_equipment()
    _check(player.equipment_amount == 1, "超过一秒后可以再次投掷")
    player.obtain_equipment_from_loot(LootItem.Type.EquipmentShield, 1)
    player.use_equipment()
    _check(not player.shield_active, "投掷后马上拾盾不能绕过冷却")
    player._process(1.0)
    player.use_equipment()
    _check(player.shield_active and player.shield_health == 10, "冷却后护盾正常举起")
    player.use_equipment()
    _check(player.shield_active, "护盾举起与收起也受冷却限制")
    # 使用真实 SceneTree 暂停，不能通过暂停菜单等待绕过战斗内冷却。
    var before := player._equipment_cooldown_remaining
    player.set_process(true)
    get_tree().paused = true
    await get_tree().create_timer(0.1, true).timeout
    _check(is_equal_approx(player._equipment_cooldown_remaining, before), "暂停期间装备冷却不推进")
    get_tree().paused = false
    player.set_process(false)
    player._process(1.0)
    player.use_equipment()
    _check(not player.shield_active, "一秒后可以收盾并再次开启冷却")
    player.node_health.health = 100
    _check(player.node_health.damage(3, Definition.Faction.Enemy) == 6, "敌军伤害是原始值的百分之二百")
    _check(player.node_health.damage(3, Definition.Faction.Friend) == 3, "友军伤害不翻倍")
    _check(player.node_health.damage(3, Definition.Faction.Player) == 3, "玩家伤害不翻倍")
    player.node_health.health = 100
    player._process(1.0)
    player.use_equipment()
    player.node_health.damage(3, Definition.Faction.Enemy)
    _check(player.shield_health == 4 and player.health_current == 100, "敌军倍率先于护盾吸收计算")
    player.node_health.damage(3, Definition.Faction.Enemy)
    _check(player.shield_health == 0 and player.health_current == 100, "翻倍后的伤害能破盾且不额外穿透")
    # 无效使用不进入冷却；物品空槽仍可在补给后立即使用。
    player._equipment_cooldown_remaining = 0.0
    player.use_equipment()
    _check(player._equipment_cooldown_remaining == 0.0, "空装备使用不占用冷却")
    grenade.free()
    fire.free()
    world.queue_free()
    await get_tree().process_frame
    print("COMBAT_BALANCE_TEST checks=%d failures=%d" % [_checks, _failures])
    get_tree().quit(1 if _failures else 0)

## 收集全部断言，便于定位平衡参数与行为的差异。
func _check(condition: bool, message: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error(message)

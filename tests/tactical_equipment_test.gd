## 战术装备契约测试：真实玩家/武器/生命/弹丸/商店/奖励，验证能力隔离及组合边界。
extends Node

var _checks: int = 0
var _failures: int = 0
var _world: Node2D
var _player_count: int = 0

## 跳过宿主自动启动流程，保留正式房间事件适配器。
class TestController extends FortressLevelController:
    func _ready() -> void:
        pass


## 使用场景入口保证 AutoLoad 和全局类先就绪。
func _ready() -> void:
    _run.call_deferred()


## 将每组能力放入独立玩家，证明运行时状态不会在不同实例间共享。
func _run() -> void:
    CurrencyManager.begin_run()
    _world = Node2D.new()
    add_child(_world)
    _test_catalog()
    _test_attributes_and_health()
    _test_shots()
    _test_defense_and_rooms()
    await _test_contact_and_magnet()
    _test_grenade_isolation()
    await _test_shop_and_rewards()
    await _test_controller_and_ui()
    _stop_audio(_world)
    _world.queue_free()
    await get_tree().create_timer(0.1).timeout
    await get_tree().process_frame
    print("TACTICAL_EQUIPMENT_TEST checks=%d failures=%d" % [_checks, _failures])
    get_tree().quit(0 if _failures == 0 else 1)


## 定义完整性、可复现抽取、已拥有过滤及奖池耗尽。
func _test_catalog() -> void:
    var all := TacticalCatalog.get_all()
    _check(all.size() == 15, "正式装备数量 15，不含余火罐")
    var ids: Dictionary = {}
    for config: TacticalDefinition in all:
        _check(config.is_valid(), "配置与图标完整：" + config.display_name)
        _check(config.ability_script.new() is TacticalAbility, "独立能力脚本：" + config.display_name)
        _check(not ids.has(config.id), "装备 ID 不重复")
        ids[config.id] = true
        _check(config.icon.get_width() == 96 and config.icon.get_height() == 96, "图集规则格完整")
    var owned: Array[StringName] = [&"ancient_coin", &"quick_hands"]
    var options := TacticalCatalog.select(123, owned)
    _check(options == TacticalCatalog.select(123, owned), "奖励相同种子可复现")
    _check(options.size() == 3, "奖励三选一")
    for config: TacticalDefinition in options:
        _check(config.id not in owned, "奖励过滤已持有")
    owned.clear()
    for id: StringName in ids:
        owned.append(id)
    _check(TacticalCatalog.select(123, owned).is_empty(), "奖池耗尽不会重复生成")


## 基础值保持不变、倍率相乘、生命代价无伪伤害及同名拒绝。
func _test_attributes_and_health() -> void:
    var player := _make_player()
    var component := player.tactical_equipment
    var base_reload := player.node_weapon_manager.slotDefault.reload_duration
    _check(component.obtain(&"quick_hands"), "快手领取成功")
    _check(component.obtain(&"pressure_ammo"), "加压弹药领取成功")
    _near(component.multiplier(&"reload"), 0.9 * 1.15, "换弹收益与代价相乘")
    _near(component.multiplier(&"gun_damage"), 1.2, "枪械独立伤害属性")
    _near(player.node_weapon_manager.slotDefault.reload_duration, base_reload, "不修改永久升级后基础换弹值")
    _check(not component.obtain(&"quick_hands") and component.get_ids().size() == 2, "同名装备不叠加")
    _check(not component.obtain(&"unknown"), "无效装备不污染背包")
    var health_events: Array[int] = []
    player.node_health.sig_health_change.connect(func(value: int): health_events.append(value))
    _check(component.obtain(&"light_vest"), "轻量背心可领取")
    _check(player.health_max == 80 and player.health_current == 80, "生命上限和当前值只截断")
    _check(health_events.is_empty(), "生命上限变化不伪造受伤事件")
    _near(component.multiplier(&"move_speed"), 1.1, "背心移动倍率")
    _check(component.obtain(&"escape_whistle"), "逃生哨可领取")
    player.node_health.damage(10)
    _near(component.multiplier(&"move_speed"), 1.1 * 1.25, "临时加速与背心独立叠加")
    component._physics_process(1.0)
    player.node_health.damage(1)
    component._physics_process(1.5)
    _near(component.multiplier(&"move_speed"), 1.375, "再次受伤刷新而不叠层")
    component._physics_process(0.6)
    _near(component.multiplier(&"move_speed"), 1.1, "到期只移除逃生哨来源")
    _check(component.obtain(&"ancient_coin"), "古老金币可领取")
    _near(component.money_drop_probability(0.65), 0.70, "掉率增加百分点")
    _near(component.money_drop_probability(0.99), 1.0, "掉率封顶")
    _check(component.obtain(&"black_market_card"), "黑市卡可领取")
    _check(component.price_for(35) == 30, "价格折扣向上取整")
    player.node_health.health = 20
    player.node_health.heal(35)
    _check(player.health_current == 48, "所有治疗经过独立负面修正")
    player.node_health.health = 0
    _check(not component.obtain(&"field_bandage"), "死亡不能领取")
    var cleared_after_death := Node.new()
    _world.add_child(cleared_after_death)
    component.clear_room(cleared_after_death, true)
    _check(player.health_current == 0, "死亡不能被被动清场治疗复活")
    var other := _make_player()
    _check(other.tactical_equipment.get_ids().is_empty() and other.health_max == 100, "新局玩家不继承装备或生命代价")
    _near(other.tactical_equipment.multiplier(&"move_speed"), 1.0, "能力状态不跨实例共享")


## 正式发射检查霰弹枪整枪快照、失败射击不消费及换弹时长稳定。
func _test_shots() -> void:
    var player := _make_player()
    var component := player.tactical_equipment
    for id: StringName in [&"last_round", &"tactical_holster", &"shooting_rest", &"pressure_ammo", &"quick_hands"]:
        _check(component.obtain(id), "射击装备安装：" + id)
    var manager := player.node_weapon_manager
    manager.obtain_shortgun(1)
    var weapon := manager.slot2
    weapon.bullet_basic_damage = 10
    weapon.ammo_magazine_cur = 1
    component.stationary_time = 0.8
    player.velocity = Vector2.ZERO
    _near(component.shot_multiplier(weapon), 1.6 * 1.3 * 1.2 * 1.2, "最后一发、切枪、定点和加压快照组合")
    weapon.is_reloading = true
    manager._switch_cooldown_remaining = 0.0
    manager.action_fire(player)
    _near(component.shot_multiplier(weapon), 1.6 * 1.3 * 1.2 * 1.2, "失败射击不消费枪套")
    weapon.is_reloading = false
    var before := _world.get_child_count()
    manager.action_fire(player)
    var bullet_count := 0
    for child: Node in _world.get_children().slice(before):
        if child is ProjectileBullet:
            bullet_count += 1
            _check(child.bullet_damage == roundi(10 * 1.6 * 1.3 * 1.2 * 1.2), "每枚霰弹获得同一次快照")
            child.queue_free()
    _check(bullet_count == weapon.bullet_count, "霰弹枪正式生成全部弹丸")
    _near(component.shot_multiplier(manager.slotDefault), 1.2 * 1.2, "枪套只消费一次，非最后一发无加成")
    manager._select_slot(manager.slotDefault, 0, false)
    _near(component.shot_multiplier(manager.slotDefault), 1.44, "冷却期间切枪不重新获得增伤")
    component._physics_process(3.1)
    manager._select_slot(weapon, 2, false)
    weapon.ammo_magazine_cur = 2
    _near(component.shot_multiplier(weapon), 1.3 * 1.44, "冷却完成后再次切枪可以装填")
    player.velocity = Vector2.RIGHT
    _near(component.shot_multiplier(weapon), 1.3 * 1.2, "移动立刻移除定点增益")
    weapon.ammo_magazine_cur = 0
    weapon.ammo_back_cur = 10
    var base := weapon.reload_duration
    _check(weapon.try_reload(player), "正式武器换弹成功")
    _near(weapon.reload_time_remaining, base * 0.9 * 1.15, "实际换弹时长组合")
    var started := weapon.active_reload_duration
    weapon.update_weapon(started / 2.0)
    _near(manager._get_reload_progress(weapon), 0.5, "HUD 使用实际换弹总时长")
    weapon.update_weapon(started / 2.0 + 0.01)
    _check(not weapon.is_reloading and weapon.ammo_magazine_cur > 0, "换弹完成正常补弹")
    var late := _make_player()
    var pistol := late.node_weapon_manager.slotDefault
    pistol.ammo_magazine_cur = 0
    pistol.try_reload(late)
    var duration := pistol.active_reload_duration
    late.tactical_equipment.obtain(&"quick_hands")
    _near(pistol.active_reload_duration, duration, "途中拾取不重启既有换弹")


## 首伤护板不被盾/闪避消费，重入不可刷新；清房治疗只触发一次。
func _test_defense_and_rooms() -> void:
    var player := _make_player()
    var component := player.tactical_equipment
    component.obtain(&"emergency_plate")
    component.obtain(&"field_bandage")
    var room := Node.new()
    var other_room := Node.new()
    _world.add_child(room)
    _world.add_child(other_room)
    component.enter_room(room, true)
    player.dodge_active = true
    player.node_health.damage(10)
    _check(player.health_current == 100, "闪避优先，不扣血")
    player.dodge_active = false
    player.obtain_equipment_from_loot(LootItem.Type.EquipmentShield, 1)
    player.shield_active = true
    player.node_health.damage(10)
    _check(player.health_current == 100 and player.shield_health == 0, "10 点主动盾先消耗至破盾，不用护板")
    player.shield_active = false
    player.node_health.damage(9)
    _check(player.health_current == 91, "敌军伤害先翻倍再由首次护板减半")
    component.enter_room(room, true)
    player.node_health.damage(10)
    _check(player.health_current == 71, "同房通知不刷新护板")
    component.enter_room(other_room, false)
    component.enter_room(room, true)
    player.node_health.damage(10)
    _check(player.health_current == 51, "离开重入同房也不刷新护板")
    component.clear_room(room, true)
    _check(player.health_current == 54, "战地绷带首次清场恢复 3%")
    component.clear_room(room, true)
    component.clear_room(other_room, false)
    _check(player.health_current == 54, "重复清场和安全房不回血")
    component.enter_room(other_room, true)
    player.node_health.damage(10)
    _check(player.health_current == 44, "新房间重新获得一次护板")


## 真实物理接触、按目标冷却、回力一次性和扩大范围的资源白名单。
func _test_contact_and_magnet() -> void:
    var player := _make_player()
    var component := player.tactical_equipment
    component.obtain(&"holy_crowbar")
    component.obtain(&"recoil_spring")
    component.obtain(&"salvage_magnet")
    await _physics_frames()
    var enemy := preload("res://Prefab/EnemySoilder/enemy_soilder.tscn").instantiate() as EnemySoilder
    enemy.position = player.position + Vector2(1, 0)
    _world.add_child(enemy)
    enemy.set_physics_process(false)
    var health := enemy.get_node("Health") as HealthComponent
    health.health_max = 100
    health.health = 100
    await _physics_frames()
    component._physics_process(0.01)
    _check(health.health == 92, "正式敌人 HurtBox 接触受伤")
    component._physics_process(0.01)
    _check(health.health == 92, "持续接触不逐帧造成伤害")
    enemy.global_position = player.global_position
    player.sig_dodge_finished.emit()
    await _physics_frames()
    component._physics_process(0.81)
    _check(health.health == 76, "闪避结束窗口内下一次接触翻倍")
    _near(component.contact_damage(8), 8.0, "回力效果仅消费一次")
    enemy.queue_free()
    # 模拟 Boss 换阶段时同步回满生命，命中成功仍必须消费回力增伤。
    var phase_target := Node2D.new()
    var phase_health := HealthComponent.new()
    phase_health.name = "Health"
    phase_health.health = 10
    phase_health.health_max = 50
    phase_target.add_child(phase_health)
    phase_target.add_to_group("enemies")
    _world.add_child(phase_target)
    phase_health.sig_die.connect(func(): phase_health.health = 50)
    player.sig_dodge_finished.emit()
    var crowbar: TacticalAbility = component._abilities[&"holy_crowbar"]
    _check(crowbar.hit(phase_target), "Boss 同步阶段回血仍判定为有效命中")
    _check(phase_health.health == 50 and component.contact_damage(8) == 8, "阶段切换后回力效果正确消费")
    phase_target.queue_free()
    var money := PrefabManager.create_currency(RunCurrencyWallet.Kind.MONEY, 5)
    money.position = player.position + Vector2(15, 0)
    _world.add_child(money)
    var research := PrefabManager.create_currency(RunCurrencyWallet.Kind.RESEARCH, 5)
    research.position = player.position + Vector2(15, 0)
    _world.add_child(research)
    var weapon := PrefabManager.create_loot_item(LootItem.Type.WeaponSMG)
    weapon.position = player.position + Vector2(15, 0)
    _world.add_child(weapon)
    _check(money.is_magnetic_supply() and not research.is_magnetic_supply() and not weapon.is_magnetic_supply(), "磁环明确白名单")
    var money_before := CurrencyManager.money
    await _physics_frames()
    component._physics_process(0.01)
    _check(CurrencyManager.money == money_before + 5, "扩大范围实际拾取金钱")
    _check(not research.is_queued_for_deletion() and not weapon.is_queued_for_deletion(), "扩大范围不捡研究和武器")
    research.queue_free()
    weapon.queue_free()


## 手雷与其他爆炸物实例隔离，修正入树前快照不改共享碰撞资源。
func _test_grenade_isolation() -> void:
    var player := _make_player()
    player.tactical_equipment.obtain(&"fragment_sleeve")
    var grenade := PrefabManager.create_bullet(Definition.Faction.Player, 25, Vector2.RIGHT, Definition.BulletType.Explosion)
    player.sig_projectile_thrown.emit(grenade)
    _check(grenade.bullet_damage == 23, "手雷伤害降低 10% 并四舍五入")
    var sample := preload("res://Prefab/explosion/explosion.tscn").instantiate()
    var base_radius: float = sample.get_node("CollisionShape2D").shape.radius
    _near(grenade.explosion_radius, base_radius * 1.2, "手雷范围读取正式基础半径")
    sample.free()
    grenade.free()
    var molotov := PrefabManager.create_bullet(Definition.Faction.Player, 2, Vector2.RIGHT, Definition.BulletType.Burning)
    player.sig_projectile_thrown.emit(molotov)
    _check(molotov.bullet_damage == 2 and molotov.explosion_radius == 0, "燃烧瓶完全不受破片装备影响")
    molotov.free()
    var rpg := player.node_weapon_manager.extra_weapons[1]
    _check(rpg.explosion_radius == 72 and rpg.bullet_basic_damage >= 42, "RPG 基础范围与伤害不被手雷修正污染")


## 正式交易、重复扣款保护、折扣本身购买前计算和奖励一次消费。
func _test_shop_and_rewards() -> void:
    var player := _make_player()
    CurrencyManager.money = 1000
    var card := _make_offer(&"black_market_card")
    var before := CurrencyManager.money
    _check(card.try_purchase(player), "可购买黑市卡")
    _check(CurrencyManager.money == before - card.product.price, "本卡首次购买不享受尚未持有的折扣")
    var vest := _make_offer(&"light_vest")
    before = CurrencyManager.money
    _check(vest.try_purchase(player), "折扣后可购买其他装备")
    _check(CurrencyManager.money == before - 30 and player.health_max == 80, "实际折扣与生命代价同时生效")
    var duplicate := _make_offer(&"light_vest")
    before = CurrencyManager.money
    _check(not duplicate.try_purchase(player) and CurrencyManager.money == before and not duplicate.sold, "已持有不扣款不消费商品")
    var poor := _make_offer(&"holy_crowbar")
    CurrencyManager.money = 0
    _check(not poor.try_purchase(player) and not player.tactical_equipment.has_equipment(&"holy_crowbar"), "余额不足不发放装备")
    var reentrant := _make_offer(&"holy_crowbar")
    CurrencyManager.money = 100
    var acquired: Array[bool] = [false]
    var callback := func(_snapshot: Dictionary):
        if not acquired[0]:
            acquired[0] = true
            player.tactical_equipment.obtain(&"holy_crowbar")
    CurrencyManager.sig_currency_changed.connect(callback)
    _check(not reentrant.try_purchase(player) and CurrencyManager.money == 100, "扣款信号重入导致发放失败时精确退款")
    CurrencyManager.sig_currency_changed.disconnect(callback)
    var reward := TacticalReward.new()
    reward.reward_seed = 456
    reward.position = Vector2(-5000, 0)
    _world.add_child(reward)
    var choices := reward.get_choices(player.tactical_equipment)
    _check(choices.size() == 3 and choices == reward.get_choices(player.tactical_equipment), "奖励关闭重开不刷新")
    _check(not reward.claim(player.tactical_equipment, &"unknown"), "任意非候选 ID 无法领取")
    _check(reward.claim(player.tactical_equipment, choices[0].id), "正式候选领取成功")
    _check(not reward.claim(player.tactical_equipment, choices[1].id), "同箱只能领取一次")
    var merchant := preload("res://Prefab/Merchant/merchant_room.tscn").instantiate() as MerchantRoom
    merchant.position = Vector2(-9000, 0)
    _world.add_child(merchant)
    _check(merchant.get_node("Offers").get_child_count() == 3, "原三件补给不改变")
    var tactical_offer := merchant.get_node_or_null("TacticalOffer") as ShopOffer
    _check(tactical_offer != null and tactical_offer.product.is_valid(), "商店额外战术位完整生成")
    await get_tree().process_frame


## 正式控制器接入奖励去重，以及独立界面的暂停所有权和领取卡片。
func _test_controller_and_ui() -> void:
    var player := _make_player()
    var controller := TestController.new()
    _world.add_child(controller)
    controller._player = player
    var room := FortressRoomTemplate.new()
    room.populate_on_first_entry = false
    room.room_type = "boss"
    room.room_id = 1
    room.population_seed = 123
    controller.add_child(room)
    controller._room_nodes[1] = room
    controller.boss_defeated = true
    controller.level_map = {"rooms": [{"id": 1, "type": "boss"}], "boss_room_id": 1}
    controller._create_tactical_reward(room)
    controller._create_tactical_reward(room)
    var rewards: Array[TacticalReward] = []
    for child: Node in room.get_children():
        if child is TacticalReward:
            rewards.append(child)
    _check(rewards.size() == 1, "正式 Boss 适配器只生成一次奖励")
    var interface := preload("res://Scene/UI/Tactical/TacticalInterface.tscn").instantiate() as TacticalInterface
    add_child(interface)
    await get_tree().process_frame
    # 测试多玩家时显式选择目标，正式场景只有一个玩家。
    interface.equipment = player.tactical_equipment
    interface.open_reward(rewards[0])
    _check(get_tree().paused and interface._opened, "奖励面板拥有暂停")
    _check(interface._cards.get_child_count() == 3, "正式界面生成三张完整奖励卡")
    var config := rewards[0].get_choices(player.tactical_equipment)[0]
    interface._claim(config.id)
    _check(not get_tree().paused and player.tactical_equipment.has_equipment(config.id), "领取关闭面板并恢复战斗")
    interface.open_inventory()
    _check(get_tree().paused and interface._cards.get_child_count() == 1, "背包展示本轮装备")
    interface.close()
    get_tree().paused = true
    interface.open_inventory()
    _check(not interface._opened and get_tree().paused, "其他暂停菜单开启时不抢夺暂停")
    get_tree().paused = false
    interface.queue_free()
    controller.queue_free()
    var stage_controller := TestController.new()
    _world.add_child(stage_controller)
    stage_controller._player = player
    stage_controller.controlled_player = player
    player.tactical_equipment.obtain(&"light_vest")
    var inventory := player.tactical_equipment.get_ids()
    var player_id := player.get_instance_id()
    stage_controller.start_level(1, 20261010)
    await get_tree().process_frame
    stage_controller.start_level(2, 20261011)
    await get_tree().process_frame
    _check(player.get_instance_id() == player_id, "正式跨关生成保留玩家实例")
    _check(player.tactical_equipment.get_ids() == inventory and player.health_max == 80, "正式跨关保留装备及属性代价")
    stage_controller.queue_free()


## 每个测试玩家保持正式节点与信号，仅关闭输入和自动计时，以便精确推进能力。
func _make_player() -> Player:
    var player := preload("res://Prefab/Player/player.tscn").instantiate() as Player
    _player_count += 1
    player.position = Vector2(_player_count * 1000, 1000)
    _world.add_child(player)
    player.set_process(false)
    player.set_physics_process(false)
    player.node_weapon_manager.set_process(false)
    player.tactical_equipment.initialize()
    player.tactical_equipment.set_physics_process(false)
    return player


## 正式商品预制体，入树前赋值，避免空配置的中间帧。
func _make_offer(id: StringName) -> ShopOffer:
    var offer := preload("res://Prefab/Merchant/shop_offer.tscn").instantiate() as ShopOffer
    offer.product = ShopProduct.from_tactical(TacticalCatalog.get_definition(id))
    offer.position = Vector2(-7000, 0)
    _world.add_child(offer)
    return offer


## 两个物理帧确保新增 Area2D 完成空间登记与重叠刷新。
func _physics_frames() -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    await get_tree().process_frame


## 汇总所有失败而不中断后续能力检查。
func _check(condition: bool, message: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error("TACTICAL FAIL: " + message)


## 小数倍率比较避免二进制表示差异。
func _near(actual: float, expected: float, message: String) -> void:
    _check(is_equal_approx(actual, expected), "%s (actual=%s expected=%s)" % [message, actual, expected])


## 批量测试同时触发多路音效，退出前释放播放引用并让音频线程完成回收。
func _stop_audio(node: Node) -> void:
    if node is AudioStreamPlayer2D or node is AudioStreamPlayer:
        node.stop()
        node.stream = null
    for child: Node in node.get_children():
        _stop_audio(child)

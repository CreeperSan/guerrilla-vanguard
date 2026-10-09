## 新武器集成回归：真实场景验证拾取/切换、升级、弹丸扫掠、范围伤害与火焰生命周期。
## 只临时替换内存升级等级，不结算、不保存或修改真实账户。
extends Node

## 测试目标显式声明阵营，并通过正式 Health 与 HurtBox 参与碰撞和伤害。
class Target extends Node2D:
    var faction: Definition.Faction = Definition.Faction.Enemy

var _checks: int = 0
var _failures: int = 0
var _world: Node2D


## 等待自动加载就绪，避免测试依赖节点初始化顺序。
func _ready() -> void:
    _run.call_deferred()


## 串行执行有共享物理空间的测试，结束后恢复账户内存并释放场景。
func _run() -> void:
    var levels := CurrencyManager._upgrade_levels.duplicate()
    CurrencyManager._upgrade_levels.clear()
    _world = Node2D.new()
    add_child(_world)
    _test_upgrades()
    CurrencyManager._upgrade_levels.clear()
    _test_pickup_and_switch()
    _test_flame_hits()
    await _test_sniper_sweep()
    await _test_rocket_explosion()
    await _test_flame_motion()
    await _test_impact_and_range_upgrade()
    CurrencyManager._upgrade_levels = levels
    _world.queue_free()
    await get_tree().process_frame
    print("SPECIAL_WEAPONS_TEST checks=%d failures=%d" % [_checks, _failures])
    get_tree().quit(1 if _failures > 0 else 0)


## 满级仍保持 RPG 单发；各武器的容量、射速、射程与换弹升级独立生效。
func _test_upgrades() -> void:
    for id: String in BattlefieldUpgradeConfig.get_config()["upgrades"]:
        CurrencyManager._upgrade_levels[id] = 3
    for weapon: PlayerWeaponSlot in [PlayerWeaponSniper.new(), PlayerWeaponRPG.new(), PlayerWeaponFlamethrower.new()]:
        var base_range := weapon.bullet_basic_range
        var base_gap := weapon.fire_gap
        var base_reload := weapon.reload_duration
        var base_reserve := weapon.ammo_back_max
        weapon.apply_battlefield_upgrades(weapon.weapon_id)
        _check(is_equal_approx(weapon.bullet_basic_range, base_range * 1.3), weapon.weapon_id + " 射程升级")
        if weapon is PlayerWeaponRPG:
            _check(is_equal_approx(weapon.fire_gap, base_gap) and weapon.bullet_basic_damage == 61, "RPG 使用有效的单发伤害升级替代射速")
        else:
            _check(is_equal_approx(weapon.fire_gap, base_gap / 1.24), weapon.weapon_id + " 射速升级")
        _check(is_equal_approx(weapon.reload_duration, base_reload / 1.3), weapon.weapon_id + " 换弹升级")
        _check(weapon.ammo_back_max == roundi(base_reserve * 1.6), weapon.weapon_id + " 备弹升级")
        if weapon is PlayerWeaponRPG:
            _check(weapon.ammo_magazine_max == 1 and is_equal_approx(weapon.explosion_radius, 104.4), "RPG 仍装一打一，爆炸范围升级")
            _check(BattlefieldUpgradeConfig.get_entry("rpg.magazine").is_empty(), "不出售破坏单发机制的 RPG 弹匣升级")
        else:
            _check(weapon.ammo_magazine_max == (7 if weapon is PlayerWeaponSniper else 116), "狙击与喷火弹匣升级")
        weapon.apply_battlefield_upgrades(weapon.weapon_id)
        _check(is_equal_approx(weapon.bullet_basic_range, base_range * 1.3), "重复应用不叠加")
        weapon.free()


## 真实物品应用后，数字槽与轮换能选中新武器；重拾仅补备弹、弹尽后丢弃。
func _test_pickup_and_switch() -> void:
    var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
    player.position = Vector2(10000, 10000)
    _world.add_child(player)
    player.set_process(false)
    player.set_physics_process(false)
    var manager := player.node_weapon_manager
    manager.set_process(false)
    var types := [LootItem.Type.WeaponSniper, LootItem.Type.WeaponRPG, LootItem.Type.WeaponFlamethrower]
    for index: int in range(3):
        var weapon := manager.extra_weapons[index]
        var item := PrefabManager.create_loot_item(types[index], 1)
        weapon.ammo_magazine_cur = 0
        weapon.ammo_back_cur = 0
        _check(item.apply_to(player) and manager.active_slot == weapon, "首次拾取解锁并选中新武器")
        _check(weapon.ammo_magazine_cur == 0 and weapon.ammo_back_cur == weapon.ammo_back_max, "只补备弹，空弹匣不变")
        _check(not item.apply_to(player), "满备弹拒绝重复消耗地面武器")
        _check(weapon.try_reload(player), "空弹匣能正常装填")
        weapon.update_weapon(weapon.reload_duration)
        _check(weapon.ammo_magazine_cur == weapon.ammo_magazine_max, "换弹转移备弹")
        var magazine_before := weapon.ammo_magazine_cur
        manager._switch_cooldown_remaining = 0.0
        manager.action_fire(player)
        var shots: Array[ProjectileBullet] = []
        for child: Node in _world.get_children():
            if child is ProjectileBullet:
                shots.append(child)
        _check(shots.size() == 1 and weapon.ammo_magazine_cur == magazine_before - 1, "真实管理器开火创建一弹并扣弹药")
        if not shots.is_empty():
            _check(shots[0].projectile_style == weapon.projectile_style and shots[0].bullet_penetration == weapon.bullet_penetration, "差异化弹丸参数接入正式射击")
        _check(player.node_fire_audio.stream == weapon.fire_sound, "开火信号播放对应原创音效")
        manager.action_fire(player)
        _check(weapon.ammo_magazine_cur == magazine_before - 1, "开火冷却阻止重复发射")
        for shot: ProjectileBullet in shots:
            shot.free()
        manager._switch_cooldown_remaining = 0.0
        manager.action_switch_weapon(index + 3)
        _check(manager.active_slot_index == index + 3, "数字槽位对应正确")
        item.free()
    manager._switch_cooldown_remaining = 0.0
    manager.action_switch_next_weapon()
    _check(manager.active_slot is PlayerWeaponSniper and manager.get_secondary_slot() is PlayerWeaponRPG, "轮换与 HUD 下一武器一致")
    var flame := manager.extra_weapons[2]
    flame.set_ammo_from_total(0)
    manager._drop_empty_weapon(flame)
    manager._switch_to_best_available_weapon(flame)
    _check(not manager.extra_unlocked.has("flamethrower") and manager.active_slot != flame, "弹尽丢弃并切换可用武器")
    player.free()


## 重叠命中最多结算三名不同敌人；友军不消耗穿透，命中后减速和轻微偏转。
func _test_flame_hits() -> void:
    seed(20261010)
    var weapon := PlayerWeaponFlamethrower.new()
    var flame := _projectile(weapon, Vector2(0, 500))
    var ally := _target(Vector2(5000, 500), Definition.Faction.Friend)
    flame._handle_hit(ally)
    _check(_health(ally) == 100 and is_equal_approx(flame.bullet_speed, 260.0), "火焰忽略友军")
    var targets: Array[Target] = []
    for index: int in range(4):
        targets.append(_target(Vector2(5100 + index * 40, 500)))
    flame._handle_hit(targets[0].get_node("HurtBox"))
    flame._handle_hit(targets[0])
    _check(_health(targets[0]) == 99 and is_equal_approx(flame.bullet_speed, 260.0 * 0.68), "身体和 HurtBox 不重复扣血减速")
    _check(not flame.bullet_direction.is_equal_approx(Vector2.RIGHT) and absf(flame.bullet_direction.angle()) <= 0.12, "命中产生小幅偏转")
    flame._handle_hit(targets[1])
    flame._handle_hit(targets[2])
    flame._handle_hit(targets[3])
    _check(_health(targets[1]) == 99 and _health(targets[2]) == 99 and _health(targets[3]) == 100 and flame._is_finished, "最多三人，第四人不受伤")
    weapon.free()


## 每帧跨越多个薄目标仍能命中；同一弹丸最多伤害六个不同敌人。
func _test_sniper_sweep() -> void:
    var targets: Array[Target] = []
    for index: int in range(7):
        targets.append(_target(Vector2(20 + index * 25, 800), Definition.Faction.Enemy, 1.0))
    await get_tree().physics_frame
    await get_tree().physics_frame
    var weapon := PlayerWeaponSniper.new()
    var bullet := _projectile(weapon, Vector2(0, 800))
    bullet._physics_process(0.2)
    for index: int in range(7):
        _check(_health(targets[index]) == (82 if index < 6 else 100), "高速扫掠及六目标穿透限制 %d" % index)
    weapon.free()


## RPG 到达射程也引爆；真实范围重叠覆盖多个敌人、排除范围外和盟友。
func _test_rocket_explosion() -> void:
    var near := _target(Vector2(75, 1200))
    var second := _target(Vector2(95, 1200))
    var outside := _target(Vector2(140, 1200))
    var ally := _target(Vector2(65, 1220), Definition.Faction.Friend)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var weapon := PlayerWeaponRPG.new()
    var rocket := _projectile(weapon, Vector2(0, 1200))
    rocket.bullet_range = 30.0
    rocket._physics_process(0.2)
    rocket._finish_at(rocket.global_position)
    var explosions: Array[ProjectileExplosion] = []
    for child: Node in _world.get_children():
        if child is ProjectileExplosion:
            explosions.append(child)
    _check(explosions.size() == 1, "终点与重复回调只产生一次爆炸")
    _check(is_equal_approx((explosions[0].get_node("CollisionShape2D").shape as CircleShape2D).radius, 72.0), "爆炸物理半径与设计一致")
    for frame: int in range(4):
        await get_tree().physics_frame
    _check(_health(near) == 58 and _health(second) == 58, "72 像素范围内多目标只扣一次 42 伤害")
    _check(_health(outside) == 100 and _health(ally) == 100, "爆炸不伤害范围外与盟友")
    weapon.free()


## 自由火焰逐渐减速并自行消失；撞墙后反弹衰减，不伤害墙后的目标。
func _test_flame_motion() -> void:
    var weapon := PlayerWeaponFlamethrower.new()
    var flame := _projectile(weapon, Vector2(0, 2000))
    flame._physics_process(0.2)
    _check(flame.bullet_speed < 260.0 and flame.bullet_speed > 0.0, "自由飞行逐渐减速")
    for index: int in range(6):
        flame._physics_process(0.2)
    _check(flame._is_finished, "速度趋零自行消失")
    var wall := StaticBody2D.new()
    wall.position = Vector2(50, 2400)
    wall.collision_layer = Definition.PHYSICS_LAYER_TERRAIN
    wall.collision_mask = 0
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(8, 80)
    collision.shape = shape
    wall.add_child(collision)
    _world.add_child(wall)
    var behind_wall := _target(Vector2(70, 2400))
    await get_tree().physics_frame
    await get_tree().physics_frame
    flame = _projectile(weapon, Vector2(0, 2400))
    flame._physics_process(0.3)
    _check(flame.bullet_direction.x < 0.0 and flame.global_position.x < 46.0, "墙面阻挡并反弹火焰")
    _check(_health(behind_wall) == 100, "宽火焰不穿墙伤害敌人")
    flame.queue_free()
    weapon.free()


## 命中触发 RPG 爆炸，墙体截停狙击弹；火焰射程升级延长实际飞行距离。
func _test_impact_and_range_upgrade() -> void:
    var victim := _target(Vector2(40, 2800))
    await get_tree().physics_frame
    await get_tree().physics_frame
    var launcher := PlayerWeaponRPG.new()
    var rocket := _projectile(launcher, Vector2(0, 2800))
    rocket._physics_process(0.2)
    _check(rocket._is_finished and rocket.global_position.x < 45.0, "火箭命中目标立即引爆")
    for frame: int in range(4):
        await get_tree().physics_frame
    _check(_health(victim) == 58, "火箭直接命中通过爆炸只造成一次伤害")
    launcher.free()
    var wall := StaticBody2D.new()
    wall.position = Vector2(50, 3200)
    wall.collision_layer = Definition.PHYSICS_LAYER_TERRAIN
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(8, 80)
    collision.shape = shape
    wall.add_child(collision)
    _world.add_child(wall)
    var behind_wall := _target(Vector2(80, 3200))
    await get_tree().physics_frame
    await get_tree().physics_frame
    var rifle := PlayerWeaponSniper.new()
    var sniper := _projectile(rifle, Vector2(0, 3200))
    sniper._physics_process(0.2)
    _check(sniper._is_finished and _health(behind_wall) == 100, "狙击穿透敌人但不穿实墙")
    rifle.free()
    var flame_weapon := PlayerWeaponFlamethrower.new()
    var base_flame := _projectile(flame_weapon, Vector2(0, 3600))
    while not base_flame._is_finished:
        base_flame._physics_process(1.0 / 60.0)
    var base_distance := base_flame._travelled_distance
    CurrencyManager._upgrade_levels["flamethrower.range"] = 3
    flame_weapon.apply_battlefield_upgrades("flamethrower")
    CurrencyManager._upgrade_levels.clear()
    var upgraded := _projectile(flame_weapon, Vector2(0, 4000))
    while not upgraded._is_finished:
        upgraded._physics_process(1.0 / 60.0)
    _check(upgraded._travelled_distance > base_distance * 1.25, "火焰射程升级实际延长减速飞行距离")
    flame_weapon.free()


## 从正式武器配置创建正式弹丸，测试与开火入口使用相同参数。
func _projectile(weapon: PlayerWeaponSlot, origin: Vector2) -> ProjectileBullet:
    var bullet := PrefabManager.create_bullet(Definition.Faction.Player, weapon.bullet_basic_damage, Vector2.RIGHT, weapon.bullet_type)
    bullet.projectile_style = weapon.projectile_style
    bullet.bullet_penetration = weapon.bullet_penetration
    bullet.bullet_speed = weapon.bullet_basic_speed
    bullet.bullet_range = weapon.bullet_basic_range
    bullet.bullet_size = weapon.bullet_basic_size
    bullet.explosion_radius = weapon.explosion_radius
    bullet.position = origin
    _world.add_child(bullet)
    bullet.set_physics_process(false)
    return bullet


## 建立独立生命和伤害区域；薄半径用于检验高速扫掠而非手动命中替身。
func _target(origin: Vector2, faction: Definition.Faction = Definition.Faction.Enemy, radius: float = 3.0) -> Target:
    var target := Target.new()
    target.faction = faction
    target.position = origin
    var health := HealthComponent.new()
    health.name = "Health"
    target.add_child(health)
    var hurtbox := HurtBox.new()
    hurtbox.name = "HurtBox"
    hurtbox.collision_layer = 2
    hurtbox.collision_mask = 0
    var collision := CollisionShape2D.new()
    var circle := CircleShape2D.new()
    circle.radius = radius
    collision.shape = circle
    hurtbox.add_child(collision)
    target.add_child(hurtbox)
    _world.add_child(target)
    return target


## 读取正式生命组件的状态，统一验证真实伤害结果。
func _health(target: Target) -> int:
    return (target.get_node("Health") as HealthComponent).health


## 累计断言，输出失败原因并保留剩余检查，方便一次定位边界问题。
func _check(condition: bool, description: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error("[SpecialWeaponsTest] " + description)

## 本轮战术装备容器：管理能力生命周期、来源隔离的修正与通用战斗事件。
## 不处理输入、商品展示或奖励选择，也不修改永久升级数值。
class_name TacticalEquipment
extends Node

signal inventory_changed
signal ability_triggered(id: StringName)

var player: Player
var _abilities: Dictionary = {}
var _modifiers: Dictionary = {}
var _cleared_rooms: Dictionary = {}
var _current_room_key: int = 0
var _current_room_combat: bool = false
var _initialized: bool = false
var _base_health_max: int = 0
var _last_position: Vector2
var stationary_time: float = 0.0
## 正式爆炸基础范围只解析一次，投掷时不反复实例化动画场景。
static var _grenade_base_radius: float = 0.0


## 子节点先于玩家 ready，延迟绑定以保留玩家原有护盾过滤器。
func _ready() -> void:
    initialize.call_deferred()


## 拾取、界面和测试可同步调用；幂等初始化不会重复连接事件。
func initialize() -> void:
    if _initialized:
        return
    player = get_parent() as Player
    if player == null or player.node_health == null or player.node_weapon_manager == null:
        return
    _initialized = true
    _base_health_max = player.health_max
    _last_position = player.global_position
    player.node_health.damage_modifiers.append(_filter_damage)
    player.node_health.heal_modifiers.append(_filter_heal)
    player.node_health.sig_health_change.connect(_on_health_change)
    player.node_weapon_manager.sig_active_weapon_change.connect(_on_weapon_change)
    player.node_weapon_manager.sig_weapon_fired.connect(_on_shot)
    player.sig_dodge_finished.connect(_on_dodge_finished)
    player.sig_projectile_thrown.connect(_on_projectile_thrown)


## 组件退出时还原基础上限并解除所有绑定，避免残留 Callable 持有旧能力。
func _exit_tree() -> void:
    for ability: TacticalAbility in _abilities.values():
        ability.uninstall()
    if not _initialized or not is_instance_valid(player):
        return
    var health := player.node_health
    if is_instance_valid(health):
        health.damage_modifiers.erase(_filter_damage)
        health.heal_modifiers.erase(_filter_heal)
        if health.sig_health_change.is_connected(_on_health_change):
            health.sig_health_change.disconnect(_on_health_change)
        health.set_max_health(_base_health_max)
    var weapons := player.node_weapon_manager
    if is_instance_valid(weapons):
        if weapons.sig_active_weapon_change.is_connected(_on_weapon_change):
            weapons.sig_active_weapon_change.disconnect(_on_weapon_change)
        if weapons.sig_weapon_fired.is_connected(_on_shot):
            weapons.sig_weapon_fired.disconnect(_on_shot)
    if player.sig_dodge_finished.is_connected(_on_dodge_finished):
        player.sig_dodge_finished.disconnect(_on_dodge_finished)
    if player.sig_projectile_thrown.is_connected(_on_projectile_thrown):
        player.sig_projectile_thrown.disconnect(_on_projectile_thrown)


## 同名装备不可叠加；只读定义生成独立能力实例，不共享运行时状态。
func obtain(id: StringName) -> bool:
    initialize()
    if not _initialized or player.health_current <= 0 or has_equipment(id):
        return false
    var config := TacticalCatalog.get_definition(id)
    if config == null or not config.is_valid():
        return false
    var ability := config.ability_script.new() as TacticalAbility
    if ability == null:
        return false
    _abilities[id] = ability
    ability.attach(self, config)
    ability.room_entered(_current_room_combat)
    RunStats.tactical(id, config.display_name)
    inventory_changed.emit()
    player.node_pickup_audio.stream = Player.SFX_PICKUP
    player.node_pickup_audio.play()
    return true


## 背包对外只返回 ID 副本，外部不能修改能力字典。
func get_ids() -> Array[StringName]:
    var result: Array[StringName] = []
    for id: StringName in _abilities:
        result.append(id)
    return result


## 奖励与商店统一检查重复装备。
func has_equipment(id: StringName) -> bool:
    return _abilities.has(id)


## 同一来源同一属性覆盖更新，不在原属性上反复乘除；不同来源相乘。
func set_modifier(source: StringName, stat: StringName, value: float) -> void:
    if not _modifiers.has(stat):
        _modifiers[stat] = {}
    _modifiers[stat][source] = value
    if stat == &"max_health" and _initialized:
        player.node_health.set_max_health(maxi(roundi(_base_health_max * multiplier(stat)), 1))


## 没有修正时严格返回 1，供玩家、武器、治疗和交易等通用接口读取。
func multiplier(stat: StringName) -> float:
    var result := 1.0
    for value: float in _modifiers.get(stat, {}).values():
        result *= value
    return result


## 概率采用百分点相加，与伤害等乘法属性分开。
func money_drop_probability(base: float) -> float:
    var bonus := 0.0
    for value: float in _modifiers.get(&"money_chance", {}).values():
        bonus += value
    return clampf(base + bonus, 0.0, 1.0)


## 交易价格统一向上取整，避免小额商品折扣变成免费。
func price_for(base: int) -> int:
    return maxi(ceili(base * multiplier(&"shop_price")), 1)


## 射击前生成一次倍率快照，所有弹丸、RPG 爆炸与喷火弹共用。
func shot_multiplier(weapon: PlayerWeaponSlot) -> float:
    var result := multiplier(&"gun_damage")
    for ability: TacticalAbility in _abilities.values():
        result *= ability.shot_multiplier(weapon)
    return result


## 独立能力每帧推进时间；站定按实际位置判断，堵墙不算实际移动。
func _physics_process(delta: float) -> void:
    if not _initialized or player.health_current <= 0:
        return
    if player.dodge_active or player.global_position.distance_squared_to(_last_position) > 0.001:
        stationary_time = 0.0
    else:
        stationary_time += delta
    _last_position = player.global_position
    for ability: TacticalAbility in _abilities.values():
        ability.tick(delta)


## 进入房间重置定点状态；同房重复状态通知不会重置首伤护板。
func enter_room(room: Node, combat: bool) -> void:
    var key := room.get_instance_id()
    if key == _current_room_key:
        return
    _current_room_key = key
    _current_room_combat = combat
    stationary_time = 0.0
    if is_instance_valid(player):
        _last_position = player.global_position
    for ability: TacticalAbility in _abilities.values():
        ability.room_entered(combat)


## 房间实例 ID 跨关不重用；重复清场以及安全房不会触发回血。
func clear_room(room: Node, combat: bool) -> void:
    var key := room.get_instance_id()
    if not combat or _cleared_rooms.has(key) or player == null or player.health_current <= 0:
        return
    _cleared_rooms[key] = true
    for ability: TacticalAbility in _abilities.values():
        ability.room_cleared()


## 身体接触攻击与枪械分开结算，避免枪械装备强化圣剑。
func contact_damage(base: int) -> int:
    var factor := 1.0
    for ability: TacticalAbility in _abilities.values():
        factor *= ability.contact_multiplier()
    return maxi(roundi(base * factor), 1)


## 成功命中敌人才消耗接触攻击效果，并通知独立视觉反馈。
func commit_contact() -> void:
    for ability: TacticalAbility in _abilities.values():
        ability.contact_committed()
    ability_triggered.emit(&"holy_crowbar")


## 保留原闪避与护盾优先级，正伤害才进入战术减免。
func _filter_damage(value: int) -> int:
    if player.health_current <= 0:
        return value
    for ability: TacticalAbility in _abilities.values():
        if value <= 0:
            break
        value = ability.filter_damage(value)
    return value


## 所有治疗来源走生命组件通用接口，减少独立补给漏掉负面效果的风险。
func _filter_heal(value: int) -> int:
    return maxi(roundi(value * multiplier(&"healing")), 1) if value > 0 else 0


## 仅实际扣血才通知逃生类能力。
func _on_health_change(change: int) -> void:
    if change < 0:
        for ability: TacticalAbility in _abilities.values():
            ability.damaged()


## 管理器只在真正切枪时发布该事件。
func _on_weapon_change(_weapon: PlayerWeaponSlot) -> void:
    for ability: TacticalAbility in _abilities.values():
        ability.weapon_changed()


## 成功发射之后才消费一次性效果。
func _on_shot(weapon: PlayerWeaponSlot) -> void:
    for ability: TacticalAbility in _abilities.values():
        ability.shot_committed(weapon)


## 玩家只发布动作完成事件，回力计时不放在玩家中。
func _on_dodge_finished() -> void:
    stationary_time = 0.0
    for ability: TacticalAbility in _abilities.values():
        ability.dodge_finished()


## 投掷快照只处理手雷，不污染 RPG、燃烧瓶和支援；用正式爆炸场景半径作基础。
func _on_projectile_thrown(bullet: ProjectileBullet) -> void:
    if bullet.bullet_type != Definition.BulletType.Explosion:
        return
    var radius_factor := multiplier(&"grenade_radius")
    if not is_equal_approx(radius_factor, 1.0):
        if _grenade_base_radius <= 0.0:
            var sample := preload("res://Prefab/explosion/explosion.tscn").instantiate()
            var shape := sample.get_node("CollisionShape2D").shape as CircleShape2D
            _grenade_base_radius = shape.radius
            sample.free()
        bullet.explosion_radius = _grenade_base_radius * radius_factor
    bullet.bullet_damage = maxi(roundi(bullet.bullet_damage * multiplier(&"grenade_damage")), 1)


## 稳定的当前房间实例键，供单房次数能力记住重入前的消费状态。
func current_room_key() -> int:
    return _current_room_key

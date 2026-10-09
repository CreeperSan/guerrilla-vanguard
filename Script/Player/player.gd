class_name Player
extends CharacterBody2D

## 玩家唯一装备槽中的装备类型。
enum EquipmentType {
    NONE,
    GRENADE,
    MOLOTOV,
    SHIELD,
}

## 记录最后使用的瞄准设备，避免移动方向覆盖方向键、手柄右摇杆或触控瞄准。
enum AimDevice { KEYBOARD, GAMEPAD, TOUCH }

## 对外转发生命值变化，关卡控制器可以连接 HUD，而不依赖 Health 子节点路径。
signal sig_health_updated(current_health: int, max_health: int)
## 体力统一由玩家管理，HUD 通过信号同步进度，不直接读取输入或计时。
signal sig_stamina_updated(current_stamina: float, max_stamina: float)
## 装备槽变化：装备类型、数量/护盾生命、护盾是否处于启用状态。
signal sig_equipment_updated(equipment_type: EquipmentType, amount: int, shield_active: bool)
## 输入接口：由后续系统连接战场支援和自身技能效果。
signal sig_battle_support_requested
signal sig_battle_support_updated(support_type: LootItem.Type)
signal sig_skill_requested
## 自身技能状态：类型、剩余冷却、冷却总时长和是否正在使用。
signal sig_skill_updated(skill_type: LootItem.Type, cooldown_remaining: float, cooldown_duration: float, is_active: bool)

const SFX_FIRE_SMG: AudioStream = preload("res://Assets/Audio/SFX/smg_fire.wav")
const SFX_FIRE_PISTOL: AudioStream = preload("res://Assets/Audio/SFX/pistol_fire.wav")
const SFX_FIRE_SHORTGUN: AudioStream = preload("res://Assets/Audio/SFX/shortgun_fire.wav")
const SFX_RELOAD: AudioStream = preload("res://Assets/Audio/SFX/reload.wav")
const SFX_PICKUP: AudioStream = preload("res://Assets/Audio/SFX/pickup.wav")
## 货币使用独立的金属音与研究提示音，复用玩家拾取播放器与现有音量控制。
const SFX_MONEY_PICKUP: AudioStream = preload("res://Assets/Audio/SFX/money_pickup.wav")
const SFX_RESEARCH_PICKUP: AudioStream = preload("res://Assets/Audio/SFX/research_pickup.wav")
const SFX_GRENADE_THROW: AudioStream = preload("res://Assets/Audio/SFX/grenade_throw.wav")
const SFX_MOLOTOV_THROW: AudioStream = preload("res://Assets/Audio/SFX/molotov_throw.wav")
const SFX_SHIELD_RAISE: AudioStream = preload("res://Assets/Audio/SFX/shield_raise.wav")
const SFX_SHIELD_LOWER: AudioStream = preload("res://Assets/Audio/SFX/shield_lower.wav")
const SFX_SHIELD_BREAK: AudioStream = preload("res://Assets/Audio/SFX/shield_break.wav")
const SFX_SHIELD_BLOCK: AudioStream = preload("res://Assets/Audio/SFX/shield_block.wav")
const SFX_BATTLE_SUPPORT: AudioStream = preload("res://Assets/Audio/SFX/battle_support.wav")

# 移动速度
@export var prop_move_speed: float = 150

@export_group("奔跑体力")
## 满体力可连续移动奔跑约四秒，停止后三秒等待，再用五秒从零回满。
@export_range(1.0, 999.0, 1.0) var stamina_max: float = 100.0
@export_range(1.0, 999.0, 1.0) var sprint_stamina_cost: float = 25.0
@export_range(1.0, 999.0, 1.0) var stamina_recovery_rate: float = 20.0
@export_range(0.0, 10.0, 0.1) var stamina_recovery_delay: float = 3.0
var stamina: float = 100.0
var _stamina_recovery_wait: float = 0.0
## 体力耗尽时需先松开奔跑键，避免一直按住导致恢复一点便立刻消耗的抖动。
var _sprint_exhausted: bool = false

@onready var anim : AnimatedSprite2D = $AnimatedSprite2D # 动画节点
@onready var node_collect_box: Area2D = $CollectBox # 拾取判定区域
@onready var node_weapon_manager: PlayerWeaponManager = $WeaponManager # 武器管理器
@onready var node_health: HealthComponent = get_node_or_null("Health") as HealthComponent
@onready var node_fire_audio: AudioStreamPlayer2D = $FireAudioPlayer
@onready var node_reload_audio: AudioStreamPlayer2D = $ReloadAudioPlayer
@onready var node_pickup_audio: AudioStreamPlayer2D = $PickupAudioPlayer
@onready var node_equipment_audio: AudioStreamPlayer2D = get_node_or_null("EquipmentAudioPlayer") as AudioStreamPlayer2D
@onready var node_shield_break_audio: AudioStreamPlayer2D = get_node_or_null("ShieldBreakAudioPlayer") as AudioStreamPlayer2D
@onready var node_shield_block_audio: AudioStreamPlayer2D = get_node_or_null("ShieldBlockAudioPlayer") as AudioStreamPlayer2D
@onready var node_shield_outline: Line2D = get_node_or_null("ShieldOutline") as Line2D


var facing_direction : Vector2
var _aim_device: AimDevice = AimDevice.KEYBOARD
## 商店确认占用手柄 A，释放前禁止同键启动角色技能。
var _shop_confirmation_held: bool = false
var _gamepad_aim_valid: bool = false
var _touch_aim_valid: bool = false
var _gamepad_device_id: int = -1
var _last_move_direction: Vector2 = Vector2.DOWN
const AIM_STICK_DEADZONE: float = 0.2

## 玩家唯一装备槽内容；手雷和燃烧瓶按数量消耗，护盾记录当前护盾生命。
var equipment_type: EquipmentType = EquipmentType.NONE
var equipment_amount: int = 0
var shield_health: int = 0
var shield_active: bool = false

## 战场支援槽当前内容；NONE 表示尚未拾取或已使用。
var battle_support_type: LootItem.Type = LootItem.Type.Empty

## 唯一自身技能槽；新技能拾取时替换当前内容。
var skill_type: LootItem.Type = LootItem.Type.Empty
## 奔跑技能按住时生效，供武器管理器阻止射击。
var sprint_active: bool = false
## 闪避期间屏蔽所有进入生命值组件的伤害。
var dodge_active: bool = false

var _skill_cooldown_remaining: float = 0.0
var _dodge_time_remaining: float = 0.0
var _dodge_direction: Vector2 = Vector2.DOWN
## 保存闪避前身体的不透明度，结束后精确还原，避免覆盖角色原本的显示状态。
var _dodge_sprite_alpha: float = 1.0
const SPRINT_COOLDOWN: float = 0.3
const DODGE_SPEED: float = 120.0
const DODGE_DURATION: float = 0.5
const DODGE_COOLDOWN: float = 3.0
const DODGE_ALPHA_MULTIPLIER: float = 0.5

## 对外提供当前生命值，避免关卡脚本读取玩家内部节点。
var health_current: int:
    get:
        return node_health.health if node_health != null else 0

## 对外提供最大生命值，供 HUD 初始化血条范围。
var health_max: int:
    get:
        return node_health.health_max if node_health != null else 0


func _ready() -> void:
    stamina = stamina_max
    sig_stamina_updated.emit(stamina, stamina_max)
    # 加入统一玩家分组，供敌人 AI 在关卡中查找追击目标。
    add_to_group("player")
    # 普通敌人可在玩家与已雇佣佣兵之间选择存活的攻击目标。
    add_to_group("combat_targets")
    # 玩家只与地形和水发生实体碰撞；敌我角色的命中继续由子弹和 HurtBox 单独处理。
    collision_mask = Definition.PHYSICS_LAYER_TERRAIN | Definition.PHYSICS_LAYER_WATER
    facing_direction = Vector2.DOWN
    # 拾取区域事件检测
    node_collect_box.area_entered.connect(on_collect_item)
    # 玩家只转发生命状态，不直接持有或操作 HUD。
    if node_health != null:
        node_health.sig_health_updated.connect(_on_health_updated)
        node_health.damage_filter = _filter_incoming_damage
    # 武器管理器只在实际射击或成功开始换弹时发信号，避免按键无效时播放音效。
    node_weapon_manager.sig_weapon_fired.connect(_on_weapon_fired)
    node_weapon_manager.sig_reload_started.connect(_on_reload_started)
    node_reload_audio.stream = SFX_RELOAD
    node_pickup_audio.stream = SFX_PICKUP
    if node_shield_outline != null:
        node_shield_outline.visible = shield_active
    _emit_equipment_updated()
    _emit_skill_updated()


## 从战利品装入唯一装备槽；手雷和燃烧瓶每件补充 10 个，护盾恢复至 50 点。
func obtain_equipment_from_loot(loot_type: LootItem.Type, item_count: int) -> bool:
    match loot_type:
        LootItem.Type.EquipmentGrenade:
            return _store_equipment(EquipmentType.GRENADE, maxi(item_count, 1) * 10)
        LootItem.Type.EquipmentMolotov:
            return _store_equipment(EquipmentType.MOLOTOV, maxi(item_count, 1) * 10)
        LootItem.Type.EquipmentShield:
            return _store_equipment(EquipmentType.SHIELD, 50)
    return false


## 同类投掷物累加；护盾同类拾取只将护盾生命补满，不叠加上限。
func _store_equipment(new_type: EquipmentType, amount: int) -> bool:
    if equipment_type == EquipmentType.SHIELD and shield_active and new_type != EquipmentType.SHIELD:
        _set_shield_active(false)
        _play_equipment_audio(SFX_SHIELD_LOWER)

    if equipment_type == new_type and new_type in [EquipmentType.GRENADE, EquipmentType.MOLOTOV]:
        equipment_amount += amount
    else:
        equipment_type = new_type
        if new_type == EquipmentType.SHIELD:
            shield_health = 50
            equipment_amount = shield_health
        else:
            shield_health = 0
            equipment_amount = amount

    _emit_equipment_updated()
    return true


## 使用装备键；投掷物向面朝方向发射，护盾按键切换启用状态。
func use_equipment() -> void:
    if sprint_active or dodge_active:
        return
    match equipment_type:
        EquipmentType.GRENADE:
            _throw_equipment(Definition.BulletType.Explosion, 25)
        EquipmentType.MOLOTOV:
            _throw_equipment(Definition.BulletType.Burning, 2)
        EquipmentType.SHIELD:
            _toggle_shield()


## 生成一枚特殊类型投掷弹；只有实例创建成功才扣除装备数量。
func _throw_equipment(bullet_type: Definition.BulletType, damage: int) -> void:
    if equipment_amount <= 0:
        _clear_equipment()
        return

    var bullet: ProjectileBullet = PrefabManager.create_bullet(
        Definition.Faction.Player,
        damage,
        facing_direction.normalized(),
        bullet_type
    )
    if bullet == null:
        return

    # 手雷和燃烧瓶共享投掷速度；相对此前的 180 提高 30%。
    bullet.bullet_speed = 234.0
    bullet.bullet_range = 90.0
    bullet.bullet_size = 3.0
    if bullet_type == Definition.BulletType.Burning:
        bullet.bullet_effect_duration = 5.0
        bullet.bullet_effect_damage_gap = 0.5
    get_parent().add_child(bullet)
    bullet.global_position = global_position + facing_direction.normalized() * 8.0
    equipment_amount -= 1
    var throw_sound: AudioStream = SFX_GRENADE_THROW
    if bullet_type == Definition.BulletType.Burning:
        throw_sound = SFX_MOLOTOV_THROW
    _play_equipment_audio(throw_sound)
    if equipment_amount <= 0:
        _clear_equipment()
    else:
        _emit_equipment_updated()


## 护盾开启时拦截全部本次伤害；破盾时不把超出部分转移给玩家生命值。
func _filter_incoming_damage(incoming_damage: int) -> int:
    if dodge_active:
        return 0
    if not shield_active or equipment_type != EquipmentType.SHIELD:
        return incoming_damage

    if incoming_damage > 0:
        if node_shield_block_audio != null:
            node_shield_block_audio.stream = SFX_SHIELD_BLOCK
            node_shield_block_audio.pitch_scale = randf_range(0.94, 1.06)
            node_shield_block_audio.play()
        else:
            push_warning("玩家场景缺少 ShieldBlockAudioPlayer，护盾抵挡音效无法播放。")

    shield_health = maxi(shield_health - maxi(incoming_damage, 0), 0)
    equipment_amount = shield_health
    if shield_health <= 0:
        _set_shield_active(false)
        equipment_type = EquipmentType.NONE
        equipment_amount = 0
        if node_shield_break_audio != null:
            node_shield_break_audio.stream = SFX_SHIELD_BREAK
            node_shield_break_audio.play()
        else:
            push_warning("玩家场景缺少 ShieldBreakAudioPlayer，护盾破碎音效无法播放。")
    _emit_equipment_updated()
    return 0


## 护盾使用键在举起与收起之间切换，并播放对应反馈音效。
func _toggle_shield() -> void:
    if equipment_type != EquipmentType.SHIELD or shield_health <= 0:
        return
    _set_shield_active(not shield_active)
    _play_equipment_audio(SFX_SHIELD_RAISE if shield_active else SFX_SHIELD_LOWER)
    _emit_equipment_updated()


## 更新护盾启用状态，并同步显示在玩家周围的护盾框。
func _set_shield_active(active: bool) -> void:
    shield_active = active
    if node_shield_outline != null:
        node_shield_outline.visible = active


## 清空装备槽并同步 HUD。
func _clear_equipment(emit_update: bool = true) -> void:
    equipment_type = EquipmentType.NONE
    equipment_amount = 0
    shield_health = 0
    _set_shield_active(false)
    if emit_update:
        _emit_equipment_updated()


## 同步装备槽状态给 HUD。
func _emit_equipment_updated() -> void:
    var amount: int = shield_health if equipment_type == EquipmentType.SHIELD else equipment_amount
    sig_equipment_updated.emit(equipment_type, amount, shield_active)


## 播放装备操作音效。
func _play_equipment_audio(stream: AudioStream) -> void:
    if node_equipment_audio == null:
        push_warning("玩家场景缺少 EquipmentAudioPlayer，装备音效无法播放。")
        return
    node_equipment_audio.stream = stream
    node_equipment_audio.play()


## 战场支援槽不可叠加；已有支援时拾取新类型会替换槽位内容。
func obtain_battle_support_from_loot(loot_type: LootItem.Type) -> bool:
    if loot_type not in [LootItem.Type.SupportMortarStriker, LootItem.Type.SupportTacticalBombing]:
        return false
    battle_support_type = loot_type
    sig_battle_support_updated.emit(battle_support_type)
    return true


## 使用并消耗战场支援；支援场景在玩家当前位置创建，并固定其打击中心。
func use_battle_support() -> void:
    if sprint_active or dodge_active:
        return
    if battle_support_type == LootItem.Type.Empty:
        return
    var support: Node2D = null
    match battle_support_type:
        LootItem.Type.SupportMortarStriker:
            support = PrefabManager.create_mortar_striker()
        LootItem.Type.SupportTacticalBombing:
            support = PrefabManager.create_tactical_bombing()
    if support == null:
        return
    var world: Node = get_tree().current_scene
    world.add_child(support)
    support.global_position = global_position
    if support.has_method("start_strike"):
        support.call("start_strike", facing_direction.normalized())
    battle_support_type = LootItem.Type.Empty
    if node_equipment_audio != null:
        node_equipment_audio.stream = SFX_BATTLE_SUPPORT
        node_equipment_audio.play()
    else:
        push_warning("玩家场景缺少 EquipmentAudioPlayer，战场支援音效无法播放。")
    sig_battle_support_requested.emit()
    sig_battle_support_updated.emit(battle_support_type)


## 将生命组件的状态变化转发给关卡控制器。
func _on_health_updated(current_health: int, max_health: int) -> void:
    sig_health_updated.emit(current_health, max_health)


## 按武器配置播放开火音效；火焰允许短尾声重叠，持续喷射时避免硬切噪声。
func _on_weapon_fired(weapon: PlayerWeaponSlot) -> void:
    if weapon.fire_sound != null:
        node_fire_audio.stream = weapon.fire_sound
    elif weapon is PlayerWeaponPistol:
        node_fire_audio.stream = SFX_FIRE_PISTOL
    elif weapon is PlayerWeaponSMG:
        node_fire_audio.stream = SFX_FIRE_SMG
    elif weapon is PlayerWeaponShortgun:
        node_fire_audio.stream = SFX_FIRE_SHORTGUN
    else:
        return

    node_fire_audio.max_polyphony = 4 if weapon is PlayerWeaponFlamethrower else 1
    node_fire_audio.pitch_scale = randf_range(0.96, 1.04)
    node_fire_audio.play()


## 成功开始换弹时播放换弹音效。
func _on_reload_started(_weapon: PlayerWeaponSlot) -> void:
    node_reload_audio.play()


## 按当前操作设备更新瞄准；键盘使用方向键，手柄使用右摇杆，触控由 HUD 虚拟摇杆提供。
func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and not event.pressed:
        _shop_confirmation_held = false
    if dodge_active:
        return
    if event is InputEventKey and (event as InputEventKey).pressed:
        _set_aim_device(AimDevice.KEYBOARD)
    elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
        _set_aim_device(AimDevice.GAMEPAD)
        _gamepad_device_id = (event as InputEventJoypadButton).device
    elif event is InputEventJoypadMotion:
        var stick_event := event as InputEventJoypadMotion
        if absf(stick_event.axis_value) >= AIM_STICK_DEADZONE:
            _set_aim_device(AimDevice.GAMEPAD)
            _gamepad_device_id = stick_event.device
            if stick_event.axis == JOY_AXIS_RIGHT_X or stick_event.axis == JOY_AXIS_RIGHT_Y:
                _update_gamepad_aim()
    elif event is InputEventScreenTouch or event is InputEventScreenDrag:
        _set_aim_device(AimDevice.TOUCH)


## 切换瞄准设备时清除旧设备的有效状态，并以最近移动方向作为新设备的初始朝向。
func _set_aim_device(device: AimDevice) -> void:
    if _aim_device == device:
        return
    _aim_device = device
    facing_direction = _last_move_direction
    if device == AimDevice.GAMEPAD:
        _gamepad_aim_valid = false
    elif device == AimDevice.TOUCH:
        _touch_aim_valid = false


## 触控开火区拖动时由 HUD 提交方向，保留最近方向供点按开火时沿用。
func set_touch_aim_direction(direction: Vector2) -> void:
    if dodge_active:
        return
    if direction.length_squared() <= AIM_STICK_DEADZONE * AIM_STICK_DEADZONE:
        return
    _set_aim_device(AimDevice.TOUCH)
    _touch_aim_valid = true
    facing_direction = direction.normalized()


## 使用当前手柄的右摇杆方向瞄准；摇杆回中后保留最近方向，便于持续开火。
func _update_gamepad_aim() -> void:
    if _gamepad_device_id < 0:
        return
    var aim_vector := Vector2(
        Input.get_joy_axis(_gamepad_device_id, JOY_AXIS_RIGHT_X),
        Input.get_joy_axis(_gamepad_device_id, JOY_AXIS_RIGHT_Y)
    )
    if aim_vector.length() > AIM_STICK_DEADZONE:
        _gamepad_aim_valid = true
        facing_direction = aim_vector.normalized()


## 方向键同时决定瞄准与连续开火；组合方向归一化后支持八向射击。
func _update_keyboard_aim() -> bool:
    var shoot_direction := Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down")
    if shoot_direction == Vector2.ZERO:
        return false
    facing_direction = shoot_direction
    return true


func _physics_process(delta: float) -> void:
    # 闪避期间忽略手动移动与瞄准，方向从启动时锁定。
    var move_input: Vector2 = Vector2.ZERO if dodge_active else Input.get_vector('move_left', 'move_right', 'move_up', 'move_down')
    if move_input:
        _last_move_direction = move_input

    # 方向键优先决定射击朝向；没有方向键输入时，键盘模式继续沿用移动朝向。
    if dodge_active:
        facing_direction = _dodge_direction
    elif _aim_device == AimDevice.KEYBOARD:
        if not _update_keyboard_aim() and move_input:
            facing_direction = move_input
    elif _aim_device == AimDevice.GAMEPAD:
        _update_gamepad_aim()
        if not _gamepad_aim_valid and move_input:
            facing_direction = move_input
    elif not _touch_aim_valid and move_input:
        facing_direction = move_input

    if dodge_active:
        # 最后一帧只推进剩余时间，避免不同帧率让总闪避距离超过 60 单位。
        var dodge_step := minf(delta, _dodge_time_remaining)
        velocity = _dodge_direction * DODGE_SPEED * (dodge_step / maxf(delta, 0.000001))
        move_and_slide()
        _dodge_time_remaining = maxf(_dodge_time_remaining - delta, 0.0)
        if _dodge_time_remaining <= 0.0:
            dodge_active = false
            anim.self_modulate.a = _dodge_sprite_alpha
            velocity = Vector2.ZERO
            _emit_skill_updated()
    else:
        var speed_multiplier: float = 2.0 if sprint_active else 1.0
        velocity = move_input * prop_move_speed * speed_multiplier
        move_and_slide()

    # 处理移动动画
    var anim_name_state: String = 'move' if velocity.length() > 0 else 'idle'
    var anim_name_direction: String = 'down'
    var facing_direction_degree = rad_to_deg(facing_direction.normalized().angle())
    if facing_direction_degree < 0: # 返回的是 -180 ~ 180，所以这里转换成 0 ~ 360
        facing_direction_degree += 360
    if facing_direction_degree >= 337.5 or facing_direction_degree < 22.5:
        anim_name_direction = 'right'
    elif facing_direction_degree >= 22.5 and facing_direction_degree < 67.5:
        anim_name_direction = 'down_right'
    elif facing_direction_degree >= 67.5 and facing_direction_degree < 112.5:
        anim_name_direction = 'down'
    elif facing_direction_degree >= 112.5 and facing_direction_degree < 157.5:
        anim_name_direction = 'down_left'
    elif facing_direction_degree >= 157.5 and facing_direction_degree < 202.5:
        anim_name_direction = 'left'
    elif facing_direction_degree >= 202.5 and facing_direction_degree < 247.5:
        anim_name_direction = 'up_left'
    elif facing_direction_degree >= 247.5 and facing_direction_degree < 292.5:
        anim_name_direction = 'up'
    elif facing_direction_degree >= 292.5 and facing_direction_degree < 337.5:
        anim_name_direction = 'up_right'
    anim.play(anim_name_state + '_' + anim_name_direction)


func _process(delta: float) -> void:
    _update_skill_input(delta)
    # 闪避为独占动作：仍推进体力/冷却，但不处理射击、道具、支援、换弹与切枪。
    if dodge_active:
        return

    # 奔跑期间禁止开火、使用装备和呼叫战场支援。
    # 发射前再次读取方向键，避免渲染帧先于物理帧时首发仍使用上一帧方向。
    var fire_requested := _update_keyboard_aim() if _aim_device == AimDevice.KEYBOARD else Input.is_action_pressed("fire")
    if not sprint_active and fire_requested:
        node_weapon_manager.action_fire(self)

    # 数字键选择固定主武器槽，R 键对当前武器手动换弹。
    if Input.is_action_just_pressed("weapon_slot_1"):
        node_weapon_manager.action_switch_weapon(1)
    elif Input.is_action_just_pressed("weapon_slot_2"):
        node_weapon_manager.action_switch_weapon(2)
    # 扩展武器固定 3/4/5 键；手柄和触控继续共用轮换入口。
    for slot_index: int in range(3, 6):
        if Input.is_action_just_pressed("weapon_slot_%d" % slot_index):
            node_weapon_manager.action_switch_weapon(slot_index)
    if Input.is_action_just_pressed("reload"):
        node_weapon_manager.action_reload()
    if not sprint_active and Input.is_action_just_pressed("use_equipment"):
        use_equipment()
    if Input.is_action_just_pressed("switch_weapon"):
        node_weapon_manager.action_switch_next_weapon()
    if not sprint_active and Input.is_action_just_pressed("battle_support"):
        use_battle_support()
    if Input.is_action_just_pressed("use_skill") and not _shop_confirmation_held:
        sig_skill_requested.emit()


## 商店在收到手柄 A 确认时调用；购买成功或失败都不允许同次按键启动技能。
func consume_shop_confirmation() -> void:
    _shop_confirmation_held = true


## 根据当前技能类型处理按住奔跑、按下闪避以及冷却计时。
func _update_skill_input(delta: float) -> void:
    _skill_cooldown_remaining = maxf(_skill_cooldown_remaining - delta, 0.0)
    var skill_held := Input.is_action_pressed("use_skill") and not _shop_confirmation_held
    if not skill_held:
        _sprint_exhausted = false
    var was_sprinting := sprint_active
    var moving := Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.0
    sprint_active = skill_type == LootItem.Type.SkillSprint and skill_held and moving and not dodge_active and not _sprint_exhausted and stamina > 0.0 and _skill_cooldown_remaining <= 0.0
    if was_sprinting and not sprint_active:
        _skill_cooldown_remaining = SPRINT_COOLDOWN
    if skill_type == LootItem.Type.SkillDodge:
        if Input.is_action_just_pressed("use_skill") and not _shop_confirmation_held and _skill_cooldown_remaining <= 0.0 and not dodge_active:
            _start_dodge()
    _update_stamina(delta)
    _emit_skill_updated()


## 移动奔跑才消耗体力；恢复只计算等待结束后的实际时间，避免跨三秒阈值提前恢复。
func _update_stamina(delta: float) -> void:
    if sprint_active:
        stamina = maxf(stamina - sprint_stamina_cost * delta, 0.0)
        _stamina_recovery_wait = stamina_recovery_delay
        if stamina <= 0.0:
            sprint_active = false
            _sprint_exhausted = true
    else:
        var recovery_delta := maxf(delta - _stamina_recovery_wait, 0.0)
        _stamina_recovery_wait = maxf(_stamina_recovery_wait - delta, 0.0)
        stamina = minf(stamina_max, stamina + stamina_recovery_rate * recovery_delta)
    sig_stamina_updated.emit(stamina, stamina_max)


## 开始一次面朝方向的定时闪避，并从启动时开始计算三秒冷却。
func _start_dodge() -> void:
    if dodge_active or _skill_cooldown_remaining > 0.0:
        return
    sprint_active = false
    var current_move_input: Vector2 = Input.get_vector('move_left', 'move_right', 'move_up', 'move_down')
    if current_move_input:
        facing_direction = current_move_input
    _dodge_direction = facing_direction.normalized()
    if _dodge_direction == Vector2.ZERO:
        _dodge_direction = Vector2.DOWN
    dodge_active = true
    # 只调整身体精灵的透明度，不影响护盾轮廓等独立表现。
    _dodge_sprite_alpha = anim.self_modulate.a
    anim.self_modulate.a = _dodge_sprite_alpha * DODGE_ALPHA_MULTIPLIER
    _dodge_time_remaining = DODGE_DURATION
    _skill_cooldown_remaining = DODGE_COOLDOWN
    _emit_skill_updated()


## 拾取技能时替换唯一技能槽，并清理旧技能尚未结束的移动状态。
func obtain_skill_from_loot(loot_type: LootItem.Type) -> bool:
    # 闪避时不能通过拾取新技能中断动作并绕过操作锁。
    if dodge_active:
        return false
    if loot_type not in [LootItem.Type.SkillSprint, LootItem.Type.SkillDodge]:
        return false
    skill_type = loot_type
    sprint_active = false
    dodge_active = false
    _dodge_time_remaining = 0.0
    _skill_cooldown_remaining = 0.0
    _emit_skill_updated()
    return true


## 通知 HUD 当前技能、冷却进度所需时长和使用状态。
func _emit_skill_updated() -> void:
    var cooldown_duration: float = SPRINT_COOLDOWN if skill_type == LootItem.Type.SkillSprint else DODGE_COOLDOWN
    var is_active: bool = sprint_active or dodge_active
    sig_skill_updated.emit(skill_type, _skill_cooldown_remaining, cooldown_duration, is_active)


## 接收拾取区内的物品；货币与原有道具共用触碰流程，但播放各自的音效。
func on_collect_item(item: Area2D):
    if item is LootItem:
        # 只有道具效果成功应用时才移除拾取物，避免满血或已满备弹时浪费道具。
        if item.apply_to(self):
            print('玩家拾取了', item.type, item.num)
            if item.type in [LootItem.Type.CurrencyMoney, LootItem.Type.CurrencyResearch]:
                var kind := RunCurrencyWallet.Kind.MONEY if item.type == LootItem.Type.CurrencyMoney else RunCurrencyWallet.Kind.RESEARCH
                play_currency_pickup_sound(kind)
            else:
                node_pickup_audio.stream = SFX_PICKUP
                node_pickup_audio.play()
            item.queue_free()


## 拾取与 Boss 直接研究奖励都由玩家播放声音，避免掉落物销毁时截断音效。
func play_currency_pickup_sound(kind: RunCurrencyWallet.Kind) -> void:
    node_pickup_audio.stream = SFX_MONEY_PICKUP if kind == RunCurrencyWallet.Kind.MONEY else SFX_RESEARCH_PICKUP
    node_pickup_audio.play()

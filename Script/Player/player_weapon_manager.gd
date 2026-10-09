## 玩家武器管理器：创建并应用永久升级，管理切换、拾取、弹药与 HUD 信号。
class_name PlayerWeaponManager
extends Node

# 切换武器时间
@export var switch_weapon_duraiton: float = 0.2

# 玩家武器切换信号
signal sig_weapon_change(primary: PlayerWeaponSlot, secondary: PlayerWeaponSlot)

# 当前使用的武器变化信号
signal sig_active_weapon_change(active: PlayerWeaponSlot)

# 当前武器弹药变化信号
signal sig_active_ammo_change(current: int, back: int)

# 当前武器换弹进度信号，1 表示换弹完成或当前未在换弹。
signal sig_active_reload(progress: float)

# 武器切换进度信号，1 表示切换等待完成。
signal sig_switch_progress(progress: float)

# 武器成功发射子弹时通知玩家播放对应开火音效。
signal sig_weapon_fired(weapon: PlayerWeaponSlot)

# 武器成功开始换弹时通知玩家播放换弹音效。
signal sig_reload_started(weapon: PlayerWeaponSlot)

var slotDefault: PlayerWeaponSlot
var slot1: PlayerWeaponSlot
var slot2: PlayerWeaponSlot
var active_slot: PlayerWeaponSlot
## 扩展武器固定对应 3、4、5；实例跨房间保留，解锁独立于弹药状态。
var extra_weapons: Array[PlayerWeaponSlot] = []
var extra_unlocked: Dictionary = {}

# 冲锋枪需要通过后续升级解锁；解锁前槽 1 不可选中。
var smg_unlocked: bool = false

# 霰弹枪需通过拾取解锁；解锁前槽 2 不可选中。
var shortgun_unlocked: bool = false

# 当前选择的武器槽编号；0 表示手枪，1/2 对应两个正式武器槽。
var active_slot_index: int = 0

# 武器切换冷却，防止输入抖动导致连续切换。
var _switch_cooldown_remaining: float = 0.0


## 初始化六把武器及其独立升级，建立弹药/换弹信号后选中开局手枪。
func _ready() -> void:
    # 手枪作为开局和弹尽后的备用武器，两个武器槽分别配置冲锋枪和霰弹枪。
    slotDefault = PlayerWeaponPistol.new()
    slotDefault.name = "Pistol"
    slot1 = PlayerWeaponSMG.new()
    slot1.name = "SMG"
    slot2 = PlayerWeaponShortgun.new()
    slot2.name = "Shortgun"
    # 每把武器只在创建时读取一次永久升级；跨关保留同一武器实例与当前弹药。
    slotDefault.apply_battlefield_upgrades("pistol")
    slot1.apply_battlefield_upgrades("smg")
    slot2.apply_battlefield_upgrades("shotgun")
    add_child(slotDefault)
    add_child(slot1)
    add_child(slot2)

    extra_weapons = [PlayerWeaponSniper.new(), PlayerWeaponRPG.new(), PlayerWeaponFlamethrower.new()]
    for weapon: PlayerWeaponSlot in extra_weapons:
        weapon.name = weapon.weapon_id
        weapon.apply_battlefield_upgrades(weapon.weapon_id)
        add_child(weapon)

    for weapon: PlayerWeaponSlot in [slotDefault, slot1, slot2] + extra_weapons:
        weapon.sig_ammo_change.connect(_on_weapon_ammo_change.bind(weapon))
        weapon.sig_reload.connect(_on_weapon_reload.bind(weapon))

    # 开局使用手枪；冲锋枪需解锁后才可切换，霰弹枪保留在第二槽。
    active_slot = slotDefault
    sig_weapon_change.emit(active_slot, _get_secondary_slot())
    sig_active_weapon_change.emit(active_slot)
    sig_active_ammo_change.emit(active_slot.ammo_magazine_cur, active_slot.ammo_back_cur)
    sig_active_reload.emit(_get_reload_progress(active_slot))


## 每帧推进武器换弹、射击冷却和切换冷却。
func _process(delta: float) -> void:
    _switch_cooldown_remaining = maxf(_switch_cooldown_remaining - delta, 0.0)
    var switch_progress: float = 1.0 - _switch_cooldown_remaining / maxf(switch_weapon_duraiton, 0.01)
    sig_switch_progress.emit(clampf(switch_progress, 0.0, 1.0))
    for weapon: PlayerWeaponSlot in [slotDefault, slot1, slot2] + extra_weapons:
        if weapon != null:
            weapon.update_weapon(delta)


## 按住开火时由玩家逐帧调用；弹匣空但还有备弹时自动开始换弹。
# 开火
func action_fire(player: Player) -> void:
    if player == null or player.sprint_active or player.dodge_active or _switch_cooldown_remaining > 0.0 or active_slot == null:
        return

    if active_slot.ammo_magazine_cur <= 0:
        if active_slot.ammo_back_infinite or active_slot.ammo_back_cur > 0:
            _try_reload_active(player)
            return
        if active_slot != slotDefault:
            _drop_empty_weapon(active_slot)
            _switch_to_best_available_weapon(active_slot)
            return

    if active_slot.try_fire(player):
        sig_weapon_fired.emit(active_slot)
        if active_slot != slotDefault and _has_no_ammo(active_slot):
            var depleted := active_slot
            _drop_empty_weapon(depleted)
            _switch_to_best_available_weapon(depleted)


## 判断主武器是否已经没有弹匣子弹和备弹。
func _has_no_ammo(weapon: PlayerWeaponSlot) -> bool:
    return weapon != null and weapon.ammo_magazine_cur <= 0 and not weapon.ammo_back_infinite and weapon.ammo_back_cur <= 0


## 弹药耗尽时丢弃主武器并清空弹药，之后拾取同类武器可重新装入槽位。
func _drop_empty_weapon(weapon: PlayerWeaponSlot) -> void:
    if weapon == slot1:
        smg_unlocked = false
    elif weapon == slot2:
        shortgun_unlocked = false
    if weapon in extra_weapons:
        extra_unlocked.erase(weapon.weapon_id)
    if weapon != null:
        weapon.set_ammo_from_total(0)


## 主武器弹药耗尽后清理空槽，优先选择其余主武器，否则切回无限备弹手枪。
func _switch_to_best_available_weapon(depleted_weapon: PlayerWeaponSlot) -> void:
    for weapon: PlayerWeaponSlot in _get_available_primary_weapons():
        if weapon == depleted_weapon:
            continue
        if _has_no_ammo(weapon):
            _drop_empty_weapon(weapon)
        else:
            _select_slot(weapon, _get_slot_index(weapon), true)
            return
    _select_slot(slotDefault, 0, true)


## 对当前武器发起手动换弹。
# 装填
func action_reload() -> void:
    if _switch_cooldown_remaining > 0.0 or active_slot == null:
        return
    _try_reload_active(get_parent() as Player)


## 启动当前武器的换弹，并仅在换弹成功开始时通知音效播放。
func _try_reload_active(player: Player) -> bool:
    if active_slot == null or not active_slot.try_reload(player):
        return false
    sig_reload_started.emit(active_slot)
    return true


## 选择固定主武器槽；1/2 为冲锋枪/霰弹枪，3/4/5 为狙击/RPG/喷火枪。
func action_switch_weapon(slot_index: int) -> void:
    # 闪避动作独占控制，外部切枪调用也不能绕过玩家输入锁。
    var player := get_parent() as Player
    if player != null and player.dodge_active:
        return
    if _switch_cooldown_remaining > 0.0:
        return

    if slot_index >= 3 and slot_index <= 5:
        var weapon := extra_weapons[slot_index - 3]
        if extra_unlocked.get(weapon.weapon_id, false):
            _select_slot(weapon, slot_index, false)
        return
    match slot_index:
        1:
            if smg_unlocked:
                _select_slot(slot1, 1, false)
        2:
            if shortgun_unlocked:
                _select_slot(slot2, 2, false)


## Q 键轮换已解锁主武器；只有一把主武器时才与手枪互切。
func action_switch_next_weapon() -> void:
    # 闪避动作独占控制，外部切枪调用也不能绕过玩家输入锁。
    var player := get_parent() as Player
    if player != null and player.dodge_active:
        return
    if _switch_cooldown_remaining > 0.0:
        return

    var available := _get_available_primary_weapons()
    if available.is_empty():
        return
    if available.size() == 1:
        var next_weapon: PlayerWeaponSlot = slotDefault if active_slot == available[0] else available[0]
        _select_slot(next_weapon, _get_slot_index(next_weapon), false)
        return
    var next_weapon: PlayerWeaponSlot = available[(available.find(active_slot) + 1) % available.size()]
    _select_slot(next_weapon, _get_slot_index(next_weapon), false)


## 由升级系统调用以解锁冲锋枪，并将其设为当前武器。
func unlock_smg() -> void:
    smg_unlocked = true
    _select_slot(slot1, 1, true)


## 拾取冲锋枪只补满备弹；首次获得时解锁并选中，任何情况下均不重置弹匣。
## 参数保留给现有物品接口做有效性判断，不再参与弹药加法或分配。
func obtain_smg(ammo_amount: int) -> bool:
    if ammo_amount <= 0:
        return false
    if not smg_unlocked:
        slot1.refill_reserve_ammo()
        smg_unlocked = true
        _select_slot(slot1, 1, true)
        return true
    return slot1.refill_reserve_ammo()


## 拾取霰弹枪只补满备弹；首次解锁与重复拾取共用同一规则，弹匣保持原样。
func obtain_shortgun(ammo_amount: int) -> bool:
    if ammo_amount <= 0:
        return false
    if not shortgun_unlocked:
        slot2.refill_reserve_ammo()
        shortgun_unlocked = true
        _select_slot(slot2, 2, true)
        return true
    return slot2.refill_reserve_ammo()


## 向已解锁的冲锋枪增加备弹，并返回实际加入的数量。
func add_smg_ammo(ammo_amount: int) -> int:
    if not smg_unlocked:
        return 0
    return slot1.add_ammo(ammo_amount)


## 向已解锁的霰弹枪增加备弹，并返回实际加入的数量。
func add_shortgun_ammo(ammo_amount: int) -> int:
    if not shortgun_unlocked:
        return 0
    return slot2.add_ammo(ammo_amount)


## 更新当前武器并通知武器栏和弹药显示。
func _select_slot(weapon: PlayerWeaponSlot, slot_index: int, _automatic: bool) -> void:
    if weapon == null or active_slot == weapon:
        return

    active_slot = weapon
    active_slot_index = slot_index
    _switch_cooldown_remaining = maxf(switch_weapon_duraiton, 0.0)
    sig_weapon_change.emit(active_slot, _get_secondary_slot())
    sig_active_weapon_change.emit(active_slot)
    sig_active_ammo_change.emit(active_slot.ammo_magazine_cur, active_slot.ammo_back_cur)
    sig_active_reload.emit(_get_reload_progress(active_slot))
    sig_switch_progress.emit(0.0 if _switch_cooldown_remaining > 0.0 else 1.0)


## 仅在当前使用武器的弹药变化时转发弹药信号。
func _on_weapon_ammo_change(current: int, back: int, weapon: PlayerWeaponSlot) -> void:
    # 副武器弹药也会变化，因此同步主副武器栏的紧凑显示。
    sig_weapon_change.emit(active_slot, _get_secondary_slot())
    if weapon == active_slot:
        sig_active_ammo_change.emit(current, back)


## 仅在当前使用武器的换弹进度变化时转发信号。
func _on_weapon_reload(progress: float, weapon: PlayerWeaponSlot) -> void:
    if weapon == active_slot:
        sig_active_reload.emit(progress)


## 对 HUD 提供轮换时的下一把可用武器槽。
func get_secondary_slot() -> PlayerWeaponSlot:
    return _get_secondary_slot()


## 挑选可显示的后备武器；优先显示另一个已解锁的正式武器，否则显示手枪。
func _get_secondary_slot() -> PlayerWeaponSlot:
    var available := _get_available_primary_weapons()
    if available.size() > 1:
        return available[(available.find(active_slot) + 1) % available.size()]
    if available.size() == 1 and active_slot != available[0]:
        return available[0]
    return slotDefault if active_slot != slotDefault else null


## 返回已解锁主武器的稳定顺序；Q、手柄与触控统一使用该轮换顺序。
func _get_available_primary_weapons() -> Array[PlayerWeaponSlot]:
    var weapons: Array[PlayerWeaponSlot] = []
    if smg_unlocked:
        weapons.append(slot1)
    if shortgun_unlocked:
        weapons.append(slot2)
    for weapon: PlayerWeaponSlot in extra_weapons:
        if extra_unlocked.get(weapon.weapon_id, false):
            weapons.append(weapon)
    return weapons


## 将武器实例转换为固定槽位编号，供自动切换和 HUD 使用。
func _get_slot_index(weapon: PlayerWeaponSlot) -> int:
    if weapon == slotDefault:
        return 0
    if weapon == slot1:
        return 1
    if weapon == slot2:
        return 2
    return extra_weapons.find(weapon) + 3


## 扩展武器拾取保持原有规则：只补满备弹，首次解锁并选中，不重置弹匣。
func obtain_special_weapon(id: String, amount: int) -> bool:
    if amount <= 0:
        return false
    for weapon: PlayerWeaponSlot in extra_weapons:
        if weapon.weapon_id != id:
            continue
        var first_pickup: bool = not extra_unlocked.get(id, false)
        var refilled := weapon.refill_reserve_ammo()
        if first_pickup:
            extra_unlocked[id] = true
            _select_slot(weapon, _get_slot_index(weapon), true)
        return first_pickup or refilled
    return false


## 获取武器当前换弹进度，供切换武器时同步 HUD。
func _get_reload_progress(weapon: PlayerWeaponSlot) -> float:
    if not weapon.is_reloading:
        return 1.0
    return clampf(1.0 - weapon.reload_time_remaining / maxf(weapon.reload_duration, 0.01), 0.0, 1.0)

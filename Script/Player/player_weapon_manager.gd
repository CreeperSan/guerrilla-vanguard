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

# 冲锋枪需要通过后续升级解锁；解锁前槽 1 不可选中。
var smg_unlocked: bool = false

# 霰弹枪需通过拾取解锁；解锁前槽 2 不可选中。
var shortgun_unlocked: bool = false

# 当前选择的武器槽编号；0 表示手枪，1/2 对应两个正式武器槽。
var active_slot_index: int = 0

# 武器切换冷却，防止输入抖动导致连续切换。
var _switch_cooldown_remaining: float = 0.0


## 初始化三把武器及其独立升级，建立弹药/换弹信号后选中开局手枪。
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

    for weapon: PlayerWeaponSlot in [slotDefault, slot1, slot2]:
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
    for weapon: PlayerWeaponSlot in [slotDefault, slot1, slot2]:
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
        if active_slot == slot1 or active_slot == slot2:
            _drop_empty_weapon(active_slot)
            _switch_to_best_available_weapon(active_slot)
            return

    if active_slot.try_fire(player):
        sig_weapon_fired.emit(active_slot)
        if active_slot == slot1 and _has_no_ammo(slot1):
            _drop_empty_weapon(slot1)
            _switch_to_best_available_weapon(slot1)
        elif active_slot == slot2 and _has_no_ammo(slot2):
            _drop_empty_weapon(slot2)
            _switch_to_best_available_weapon(slot2)


## 判断主武器是否已经没有弹匣子弹和备弹。
func _has_no_ammo(weapon: PlayerWeaponSlot) -> bool:
    return weapon != null and weapon.ammo_magazine_cur <= 0 and not weapon.ammo_back_infinite and weapon.ammo_back_cur <= 0


## 弹药耗尽时丢弃主武器并清空弹药，之后拾取同类武器可重新装入槽位。
func _drop_empty_weapon(weapon: PlayerWeaponSlot) -> void:
    if weapon == slot1:
        smg_unlocked = false
    elif weapon == slot2:
        shortgun_unlocked = false
    if weapon != null:
        weapon.set_ammo_from_total(0)


## 主武器弹药耗尽后优先切换另一槽；两槽均不可用时才切回无限备弹手枪。
func _switch_to_best_available_weapon(depleted_weapon: PlayerWeaponSlot) -> void:
    var fallback_weapon: PlayerWeaponSlot = null
    if depleted_weapon != slot1 and smg_unlocked:
        if _has_no_ammo(slot1):
            _drop_empty_weapon(slot1)
        else:
            fallback_weapon = slot1
    if fallback_weapon == null and depleted_weapon != slot2 and shortgun_unlocked:
        if _has_no_ammo(slot2):
            _drop_empty_weapon(slot2)
        else:
            fallback_weapon = slot2

    if fallback_weapon == null:
        fallback_weapon = slotDefault
    var fallback_index: int = 0 if fallback_weapon == slotDefault else (1 if fallback_weapon == slot1 else 2)
    _select_slot(fallback_weapon, fallback_index, true)


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


## 切换到指定武器槽；槽 1 为冲锋枪，槽 2 为霰弹枪。
func action_switch_weapon(slot_index: int) -> void:
    # 闪避动作独占控制，外部切枪调用也不能绕过玩家输入锁。
    var player := get_parent() as Player
    if player != null and player.dodge_active:
        return
    if _switch_cooldown_remaining > 0.0:
        return

    match slot_index:
        1:
            if smg_unlocked:
                _select_slot(slot1, 1, false)
        2:
            if shortgun_unlocked:
                _select_slot(slot2, 2, false)


## Q 键优先在两把已解锁主武器间切换；只有一把主武器时才与手枪互切。
func action_switch_next_weapon() -> void:
    # 闪避动作独占控制，外部切枪调用也不能绕过玩家输入锁。
    var player := get_parent() as Player
    if player != null and player.dodge_active:
        return
    if _switch_cooldown_remaining > 0.0:
        return

    var next_weapon: PlayerWeaponSlot = null
    if smg_unlocked and shortgun_unlocked:
        # 两把主武器都已解锁时，手枪不加入轮换；若当前因弹尽处于手枪，Q 回到冲锋枪。
        next_weapon = slot2 if active_slot == slot1 else slot1
    elif smg_unlocked or shortgun_unlocked:
        # 只有一把主武器时，Q 在该主武器和无限备弹手枪之间切换。
        var primary_weapon: PlayerWeaponSlot = slot1 if smg_unlocked else slot2
        next_weapon = slotDefault if active_slot == primary_weapon else primary_weapon
    else:
        return

    var slot_index: int = 0 if next_weapon == slotDefault else (1 if next_weapon == slot1 else 2)
    _select_slot(next_weapon, slot_index, false)


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


## 对 HUD 提供当前未选中的首选可用武器槽。
func get_secondary_slot() -> PlayerWeaponSlot:
    return _get_secondary_slot()


## 挑选可显示的后备武器；优先显示另一个已解锁的正式武器，否则显示手枪。
func _get_secondary_slot() -> PlayerWeaponSlot:
    if active_slot != slot1 and smg_unlocked:
        return slot1
    if active_slot != slot2 and shortgun_unlocked:
        return slot2
    if active_slot != slotDefault:
        return slotDefault
    return null


## 获取武器当前换弹进度，供切换武器时同步 HUD。
func _get_reload_progress(weapon: PlayerWeaponSlot) -> float:
    if not weapon.is_reloading:
        return 1.0
    return clampf(1.0 - weapon.reload_time_remaining / maxf(weapon.reload_duration, 0.01), 0.0, 1.0)

class_name PlayerWeaponSlot
extends Node

################################################################################ 常量定义
const INFINITY : int = -99999;

################################################################################ 属性定义

# 弹夹最大子弹数
var ammo_magazine_max : int = 30

# 当前弹夹子弹数
var ammo_magazine_cur : int = ammo_magazine_max

# 最大备弹数
var ammo_back_max : int = 120

# 当前备弹数
var ammo_back_cur : int = ammo_back_max

# 重新换弹时间
var reload_duration: float = 0.8

# 武器开火间隔
var fire_gap: float = 0.2

# 子弹基础速度（可通过商店强化）
var bullet_basic_speed: float = 30

# 子弹基础射程（可通过商店强化）
var bullet_basic_range: float = 5

# 子弹基础伤害
var bullet_basic_damage: int = 3

# 子弹基础大小
var bullet_basic_size: float = 2.0

# 子弹类型
var bullet_type: Definition.BulletType = Definition.BulletType.Bullet

# 子弹飞行时间
var bullet_basic_duration: float = 5

# 弹匣空后是否拥有无限备弹；手枪使用该选项实现无限总弹药。
var ammo_back_infinite: bool = false

# 单次射击发射的子弹数量。
var bullet_count: int = 1

# 多发子弹的总散布角度；单发武器将其作为随机偏移范围。
var bullet_spread_degrees: float = 0.0

# 当前武器是否正在换弹。
var is_reloading: bool = false

# 当前射击冷却剩余时间。
var fire_cooldown_remaining: float = 0.0

# 当前换弹剩余时间。
var reload_time_remaining: float = 0.0

# 子弹变化信号（current 当前子弹，back 备弹）
signal sig_ammo_change(current: int, back: int)

# 换弹变化信号（progress 换弹进度，1代表换弹完成）
signal sig_reload(progress: float)

################################################################################ 事件

## 尝试开火；弹药扣除、子弹实例化和弹药信号在同一流程中完成。
# 尝试开火
# return: true 代表开火成功
func try_fire(player: Player) -> bool:
    if is_reloading or fire_cooldown_remaining > 0.0 or ammo_magazine_cur <= 0:
        return false

    var spawned_count: int = _spawn_bullets(player)
    if spawned_count <= 0:
        return false

    ammo_magazine_cur -= 1
    fire_cooldown_remaining = maxf(fire_gap, 0.01)
    sig_ammo_change.emit(ammo_magazine_cur, ammo_back_cur)
    return true


## 尝试从备弹装填弹匣；无限备弹不会递减备弹数量。
# 尝试换弹
# return: true 代表触发换弹成功
func try_reload(player: Player) -> bool:
    if is_reloading or ammo_magazine_cur >= ammo_magazine_max:
        return false
    if not ammo_back_infinite and ammo_back_cur <= 0:
        return false

    is_reloading = true
    reload_time_remaining = maxf(reload_duration, 0.01)
    sig_reload.emit(0.0)
    return true


## 推进武器冷却和换弹计时，并在换弹结束时转移备弹。
func update_weapon(delta: float) -> void:
    fire_cooldown_remaining = maxf(fire_cooldown_remaining - delta, 0.0)
    if not is_reloading:
        return

    reload_time_remaining = maxf(reload_time_remaining - delta, 0.0)
    var reload_progress: float = 1.0 - reload_time_remaining / maxf(reload_duration, 0.01)
    sig_reload.emit(clampf(reload_progress, 0.0, 1.0))
    if reload_time_remaining > 0.0:
        return

    var ammo_needed: int = maxi(ammo_magazine_max - ammo_magazine_cur, 0)
    var ammo_to_load: int = ammo_needed if ammo_back_infinite else mini(ammo_needed, ammo_back_cur)
    ammo_magazine_cur += ammo_to_load
    if not ammo_back_infinite:
        ammo_back_cur -= ammo_to_load
    is_reloading = false
    sig_ammo_change.emit(ammo_magazine_cur, ammo_back_cur)
    sig_reload.emit(1.0)


## 拾取弹药时补充备弹，并返回实际加入的数量。
func add_ammo(amount: int) -> int:
    if amount <= 0 or ammo_back_infinite:
        return 0

    var ammo_added: int = mini(amount, maxi(ammo_back_max - ammo_back_cur, 0))
    if ammo_added <= 0:
        return 0

    ammo_back_cur += ammo_added
    sig_ammo_change.emit(ammo_magazine_cur, ammo_back_cur)
    return ammo_added


## 首次拾取武器时按拾取数量装填弹匣和备弹，并返回实际获得数量。
func set_ammo_from_total(amount: int) -> int:
    if ammo_back_infinite:
        return 0

    var total_capacity: int = ammo_magazine_max + ammo_back_max
    var safe_amount: int = clampi(amount, 0, total_capacity)
    ammo_magazine_cur = mini(safe_amount, ammo_magazine_max)
    ammo_back_cur = mini(safe_amount - ammo_magazine_cur, ammo_back_max)
    is_reloading = false
    reload_time_remaining = 0.0
    sig_ammo_change.emit(ammo_magazine_cur, ammo_back_cur)
    sig_reload.emit(1.0)
    return ammo_magazine_cur + ammo_back_cur


## 按武器散布角生成子弹，并返回成功创建的数量。
func _spawn_bullets(player: Player) -> int:
    var shot_count: int = maxi(bullet_count, 1)
    var spread_radians: float = deg_to_rad(maxf(bullet_spread_degrees, 0.0))
    var base_angle: float = player.facing_direction.angle()
    var spawned_count: int = 0

    for shot_index: int in range(shot_count):
        var angle_offset: float = 0.0
        if shot_count == 1:
            angle_offset = randf_range(-spread_radians * 0.5, spread_radians * 0.5)
        elif shot_count > 1:
            angle_offset = lerpf(
                -spread_radians * 0.5,
                spread_radians * 0.5,
                float(shot_index) / float(shot_count - 1)
            )

        var bullet_direction: Vector2 = Vector2.from_angle(base_angle + angle_offset)
        var bullet: ProjectileBullet = PrefabManager.create_bullet(
            Definition.Faction.Player,
            bullet_basic_damage,
            bullet_direction,
            bullet_type
        )
        if bullet == null:
            continue

        bullet.bullet_speed = bullet_basic_speed
        bullet.bullet_range = bullet_basic_range
        bullet.bullet_size = bullet_basic_size
        bullet.bullet_duration = bullet_basic_duration
        player.get_parent().add_child(bullet)
        bullet.global_position = player.global_position + bullet_direction * 8.0
        spawned_count += 1

    return spawned_count

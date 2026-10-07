## 测试关卡控制器：负责连接玩家状态和 HUD 展示。
extends Node2D

@onready var node_player: Player = $Player
@onready var node_hud: GameHUD = $HUD
@onready var node_explosion: Area2D = $Explosion
@onready var node_weapon_manager: PlayerWeaponManager = $Player/WeaponManager
@onready var node_player_health: HealthComponent = $Player/Health


## 连接生命值信号，并在连接时主动同步一次初始状态。
func _ready() -> void:
    # 测试关卡中的爆炸需要同时监测玩家物理层和敌人 HurtBox 所在层。
    node_explosion.collision_mask |= 1 << 0
    node_explosion.collision_mask |= 1 << 1

    node_player.sig_health_updated.connect(node_hud.set_health)
    node_player.sig_equipment_updated.connect(node_hud.set_equipment)
    node_hud.set_equipment(
        node_player.equipment_type,
        node_player.equipment_amount,
        node_player.shield_active
    )
    node_hud.set_health(node_player.health_current, node_player.health_max)
    # 将当前武器、弹药数量和换弹进度同步到 HUD，并主动同步启动时的武器状态。
    node_weapon_manager.sig_active_weapon_change.connect(node_hud.set_weapon)
    node_weapon_manager.sig_weapon_change.connect(node_hud.set_weapon_slots)
    node_weapon_manager.sig_switch_progress.connect(node_hud.set_switch_progress)
    node_player.sig_battle_support_updated.connect(node_hud.set_battle_support)
    node_player.sig_skill_updated.connect(node_hud.set_skill)
    node_weapon_manager.sig_active_ammo_change.connect(node_hud.set_ammo)
    node_weapon_manager.sig_active_reload.connect(node_hud.set_reload_progress)
    node_hud.set_weapon(node_weapon_manager.active_slot)
    node_hud.set_weapon_slots(node_weapon_manager.active_slot, node_weapon_manager.get_secondary_slot())
    node_hud.set_battle_support(node_player.battle_support_type)
    node_hud.set_skill(node_player.skill_type, 0.0, 0.3, false)
    node_hud.set_switch_progress(1.0)
    node_hud.set_ammo(
        node_weapon_manager.active_slot.ammo_magazine_cur,
        node_weapon_manager.active_slot.ammo_back_cur
    )
    node_hud.set_reload_progress(1.0)
    # 监听玩家与所有敌人的生命变化；正数是治疗，只为受到伤害的目标显示飘字。
    node_player_health.sig_health_change.connect(
        _on_target_health_change.bind(node_player, Definition.Faction.Player)
    )
    for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
        var enemy_health: HealthComponent = enemy.get_node_or_null("Health") as HealthComponent
        if enemy_health != null:
            enemy_health.sig_health_change.connect(
                _on_target_health_change.bind(enemy, Definition.Faction.Enemy)
            )


## 为受伤目标创建伤害飘字，并放置在目标当前位置。
func _on_target_health_change(health_change: int, target: Node2D, faction: Definition.Faction) -> void:
    if health_change >= 0:
        return

    var damage_pop: DamagePop = PrefabManager.create_damage_pop(-health_change, faction)
    if damage_pop == null:
        return
    add_child(damage_pop)
    damage_pop.global_position = target.global_position

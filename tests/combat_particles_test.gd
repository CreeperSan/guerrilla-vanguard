## 粒子接入契约：覆盖真实位移、命中/射程消失去重、爆炸伤害不变、暂停与自动回收。
## 不修改账户存档；首页制作名单通过实际按钮和场景导航验证。
extends Node

var _world: Node2D
var _failures := 0
var _checks := 0


## 保留测试观察者跨场景存活，同时允许在暂停期间完成检查。
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _run.call_deferred()


## 特效与碰撞测试按顺序运行，避免不同用例的投射物或计时器相互影响。
func _run() -> void:
    get_tree().current_scene = null
    _world = Node2D.new()
    add_child(_world)
    var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
    _world.add_child(player)
    player.set_process(false)
    player.set_physics_process(false)
    player._update_walking_dust(player.global_position, Vector2.RIGHT)
    _check(_effects("WalkingDust").is_empty(), "原地受阻不生成灰尘")
    player.position += Vector2(24, 0)
    player._update_walking_dust(Vector2.ZERO, Vector2.RIGHT)
    _check(_effects("WalkingDust").size() == 1, "按真实位移触发行走灰尘")
    var dust := _effects("WalkingDust")[0]
    var fixed_position: Vector2 = dust.global_position
    player.position += Vector2(20, 0)
    _check(dust.global_position == fixed_position, "灰尘留在世界中，不跟随玩家")
    player.dodge_active = true
    player._update_walking_dust(Vector2.ZERO, Vector2.RIGHT)
    _check(_effects("WalkingDust").size() == 1, "闪避不会错误触发行走灰尘")
    player.free()
    var bullet := PrefabManager.create_bullet(Definition.Faction.Player, 3, Vector2.RIGHT) as ProjectileBullet
    bullet.position = Vector2(100, 100)
    _world.add_child(bullet)
    bullet.set_physics_process(false)
    bullet._finish_at(bullet.global_position)
    _check(_effects("BulletImpact").size() == 1, "射程终点生成烟尘")
    bullet._finish_at(bullet.global_position)
    _check(_effects("BulletImpact").size() == 1, "同一终止事件只生成一次")
    var target := Node2D.new()
    var health := HealthComponent.new()
    health.name = "Health"
    target.add_child(health)
    _world.add_child(target)
    var piercing := PrefabManager.create_bullet(Definition.Faction.Player, 3, Vector2.RIGHT) as ProjectileBullet
    piercing.bullet_penetration = 1
    _world.add_child(piercing)
    piercing.set_physics_process(false)
    piercing._handle_hit(target)
    piercing._handle_hit(target)
    _check(_effects("BulletImpact").size() == 2 and health.health == 97, "命中产生烟尘，重复碰撞不重复伤害或发射")
    piercing.free()
    var explosion := PrefabManager.create_explosion(Definition.Faction.Player, 7) as ProjectileExplosion
    explosion.position = Vector2(400, 400)
    _world.add_child(explosion)
    explosion._apply_damage_to(target)
    explosion._apply_damage_to(target)
    _check(_effects("ExplosionDebris").size() == 1, "爆炸生成独立碎屑和烟尘")
    _check(health.health == 90, "粒子不改变爆炸伤害及去重")
    explosion.queue_free()
    await get_tree().process_frame
    _check(_effects("ExplosionDebris").size() == 1, "爆炸主体销毁后碎屑继续消散")
    get_tree().paused = true
    await get_tree().create_timer(1.3, true).timeout
    _check(_effects("ExplosionDebris").size() == 1, "暂停期间粒子不会提前回收")
    get_tree().paused = false
    await get_tree().create_timer(1.3, true).timeout
    _check(get_tree().get_nodes_in_group("transient_combat_vfx").is_empty(), "超过最长生命周期后自动回收")
    var hud := load("res://Scene/UI/HUD/HUD.tscn").instantiate() as GameHUD
    add_child(hud)
    hud.enable_run_ui()
    hud.show_boss_health("测试首领", 50, 100, 1)
    await get_tree().process_frame
    var panel := hud.get_node("UIRoot/BossHealthPanel") as Control
    _check(panel.anchor_top == 0 and panel.size.x <= 360 and panel.size.y <= 36, "Boss 血条位于顶部且缩小")
    hud.free()
    _world.free()
    var menu := load("res://Scene/MainMenu/MainMenu.tscn").instantiate() as Control
    get_tree().root.add_child(menu)
    get_tree().current_scene = menu
    menu.get_node("MainPage/MenuList/AboutLinks/CreditsButton").pressed.emit()
    for frame: int in range(300):
        if get_tree().current_scene != null and get_tree().current_scene.name == "Credits":
            break
        await get_tree().create_timer(0.01, true).timeout
    _check(get_tree().current_scene != null and get_tree().current_scene.name == "Credits", "首页制作人员按钮进入已有名单场景")
    var report_button := false
    for button: Node in get_tree().current_scene.find_children("*", "Button", true, false):
        if button.text == "返回战报":
            report_button = true
    _check(not report_button and GameManager.run_state == RogueRunManager.RunState.IDLE, "首页名单不会进入旧战报或创建对局")
    while SceneTransition.busy:
        await get_tree().process_frame
    print("COMBAT_PARTICLES_TEST checks=%d failures=%d" % [_checks, _failures])
    get_tree().quit(1 if _failures else 0)


## 以资源路径统计特效，不依赖 Godot 为重名节点自动分配的运行时名字。
func _effects(prefix: String) -> Array[Node]:
    var found: Array[Node] = []
    for effect: Node in get_tree().get_nodes_in_group("transient_combat_vfx"):
        if effect.scene_file_path.get_file().get_basename() == prefix:
            found.append(effect)
    return found


## 收集全部失败，确保视觉接入同时满足生命周期和玩法不变的约束。
func _check(condition: bool, description: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error(description)

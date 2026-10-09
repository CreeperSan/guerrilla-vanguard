## 新武器独立靶场：开局解锁三把武器，提供可复位靶子和正式 HUD，不改写永久账户。
## 编辑器运行本场景即可试玩；命令行传 --weapon-preview 可保存预览并自动退出。
extends LevelController

const RANGE_FONT: Font = preload("res://Font/fusion-pixel-12-zh-hans.ttf")
const WEAPON_ICONS: Array[Texture2D] = [
    preload("res://Assets/Art/MilitaryArcade/Weapons/sniper_icon.tres"),
    preload("res://Assets/Art/MilitaryArcade/Weapons/rpg_icon.tres"),
    preload("res://Assets/Art/MilitaryArcade/Weapons/flamethrower_icon.tres"),
]

## 靶子使用正式生命组件和 HurtBox，死亡后短暂关闭检测，再原地复位。
class RangeTarget extends Node2D:
    var faction: Definition.Faction = Definition.Faction.Enemy
    var health: HealthComponent
    var hurtbox: HurtBox
    var resetting: bool = false

    ## 建立碰撞圆与生命反馈，不使用敌人 AI、掉落或结算。
    func _ready() -> void:
        health = HealthComponent.new()
        health.name = "Health"
        add_child(health)
        hurtbox = HurtBox.new()
        hurtbox.collision_layer = 2
        hurtbox.collision_mask = 0
        var collision := CollisionShape2D.new()
        var circle := CircleShape2D.new()
        circle.radius = 12.0
        collision.shape = circle
        hurtbox.add_child(collision)
        add_child(hurtbox)
        health.sig_health_updated.connect(func(_current: int, _maximum: int): queue_redraw())
        health.sig_die.connect(_reset_target)

    ## 死亡靶子暂时离开检测，防止爆炸或穿透在复位前再次命中。
    func _reset_target() -> void:
        resetting = true
        hurtbox.set_deferred("collision_layer", 0)
        queue_redraw()
        await get_tree().create_timer(1.5).timeout
        health.health = health.health_max
        resetting = false
        hurtbox.collision_layer = 2
        queue_redraw()

    ## 绘制同物理范围一致的靶面和生命条，便于观察穿透与爆炸结果。
    func _draw() -> void:
        draw_circle(Vector2.ZERO, 15.0, Color("303a35") if resetting else Color("cf704b"))
        draw_circle(Vector2.ZERO, 10.0, Color("182a2d"))
        draw_circle(Vector2.ZERO, 4.0, Color("f4d28b"))
        if health != null:
            draw_rect(Rect2(-16, -25, 32, 4), Color("182a2d"))
            draw_rect(Rect2(-16, -25, 32.0 * health.health / health.health_max, 4), Color("b8ce80"))


## 先复用关卡的玩家/HUD 绑定，再准备独立靶场与测试武器。
func _ready() -> void:
    super._ready()
    var player := controlled_player as Player
    controlled_hud.get_node("UIRoot/RoomMinimap").hide()
    player.facing_direction = Vector2.RIGHT
    for id: String in ["sniper", "rpg", "flamethrower"]:
        player.node_weapon_manager.obtain_special_weapon(id, 1)
    player.node_weapon_manager._switch_cooldown_remaining = 0.0
    player.node_weapon_manager.action_switch_weapon(3)
    for origin: Vector2 in [Vector2(320, 320), Vector2(410, 320), Vector2(500, 320), Vector2(590, 320), Vector2(680, 320), Vector2(770, 320), Vector2(760, 455), Vector2(800, 475), Vector2(740, 495), Vector2(265, 480), Vector2(290, 505), Vector2(315, 480)]:
        var target := RangeTarget.new()
        target.position = origin
        add_child(target)
        target.health.sig_health_change.connect(_on_target_health_change.bind(target, Definition.Faction.Enemy))
    # 右侧实墙用于检验火箭引爆与火焰反弹；靶场不限制玩家自由移动。
    var wall := StaticBody2D.new()
    wall.position = Vector2(960, 390)
    wall.collision_layer = Definition.PHYSICS_LAYER_TERRAIN
    var collision := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(16, 300)
    collision.shape = rectangle
    wall.add_child(collision)
    add_child(wall)
    if "--weapon-preview" in OS.get_cmdline_user_args():
        _save_preview.call_deferred()


## 绘制靶场地面、武器展示与操作说明，图标直接使用正式游戏资源。
func _draw() -> void:
    draw_rect(Rect2(-2000, -2000, 5000, 5000), Color("162a2b"))
    for x: int in range(0, 1153, 32):
        draw_line(Vector2(x, 0), Vector2(x, 648), Color("203537"))
    for y: int in range(0, 649, 32):
        draw_line(Vector2(0, y), Vector2(1152, y), Color("203537"))
    draw_string(RANGE_FONT, Vector2(280, 135), "新武器试验场", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("f4d28b"))
    var names := ["3  狙击步枪", "4  RPG", "5  喷火枪"]
    for index: int in range(3):
        var x: float = 285 + index * 240
        var icon := WEAPON_ICONS[index]
        var height: float = 130.0 * icon.get_height() / icon.get_width()
        draw_texture_rect(icon, Rect2(x, 165 + (45 - height) * 0.5, 130, height), false)
        draw_string(RANGE_FONT, Vector2(x, 235), names[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("c8d8bd"))
    draw_line(Vector2(280, 320), Vector2(900, 320), Color("8c8154"), 1.0)
    draw_string(RANGE_FONT, Vector2(320, 280), "穿透靶列", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("c8d8bd"))
    draw_string(RANGE_FONT, Vector2(200, 560), "近距火焰", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("c8d8bd"))
    draw_string(RANGE_FONT, Vector2(700, 550), "范围爆炸", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("c8d8bd"))
    draw_rect(Rect2(952, 240, 16, 300), Color("687b70"))
    draw_string(RANGE_FONT, Vector2(200, 578), "WASD 移动 · 方向键瞄准/射击 · Q 切换 · R 换弹 · 靶子自动复位", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("a6baad"))


## 渲染正式靶场与 HUD 后保存图片，只在显式预览参数下执行。
func _save_preview() -> void:
    await get_tree().create_timer(3.9, true).timeout
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var error := image.save_png("res://docs/art/special_weapons_range.png")
    print("WEAPON_RANGE_PREVIEW error=%d" % error)
    get_tree().quit(0 if error == OK else 1)

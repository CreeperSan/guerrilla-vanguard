## 独立 Boss 试战场：F6 运行，选择七种 Level 的固定竞技场，提供三枪与阶段血条。
## 不接入钱包、研究奖励或正式对局推进；切换/重试仅重建本场战斗。
extends Node2D

const THEMES: Array[String] = ["Village", "Jungle", "Valley", "Metropolis", "MineShaft", "Fortress", "UndergroundFortress", "OldTown", "Neon", "Park", "Chemical", "Route66", "Swamp", "Canal", "Hospital"]
var _arena: FortressRoomTemplate
var _boss: BattlefieldBoss
var _player: Player
var _health: ProgressBar
var _status: Label
var _selection: OptionButton
var _revision: int = 0


## 构建轻量试战 UI，不依赖正式 HUD 的布局和存档。
func _ready() -> void:
    get_tree().paused = false
    var camera := Camera2D.new()
    camera.zoom = Vector2.ONE * 0.65
    add_child(camera)
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := VBoxContainer.new()
    panel.position = Vector2(16, 16)
    panel.custom_minimum_size.x = 320
    layer.add_child(panel)
    _selection = OptionButton.new()
    for theme_name: String in THEMES:
        var theme := load("res://Scene/Level%s/theme.tres" % theme_name) as BattlefieldTheme
        _selection.add_item(theme.display_name)
    panel.add_child(_selection)
    _selection.item_selected.connect(_start)
    _health = ProgressBar.new()
    panel.add_child(_health)
    _status = Label.new()
    panel.add_child(_status)
    var restart := Button.new()
    restart.text = "重新挑战"
    restart.pressed.connect(func(): _start(_selection.selected))
    panel.add_child(restart)
    _start(0)


## 先禁用旧场景再等待回收；版本号阻止快速连续选择产生多个 Boss。
func _start(index: int) -> void:
    _revision += 1
    var revision := _revision
    if is_instance_valid(_arena):
        _arena.process_mode = Node.PROCESS_MODE_DISABLED
        _arena.queue_free()
    await get_tree().process_frame
    if revision != _revision:
        return
    var theme := load("res://Scene/Level%s/theme.tres" % THEMES[index]) as BattlefieldTheme
    _arena = theme.boss_room_scene.instantiate() as FortressRoomTemplate
    _arena.battlefield_theme = theme
    _arena.set_meta("boss_spawned", true)
    add_child(_arena)
    _player = preload("res://Prefab/Player/player.tscn").instantiate() as Player
    _player.position = Vector2(0, 280)
    _arena.add_child(_player)
    var weapons := _player.get_node("WeaponManager") as PlayerWeaponManager
    weapons.obtain_smg(180)
    weapons.obtain_shortgun(48)
    _player.get_node("Health").sig_die.connect(_player_defeated)
    _boss = theme.boss_scene.instantiate() as BattlefieldBoss
    _boss.position = Vector2(0, -100)
    _arena.add_child(_boss)
    _arena.track_enemy(_boss)
    _boss.health_component.sig_health_updated.connect(_set_health)
    _boss.sig_phase_changed.connect(_set_phase)
    _boss.sig_defeated.connect(_boss_defeated)
    _set_phase(1, _boss.health_component.health, _boss.health_component.health_max)


## 中间阶段只更新名称与独立血量，不结束挑战。
func _set_phase(phase: int, current: int, maximum: int) -> void:
    _status.text = "%s · 阶段 %d" % [_boss.boss_display_name, phase]
    _set_health(current, maximum)


## 直接展示真实生命组件数据。
func _set_health(current: int, maximum: int) -> void:
    _health.max_value = maximum
    _health.value = current


## 本场胜利停止所有战斗并回收剩余敌人/攻击，不发研究或积分。
func _boss_defeated() -> void:
    _status.text = "Boss 已击败，可以切换或重试。"
    _arena.process_mode = Node.PROCESS_MODE_DISABLED
    for node: Node in _arena.find_children("*", "Node", true, false):
        if node.is_in_group("enemies") or node.is_in_group("boss_hazards") or node is ProjectileBullet or node is BurningEffect:
            node.queue_free()


## 玩家死亡停止场内处理，UI 保持可用。
func _player_defeated() -> void:
    _status.text = "玩家已战败，可以重新挑战。"
    _arena.process_mode = Node.PROCESS_MODE_DISABLED

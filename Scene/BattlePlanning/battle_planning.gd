## 正式战斗前的路线简报：只展示 GameManager 已选路线，不重新抽取主题或种子。
## 卡片逐张滑入、锁定闪光、连接路线，全部展示后保留三秒再进入正式宿主。
extends Control

## 演出参数可以在场景 Inspector 调整；停留时间从最后一张卡片锁定后开始计算。
@export_range(0.1, 2.0, 0.05) var card_reveal_duration := 0.35
@export_range(0.0, 1.0, 0.05) var card_interval := 0.15
@export_range(0.1, 10.0, 0.1) var hold_duration := 3.0
const FONT: Font = preload("res://Font/fusion-pixel-12-zh-hans.ttf")
var _cards: Array[Control] = []
var _footer: Label
var _subtitle: Label
var _row: HBoxContainer
var _locked := 0
var _launching := false


## 暂停战斗时本场景仍播放动画，空路线的独立 F6 预览则显示提示，不启动伪造对局。
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    theme = Theme.new()
    theme.default_font = FONT
    var heading := _label("作战规划  /  OPERATION ROUTE", 30, Color("f4dfae"))
    heading.position = Vector2(40, 48)
    add_child(heading)
    var snapshot := GameManager.get_run_snapshot()
    var levels: Array = snapshot.get("levels", [])
    _subtitle = _label("%s     /     %02d 个作战区域     /     航线确认中" % [snapshot.get("mode_name", "行动"), levels.size()], 16, Color("92b6c2"))
    _subtitle.position = Vector2(42, 96)
    add_child(_subtitle)
    _row = HBoxContainer.new()
    _row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _row.offset_left = 40
    _row.offset_right = -40
    _row.anchor_top = 0.29
    _row.anchor_bottom = 0.77
    _row.add_theme_constant_override("separation", 12)
    add_child(_row)
    for level: Dictionary in levels:
        var card := _create_card(level)
        _row.add_child(card)
        _cards.append(card)
    _footer = _label("正在建立进攻路线…", 20, Color("f4dfae"))
    _footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _footer.offset_left = -300
    _footer.offset_right = 300
    _footer.offset_top = -88
    _footer.offset_bottom = -48
    _footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_footer)
    resized.connect(_fit_cards)
    _fit_cards.call_deferred()
    _present.call_deferred()


## 每张卡片使用关卡自己的地形与道具资源，让主题视觉和实际关卡保持一致。
func _create_card(level: Dictionary) -> Control:
    var card := PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.modulate.a = 0
    var style := StyleBoxFlat.new()
    style.bg_color = Color("233746")
    style.border_color = Color("7a9da9")
    style.set_border_width_all(2)
    style.set_content_margin_all(12)
    card.add_theme_stylebox_override("panel", style)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 12)
    card.add_child(stack)
    stack.add_child(_label("区域  %02d" % int(level["number"]), 16, Color("edc879")))
    var art := TextureRect.new()
    art.custom_minimum_size.y = 64
    art.size_flags_vertical = Control.SIZE_EXPAND_FILL
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    var battlefield := load(str(level["theme_path"])) as BattlefieldTheme
    if battlefield != null:
        art.texture = battlefield.ground_texture
        var landmark := TextureRect.new()
        landmark.texture = battlefield.decoration_texture if battlefield.decoration_texture != null else battlefield.box_texture
        landmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        landmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        landmark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        landmark.offset_left = 8
        landmark.offset_right = -8
        landmark.offset_top = 8
        landmark.offset_bottom = -8
        art.add_child(landmark)
    stack.add_child(art)
    var name_label := _label(str(level["name"]), 20, Color("eff2dc"))
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    stack.add_child(name_label)
    var target := _label("最终突击" if bool(level.get("fixed", false)) else "清剿 / 首领", 12, Color("92b6c2"))
    target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(target)
    return card


## 尺寸随窗口变化；手机横屏和七关路线也保持一行完整可见。
func _fit_cards() -> void:
    for card: Control in _cards:
        card.pivot_offset = card.size * 0.5
    queue_redraw()


## 等待转场完全揭幕后开始逐张锁定；容器负责布局，动画仅改变 scale 避免布局相互争抢。
func _present() -> void:
    while SceneTransition.busy:
        await get_tree().process_frame
    if _cards.is_empty():
        _footer.text = "请从首页选择模式后进入作战规划"
        return
    for card: Control in _cards:
        card.scale = Vector2(0.78, 1.12)
        card.rotation = -0.035
        var tween := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        tween.tween_property(card, "modulate:a", 1.0, card_reveal_duration)
        tween.tween_property(card, "scale", Vector2.ONE, card_reveal_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(card, "rotation", 0.0, card_reveal_duration)
        await tween.finished
        _locked += 1
        card.modulate = Color(1.55, 1.55, 1.35)
        var flash := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        flash.tween_property(card, "modulate", Color.WHITE, 0.18)
        _footer.text = "路线锁定  %02d / %02d" % [_locked, _cards.size()]
        queue_redraw()
        await get_tree().create_timer(card_interval, true).timeout
    _subtitle.text = _subtitle.text.replace("航线确认中", "航线已确认")
    var remaining := hold_duration
    while remaining > 0:
        _footer.text = "准备部署 · %d 秒后进入战场" % ceili(remaining)
        var step := minf(1.0, remaining)
        await get_tree().create_timer(step, true).timeout
        remaining -= step
    if not _launching:
        _launching = true
        GameManager.launch_planned_run()


## 轻量 HUD 网格和逐步点亮的路线连线由矢量绘制，避免额外贴图缩放模糊。
func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("101c26"))
    for x: int in range(0, int(size.x), 40):
        draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.38, 0.46, 0.12))
    for y: int in range(0, int(size.y), 40):
        draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.38, 0.46, 0.12))
    if _row == null:
        return
    var line_y := size.y * 0.82
    draw_line(Vector2(40, line_y), Vector2(size.x - 40, line_y), Color("344e5c"), 2)
    for index: int in range(_locked):
        var card := _cards[index]
        var center := _row.position.x + card.position.x + card.size.x * 0.5
        draw_circle(Vector2(center, line_y), 5, Color("edc879"))
        if index > 0:
            var previous := _cards[index - 1]
            var left := _row.position.x + previous.position.x + previous.size.x * 0.5
            draw_line(Vector2(left, line_y), Vector2(center, line_y), Color("edc879"), 3)


## 统一标签字体与颜色；文字内容保持可编辑，不烘焙到美术资源中。
func _label(value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label

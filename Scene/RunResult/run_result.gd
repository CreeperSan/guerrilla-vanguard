## 独立行动结算页面：读取冻结战报，数字逐项增长；展示不参与实际收益结算。
extends Control
var report: Dictionary
var _animations: Array[Tween] = []
var _scroll: ScrollContainer
var _retry: Button
var _status: Label
var _navigation: Array[Button] = []
## 正文区域拥有一根拖动手指；在 _input 阶段处理，避免行标签截获触摸后无法滚动。
var _scroll_touch_index := -1
var _scroll_touch_origin := Vector2.ZERO
var _scroll_touch_start := 0.0
var _scroll_touch_velocity := 0.0
var _scroll_touch_dragging := false
var _scroll_last_drag_msec := -1000
const TOUCH_SCROLL_DEADZONE := 8.0
const TOUCH_SCROLL_FRICTION := 2400.0

## 滚动正文兼容大量装备及敌军种类，固定底部按钮支持触屏和手柄。
func _ready() -> void:
	get_tree().paused = false
	GameSettings.play_menu_music()
	report = RunStats.get_report()
	# 旧战报保留稳定模式 ID，显示名称使用现行配置，不需要改写历史文件。
	if int(report.get("mode", -1)) >= 0:
		report["mode_name"] = GameManager.get_mode_name(int(report.mode))
	var page := FlowUI.page(self)
	var won := bool(report.get("won", false))
	FlowUI.label(page, "行动完成" if won else "行动结束", 42)
	FlowUI.label(page, "%s  ·  完成 %s / %s 关  ·  %s" % [report.get("mode_name", "行动战报"), report.get("completed", 0), report.get("total", 1), report.get("finished_at", "")], 20)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 48)
	page.add_child(summary)
	_counter(summary, "作战时间", roundi(float(report.get("elapsed_seconds", 0))), 0.0, true)
	_counter(summary, "总积分", int(report.get("score", 0)), 0.1)
	_counter(summary, "金币收入", int(report.get("money_earned", 0)), 0.2)
	_counter(summary, "金币消耗", int(report.get("money_spent", 0)), 0.3)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 12)
	scroll.add_child(entries)
	FlowUI.label(entries, "行动记录", 28)
	var sections := [["rooms", "完成与探索的房间"], ["enemies", "消灭的敌军（含佣兵贡献）"], ["items", "已使用的道具与能力"], ["weapons", "武器开火次数（按扳机计）"]]
	var delay := 0.35
	for section: Array in sections:
		FlowUI.label(entries, "—  " + section[1], 24)
		var counts: Dictionary = report.get(section[0], {})
		if counts.is_empty():
			FlowUI.label(entries, "暂无记录", 20)
		for key: String in counts:
			_counter(entries, key, int(counts[key]), minf(delay, 1.2))
			delay += 0.04
	FlowUI.label(entries, "—  获得的战术装备", 24)
	var equipment: Dictionary = report.get("tactical", {})
	FlowUI.label(entries, "暂无记录" if equipment.is_empty() else "  /  ".join(equipment.values()), 22)
	FlowUI.label(entries, "佣兵击杀 %d  ·  发射投射物 %d  ·  获得研究点数 %d  ·  结算前剩余金币 %d" % [report.get("ally_kills", 0), report.get("projectiles", 0), report.get("research_earned", 0), report.get("money_remaining", 0)], 20)
	_status = FlowUI.label(page, "战报已保存到本地", 18)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	page.add_child(actions)
	var credits := won and int(report.get("mode", -1)) == RogueRunManager.AttackMode.COUNTERATTACK and int(report.get("completed", 0)) == RogueRunManager.COUNTERATTACK_LEVEL_COUNT
	_navigation.append(FlowUI.button(actions, "继续 · 制作人员" if credits else "返回首页", _continue.bind(credits)))
	FlowUI.button(actions, "立即显示全部成果", _finish_animation)
	_retry = FlowUI.button(actions, "重试保存", _retry_save)
	_navigation[0].grab_focus()
	_refresh_status()

## 每一行的计数使用独立 Tween，不修改已存档的数据；时间以分秒显示。
func _counter(parent: Node, title: String, value: int, delay: float, clock: bool = false) -> void:
	var label := FlowUI.label(parent, title + "  0", 22)
	var update := func(current: float) -> void:
		var n := roundi(current)
		label.text = "%s  %02d:%02d" % [title, n / 60, n % 60] if clock else "%s  %d" % [title, n]
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_method(update, 0.0, float(value), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animations.append(tween)

## 允许玩家立即展开成果，不会跳过正式结算或后续片尾。
func _finish_animation() -> void:
	for tween: Tween in _animations:
		if tween.is_running():
			tween.custom_step(100.0)

## 保存失败必须明确告知；保留内存收益，并提供原位重试。
func _refresh_status() -> void:
	var pending := CurrencyManager.has_pending_settlement()
	_status.text = "研究收益尚未保存，请重试保存。" if pending else ("本地战报保存失败，请重试保存。" if RunStats.save_error != OK else "战报已保存到本地 · 金币仅限本局，研究点数进入账户")
	_retry.visible = pending or RunStats.save_error != OK
	for button: Button in _navigation:
		button.disabled = pending

## 战报与研究账户分别重试，各自保持幂等，避免重复入账。
func _retry_save() -> void:
	RunStats.save_report()
	if CurrencyManager.has_pending_settlement():
		CurrencyManager.settle_run()
	_refresh_status()

## 反击完整胜利进入制作名单；其他结果返回首页。
func _continue(credits: bool) -> void:
	if credits:
		GameManager.open_presentation("res://Scene/Credits/Credits.tscn", "制作与致谢")
	else:
		GameManager.return_to_main_menu()

## 上下方向键或手柄方向操作滚动正文，左右仍由 GUI 在底部按钮之间切换焦点。
func _input(event: InputEvent) -> void:
	if SceneTransition.busy or _scroll == null:
		_stop_touch_scroll()
		return
	if _handle_touch_scroll(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down", true):
		_stop_touch_scroll()
		_scroll.scroll_vertical += 80
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up", true):
		_stop_touch_scroll()
		_scroll.scroll_vertical -= 80
		get_viewport().set_input_as_handled()


## 只从正文内开始拖动；页头、底部按钮与原生滚动条仍使用各自的 GUI 交互。
func _handle_touch_scroll(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _scroll_touch_index == -1:
				_scroll_touch_velocity = 0.0
			var bar := _scroll.get_v_scroll_bar()
			if not _scroll.get_global_rect().has_point(event.position) or (bar.is_visible_in_tree() and bar.get_global_rect().has_point(event.position)):
				return false
			if _scroll_touch_index == -1:
				_scroll_touch_index = event.index
				_scroll_touch_origin = event.position
				_scroll_touch_start = _scroll.scroll_vertical
				_scroll_touch_dragging = false
			return true
		if event.index == _scroll_touch_index:
			_scroll_touch_index = -1
			if event.canceled or Time.get_ticks_msec() - _scroll_last_drag_msec > 100:
				_scroll_touch_velocity = 0.0
			return true
	elif event is InputEventScreenDrag and event.index == _scroll_touch_index:
		var distance: float = _scroll_touch_origin.y - event.position.y
		if _scroll_touch_dragging or absf(distance) >= TOUCH_SCROLL_DEADZONE:
			_scroll_touch_dragging = true
			_scroll_last_drag_msec = Time.get_ticks_msec()
			_set_touch_scroll(_scroll_touch_start + distance)
			_scroll_touch_velocity = -event.velocity.y
		return true
	elif event is InputEventMouseButton:
		# 鼠标滚轮/点击接管时停止惯性，但不消费事件，保留桌面原有交互。
		if _scroll_touch_index == -1 and Time.get_ticks_msec() - _scroll_last_drag_msec > 100:
			_scroll_touch_velocity = 0.0
	return false


## 松手后沿最后拖动方向减速；到达列表两端即停止，不影响固定的结算操作按钮。
func _process(delta: float) -> void:
	if _scroll == null or _scroll_touch_index != -1 or is_zero_approx(_scroll_touch_velocity):
		return
	if SceneTransition.busy:
		_stop_touch_scroll()
		return
	if not _set_touch_scroll(_scroll.scroll_vertical + _scroll_touch_velocity * delta):
		_scroll_touch_velocity = 0.0
	else:
		_scroll_touch_velocity = move_toward(_scroll_touch_velocity, 0.0, TOUCH_SCROLL_FRICTION * delta)


## 使用滚动条实际内容范围夹紧，防止快速滑动或列表尺寸变化时越界。
func _set_touch_scroll(value: float) -> bool:
	var bar := _scroll.get_v_scroll_bar()
	var maximum := maxf(bar.max_value - bar.page, 0.0)
	var clamped := clampf(value, 0.0, maximum)
	_scroll.scroll_vertical = roundi(clamped)
	return value > 0.0 and value < maximum


## 失焦与取消时释放触点和惯性，恢复窗口后不会继续自行滑动。
func _stop_touch_scroll() -> void:
	_scroll_touch_index = -1
	_scroll_touch_velocity = 0.0
	_scroll_touch_dragging = false


## 移动端切到后台可能不再发送松手事件，因此单独清理手势所有权。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_stop_touch_scroll()

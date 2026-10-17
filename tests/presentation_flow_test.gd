## 新流程回归：验证真实事件账本、动画页面、漫画输入及暂停转场，不改写用户存档。
extends Node
var checks := 0
var failures := 0

## 自动加载就绪后执行；账本输出重定向到临时目录。
func _ready() -> void:
	# 剧情场景现在自动保存已展示标记，验证时同样隔离用户偏好文件。
	GameSettings.settings_path = "/private/tmp/gv-presentation-flow-settings.cfg"
	_run.call_deferred()

## 依次覆盖结算数据冻结、重复事件、失败操作及新页面资源契约。
func _run() -> void:
	RunStats.report_path = "/private/tmp/gv-presentation-test-report.json"
	RunStats.begin(RogueRunManager.AttackMode.FULL_ASSAULT, 123)
	RunStats.room(1, 7, "combat")
	RunStats.room(1, 7, "combat")
	RunStats.room(2, 7, "boss")
	_check(RunStats.data.rooms.size() == 2 and RunStats.data.rooms["战斗房"] == 1, "房间按关卡编号去重")
	var enemy := Node.new()
	add_child(enemy)
	RunStats.enemy(enemy, true)
	RunStats.enemy(enemy, true)
	_check(RunStats.data.enemies["敌军"] == 1 and RunStats.data.ally_kills == 1, "敌军和佣兵贡献只计一次")
	RunStats.currency(0, 100)
	RunStats.currency(0, 40, true)
	RunStats.currency(0, -10, true)
	RunStats.currency(1, 7)
	RunStats.count("items", "手雷", 3)
	RunStats.tactical(&"sample", "测试装备")
	RunStats.tactical(&"sample", "测试装备")
	var world := Node2D.new()
	add_child(world)
	var player := load("res://Prefab/Player/player.tscn").instantiate() as Player
	world.add_child(player)
	var weapon := PlayerWeaponPistol.new()
	_check(weapon.try_fire(player), "真实武器成功发射")
	_check(not weapon.try_fire(player), "冷却期间不计无效扳机")
	_check(RunStats.data.weapons["手枪"] == 1 and RunStats.data.projectiles == 1, "开火计数由实际弹夹消耗驱动")
	var initial := RunStats.elapsed
	get_tree().paused = true
	await get_tree().create_timer(0.05, true).timeout
	_check(is_equal_approx(initial, RunStats.elapsed), "暂停时不增加作战耗时")
	_check(await SceneTransition.cover("转场测试"), "暂停时遮幕可以完成")
	_check(SceneTransition.busy, "遮幕期间锁住输入与导航")
	_check(not await SceneTransition.cover("重复请求"), "拒绝重入遮幕")
	await SceneTransition.reveal()
	_check(not SceneTransition.busy, "揭幕后释放导航锁")
	get_tree().paused = false
	await get_tree().process_frame
	var report := RunStats.finish(true, 900, {"completed": 7, "total": 7, "mode_name": "反击模式"}, {"money": 70})
	_check(report.money_earned == 100 and report.money_spent == 30 and report.research_earned == 7, "经济记录使用实际收益，退款冲减支出")
	_check(report.money_remaining == 70 and report.tactical.size() == 1, "清空钱包前保留余额与装备")
	_check(RunStats.save_error == OK and FileAccess.file_exists(RunStats.report_path), "本地战报成功保存")
	RunStats.count("items", "手雷", 10)
	RunStats.finish(false, 0, {}, {})
	_check(RunStats.last_report.won and RunStats.last_report.items["手雷"] == 3, "冻结后重复结算与事件不改变成果")
	report.items["手雷"] = 99
	_check(RunStats.get_report().items["手雷"] == 3, "外部副本不能污染报告")
	var story = load("res://Scene/StoryIntro/StoryIntro.tscn").instantiate()
	add_child(story)
	await get_tree().create_timer(0.25).timeout
	_check(story.panel_index == 0, "故事从第一格开始")
	for i: int in range(1, 6):
		var event := InputEventJoypadButton.new()
		event.pressed = true
		story._input(event)
		await get_tree().create_timer(0.24).timeout
		_check(story.panel_index == i, "手柄按键逐格推进 %s" % i)
	_check((story.get("_picture") as TextureRect).texture.region.position.y > 0, "下排分镜取图正确")
	story.free()
	# 构造超过屏幕高度的报告，验证方向键滚动而不依赖运行窗口尺寸。
	for i: int in range(24):
		RunStats.last_report.enemies["测试敌军类别 %s" % i] = i + 1
	var results = load("res://Scene/RunResult/RunResult.tscn").instantiate()
	add_child(results)
	results._finish_animation()
	_check(results._navigation[0].text == "继续 · 制作人员", "反击完整胜利主操作进入片尾")
	_check(not results._navigation[0].disabled, "已保存战报允许继续")
	_check(not results._retry.visible, "保存成功不显示多余重试操作")
	await get_tree().process_frame
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	results._input(down)
	_check(results._scroll.scroll_vertical > 0, "方向操作可以滚动较长战报")
	# 通过真实输入分发从正文标签上滑动，验证 _input 提前接管，不依赖子控件 GUI 冒泡。
	await get_tree().process_frame
	var scroll_before: int = results._scroll.scroll_vertical
	var scroll_point: Vector2 = results._scroll.get_global_rect().get_center()
	var finger := InputEventScreenTouch.new()
	finger.index = 2
	finger.position = scroll_point
	finger.pressed = true
	get_viewport().push_input(finger.duplicate(), true)
	await get_tree().process_frame
	var swipe := InputEventScreenDrag.new()
	swipe.index = 2
	swipe.position = scroll_point - Vector2(0, 100)
	swipe.relative = Vector2(0, -100)
	swipe.velocity = Vector2(0, -700)
	get_viewport().push_input(swipe.duplicate(), true)
	await get_tree().process_frame
	_check(results._scroll.scroll_vertical >= scroll_before + 90, "正文标签区域触摸上滑可以向下滚动列表")
	finger.index = 3
	get_viewport().push_input(finger.duplicate(), true)
	await get_tree().process_frame
	_check(results._scroll_touch_index == 2, "第二根手指不抢占结算列表拖动")
	finger.pressed = false
	get_viewport().push_input(finger.duplicate(), true)
	await get_tree().process_frame
	_check(results._scroll_touch_index == 2, "无关手指松开不终止当前拖动")
	finger.index = 2
	get_viewport().push_input(finger.duplicate(), true)
	await get_tree().process_frame
	_check(results._scroll_touch_index == -1, "当前手指松开后释放滚动所有权")
	scroll_before = results._scroll.scroll_vertical
	results._process(0.05)
	_check(results._scroll.scroll_vertical > scroll_before, "快速滑动松手后继续减速滚动")
	results._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(results._scroll_touch_velocity == 0.0, "结算页失焦后停止滚动惯性")
	finger.position = results._scroll.get_global_rect().position - Vector2(0, 12)
	finger.pressed = true
	get_viewport().push_input(finger.duplicate(), true)
	await get_tree().process_frame
	_check(results._scroll_touch_index == -1, "正文以外的触摸不会接管结算列表")
	finger.position = scroll_point
	get_viewport().push_input(finger.duplicate(), true)
	await get_tree().process_frame
	swipe.position = scroll_point + Vector2(0, 10000)
	get_viewport().push_input(swipe.duplicate(), true)
	await get_tree().process_frame
	_check(results._scroll.scroll_vertical == 0, "向下大幅拖动夹紧列表顶部")
	swipe.position = scroll_point - Vector2(0, 10000)
	get_viewport().push_input(swipe.duplicate(), true)
	await get_tree().process_frame
	var scrollbar: VScrollBar = results._scroll.get_v_scroll_bar()
	_check(results._scroll.scroll_vertical <= scrollbar.max_value - scrollbar.page, "向上大幅拖动不会超过列表底部")
	finger.pressed = false
	finger.canceled = true
	get_viewport().push_input(finger.duplicate(), true)
	await get_tree().process_frame
	_check(results._scroll_touch_index == -1 and results._scroll_touch_velocity == 0.0, "系统取消触摸时释放列表手势与惯性")
	results.free()
	RunStats.last_report.won = false
	results = load("res://Scene/RunResult/RunResult.tscn").instantiate()
	add_child(results)
	_check(results._navigation[0].text == "返回首页", "战败不进入片尾")
	results.free()
	var credits = load("res://Scene/Credits/Credits.tscn").instantiate()
	add_child(credits)
	await get_tree().process_frame
	var offset: float = credits._offset
	credits._process(1.0)
	_check(credits._offset < offset, "制作名单自动向上滚动")
	_check(credits.CONTENT.text.contains("Sunny Studio") and credits.CONTENT.text.contains("Godot"), "片尾包含版权占位和引擎致谢")
	credits.free()
	weapon.free()
	world.queue_free()
	enemy.queue_free()
	RunStats.begin()
	_check(RunStats.data.weapons.is_empty() and RunStats.elapsed == 0.0, "新一局清空上局计数")
	RunStats.recording = false
	print("PRESENTATION_FLOW_TEST checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

## 汇总所有失败，单条断言不阻断后续功能检查。
func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

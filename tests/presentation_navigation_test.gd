## 启动与导航集成测试：真实切换工作室、剧情、菜单、战场及战报，临时文件隔离成果。
extends Node
var _checks := 0
var _failures := 0
var _original_preference := false

## 测试节点脱离 current_scene，作为观察者跨 SceneTree 换场保留。
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_run.call_deferred()

## 验证两个剧情设置分支、工作室输入不可跳过及战败实际路由。
func _run() -> void:
	get_tree().current_scene = null
	_original_preference = GameSettings.skip_story_intro
	RunStats.report_path = "/private/tmp/gv-presentation-navigation-report.json"
	GameSettings.skip_story_intro = false
	await _start_studio()
	_check(get_tree().current_scene.name == "StoryIntro", "未跳过剧情时工作室结束进入漫画")
	await _wait_transition()
	var story := get_tree().current_scene
	await get_tree().create_timer(0.25, true).timeout
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(100, 200)
	Input.parse_input_event(touch)
	await get_tree().create_timer(0.25, true).timeout
	_check(story.panel_index == 1, "触摸漫画区域实际推进下一格")
	story._skip.pressed.emit()
	await _wait_scene("MainMenu")
	await _wait_transition()
	_check(get_tree().current_scene.name == "MainMenu", "漫画跳过按钮实际进入首页")
	GameSettings.skip_story_intro = true
	await _start_studio()
	_check(get_tree().current_scene.name == "MainMenu", "跳过剧情设置仅略过漫画")
	await _wait_transition()
	_check(GameManager.start_from_menu(RogueRunManager.AttackMode.AIRBORNE), "首页可以开始空降模式")
	await _wait_scene("BattlePlanning")
	await _wait_scene("GameRun")
	await _wait_transition()
	# 首关降落动画结束后才确认 ACTIVE；等待状态以覆盖完整入场流程。
	for i: int in range(200):
		if GameManager.run_state == RogueRunManager.RunState.ACTIVE:
			break
		await get_tree().create_timer(0.02, true).timeout
	var host := get_tree().current_scene
	_check(GameManager.run_state == RogueRunManager.RunState.ACTIVE, "正式首关正确生成并确认")
	# 模拟安全出口已清场，只推进路线，不制造击杀或研究奖励。
	var boss_room: Node = host._room_nodes[int(host.level_map.boss_room_id)]
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if boss_room.is_ancestor_of(enemy):
			enemy.remove_from_group("enemies")
	host.boss_defeated = true
	RunStats.count("items", "跨关标记")
	_check(GameManager.report_level_cleared(host, 1), "首关安全出口允许推进")
	await get_tree().process_frame
	for i: int in range(200):
		if GameManager.run_state == RogueRunManager.RunState.ACTIVE and GameManager.get_current_stage_number() == 2 and not SceneTransition.busy:
			break
		await get_tree().create_timer(0.02, true).timeout
	_check(GameManager.run_state == RogueRunManager.RunState.ACTIVE and GameManager.get_current_stage_number() == 2, "后续 Level 完成遮幕生成与确认")
	_check(RunStats.data.items.get("跨关标记") == 1, "切关保留整局事件账本")
	# 测试仅检查失败路由，不结算真实研究收益，控制器入口已经由事件测试覆盖。
	GameManager.fail_run(host)
	RunStats.finish(false, 123, GameManager.get_run_snapshot(), {"money": 0})
	host.controlled_hud.show_defeat(123)
	await _wait_scene("RunResult")
	await _wait_transition()
	_check(get_tree().current_scene.report.score == 123 and not get_tree().paused, "战败进入独立结果页并解除场景暂停")
	# 构造已完成反击的冻结战报，检查真实结果页到片尾的按钮导航。
	RunStats.last_report.merge({"won": true, "mode": RogueRunManager.AttackMode.FULL_ASSAULT, "completed": 7, "total": 7}, true)
	GameManager.open_presentation("res://Scene/RunResult/RunResult.tscn", "反击成果")
	await _wait_transition()
	get_tree().current_scene._navigation[0].pressed.emit()
	await _wait_scene("Credits")
	await _wait_transition()
	_check(get_tree().current_scene.name == "Credits", "反击战报继续按钮实际进入滚动片尾")
	get_tree().current_scene._back_report()
	await _wait_scene("RunResult")
	await _wait_transition()
	_check(get_tree().current_scene.report.score == 123, "片尾返回仍保留原成果")
	GameManager.return_to_main_menu()
	await _wait_scene("MainMenu")
	await _wait_transition()
	_check(GameManager.run_state == RogueRunManager.RunState.IDLE, "结果返回首页清理对局状态")
	GameSettings.skip_story_intro = _original_preference
	print("PRESENTATION_NAVIGATION_TEST checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(1 if _failures else 0)

## 两次启动均播放工作室；测试缩短停留时间，但动画仍完整执行。
func _start_studio() -> void:
	var previous := get_tree().current_scene
	if is_instance_valid(previous):
		get_tree().current_scene = null
		previous.free()
	var studio: Control = load("res://Scene/StudioIntro/StudioIntro.tscn").instantiate()
	studio.card_duration = 0.02
	get_tree().root.add_child(studio)
	get_tree().current_scene = studio
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	Input.parse_input_event(key)
	await get_tree().create_timer(0.1, true).timeout
	_check(get_tree().current_scene == studio, "启动信息不可通过按键跳过")
	for i: int in range(300):
		if get_tree().current_scene != studio:
			return
		await get_tree().create_timer(0.02, true).timeout
	_check(false, "工作室导航超时")

## 有界等待真实场景名，遇到故障输出明确断言而非永久挂起。
func _wait_scene(expected: String) -> void:
	for i: int in range(400):
		if is_instance_valid(get_tree().current_scene) and get_tree().current_scene.name == expected:
			return
		await get_tree().create_timer(0.02, true).timeout
	_check(false, "等待页面超时：" + expected)

## 遮幕是异步流程，页面出现不代表已允许输入。
func _wait_transition() -> void:
	for i: int in range(100):
		if not SceneTransition.busy:
			return
		await get_tree().create_timer(0.02, true).timeout
	_check(false, "转场锁释放超时")

## 汇总错误供 CLI 判断，成功测试不写账户或偏好。
func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)

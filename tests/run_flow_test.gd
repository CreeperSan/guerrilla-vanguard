## 对局流程契约检查；使用模拟宿主，不创建玩家、敌人或实际房间。
## 导入项目后执行：godot --headless --path . --script res://tests/run_flow_test.gd
extends SceneTree

const MANAGER_SCRIPT = preload("res://Script/Global/game_manager.gd")
const FINAL_THEME_PATH := "res://Scene/LevelUndergroundFortress/theme.tres"

## 模拟宿主只记录切关请求，并允许测试独立控制安全出口条件与加载确认。
class TestHost extends Node:
	var cleared: bool = false
	var requests: Array[Dictionary] = []

	## 记录加载版本，测试不会自动确认，便于检查切关等待期间的重复请求。
	func _on_run_stage_requested(stage_number: int, theme: BattlefieldTheme, stage_seed: int, revision: int) -> void:
		requests.append({"stage": stage_number, "theme": theme, "seed": stage_seed, "revision": revision})

	## 返回当前测试设置的清场状态，模拟 Boss 与守卫都被消灭。
	func is_current_level_cleared() -> bool:
		return cleared

var _failures: int = 0
var _checks: int = 0


## 等自动加载完成后开始测试；使用独立管理器，不改变项目的 AutoLoad 实例。
func _initialize() -> void:
	_run_tests.call_deferred()


## 顺序检查抽取规则、可复现性、推进锁、胜败、宿主替换及过期请求。
func _run_tests() -> void:
	var manager: RogueRunManager = MANAGER_SCRIPT.new()
	root.add_child(manager)
	for mode: int in [RogueRunManager.AttackMode.AIRBORNE, RogueRunManager.AttackMode.FULL_ASSAULT]:
		var first: Array[Dictionary] = []
		for repetition: int in range(2):
			manager.reset_run()
			_check(manager.start_run(mode, 20261007), "有效主题池允许开始对局")
			var snapshot := manager.get_run_snapshot()
			_check(int(snapshot["total"]) == (5 if mode == RogueRunManager.AttackMode.AIRBORNE else 7), "模式总关数正确")
			var levels: Array = snapshot["levels"]
			var seen: Dictionary = {}
			for index: int in range(levels.size()):
				var level: Dictionary = levels[index]
				var path := str(level["theme_path"])
				_check(not seen.has(path), "同一局主题不重复")
				seen[path] = true
				var fixed := mode == RogueRunManager.AttackMode.FULL_ASSAULT and index == 6
				_check((path == FINAL_THEME_PATH) == fixed, "地下要塞仅作为总攻第七关")
				_check(bool(level["fixed"]) == fixed, "固定终点标记一致")
				_check(int(level["seed"]) > 0, "各关种子有效")
			if repetition == 0:
				first.assign(levels)
			else:
				_check(first == levels, "相同模式和种子复现全部主题与房间种子")
		manager.reset_run()
		_check(manager.start_run(mode, 20261008), "另一个种子允许开始")
		_check(first != manager.get_run_snapshot()["levels"], "不同种子可产生不同路线或房间")

	manager.reset_run()
	var incomplete := BattlefieldCampaign.new()
	incomplete.themes.append(manager.level_pool.themes[0])
	incomplete.themes.append(manager.level_pool.themes[0])
	incomplete.themes.append(null)
	# 这两次拒绝故意产生错误日志；判定以检查结果和进程退出码为准。
	_check(not manager.start_run(RogueRunManager.AttackMode.AIRBORNE, 1, incomplete), "空值和重复主题不能补足主题池")
	_check(manager.get_run_snapshot()["total"] == 0, "无效主题池不提交部分路线")
	_check(not manager.start_run(99, 1), "未知模式被拒绝")

	var host := TestHost.new()
	var outsider := TestHost.new()
	root.add_child(host)
	root.add_child(outsider)
	_check(manager.attach_level_host(host), "有效宿主可绑定")
	_check(manager.start_run(RogueRunManager.AttackMode.FULL_ASSAULT, 1234), "总攻流程开始")
	await _flush_requests()
	for stage: int in range(1, 8):
		_check(host.requests.size() == stage, "每关只发送一个加载请求")
		var request: Dictionary = host.requests.back()
		var revision := int(request["revision"])
		_check(int(request["stage"]) == stage, "请求序号与当前关一致")
		_check(not manager.report_level_cleared(host, stage), "加载未确认时不能通关")
		_check(not manager.confirm_stage_ready(outsider, stage, revision), "非当前宿主不能确认")
		_check(not manager.confirm_stage_ready(host, stage + 1, revision), "错误序号不能确认")
		_check(not manager.confirm_stage_ready(host, stage, revision - 1), "过期版本不能确认")
		_check(manager.confirm_stage_ready(host, stage, revision), "正确加载确认进入战斗")
		_check(not manager.confirm_stage_ready(host, stage, revision), "不能重复确认")
		host.cleared = false
		_check(not manager.report_level_cleared(host, stage), "未清空 Boss 房不能通关")
		host.cleared = true
		_check(not manager.report_level_cleared(outsider, stage), "非当前宿主不能推进")
		_check(manager.report_level_cleared(host, stage), "安全出口成功推进")
		_check(not manager.report_level_cleared(host, stage), "重复触碰出口无效")
		_check(manager.completed_level_count == stage, "完成数只增加一次")
		await _flush_requests()
	_check(manager.run_state == RogueRunManager.RunState.COMPLETED, "第七关结束后进入胜利")
	_check(host.requests.size() == 7, "胜利后不请求第八关")
	_check(not manager.fail_run(host), "完成状态不能再变为战败")

	manager.reset_run()
	host.requests.clear()
	_check(manager.start_run(RogueRunManager.AttackMode.AIRBORNE, 55), "重置后可创建新局")
	_check(manager.fail_run(host), "加载期间死亡可结束本局")
	await _flush_requests()
	_check(host.requests.is_empty(), "失败后排队的请求失效")
	_check(not manager.report_level_cleared(host, 1), "失败后不能继续推进")
	_check(manager.get_run_snapshot()["levels"][0]["status"] == "failed", "失败位置显示红色状态")

	manager.reset_run()
	_check(manager.start_run(RogueRunManager.AttackMode.AIRBORNE, 66), "新局可重新加载第一关")
	await _flush_requests()
	var old_request: Dictionary = host.requests.back()
	manager.reset_run()
	_check(manager.start_run(RogueRunManager.AttackMode.AIRBORNE, 77), "相同序号的新局可重新创建")
	_check(not manager.confirm_stage_ready(host, 1, int(old_request["revision"])), "上一局同序号的异步确认失效")
	manager.reset_run()
	host.requests.clear()
	await _flush_requests()
	_check(host.requests.is_empty(), "重置后排队的请求失效")

	_check(manager.start_run(RogueRunManager.AttackMode.AIRBORNE, 88), "宿主替换前创建路线")
	_check(manager.attach_level_host(outsider), "新宿主可替换旧宿主")
	await _flush_requests()
	_check(host.requests.is_empty() and outsider.requests.size() == 1, "请求只发送到最新宿主")
	var new_request: Dictionary = outsider.requests.back()
	_check(not manager.confirm_stage_ready(host, 1, int(new_request["revision"])), "旧宿主不能提交结果")
	_check(manager.confirm_stage_ready(outsider, 1, int(new_request["revision"])), "新宿主确认有效")
	var snapshot_copy := manager.get_run_snapshot()
	snapshot_copy["levels"][0]["name"] = "外部修改"
	_check(manager.get_run_snapshot()["levels"][0]["name"] != "外部修改", "界面快照不允许修改内部路线")

	manager.reset_run()
	manager.detach_level_host(outsider)
	host.queue_free()
	outsider.queue_free()
	manager.queue_free()
	print("[run_flow_test] checks=%d failures=%d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


## 延迟调用在帧末执行；跨两帧等待，避免断言先于请求真正分发。
func _flush_requests() -> void:
	await process_frame
	await process_frame


## 收集全部检查结果，失败时返回非零退出码，便于在命令行定位具体契约。
func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[run_flow_test] " + description)

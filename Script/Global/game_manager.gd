## AutoLoad 对局流程管理器：抽取 Level 直线路线，协调切关，并向 HUD 发布本局进度。
## 房间、角色和背包仍由关卡场景管理；切关时持久宿主保留玩家和 HUD。
class_name RogueRunManager
extends Node

enum AttackMode { AIRBORNE, FULL_ASSAULT }
enum RunState { IDLE, TRANSITIONING, ACTIVE, COMPLETED, FAILED }

signal sig_run_changed(snapshot: Dictionary)
signal sig_stage_requested(stage_number: int, theme: BattlefieldTheme, stage_seed: int, revision: int)
signal sig_run_finished(won: bool)

const RUN_SCENE_PATH := "res://Scene/GameRun/GameRun.tscn"
const DEFAULT_LEVEL_POOL: BattlefieldCampaign = preload("res://Script/Level/run_level_pool.tres")
const AIRBORNE_LEVEL_COUNT := 5
const FULL_ASSAULT_LEVEL_COUNT := 7

## 全局可替换的主题池；不在各关卡脚本内分别维护随机顺序。
@export var level_pool: BattlefieldCampaign = DEFAULT_LEVEL_POOL
## 总攻的固定终点不参与任何模式的随机抽取；使用项目现有 UndergroundFortress 目录。
@export var full_assault_final_theme: BattlefieldTheme = preload("res://Scene/LevelUndergroundFortress/theme.tres")

## 只读约定：外部通过方法请求推进，不直接修改当前状态、序号与完成数。
var run_state: RunState = RunState.IDLE
var attack_mode: int = AttackMode.AIRBORNE
var run_seed: int = 0
var current_stage_index: int = -1
var completed_level_count: int = 0

var _route: Array[Dictionary] = []
var _host_ref: WeakRef
var _run_revision: int = 0


## 管理器在模式选择、暂停和结果页期间也可以接收重新开始请求；无逐帧轮询。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## 绑定唯一持久关卡宿主，替换宿主时断开旧连接，避免一次切关生成多份地图。
func attach_level_host(host: Node) -> bool:
	if not is_instance_valid(host) or not host.has_method("_on_run_stage_requested") or not host.has_method("is_current_level_cleared"):
		push_error("GameManager：关卡宿主缺少流程请求或安全出口接口。")
		return false
	if _get_host() == host:
		return true
	var previous := _get_host()
	if previous != null:
		detach_level_host(previous)
	_host_ref = weakref(host)
	sig_stage_requested.connect(Callable(host, "_on_run_stage_requested"))
	if run_state in [RunState.ACTIVE, RunState.TRANSITIONING]:
		run_state = RunState.TRANSITIONING
		_run_revision += 1
		_emit_snapshot()
		_request_current_stage.call_deferred(_run_revision)
	return true


## 场景退出时释放信号与弱引用；对局结果继续保留在单例中供界面读取。
func detach_level_host(host: Node) -> void:
	if _get_host() != host:
		return
	var callback := Callable(host, "_on_run_stage_requested")
	if sig_stage_requested.is_connected(callback):
		sig_stage_requested.disconnect(callback)
	_host_ref = null


## 开始新局：先校验主题池，再用独立 RNG 不重复抽取，保证无效配置不会覆盖已有路线。
func start_run(mode: int, seed_value: int = 0, pool: BattlefieldCampaign = null) -> bool:
	if mode not in [AttackMode.AIRBORNE, AttackMode.FULL_ASSAULT]:
		push_error("GameManager：未知进攻模式 %s。" % mode)
		return false
	if run_state != RunState.IDLE:
		push_warning("GameManager：当前不是待开始状态，请通过 restart_run 重建玩家并创建新局。")
		return false
	var required_count := AIRBORNE_LEVEL_COUNT if mode == AttackMode.AIRBORNE else FULL_ASSAULT_LEVEL_COUNT
	var candidates := _get_valid_themes(pool if pool != null else level_pool)
	var fixed_directory := full_assault_final_theme.room_template_root.trim_suffix("/") if full_assault_final_theme != null else "res://Scene/LevelUndergroundFortress"
	for index: int in range(candidates.size() - 1, -1, -1):
		if candidates[index].room_template_root.trim_suffix("/") == fixed_directory:
			candidates.remove_at(index)
	var random_count := required_count - 1 if mode == AttackMode.FULL_ASSAULT else required_count
	if mode == AttackMode.FULL_ASSAULT and (full_assault_final_theme == null or not _has_room_templates(fixed_directory)):
		push_error("GameManager：总攻模式缺少有效的固定地下要塞终点。")
		return false
	if candidates.size() < random_count:
		push_error("GameManager：%s需要随机抽取 %d 个不同主题，目前只有 %d 个有效随机主题。" % [get_mode_name(mode), random_count, candidates.size()])
		return false
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var actual_seed := rng.seed
	# Fisher–Yates 使用本局 RNG，不依赖全局 shuffle，也不把主题固定绑定到难度序号。
	for index: int in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = temporary
	var next_route: Array[Dictionary] = []
	for index: int in range(random_count):
		next_route.append({"theme": candidates[index], "seed": rng.randi_range(1, 2147483646), "fixed": false})
	if mode == AttackMode.FULL_ASSAULT:
		next_route.append({"theme": full_assault_final_theme, "seed": rng.randi_range(1, 2147483646), "fixed": true})
	_route = next_route
	attack_mode = mode
	run_seed = actual_seed
	current_stage_index = 0
	completed_level_count = 0
	run_state = RunState.TRANSITIONING
	_run_revision += 1
	_emit_snapshot()
	print("[GameManager] mode=%s seed=%s route=%s" % [get_mode_name(attack_mode), run_seed, get_run_snapshot()["levels"]])
	_request_current_stage.call_deferred(_run_revision)
	return true


## 宿主完成对应地图初始化后才进入 ACTIVE，过期序号和非当前宿主的确认无效。
func confirm_stage_ready(host: Node, stage_number: int, revision: int) -> bool:
	if not is_stage_request_current(host, stage_number, revision):
		return false
	run_state = RunState.ACTIVE
	_emit_snapshot()
	return true


## 宿主异步清理后再次校验版本，同序号的新局也不能被上一局的加载结果覆盖。
func is_stage_request_current(host: Node, stage_number: int, revision: int) -> bool:
	return is_instance_valid(host) and host == _get_host() and run_state == RunState.TRANSITIONING and stage_number == get_current_stage_number() and revision == _run_revision


## 安全 Boss 出口请求推进：来源、阶段和清场状态同时校验，重复进入只能完成一次。
func report_level_cleared(host: Node, stage_number: int) -> bool:
	if host != _get_host() or not is_instance_valid(host) or run_state != RunState.ACTIVE or stage_number != get_current_stage_number():
		return false
	if not bool(host.call("is_current_level_cleared")):
		return false
	completed_level_count += 1
	_run_revision += 1
	if completed_level_count >= _route.size():
		run_state = RunState.COMPLETED
		_emit_snapshot()
		sig_run_finished.emit(true)
		return true
	current_stage_index += 1
	run_state = RunState.TRANSITIONING
	_emit_snapshot()
	_request_current_stage.call_deferred(_run_revision)
	return true


## 玩家死亡后保留已完成的关卡和失败位置，并使所有排队的切关请求失效。
func fail_run(host: Node) -> bool:
	if host != _get_host() or not is_instance_valid(host) or run_state not in [RunState.ACTIVE, RunState.TRANSITIONING]:
		return false
	run_state = RunState.FAILED
	_run_revision += 1
	_emit_snapshot()
	sig_run_finished.emit(false)
	return true


## 清空流程数据；测试或外部菜单可调用，正式重新开始通过 restart_run 同时重建玩家。
func reset_run() -> void:
	_run_revision += 1
	_route.clear()
	current_stage_index = -1
	completed_level_count = 0
	run_seed = 0
	run_state = RunState.IDLE
	_emit_snapshot()


## 重开时重载持久战斗宿主，确保上一局的生命、背包、技能和积分不会带入新局。
func restart_run() -> void:
	reset_run()
	var host := _get_host()
	if host != null:
		detach_level_host(host)
	_reload_run_scene.call_deferred(_run_revision)


## 返回不包含可修改主题资源的快照，HUD 和其他系统只读取同一份进度。
func get_run_snapshot() -> Dictionary:
	var levels: Array[Dictionary] = []
	for index: int in range(_route.size()):
		var theme := _route[index]["theme"] as BattlefieldTheme
		var status := "completed" if index < completed_level_count else "upcoming"
		if index == current_stage_index and index >= completed_level_count:
			status = "failed" if run_state == RunState.FAILED else "current"
		levels.append({"number": index + 1, "name": theme.display_name, "theme_path": theme.resource_path, "seed": int(_route[index]["seed"]), "status": status, "fixed": bool(_route[index].get("fixed", false))})
	return {"mode": attack_mode, "mode_name": get_mode_name(attack_mode), "state": run_state, "seed": run_seed, "current": get_current_stage_number(), "completed": completed_level_count, "total": _route.size(), "levels": levels}


## 对外关卡序号从 1 开始；尚未开始时为 0，与数组下标明确区分。
func get_current_stage_number() -> int:
	return current_stage_index + 1


## 模式名称集中定义，日志、HUD 和模式菜单使用相同规则。
func get_mode_name(mode: int) -> String:
	return "空降模式" if mode == AttackMode.AIRBORNE else "总攻模式"


## 排除空资源和重复主题目录，保证抽取到的主题包含全部九种尺寸的两个样式。
func _get_valid_themes(pool: BattlefieldCampaign) -> Array[BattlefieldTheme]:
	var themes: Array[BattlefieldTheme] = []
	var seen: Dictionary = {}
	if pool == null:
		return themes
	for theme: BattlefieldTheme in pool.themes:
		if theme == null:
			continue
		var directory := theme.room_template_root.trim_suffix("/")
		if directory.is_empty() or seen.has(directory):
			continue
		if not _has_room_templates(directory):
			push_warning("GameManager：主题 %s 的房间模板不完整，已排除。" % theme.display_name)
			continue
		seen[directory] = true
		themes.append(theme)
	return themes


## 按目录规则检查每个尺寸至少两种有效场景，不预先实例化房间或其敌人。
func _has_room_templates(directory: String) -> bool:
	if not DirAccess.dir_exists_absolute(directory):
		return false
	var folders := DirAccess.get_directories_at(directory)
	for width: int in range(1, 4):
		for height: int in range(1, 4):
			var prefix := "Room_%dx%d_" % [width, height]
			var count := 0
			for folder: String in folders:
				if folder.begins_with(prefix) and ResourceLoader.exists("%s/%s/%s.tscn" % [directory, folder, folder], "PackedScene"):
					count += 1
			if count < 2:
				return false
	return true


## 弱引用避免退出场景后保留失效宿主；不持有任何房间实例。
func _get_host() -> Node:
	return _host_ref.get_ref() as Node if _host_ref != null else null


## 只发送当前版本的切关请求；宿主稍后绑定时会再次发送，失败和重开不会加载旧关卡。
func _request_current_stage(revision: int) -> void:
	if revision != _run_revision or run_state != RunState.TRANSITIONING or _get_host() == null:
		return
	var entry: Dictionary = _route[current_stage_index]
	sig_stage_requested.emit(get_current_stage_number(), entry["theme"] as BattlefieldTheme, int(entry["seed"]), revision)


## 在统一位置发布快照，避免界面与控制器分别计算完成进度。
func _emit_snapshot() -> void:
	sig_run_changed.emit(get_run_snapshot())


## 场景重载放到延迟回调，避免在按钮或死亡信号回调中直接释放当前场景。
func _reload_run_scene(revision: int) -> void:
	if revision != _run_revision:
		return
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(RUN_SCENE_PATH)
	if error != OK:
		push_error("GameManager：无法重新加载对局场景，错误码 %s。" % error)

## 整局事件账本：跨关保留，暂停不计时，结算前冻结；只保存本地最后一次战报。
class_name RunStatistics
extends Node

var report_path := "user://last_run_report.json"
var recording := false
var elapsed := 0.0
var data: Dictionary = {}
var last_report: Dictionary = {}
var save_error := OK
var _rooms: Dictionary = {}
var _enemies: Dictionary = {}

## 常驻节点在暂停时仍运行，只有实际战斗时间累加。
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(report_path):
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		if loaded is Dictionary:
			last_report = loaded

## 每个新宿主初始化；正式路线开始时补充模式和种子，不跨关重置。
func begin(mode: int = -1, seed_value: int = 0) -> void:
	recording = true
	elapsed = 0.0
	_rooms.clear()
	_enemies.clear()
	data = {"mode": mode, "seed": seed_value, "rooms": {}, "enemies": {}, "items": {}, "weapons": {}, "tactical": {}, "money_earned": 0, "money_spent": 0, "research_earned": 0, "ally_kills": 0, "projectiles": 0}

## 暂停、倒计时、切关及结果展示均不计入有效作战耗时。
func _process(delta: float) -> void:
	if recording and not get_tree().paused and not SceneTransition.busy:
		elapsed += delta

## 仅接受已确认的事件；通用计数器供实际消费及成功开火使用。
func count(category: String, label: String, amount: int = 1) -> void:
	if recording and amount > 0:
		data[category][label] = int(data[category].get(label, 0)) + amount

## 同一关同一房间只记一次，安全房的完成表示已探索。
func room(stage: int, room_id: int, kind: String) -> void:
	var key := "%s:%s" % [stage, room_id]
	if not recording or _rooms.has(key):
		return
	_rooms[key] = true
	var names := {"combat": "战斗房", "combat_supply": "战斗补给房", "boss": "首领房", "merchant": "商店", "mercenary": "佣兵房", "start": "起始房", "supply": "补给房"}
	count("rooms", names.get(kind, kind))

## 死亡信号可能被多个观察者订阅；按实例去重，并保留佣兵贡献。
func enemy(target: Node, ally: bool) -> void:
	if not recording or not is_instance_valid(target) or _enemies.has(target.get_instance_id()):
		return
	_enemies[target.get_instance_id()] = true
	var label := "敌军"
	if target is BattlefieldBoss:
		label = "首领 · " + target.boss_display_name
	elif target.get("behavior_mode") != null:
		label = ["固定警戒兵", "游走追击兵", "追击射手", "移动射手"][clampi(int(target.get("behavior_mode")), 0, 3)]
	count("enemies", label)
	if ally:
		data.ally_kills += 1

## 记录实际入账与退款，退款冲减支出，避免把商店失败发放当作收益。
func currency(kind: int, amount: int, spending: bool = false) -> void:
	if recording:
		var key := "money_spent" if spending else ("money_earned" if kind == 0 else "research_earned")
		data[key] = maxi(0, int(data[key]) + amount)

## 开火次数是扣除弹夹的一次扳机；霰弹颗粒另计投射物。
func shot(slot: Node, pellets: int) -> void:
	var label := str(slot.get("display_name"))
	if label.is_empty():
		label = slot.get_script().resource_path.get_file().get_basename()
	count("weapons", label)
	if recording:
		data.projectiles += pellets

## 战术装备按唯一标识存储，显示名不参与去重。
func tactical(id: StringName, label: String) -> void:
	if recording:
		data.tactical[str(id)] = label

## 必须在钱包 settle_run 清空金钱前调用；重复完成不会重写或重复入账。
func finish(won: bool, score: int, route: Dictionary, wallet: Dictionary) -> Dictionary:
	if not recording:
		return last_report.duplicate(true)
	recording = false
	last_report = data.duplicate(true)
	last_report.merge({"won": won, "score": score, "elapsed_seconds": elapsed, "finished_at": Time.get_datetime_string_from_system(), "completed": route.get("completed", 0), "total": route.get("total", 1), "mode_name": route.get("mode_name", "单关行动"), "money_remaining": wallet.get("money", 0)}, true)
	save_report()
	return last_report.duplicate(true)

## 临时文件完整写入后原子替换；失败保留内存报告，允许结果页重试。
func save_report() -> Error:
	var file := FileAccess.open(report_path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_error = FileAccess.get_open_error()
		return save_error
	file.store_string(JSON.stringify(last_report, "\t"))
	file.flush()
	# 打开成功不代表写入成功，磁盘写满等错误不得替换原战报。
	save_error = file.get_error()
	file.close()
	if save_error != OK:
		return save_error
	save_error = DirAccess.rename_absolute(report_path + ".tmp", report_path)
	return save_error

## UI 获取副本，计数动画不会污染已冻结的原始数据。
func get_report() -> Dictionary:
	return last_report.duplicate(true)

## AutoLoad 货币账户：金钱只属于本局，研究点数只在胜败结算后写入本地账户。
## 所有变更通过方法执行，HUD 读取快照；保存失败保留待结算收益，允许重试。
class_name RunCurrencyWallet
extends Node

enum Kind { MONEY, RESEARCH }
signal sig_currency_changed(snapshot: Dictionary)

const SAVE_PATH := "user://research_account.cfg"
const TEMP_PATH := "user://research_account.cfg.tmp"

var money: int = 0
var run_research: int = 0
var banked_research: int = 0
## 各独立升级项目的已购等级；与研究余额在同一个文件中原子提交。
var _upgrade_levels: Dictionary = {}
## 两类收益各自累计小数，避免低额拾取逐次取整损失加成。
var _reward_remainders: Dictionary = {Kind.MONEY: 0.0, Kind.RESEARCH: 0.0}
var _run_open: bool = false
var _settled: bool = false
var _settlement_failed: bool = false
## 无法读取已有账户时禁止覆盖存档，避免把原余额错误替换为零。
var _account_loaded: bool = true
## 首次完整通关空降后解锁强攻，与研究账户共用同一持久存档。
var _airborne_completed: bool = false
var _pending_airborne_completion: bool = false


## 暂停与结果页期间仍能保存账户；启动时只加载已经结算的研究点数。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var account := ConfigFile.new()
	var error := account.load(SAVE_PATH)
	if error == OK:
		var saved: Variant = account.get_value("account", "research", 0)
		if saved is int and saved >= 0:
			banked_research = saved
			var levels: Variant = account.get_value("upgrades", "levels", {})
			if not _load_upgrade_levels(levels):
				_account_loaded = false
				push_error("升级存档内容无效，禁止覆盖原账户。")
			_airborne_completed = account.get_value("progress", "airborne_completed", false) == true
		else:
			_account_loaded = false
			push_error("研究账户内容无效，请检查 user://research_account.cfg。")
	elif error != ERR_FILE_NOT_FOUND:
		_account_loaded = false
		push_error("研究账户加载失败，错误码 %s。" % error)
	_publish()


## 新战斗宿主建立时清空局内钱包；跨 Level 切换不会调用，因此收益可以继续累积。
func begin_run() -> bool:
	if _settlement_failed and not settle_run():
		return false
	money = 0
	run_research = 0
	_reward_remainders = {Kind.MONEY: 0.0, Kind.RESEARCH: 0.0}
	_run_open = true
	_settled = false
	_settlement_failed = false
	_publish()
	return true


## 拾取与 Boss 奖励统一入账；结果页及无效数量不能继续增加本局收益。
func credit(kind: Kind, amount: int) -> bool:
	if not _run_open or amount <= 0:
		return false
	if kind != Kind.MONEY and kind != Kind.RESEARCH:
		return false
	var id := "battlefield.money" if kind == Kind.MONEY else "battlefield.research"
	var scaled := amount * get_upgrade_multiplier(id) + float(_reward_remainders[kind])
	var credited := floori(scaled + 0.0000001)
	_reward_remainders[kind] = maxf(scaled - credited, 0.0)
	if kind == Kind.MONEY:
		money += credited
	else:
		run_research += credited
	_publish()
	return true


## 商店扣款入口：只有进行中的本局钱包能够支付正数价格，成功后立即更新 HUD。
func try_spend_money(cost: int) -> bool:
	if not _run_open or cost <= 0 or money < cost:
		return false
	money -= cost
	_publish()
	return true


## 预留闯关外研究扣款入口，先确认保存成功再提交余额；战斗内不能花费已存研究。
## 升级购买使用 try_purchase_upgrade，将余额和等级一次提交。
func try_spend_research(cost: int) -> bool:
	if _run_open or _settlement_failed or cost <= 0 or banked_research < cost:
		return false
	var next_balance := banked_research - cost
	var error := _save_balance(next_balance)
	if error != OK:
		push_error("研究点数扣款保存失败，余额未变更，错误码 %s。" % error)
		return false
	banked_research = next_balance
	_publish()
	return true


## 从旧存档迁移时缺省零级；保留未知项目，已知项目只接受合法整数等级。
func _load_upgrade_levels(saved: Variant) -> bool:
	if not saved is Dictionary:
		return false
	for id: Variant in saved:
		var level: Variant = saved[id]
		if not id is String or not level is int or level < 0 or level > BattlefieldUpgradeConfig.MAX_LEVEL:
			return false
	_upgrade_levels = saved.duplicate()
	return true


## UI 和武器读取当前持久等级，未知项目也只能从零级开始。
func get_upgrade_level(id: String) -> int:
	return int(_upgrade_levels.get(id, 0))


## 获取该独立项目相对零级的能力倍率。
func get_upgrade_multiplier(id: String) -> float:
	return BattlefieldUpgradeConfig.get_multiplier(id, get_upgrade_level(id))


## 返回下一等级的费用；满级或未知项目返回零，不能再扣款。
func get_upgrade_cost(id: String) -> int:
	var entry := BattlefieldUpgradeConfig.get_entry(id)
	var level := get_upgrade_level(id)
	if entry.is_empty() or level >= BattlefieldUpgradeConfig.MAX_LEVEL:
		return 0
	return int(entry["costs"][level])


## 首页按钮和事务共用购买条件，战斗中、结算失败和账户损坏时均不可购买。
func can_purchase_upgrade(id: String) -> bool:
	var cost := get_upgrade_cost(id)
	return _account_loaded and not _run_open and not _settlement_failed and cost > 0 and banked_research >= cost


## 一次只购买下一级，不接受外部指定等级；等级和余额一起落盘后才刷新内存/UI。
func try_purchase_upgrade(id: String) -> bool:
	if not can_purchase_upgrade(id):
		return false
	var next_levels := _upgrade_levels.duplicate()
	next_levels[id] = get_upgrade_level(id) + 1
	var next_balance := banked_research - get_upgrade_cost(id)
	var error := _save_balance(next_balance, next_levels)
	if error != OK:
		push_error("升级保存失败，余额和等级未变更，错误码 %s。" % error)
		return false
	_upgrade_levels = next_levels
	banked_research = next_balance
	_publish()
	return true


## 胜利与战败采用同一结算规则；先保存账户再确认收益，重复调用不会重复入账。
func settle_run(airborne_victory: bool = false) -> bool:
	if _settled:
		return true
	if not _run_open and not _settlement_failed:
		return false
	# 只有正式空降完整胜利才提交解锁；失败、单关测试与提前退出都不会解锁。
	_pending_airborne_completion = _pending_airborne_completion or airborne_victory
	_run_open = false
	money = 0
	var next_balance := banked_research + run_research
	var error := _save_balance(next_balance)
	if error != OK:
		_settlement_failed = true
		push_error("研究点数结算保存失败，收益暂留内存，错误码 %s。" % error)
		_publish()
		return false
	banked_research = next_balance
	_airborne_completed = _airborne_completed or _pending_airborne_completion
	_pending_airborne_completion = false
	_settled = true
	_settlement_failed = false
	_publish()
	return true


## 保存失败时阻止重开丢失内存收益；重新开始按钮会再次尝试结算。
func has_pending_settlement() -> bool:
	return _settlement_failed


## 首页和模式启动共同检查，避免只禁用按钮却仍允许外部调用启动强攻。
func is_assault_unlocked() -> bool:
	return _airborne_completed


## 离开战斗回首页时关闭钱包，未结算退出不带出本局研究点数。
func close_run() -> void:
	money = 0
	run_research = 0
	_reward_remainders = {Kind.MONEY: 0.0, Kind.RESEARCH: 0.0}
	_run_open = false
	_settled = false
	_publish()


## 只删除游戏拥有的账户文件；音量设置独立保存，不删除用户数据目录内的其他文件。
## 调用方必须先展示二次确认；删除失败时不谎报账户已清空。
func delete_game_save() -> Error:
	for path: String in [TEMP_PATH, SAVE_PATH]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				return error
	banked_research = 0
	_upgrade_levels.clear()
	_airborne_completed = false
	_pending_airborne_completion = false
	_settlement_failed = false
	_account_loaded = true
	close_run()
	return OK


## 明确区分本局研究收益与已存账户；局内研究保留用于结算页显示，不能再次带出。
func get_snapshot() -> Dictionary:
	return {"money": money, "research_run": run_research, "research_bank": banked_research, "settled": _settled, "settlement_failed": _settlement_failed, "assault_unlocked": _airborne_completed}


## 先写临时文件，再替换正式账户，避免写入中断把原有已存研究点数截断。
## 购买可传入候选等级；普通结算和扣款沿用当前等级，均不覆盖其他账户状态。
func _save_balance(balance: int, levels: Dictionary = {}) -> Error:
	if not _account_loaded:
		return ERR_FILE_CORRUPT
	var account := ConfigFile.new()
	account.set_value("account", "version", 3)
	account.set_value("upgrades", "levels", _upgrade_levels if levels.is_empty() else levels)
	account.set_value("account", "research", balance)
	account.set_value("progress", "airborne_completed", _airborne_completed or _pending_airborne_completion)
	return _store_account(account)


## 持久化边界独立于升级事务，临时文件写完后才替换正式账户。
func _store_account(account: ConfigFile) -> Error:
	var error := account.save(TEMP_PATH)
	if error != OK:
		return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))


## 所有入账、扣款、开局和结算都从这里发布同一份钱包快照。
func _publish() -> void:
	sig_currency_changed.emit(get_snapshot())

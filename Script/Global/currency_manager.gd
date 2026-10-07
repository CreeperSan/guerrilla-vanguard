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
	_run_open = true
	_settled = false
	_settlement_failed = false
	_publish()
	return true


## 拾取与 Boss 奖励统一入账；结果页及无效数量不能继续增加本局收益。
func credit(kind: Kind, amount: int) -> bool:
	if not _run_open or amount <= 0:
		return false
	match kind:
		Kind.MONEY:
			money += amount
		Kind.RESEARCH:
			run_research += amount
		_:
			return false
	_publish()
	return true


## 预留局内购买扣款入口；TODO：后续商店接入装备、道具与增益发放事务。
func try_spend_money(cost: int) -> bool:
	if not _run_open or cost <= 0 or money < cost:
		return false
	money -= cost
	_publish()
	return true


## 预留闯关外研究扣款入口，先确认保存成功再提交余额；战斗内不能花费已存研究。
## TODO：强化菜单调用成功后应用角色强化或装备升级，失败时不发放升级。
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
## TODO：闯关外角色强化与装备升级需要先保存扣款，再应用对应升级效果。
func _save_balance(balance: int) -> Error:
	if not _account_loaded:
		return ERR_FILE_CORRUPT
	var account := ConfigFile.new()
	account.set_value("account", "version", 2)
	account.set_value("account", "research", balance)
	account.set_value("progress", "airborne_completed", _airborne_completed or _pending_airborne_completion)
	var error := account.save(TEMP_PATH)
	if error != OK:
		return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))


## 所有入账、扣款、开局和结算都从这里发布同一份钱包快照。
func _publish() -> void:
	sig_currency_changed.emit(get_snapshot())

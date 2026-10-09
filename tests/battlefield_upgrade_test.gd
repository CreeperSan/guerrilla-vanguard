## 升级契约测试：使用临时文件验证保存成功/失败，不扣除或改写用户真实研究账户。
## 验证顺序购买、存档字段、收益累计、武器属性、实际五发散射及菜单分组。
extends Node

## 保存替身仍调用真实序列化逻辑，使用独立临时目录验证正式文件与重载。
class TestWallet extends RunCurrencyWallet:
	var fail_save := false
	var committed_balance := 0
	var committed_levels: Dictionary = {}

	## 禁止读取真实账户，测试余额由断言流程设置。
	func _ready() -> void:
		pass

	## 真实事务在这里替换磁盘路径；写临时文件、替换和重载均使用 Godot 文件 API。
	func _store_account(account: ConfigFile) -> Error:
		if fail_save:
			return ERR_CANT_CREATE
		var path := "/tmp/guerrilla_upgrade_%d.cfg" % get_instance_id()
		var error := account.save(path + ".tmp")
		if error != OK:
			return error
		error = DirAccess.rename_absolute(path + ".tmp", path)
		if error != OK:
			return error
		var restored := ConfigFile.new()
		error = restored.load(path)
		DirAccess.remove_absolute(path)
		if error != OK:
			return error
		committed_balance = restored.get_value("account", "research")
		committed_levels = restored.get_value("upgrades", "levels").duplicate()
		return OK

var _checks := 0
var _failures := 0


## 自动加载准备完毕后测试，最后以失败数决定命令行退出码。
func _ready() -> void:
	_run.call_deferred()


## 项目之间等级独立；每次购买只走下一级，满级、余额不足和失败均不能变更。
func _run() -> void:
	var wallet := TestWallet.new()
	get_tree().root.add_child(wallet)
	wallet.banked_research = 10000
	var entries: Dictionary = BattlefieldUpgradeConfig.get_config().get("upgrades", {})
	_check(entries.size() == 31 and not entries.has("pistol.reserve"), "手枪四项、五把主武器各五项、收益两项")
	for id: String in entries:
		for level: int in range(1, 4):
			var before := wallet.banked_research
			var cost := wallet.get_upgrade_cost(id)
			_check(wallet.try_purchase_upgrade(id), "逐级购买 " + id)
			_check(wallet.get_upgrade_level(id) == level, "不能跳级 " + id)
			_check(wallet.banked_research == before - cost and wallet.committed_balance == wallet.banked_research, "扣款和持久余额一致")
			_check(wallet.committed_levels[id] == level, "等级和余额同次保存")
		_check(not wallet.try_purchase_upgrade(id), "满级不能再购买")
	_check(not wallet.try_purchase_upgrade("unknown"), "未知项目不能扣款")
	_check(wallet._load_upgrade_levels({}), "旧账户缺少升级数据时默认零级")
	wallet.banked_research = 0
	_check(not wallet.try_purchase_upgrade("pistol.range") and wallet.get_upgrade_level("pistol.range") == 0, "余额不足不升级")
	wallet.banked_research = 100
	wallet.fail_save = true
	_check(not wallet.try_purchase_upgrade("pistol.range"), "保存失败拒绝购买，预期错误日志")
	_check(wallet.banked_research == 100 and wallet.get_upgrade_level("pistol.range") == 0, "保存失败余额等级均不变")
	wallet.fail_save = false
	_check(not wallet._load_upgrade_levels({"pistol.range": 4}), "非法存档等级拒绝加载")
	_check(wallet._load_upgrade_levels({"battlefield.money": 3, "battlefield.research": 3}), "合法存档可重载")
	wallet.begin_run()
	_check(not wallet.try_purchase_upgrade("pistol.range"), "战斗中不可购买")
	for index: int in range(20):
		wallet.credit(RunCurrencyWallet.Kind.MONEY, 1)
		wallet.credit(RunCurrencyWallet.Kind.RESEARCH, 1)
	_check(wallet.money == 30 and wallet.run_research == 30, "两类小额收益均累计为 1.5 倍")
	_check(wallet.settle_run(), "升级后收益正常结算")
	_check(wallet.banked_research == 130, "结算不再次乘倍率")
	_check(wallet.settle_run() and wallet.banked_research == 130, "重复结算不重复入账")
	wallet.begin_run()
	_check(wallet.money == 0 and wallet.run_research == 0, "新局不带入旧收益")
	wallet.close_run()

	# 仅临时更改真实单例的内存等级验证武器消费者，结束前恢复，不触发保存。
	var global_wallet: RunCurrencyWallet = get_tree().root.get_node("CurrencyManager")
	var original_levels := global_wallet._upgrade_levels.duplicate()
	global_wallet._upgrade_levels.clear()
	var pistol := PlayerWeaponPistol.new()
	for id: String in entries:
		global_wallet._upgrade_levels[id] = 3
	pistol.apply_battlefield_upgrades("pistol")
	_check(pistol.ammo_back_infinite, "手枪保留无限备弹")
	_check(is_equal_approx(pistol.bullet_basic_range, 598.0) and pistol.ammo_magazine_max == 17, "手枪射程弹匣生效")
	_check(is_equal_approx(pistol.fire_gap, 0.24 / 1.24) and is_equal_approx(pistol.reload_duration, 0.75 / 1.24), "射速换弹速度生效")
	pistol.apply_battlefield_upgrades("pistol")
	_check(is_equal_approx(pistol.bullet_basic_range, 598.0), "重复初始化不叠加升级倍率")
	var smg := PlayerWeaponSMG.new()
	smg.apply_battlefield_upgrades("smg")
	_check(smg.ammo_back_max == 192 and smg.ammo_magazine_max == 44, "SMG 容量升级生效")
	var shotgun := PlayerWeaponShortgun.new()
	shotgun.apply_battlefield_upgrades("shotgun")
	_check(shotgun.ammo_magazine_max == 12 and shotgun.ammo_back_max == 64, "霰弹枪容量升级生效")
	var host := Node2D.new()
	var player := Player.new()
	host.add_child(player)
	player.facing_direction = Vector2.RIGHT
	var ammo_before := shotgun.ammo_magazine_cur
	_check(shotgun.try_fire(player), "霰弹枪真实发射流程成功")
	var pellets: Array[ProjectileBullet] = []
	for child: Node in host.get_children():
		if child is ProjectileBullet:
			pellets.append(child)
	_check(pellets.size() == 5 and shotgun.ammo_magazine_cur == ammo_before - 1, "一次发射五枚弹丸仅耗一发弹药")
	for index: int in range(pellets.size()):
		_check(is_equal_approx(rad_to_deg(pellets[index].bullet_direction.angle()), -12.0 + index * 6.0), "五枚子弹对称向前散射")
	_check(not shotgun.try_fire(player), "射击冷却阻止重复发射")
	host.free()
	pistol.free()
	smg.free()
	shotgun.free()
	global_wallet._upgrade_levels = original_levels

	var menu := load("res://Scene/MainMenu/MainMenu.tscn").instantiate() as Control
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	var tabs: TabContainer = menu.get_node("UpgradePage/UpgradeTabs")
	_check(tabs.get_tab_count() == 7, "升级菜单七组可加载")
	for index: int in range(7):
		tabs.current_tab = index
		var list := tabs.get_child(index).get_node("Items")
		_check(list.get_child_count() == [4, 5, 5, 5, 5, 5, 2][index], "各组展示正确项目数量")
	menu.queue_free()
	wallet.queue_free()
	await get_tree().process_frame
	print("[battlefield_upgrade_test] checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


## 收集全部失败便于一次定位多个边界问题。
func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[battlefield_upgrade_test] " + description)

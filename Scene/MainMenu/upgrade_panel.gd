## 升级页控制器：场景提供分组与行模板，配置提供项目、价格和能力倍率。
## 只允许购买下一等级；钱包负责保存事务，界面只在结果确认后显示成功。
extends TabContainer

const ROW_SCENE: PackedScene = preload("res://Scene/MainMenu/UpgradeRow.tscn")
var _rows: Dictionary = {}


## 根据配置建立各组的独立升级项；按钮支持主题、焦点与滚动容器导航。
func _ready() -> void:
	for id: String in BattlefieldUpgradeConfig.get_config().get("upgrades", {}):
		var entry := BattlefieldUpgradeConfig.get_entry(id)
		var list := get_node_or_null(str(entry.get("group", "")) + "/Items")
		if list == null:
			push_error("升级分组不存在：" + id)
			continue
		var row := ROW_SCENE.instantiate()
		list.add_child(row)
		row.get_node("Contents/Title").text = str(entry["name"])
		row.get_node("Contents/Purchase").pressed.connect(_purchase.bind(id))
		_rows[id] = row
	set_tab_title(0, "手枪")
	set_tab_title(1, "SMG")
	set_tab_title(2, "霰弹枪")
	set_tab_title(3, "狙击步枪")
	set_tab_title(4, "RPG")
	set_tab_title(5, "喷火枪")
	set_tab_title(6, "战场收益")
	CurrencyManager.sig_currency_changed.connect(_refresh)
	_refresh(CurrencyManager.get_snapshot())


## 余额和等级共用钱包通知，购买或删除存档后立即刷新所有分组。
func _refresh(_snapshot: Dictionary) -> void:
	for id: String in _rows:
		var row: Node = _rows[id]
		var level := CurrencyManager.get_upgrade_level(id)
		var current := CurrencyManager.get_upgrade_multiplier(id)
		var button: Button = row.get_node("Contents/Purchase")
		var effect: Label = row.get_node("Contents/Effect")
		row.get_node("Contents/Title").text = "%s   %d / 3 级" % [BattlefieldUpgradeConfig.get_entry(id)["name"], level]
		if level >= BattlefieldUpgradeConfig.MAX_LEVEL:
			effect.text = "当前能力 ×%.2f · 已满级" % current
			button.text = "已满级"
		else:
			var next := BattlefieldUpgradeConfig.get_multiplier(id, level + 1)
			effect.text = "能力 ×%.2f → ×%.2f" % [current, next]
			button.text = "升至 %d 级 · ◆ %d" % [level + 1, CurrencyManager.get_upgrade_cost(id)]
		button.disabled = not CurrencyManager.can_purchase_upgrade(id)
		button.tooltip_text = "相对基础值的倍率；弹夹和备弹容量四舍五入。" if not button.disabled else ("已达最高等级" if level == 3 else "研究点数不足或账户暂不可购买")


## 成功购买后钱包已经持久化；失败只反馈状态，不提前改变等级或余额。
func _purchase(id: String) -> void:
	var status: Label = get_parent().get_node("UpgradeStatus")
	if CurrencyManager.try_purchase_upgrade(id):
		status.text = "%s已升至 %d 级，下次进入战斗生效。" % [BattlefieldUpgradeConfig.get_entry(id)["name"], CurrencyManager.get_upgrade_level(id)]
	else:
		status.text = "升级未成功，余额和等级未改变；请检查余额或输出日志。"
	_refresh(CurrencyManager.get_snapshot())

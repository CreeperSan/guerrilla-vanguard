## 世界中的限购商品；独立于免费 LootItem，所有商品进入范围后使用确认键购买。
## 先锁住本次交易，再通过钱包扣款并发放；满血/满弹也按用户要求扣钱消耗。
class_name ShopOffer
extends Area2D

signal sig_purchase_result(success: bool, message: String)

var product: ShopProduct
var sold: bool = false
## 钱包信号和触碰回调可能同步重入；在扣款前上锁避免同件商品被重复购买。
var _purchasing: bool = false
## 仅物理触碰范围内的玩家可以确认商品购买，离开时清空引用。
var _nearby_player: Player
var _touch_mode: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

@onready var purchase_prompt: Control = $PurchaseUI/Prompt
@onready var purchase_button: Button = $PurchaseUI/Prompt/BuyButton
@onready var confirm_hint: Label = $PurchaseUI/Prompt/ConfirmHint


## 设置商品外观并连接物理触碰；价格文字的尺寸和位置由独立场景配置。
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	purchase_button.pressed.connect(confirm_purchase)
	if product != null:
		refresh_appearance()


## 父房间分配库存后更新图标和文字；支持单独测试时在入树前指定商品。
func refresh_appearance() -> void:
	if product == null or not product.is_valid():
		push_error("商店商品配置无效。")
		return
	$Sprite2D.texture = product.icon
	var factor := 32.0 / maxf(product.icon.get_width(), product.icon.get_height())
	$Sprite2D.scale = Vector2.ONE * factor
	$NameLabel.text = product.display_name
	$PriceLabel.text = "%d 金" % product.price
	$DetailLabel.text = product.description


## 只接受存活玩家，余额不足保留商品；离开后重新触碰可再次尝试。
func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	_nearby_player = player
	_update_purchase_prompt()


## 所有有效商品统一使用确认购买，避免进入展示位时自动扣钱。
func requires_confirmation() -> bool:
	return product != null and product.is_valid()


## 离开商品碰撞区域后立刻隐藏专用购买按钮，防止远程购买。
func _on_body_exited(body: Node2D) -> void:
	if body == _nearby_player:
		_nearby_player = null
		_update_purchase_prompt()


## 定期同步存活、房间淡出和输入设备状态，隐藏房间不能保留屏幕购买提示。
func _process(_delta: float) -> void:
	_update_purchase_prompt()


## 三种确认输入共用同一事务；键盘长按回声、按键释放不触发购买。
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_mode = true
	elif event is InputEventKey and event.pressed:
		_touch_mode = false
	elif event is InputEventJoypadButton and event.pressed:
		_touch_mode = false
	_update_purchase_prompt()
	if not purchase_prompt.visible or get_tree().paused:
		return
	var confirmed := false
	if event is InputEventKey:
		confirmed = event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]
	elif event is InputEventJoypadButton:
		confirmed = event.pressed and event.button_index == JOY_BUTTON_A
		if confirmed:
			# A 同时是技能键；本次确认优先交给商店，直至释放前不再启动技能。
			_nearby_player.consume_shop_confirmation()
	elif event is InputEventScreenTouch:
		confirmed = event.pressed and purchase_button.visible and purchase_button.get_global_rect().has_point(event.position)
	if confirmed:
		confirm_purchase()
		get_viewport().set_input_as_handled()


## 触屏独立按钮与确认键共用的入口，始终检查玩家仍在范围内且商品未售出。
func confirm_purchase() -> void:
	if _can_confirm_purchase():
		try_purchase(_nearby_player)


## CanvasLayer 不继承房间透明度，因此额外检查父房间的世界可见透明度。
func _can_confirm_purchase() -> bool:
	return requires_confirmation() and not sold and not get_tree().paused and is_instance_valid(_nearby_player) and _nearby_player.health_current > 0 and not _nearby_player.dodge_active and get_overlapping_bodies().has(_nearby_player) and _is_room_visible()


## 房间通过父 CanvasItem 的 modulate 淡出；屏幕 UI 单独检查所有父节点的可见性。
func _is_room_visible() -> bool:
	var ancestor: Node = self
	while ancestor != null:
		if ancestor is CanvasItem and (not ancestor.is_visible_in_tree() or ancestor.modulate.a <= 0.01):
			return false
		ancestor = ancestor.get_parent()
	return true


## 布局由场景定义，触控显示独立按钮，键鼠/手柄显示确认提示，范围外两者都隐藏。
func _update_purchase_prompt() -> void:
	if not is_node_ready():
		return
	purchase_prompt.visible = _can_confirm_purchase()
	purchase_button.visible = _touch_mode
	confirm_hint.visible = not _touch_mode
	if purchase_prompt.visible:
		purchase_button.text = "购买 %s · %d 金" % [product.display_name, product.price]
		confirm_hint.text = "回车 / A 购买 %s · %d 金" % [product.display_name, product.price]


## 同步购买事务：扣款失败不发放、不销毁；成功只发放一次并立即停止显示和触碰。
## 发放结果不决定退款：满血、满备弹时效果可能为零，但用户明确要求仍然购买。
func try_purchase(player: Player) -> bool:
	if get_tree().paused or sold or _purchasing or product == null or not product.is_valid():
		return false
	if player == null or player.node_health == null or player.node_health.health <= 0 or player.dodge_active:
		return false
	if product.loot_type in [LootItem.Type.WeaponSMG, LootItem.Type.WeaponShortgun] and player.node_weapon_manager == null:
		return false
	_purchasing = true
	if not CurrencyManager.try_spend_money(product.price):
		_purchasing = false
		sig_purchase_result.emit(false, "金钱不足")
		return false
	# 复用既有武器、装备、治疗和研究收益规则；不把效果节点加入场景以免免费拾取。
	var effect := LootItem.new()
	effect.type = product.loot_type
	effect.num = product.amount
	effect.apply_to(player)
	effect.free()
	sold = true
	purchase_prompt.hide()
	hide()
	set_deferred("monitoring", false)
	sig_purchase_result.emit(true, "已购买 %s" % product.display_name)
	queue_free()
	return true

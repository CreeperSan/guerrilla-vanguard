## 雇佣兵房的独立交互点：玩家靠近后可付费招募一次，并显示余额不足反馈。
class_name MercenaryRecruitment
extends Node2D

@onready var _area: Area2D = $Area2D
@onready var _prompt: Label = $Prompt
@onready var _hire_button: Button = $CanvasLayer/HireButton
var _nearby_player: Player
var _contract_used: bool = false
var _feedback_message: String = ""
var _touch_mode: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


## 连接近距离触发和触屏/鼠标按钮；键盘与手柄确认仍走相同招募入口。
func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_hire_button.pressed.connect(_try_hire)
	_prompt.text = "靠近签约 · %d 金\n按 Enter / A" % HiredMercenary.HIRE_COST
	_update_prompt()


## 只允许玩家触发签约区域，佣兵或敌人经过不会扣款。
func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	_nearby_player = player
	_feedback_message = ""
	_update_prompt()


## 玩家离开范围后撤销购买权限并隐藏 UI。
func _on_body_exited(body: Node2D) -> void:
	if body == _nearby_player:
		_nearby_player = null
		_feedback_message = ""
		_update_prompt()


## 范围内且房间可见时允许确认；成功后本签约点永久关闭。
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_mode = true
	elif event is InputEventKey and event.pressed:
		_touch_mode = false
	elif event is InputEventJoypadButton and event.pressed:
		_touch_mode = false
	if not _can_hire() or get_tree().paused:
		_update_prompt()
		return
	var confirmed := false
	if event is InputEventKey:
		confirmed = event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]
	elif event is InputEventJoypadButton:
		confirmed = event.pressed and event.button_index == JOY_BUTTON_A
	if confirmed:
		_try_hire()
		get_viewport().set_input_as_handled()


## 房间淡出时隐藏 CanvasLayer 按钮，避免 UI 留在屏幕上继续招募。
func _process(_delta: float) -> void:
	_update_prompt()


## 通过关卡控制器扣款并雇佣；失败时保留签约点，余额充足才允许再次使用。
func _try_hire() -> void:
	if not _can_hire():
		return
	var room := get_parent() as FortressRoomTemplate
	var level_controller: Node
	if room != null:
		level_controller = room.get_parent()
	var candidate: HiredMercenary
	if room != null:
		candidate = room.get_node_or_null("HireableMercenary") as HiredMercenary
	if level_controller == null or not level_controller.has_method("hire_mercenary"):
		_prompt.text = "无法联系佣兵队"
		return
	if bool(level_controller.call("hire_mercenary", candidate)):
		_contract_used = true
		_feedback_message = "合同生效 · 佣兵已加入"
		_update_prompt()
	else:
		_feedback_message = "金钱不足 · 需要 %d 金" % HiredMercenary.HIRE_COST
		_update_prompt()


## 只在玩家仍存活、位于触发范围且合约未使用时开放招募。
func _can_hire() -> bool:
	return not _contract_used and is_instance_valid(_nearby_player) and _nearby_player.health_current > 0 and _area.get_overlapping_bodies().has(_nearby_player) and _is_room_visible()


## 检查父房间透明度；CanvasLayer 本身不继承 CanvasItem 的房间淡出效果。
func _is_room_visible() -> bool:
	var ancestor: Node = self
	while ancestor != null:
		if ancestor is CanvasItem and (not ancestor.is_visible_in_tree() or ancestor.modulate.a <= 0.01):
			return false
		ancestor = ancestor.get_parent()
	return true


## 同步场景标签和按钮；合同使用后只显示签约结果。
func _update_prompt() -> void:
	if not is_node_ready():
		return
	var visible := _can_hire()
	_hire_button.visible = visible and _touch_mode
	_prompt.visible = is_instance_valid(_nearby_player) and _is_room_visible() and (not _contract_used or not _feedback_message.is_empty())
	if not _feedback_message.is_empty():
		_prompt.text = _feedback_message
	else:
		_prompt.text = "靠近签约 · %d 金\n%s" % [HiredMercenary.HIRE_COST, "点击按钮" if _touch_mode else "按 Enter / A"]

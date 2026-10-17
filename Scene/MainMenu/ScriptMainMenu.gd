## 正式首页：模式选择、永久战场升级、独立音频设置、关于与二次确认删除存档。
## 首页不创建战斗宿主或开启局内钱包，研究账户和模式解锁只读取全局持久数据。
extends Control

@export var cover_texture: Texture2D
@export var upgrade_texture: Texture2D

@onready var btnStart: Button = %AirborneButton
@onready var btnSetting: Button = %SettingsButton
@onready var btnExit: Button = %ExitButton
@onready var _assault_button: Button = %AssaultButton
@onready var _background: TextureRect = %Background
@onready var _main_page: Control = %MainPage
@onready var _upgrade_page: Control = %UpgradePage
@onready var _settings_page: Control = %SettingsPage
@onready var _about_page: Control = %AboutPage
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _delete_confirmation: ConfirmationDialog = %DeleteConfirmation

var _page_tween: Tween
var _current_page: Control
var _launching: bool = false
## 设置列表记录一根拖动手指，纵向拖动超过阈值后才取消按钮点击。
var _settings_touch_index := -1
var _settings_touch_origin := Vector2.ZERO
var _settings_touch_start := 0.0
var _settings_dragging := false
@onready var _settings_scroll: ScrollContainer = %SettingsScroll


## 初始化菜单和全局订阅；按钮、滑块与确认框支持键鼠、手柄和触控。
func _ready() -> void:
	get_tree().paused = false
	GameSettings.play_menu_music()
	_build_control_settings()
	_settings_page.resized.connect(_resize_settings_card)
	_resize_settings_card()
	%ReplayStory.pressed.connect(_replay_story)
	btnStart.pressed.connect(_start_game.bind(RogueRunManager.AttackMode.AIRBORNE))
	_assault_button.pressed.connect(_start_game.bind(RogueRunManager.AttackMode.COUNTERATTACK))
	%UpgradeButton.pressed.connect(_show_page.bind(_upgrade_page))
	# 点击设置
	btnSetting.pressed.connect(_show_page.bind(_settings_page))
	%CreditsButton.pressed.connect(_open_credits)
	%AboutButton.pressed.connect(_show_page.bind(_about_page))
	btnExit.pressed.connect(_quit_game)
	for button: Button in [%UpgradeBack, %SettingsBack, %AboutBack]:
		button.pressed.connect(_show_page.bind(_main_page))
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	%MusicMute.pressed.connect(GameSettings.toggle_music_mute)
	%SfxMute.pressed.connect(GameSettings.toggle_sfx_mute)
	%DeleteSaveButton.pressed.connect(_ask_delete_save)
	_delete_confirmation.confirmed.connect(_delete_save)
	_delete_confirmation.get_ok_button().text = "确认删除"
	_delete_confirmation.get_cancel_button().text = "取消"
	CurrencyManager.sig_currency_changed.connect(_on_account_changed)
	GameSettings.sig_audio_changed.connect(_sync_audio_controls)
	GameManager.sig_navigation_failed.connect(_on_navigation_failed)
	_on_account_changed(CurrencyManager.get_snapshot())
	_sync_audio_controls()
	_show_page(_main_page)


## 点击开始游戏：首页与管理器双重检查解锁，成功后禁止重复点击。
func _start_game(mode: int) -> void:
	if _launching:
		return
	if not GameManager.start_from_menu(mode):
		%MenuStatus.text = "暂时无法开始，请先通关空降或查看输出日志。"
		return
	_launching = true
	btnStart.disabled = true
	_assault_button.disabled = true
	# 加载期间禁止再导航到删除存档页面，避免取消排队加载后按钮停留在禁用状态。
	for button: Button in [btnSetting, %UpgradeButton, %AboutButton, %CreditsButton]:
		button.disabled = true
	%MenuStatus.text = "正在进入战场……"


## 导航资源失效时恢复可操作首页，避免加载失败后所有模式按钮一直禁用。
func _on_navigation_failed(message: String) -> void:
	_launching = false
	btnStart.disabled = false
	for button: Button in [btnSetting, %UpgradeButton, %AboutButton, %CreditsButton]:
		button.disabled = false
	_on_account_changed(CurrencyManager.get_snapshot())
	%MenuStatus.text = message


## 切换独立页面，隐藏页面不拦截点击；短正弦缓动只作用于进入页面。
func _show_page(page: Control) -> void:
	if _page_tween != null and _page_tween.is_running():
		_page_tween.kill()
	for candidate: Control in [_main_page, _upgrade_page, _settings_page, _about_page]:
		candidate.visible = candidate == page
	_current_page = page
	_background.texture = upgrade_texture if page == _upgrade_page else cover_texture
	page.modulate.a = 0.0
	_page_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(page, "modulate:a", 1.0, 0.2)
	if page == _main_page:
		btnStart.grab_focus()
	elif page == _upgrade_page:
		%UpgradeBack.grab_focus()
	elif page == _settings_page:
		%ReplayStory.grab_focus()
	else:
		%AboutBack.grab_focus()


## 子页面按返回键回首页，原生确认弹窗自行处理取消按键。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _current_page != _main_page:
		_show_page(_main_page)
		get_viewport().set_input_as_handled()


## 已存研究立即刷新首页与升级页，模式解锁始终读取持久账户。
func _on_account_changed(snapshot: Dictionary) -> void:
	var research := int(snapshot["research_bank"])
	%ResearchBadge.text = "◆  研究点数  %s" % str(research)
	%UpgradeResearch.text = "研究点数  ◆ %s" % str(research)
	_assault_button.disabled = _launching or not bool(snapshot["assault_unlocked"])
	%AssaultLock.text = "反击已解锁 · 6 个随机战场 + 地下要塞" if bool(snapshot["assault_unlocked"]) else "反击锁定 · 通关一次空降后开放"
	var profile := BattleBalance.config.get_profile(RogueRunManager.AttackMode.COUNTERATTACK)
	var difficulty := "敌军生命 %.0f%% · 伤害 %.0f%%（相对基础难度）" % [profile.enemy_health_multiplier * 100.0, profile.enemy_damage_multiplier * 100.0]
	_assault_button.tooltip_text = difficulty if bool(snapshot["assault_unlocked"]) else "需要完整通关一次空降模式\n" + difficulty


## 同步滑块时不再次触发保存，快捷静音保留原有音量数值。
func _sync_audio_controls() -> void:
	_music_slider.set_value_no_signal(GameSettings.music_volume * 100.0)
	_sfx_slider.set_value_no_signal(GameSettings.sfx_volume * 100.0)
	%MusicValue.text = "%d%%" % roundi(GameSettings.music_volume * 100.0)
	%SfxValue.text = "%d%%" % roundi(GameSettings.sfx_volume * 100.0)
	%MusicMute.text = "取消静音" if GameSettings.music_muted else "静音"
	%SfxMute.text = "取消静音" if GameSettings.sfx_muted else "静音"


## 音乐滑块只修改 Music 分支。
func _on_music_volume_changed(value: float) -> void:
	GameSettings.set_music_volume(value / 100.0)


## 音效滑块只修改 SFX 分支，与战斗暂停菜单共用同一设置。
func _on_sfx_volume_changed(value: float) -> void:
	GameSettings.set_sfx_volume(value / 100.0)


## 首次点击只打开说明弹窗，默认聚焦取消，不自动执行删除。
func _ask_delete_save() -> void:
	_delete_confirmation.popup_centered(Vector2i(500, 210))
	_delete_confirmation.get_cancel_button().grab_focus()


## 明确二次确认后删除；失败时不显示虚假的成功状态。
func _delete_save() -> void:
	var error := CurrencyManager.delete_game_save()
	if error != OK:
		%SettingsStatus.text = "删除失败，错误码 %s；请检查存档目录权限。" % error
		return
	GameManager.reset_run()
	%SettingsStatus.text = "存档已删除，研究点数与升级归零，反击恢复锁定。"


## 点击退出游戏：先保存最后一次音量修改，再正常结束进程。
func _quit_game() -> void:
	GameSettings.save_now()
	get_tree().quit()


## 首页制作名单复用现有滚动场景；转场锁阻止重复点击，不创建对局或结算记录。
func _open_credits() -> void:
	if _launching or SceneTransition.busy:
		return
	GameManager.open_presentation("res://Scene/Credits/Credits.tscn", "制作与致谢")


## 操控分组由全局偏好初始化；编辑场景使用草稿，返回后保留列表滚动位置。
func _build_control_settings() -> void:
	var parent: VBoxContainer = %操控
	FlowUI.label(parent, "十字移动方式", 18)
	# 两个等宽按钮直接展示模式；互斥分组始终保留一个选中项，触摸无需打开下拉框。
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 12)
	parent.add_child(modes)
	var group := ButtonGroup.new()
	for floating: bool in [false, true]:
		var button := FlowUI.button(modes, "活动" if floating else "固定", _set_movement_mode.bind(floating))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = GameSettings.floating_movement == floating
		button.tooltip_text = "出现在左半屏首次触点" if floating else "保持固定位置"
	var caption := FlowUI.label(parent, "移动区大小：%d%%" % roundi(GameSettings.movement_scale * 100), 18)
	var area := HSlider.new()
	area.custom_minimum_size.y = 36
	area.min_value = 50
	area.max_value = 150
	area.step = 5
	area.value = GameSettings.movement_scale * 100
	parent.add_child(area)
	area.value_changed.connect(func(value: float):
		caption.text = "移动区大小：%d%%" % roundi(value)
		GameSettings.set_movement_options(GameSettings.floating_movement, value / 100.0)
	)
	FlowUI.button(parent, "触摸按键布局设置", _open_touch_layout)
	FlowUI.button(parent, "重置触摸按键布局", GameSettings.reset_touch_layout)


## 点击模式按钮立即保存选择，移动区大小保留原值；选中外观由互斥按钮组管理。
func _set_movement_mode(floating: bool) -> void:
	GameSettings.set_movement_options(floating, GameSettings.movement_scale)


## 在首页上方挂载独立场景，保留设置页和滚动位置；关闭编辑器不启动或重置对局。
func _open_touch_layout() -> void:
	var editor := preload("res://Scene/TouchLayout/TouchLayoutEditor.tscn").instantiate()
	add_child(editor)


## 手动重温不清空已展示标记；故事原有出口返回首页。
func _replay_story() -> void:
	if not SceneTransition.busy:
		GameManager.open_presentation("res://Scene/StoryIntro/StoryIntro.tscn", "重温行动序章")


## 固定设置卡片的可视高度，长列表只在正文内滚动，返回首页按钮始终可见。
func _resize_settings_card() -> void:
	var card: Control = $SettingsPage/Center/Card
	card.custom_minimum_size = Vector2(minf(680.0, maxf(260.0, _settings_page.size.x - 56.0)), maxf(220.0, _settings_page.size.y - 56.0))


## 设置列表的触摸拖动优先于子标签；横向滑块保留原生操作。
func _input(event: InputEvent) -> void:
	if _current_page != _settings_page or has_node("TouchLayoutEditor") or _delete_confirmation.visible or SceneTransition.busy:
		_settings_touch_index = -1
		return
	if event is InputEventScreenTouch:
		if event.pressed and _settings_touch_index == -1:
			if not _settings_scroll.get_global_rect().has_point(event.position):
				return
			var bar := _settings_scroll.get_v_scroll_bar()
			if bar.is_visible_in_tree() and bar.get_global_rect().has_point(event.position):
				return
			# 在滑块上落指时不接管，避免调节音量和移动区大小被纵向滚动抢走。
			for control: Node in _settings_scroll.find_children("*", "Control", true, false):
				if control is Range and (control as Control).is_visible_in_tree() and (control as Control).get_global_rect().has_point(event.position):
					return
			_settings_touch_index = event.index
			_settings_touch_origin = event.position
			_settings_touch_start = _settings_scroll.scroll_vertical
			_settings_dragging = false
		elif not event.pressed and event.index == _settings_touch_index:
			_settings_touch_index = -1
			if _settings_dragging:
				_settings_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_END)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _settings_touch_index:
		var distance: float = _settings_touch_origin.y - event.position.y
		if _settings_dragging or absf(distance) > 12.0:
			if not _settings_dragging:
				# BaseButton 收到滚动开始通知后取消按下状态，滑过删除/重置按钮不会误执行。
				_settings_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
			_settings_dragging = true
			var bar := _settings_scroll.get_v_scroll_bar()
			_settings_scroll.scroll_vertical = roundi(clampf(_settings_touch_start + distance, 0.0, maxf(0.0, bar.max_value - bar.page)))
			get_viewport().set_input_as_handled()


## 切换到后台时释放未收到松手的设置手势，返回后可以重新从任意位置滑动。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_settings_touch_index = -1

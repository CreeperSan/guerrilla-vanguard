## 正式首页：模式选择、战场升级占位、独立音频设置、关于与二次确认删除存档。
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


## 初始化菜单和全局订阅；按钮、滑块与确认框支持键鼠、手柄和触控。
func _ready() -> void:
	get_tree().paused = false
	GameSettings.play_menu_music()
	btnStart.pressed.connect(_start_game.bind(RogueRunManager.AttackMode.AIRBORNE))
	_assault_button.pressed.connect(_start_game.bind(RogueRunManager.AttackMode.FULL_ASSAULT))
	%UpgradeButton.pressed.connect(_show_page.bind(_upgrade_page))
	# 点击设置
	btnSetting.pressed.connect(_show_page.bind(_settings_page))
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
	for button: Button in [btnSetting, %UpgradeButton, %AboutButton]:
		button.disabled = true
	%MenuStatus.text = "正在进入战场……"


## 导航资源失效时恢复可操作首页，避免加载失败后所有模式按钮一直禁用。
func _on_navigation_failed(message: String) -> void:
	_launching = false
	btnStart.disabled = false
	for button: Button in [btnSetting, %UpgradeButton, %AboutButton]:
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
		_music_slider.grab_focus()
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
	%AssaultLock.text = "强攻已解锁 · 6 个随机战场 + 地下要塞" if bool(snapshot["assault_unlocked"]) else "强攻锁定 · 通关一次空降后开放"
	_assault_button.tooltip_text = "" if bool(snapshot["assault_unlocked"]) else "需要完整通关一次空降模式"


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
	%SettingsStatus.text = "存档已删除，研究点数归零，强攻恢复锁定。"


## 点击退出游戏：先保存最后一次音量修改，再正常结束进程。
func _quit_game() -> void:
	GameSettings.save_now()
	get_tree().quit()

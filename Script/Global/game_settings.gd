## AutoLoad 用户设置：音频、剧情已展示标记与触控布局跨场景持久保存。
## 设置与游戏进度分文件保存，删除研究账户不会改变音量、操控与剧情状态。
extends Node

signal sig_audio_changed
signal sig_controls_changed
const SETTINGS_PATH := "user://audio_settings.cfg"
## 可替换路径用于隔离自动验证，不触碰玩家真实偏好文件。
var settings_path: String = SETTINGS_PATH
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const MENU_MUSIC: AudioStream = preload("res://Assets/Audio/Music/menu_command.wav")
const FORTRESS_MUSIC: AudioStream = preload("res://Assets/Audio/Music/level_fortress.wav")
const MUSIC_FADE_DURATION := 0.8
const MUSIC_GAIN := 0.4

## 进入剧情场景即落盘；旧版跳过开关不迁移为已观看状态。
var story_intro_seen := false
## 操控偏好独立于研究存档；活动摇杆仅在手指首次落点建立中心。
var floating_movement := false
var movement_scale := 1.0
var touch_layout: Dictionary = TouchLayout.DEFAULTS.duplicate(true)
var music_volume: float = 0.65
var sfx_volume: float = 0.8
var music_muted: bool = false
var sfx_muted: bool = false
var _save_timer: Timer
var _music_player: AudioStreamPlayer
var _music_players: Array[AudioStreamPlayer] = []
var _loop_cache: Dictionary[String, AudioStream] = {}
var _current_music_key: String = ""
var _music_fade: Tween


## 在场景加载前建立总线、读取偏好并启动循环配乐；设置页暂停时仍可以试听调整。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_load_settings()
	_apply_audio()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.25
	_save_timer.timeout.connect(save_now)
	add_child(_save_timer)
	# 既有玩家与炮弹音效没有单独总线，由此统一归入 SFX，不改变各音效自己的响度。
	get_tree().node_added.connect(_route_audio_player)
	play_menu_music()


## 首页和升级、设置、关于页面共用首页曲；同一曲目不重新起播。
func play_menu_music() -> void:
	_play_music(MENU_MUSIC)


## Level 主题资源选择自己的配乐，旧要塞或未配置音乐时使用要塞曲。
func play_level_music(theme: BattlefieldTheme) -> void:
	var stream := theme.background_music if theme != null and theme.background_music != null else FORTRESS_MUSIC
	_play_music(stream)


## 双播放器交叉淡化，切关和返回首页平滑换曲；快速切换会接管当前实际音量。
func _play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	var key := stream.resource_path if not stream.resource_path.is_empty() else str(stream.get_instance_id())
	if key == _current_music_key and is_instance_valid(_music_player) and _music_player.playing:
		return
	var loop := _loop_stream(stream, key)
	if loop == null:
		return
	if _music_fade != null and _music_fade.is_running():
		_music_fade.kill()
	var next_player := AudioStreamPlayer.new()
	next_player.bus = MUSIC_BUS
	next_player.stream = loop
	next_player.volume_db = -80.0
	add_child(next_player)
	next_player.play()
	_music_player = next_player
	_current_music_key = key
	_music_players.append(next_player)
	_music_fade = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for player: AudioStreamPlayer in _music_players:
		var target := MUSIC_GAIN if player == next_player else 0.0
		_music_fade.tween_method(_set_music_gain.bind(player), db_to_linear(player.volume_db), target, MUSIC_FADE_DURATION)
	_music_fade.chain().tween_callback(_remove_faded_players.bind(next_player))


## 设置资源副本的完整乐句循环，不在 finished 回调中重新 play，避免停播间隙。
func _loop_stream(stream: AudioStream, key: String) -> AudioStream:
	if _loop_cache.has(key):
		return _loop_cache[key]
	var loop := stream.duplicate() as AudioStream
	if loop is AudioStreamWAV:
		var wav := loop as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	elif loop is AudioStreamOggVorbis:
		(loop as AudioStreamOggVorbis).loop = true
	elif loop is AudioStreamMP3:
		(loop as AudioStreamMP3).loop = true
	else:
		push_warning("配乐格式不支持循环，请使用 WAV、OGG 或 MP3：%s" % key)
		return null
	_loop_cache[key] = loop
	return loop


## 以线性响度进行淡化，再转换为分贝，避免直接插值分贝导致中间突然过小。
func _set_music_gain(gain: float, player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		player.volume_db = linear_to_db(maxf(gain, 0.0001))


## 淡化结束才释放旧播放器，持续切换时也不会残留多路旧曲同时播放。
func _remove_faded_players(current: AudioStreamPlayer) -> void:
	for player: AudioStreamPlayer in _music_players:
		if player != current and is_instance_valid(player):
			player.stop()
			player.queue_free()
	_music_players = [current]


## 原有场景继续使用 Master 默认值；只重新路由默认音效，不覆盖明确设置的其他总线。
func _route_audio_player(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if str(node.get("bus")) == "Master":
			node.set("bus", SFX_BUS)


## 没有预配置总线时自动建立；两个分支都输出到 Master。
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


## 滑块使用 0～1 的实际音量，静音按钮独立保留上次非零音量。
func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_changed()


## 音效入口同时供首页设置页和战斗暂停菜单使用。
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_changed()


## 快捷静音不把音量数值覆盖为零，再次按下即可恢复原有响度。
func toggle_music_mute() -> void:
	music_muted = not music_muted
	_changed()


## 音效快捷静音与音乐互不影响。
func toggle_sfx_mute() -> void:
	sfx_muted = not sfx_muted
	_changed()


## 即时生效、推送界面、延迟合并磁盘写入，避免拖动滑块时每帧写文件。
func _changed() -> void:
	_apply_audio()
	sig_audio_changed.emit()
	_save_timer.start()


## 所有设备共用总线设置，0 音量也静音，但保留显式静音按钮的独立状态。
func _apply_audio() -> void:
	var music_index := AudioServer.get_bus_index(MUSIC_BUS)
	var sfx_index := AudioServer.get_bus_index(SFX_BUS)
	AudioServer.set_bus_volume_db(music_index, linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(sfx_index, linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_mute(music_index, music_muted or music_volume <= 0.0)
	AudioServer.set_bus_mute(sfx_index, sfx_muted or sfx_volume <= 0.0)


## 防御旧配置中的非法类型，持久设置优先于代码默认值。
func _load_settings() -> void:
	var settings := ConfigFile.new()
	var error := settings.load(settings_path)
	if error != OK:
		if error != ERR_FILE_NOT_FOUND:
			push_warning("用户设置读取失败，暂用默认值，错误码 %s。" % error)
		return
	var music: Variant = settings.get_value("audio", "music_volume", music_volume)
	var sfx: Variant = settings.get_value("audio", "sfx_volume", sfx_volume)
	if music is float or music is int:
		music_volume = clampf(float(music), 0.0, 1.0)
	if sfx is float or sfx is int:
		sfx_volume = clampf(float(sfx), 0.0, 1.0)
	story_intro_seen = settings.get_value("presentation", "story_intro_seen", false) == true
	floating_movement = settings.get_value("controls", "floating_movement", false) == true
	var area: Variant = settings.get_value("controls", "movement_scale", 1.0)
	if (area is float or area is int) and is_finite(float(area)):
		movement_scale = clampf(float(area), 0.5, 1.5)
	var raw_layout: Variant = settings.get_value("controls", "layout", {})
	var layout_version: Variant = settings.get_value("controls", "layout_version", 1)
	if not layout_version is int or layout_version < TouchLayout.LAYOUT_VERSION:
		raw_layout = TouchLayout.migrate_legacy_layout(raw_layout)
	touch_layout = TouchLayout.sanitize(raw_layout)
	music_muted = settings.get_value("audio", "music_muted", false) == true
	sfx_muted = settings.get_value("audio", "sfx_muted", false) == true


## 退出按钮在结束进程前主动调用，避免最后一次拖动还没经过合并计时就丢失设置。
func save_now() -> void:
	var settings := ConfigFile.new()
	settings.set_value("presentation", "story_intro_seen", story_intro_seen)
	settings.set_value("controls", "floating_movement", floating_movement)
	settings.set_value("controls", "movement_scale", movement_scale)
	settings.set_value("controls", "layout", touch_layout)
	settings.set_value("controls", "layout_version", TouchLayout.LAYOUT_VERSION)
	settings.set_value("audio", "music_volume", music_volume)
	settings.set_value("audio", "sfx_volume", sfx_volume)
	settings.set_value("audio", "music_muted", music_muted)
	settings.set_value("audio", "sfx_muted", sfx_muted)
	var error := settings.save(settings_path)
	if error != OK:
		push_warning("用户设置保存失败，错误码 %s。" % error)


## 正常关闭窗口也落盘，保留尚未经过定时器保存的最后一次调整。
func _exit_tree() -> void:
	save_now()


## 场景进入时立即保存，即使用户中途关闭程序，下次也不重复自动播放。
func mark_story_intro_seen() -> void:
	story_intro_seen = true
	save_now()


## 操控选项即时更新，滑块拖动合并磁盘写入。
func set_movement_options(floating: bool, area_scale: float) -> void:
	floating_movement = floating
	movement_scale = clampf(area_scale, 0.5, 1.5)
	sig_controls_changed.emit()
	_save_timer.start()


## 编辑器确认保存才提交草稿；运行 HUD 订阅同一信号立即刷新布局。
func set_touch_layout(layout: Dictionary) -> void:
	touch_layout = TouchLayout.sanitize(layout)
	sig_controls_changed.emit()
	save_now()


## 重置仅恢复按钮位置及各按钮大小，保留移动方式和移动区整体倍率。
func reset_touch_layout() -> void:
	set_touch_layout(TouchLayout.DEFAULTS)

## 独立坦克试战场：F6 运行即可体验三阶段，提供三把武器与实时 Boss 血条。
## 仅用于机制/美术/听感调试，不开启局内钱包、不推进路线、不结算研究点数。
extends Node2D

@onready var _player: Player = $Player
@onready var _tank: BossTank = $HeavyTank
@onready var _name: Label = $UI/Panel/Rows/BossName
@onready var _health: ProgressBar = $UI/Panel/Rows/Health
@onready var _status: Label = $UI/Panel/Rows/Status


## 注册独立试战 HUD，不依赖正式 HUD 的输入布局，方便逐项调试新首领。
func _ready() -> void:
	get_tree().paused = false
	_tank.health_component.sig_health_updated.connect(_set_health)
	_tank.sig_phase_changed.connect(_set_phase)
	_tank.sig_defeated.connect(_on_boss_defeated)
	_player.get_node("Health").sig_die.connect(_on_player_defeated)
	$UI/Panel/Rows/Restart.pressed.connect(_restart)
	var weapons := _player.get_node("WeaponManager") as PlayerWeaponManager
	weapons.obtain_smg(180)
	weapons.obtain_shortgun(48)
	_set_phase(1, 120, 120)


## 各阶段血量独立显示；中间阶段不会显示胜利。
func _set_phase(phase: int, current: int, maximum: int) -> void:
	_name.text = ["重型坦克 · 坦克形态", "重型坦克 · 过载模式", "重型坦克 · 驾驶员"][clampi(phase, 1, 3) - 1]
	_set_health(current, maximum)


## 显示真实 HealthComponent 状态，避免预览数字与伤害结算脱节。
func _set_health(current: int, maximum: int) -> void:
	_health.max_value = maximum
	_health.value = current


## 最终击败只结束试战，不调用正式奖励或关卡推进。
func _on_boss_defeated() -> void:
	_status.text = "坦克已击败，可以重新挑战。"


## 玩家死亡停止两侧战斗，保留按钮可用，不暂停全局树或写入存档。
func _on_player_defeated() -> void:
	_status.text = "玩家已战败，可以重新挑战。"
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_tank):
		_tank.process_mode = Node.PROCESS_MODE_DISABLED
		_tank._sync_track_audio(false)


## 重新加载当前试战场，只重置本场玩家与 Boss。
func _restart() -> void:
	get_tree().reload_current_scene()

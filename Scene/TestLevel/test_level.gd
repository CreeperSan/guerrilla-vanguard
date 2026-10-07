## 测试关卡在通用 LevelController 的基础上保留本场景专属爆炸碰撞设置。
extends LevelController

@onready var node_explosion: Area2D = $Explosion


## 先连接通用玩家/HUD/敌人逻辑，再设置测试场景专属爆炸碰撞层。
func _ready() -> void:
    super._ready()
    # 独立测试关卡沿用要塞配乐，首页与正式关卡仍按各自主题选曲。
    GameSettings.play_level_music(null)
    # 测试关卡中的爆炸需要同时监测玩家物理层和敌人 HurtBox 所在层。
    node_explosion.collision_mask |= 1 << 0
    node_explosion.collision_mask |= 1 << 1

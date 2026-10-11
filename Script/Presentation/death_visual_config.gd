## 死亡演出与遗体预算的外部配置；替换贴图、播放速度和数量不需要修改战斗代码。
class_name DeathVisualConfig
extends Resource

## 图集按玩家、士兵、指挥官、佣兵、胜利五行排列，每行三帧。
@export var atlas: Texture2D
@export var frame_size := Vector2i(96, 80)
@export_range(1, 12, 1) var frame_count: int = 3
@export_range(1.0, 30.0, 0.5) var frames_per_second: float = 6.0
## 旧遗体按生成顺序淡出；预算只限制遗体，不限制活着的敌人。
@export_range(1, 300, 1) var room_limit: int = 40
@export_range(1, 1000, 1) var level_limit: int = 200
@export_range(0.0, 2.0, 0.05) var eviction_fade: float = 0.2

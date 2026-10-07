## 关卡主题配置：描述美术、配乐和房间目录，生成、清场、拾取与传送由现有控制器复用。
class_name BattlefieldTheme
extends Resource

## 展示名称和房间模板根目录；模板继续遵守 Room_宽x高_样式编号的命名。
@export var display_name: String = ""
@export_dir var room_template_root: String = ""

@export_group("主题配乐")
## 同一主题内房间切换不重播，进入新 Level 时由 GameSettings 交叉淡化并无限循环。
@export var background_music: AudioStream

@export_group("地形美术")
## 主题资源为空时，房间使用原有 Fortress 图片作为安全兜底。
@export var ground_texture: Texture2D
@export var wall_texture: Texture2D
@export var water_texture: Texture2D
@export var box_texture: Texture2D
@export var entrance_texture: Texture2D
## 掩体阻挡角色和子弹；装饰只绘制，不参与碰撞。
@export var cover_texture: Texture2D
@export var decoration_texture: Texture2D
@export var secondary_style_tint: Color = Color(0.9, 0.94, 0.9, 1.0)

@export_group("主题内容")
## 每个房间至少生成的主题掩体数量；大房间会适当增加，首次进入房间才创建。
@export_range(0, 5, 1) var cover_count: int = 1
## 主题掩体的重复贴图和物理碰撞共用此尺寸。
@export var cover_size: Vector2 = Vector2(64.0, 32.0)

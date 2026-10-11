## 图标周围的圆形进度：保留 ProgressBar/Range 数值接口，以弧线绘制并按变化重画。
## 不加载额外图片、不运行逐帧脚本，颜色、线宽与内缩均可在 Inspector 编辑。
@tool
class_name CircularHUDProgress
extends ProgressBar

@export var fill_color := Color("edc879"):
    set(value_color):
        fill_color = value_color
        queue_redraw()
@export var track_color := Color("263b36")
@export_range(1.0, 8.0, 0.5) var line_width: float = 3.0
## 同一图标需要两个环时，可通过内缩区分内外环。
@export_range(0.0, 12.0, 0.5) var ring_inset: float = 0.0


## 屏蔽原生长条背景，只在尺寸或进度变化时更新弧线。
func _ready() -> void:
    add_theme_stylebox_override("background", StyleBoxEmpty.new())
    add_theme_stylebox_override("fill", StyleBoxEmpty.new())
    show_percentage = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    value_changed.connect(func(_value: float): queue_redraw())
    resized.connect(queue_redraw)


## 从正上方顺时针填充；体力与冷却共用百分比算法，满环表示资源充足/已就绪。
func _draw() -> void:
    var center := size * 0.5
    var radius := maxf(minf(size.x, size.y) * 0.5 - line_width * 0.5 - ring_inset, 0.0)
    var fraction := clampf((value - min_value) / maxf(max_value - min_value, 0.001), 0.0, 1.0)
    draw_arc(center, radius, -PI * 0.5, TAU - PI * 0.5, 64, track_color, line_width, true)
    if fraction > 0.0:
        draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, 64, fill_color, line_width, true)

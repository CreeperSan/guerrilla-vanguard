## 终局标题演出：字幕显现后保持三秒，通过信号让 HUD 进入已有结算页面。
## 暂停世界期间仍播放，时长、字号和布局可直接在 Scene Inspector 中修改。
extends Control

signal finished

@export_range(0.0, 10.0, 0.1) var hold_duration: float = 3.0
@export_range(0.1, 2.0, 0.05) var reveal_duration: float = 0.4
@onready var title: Label = $Title


## 标题从小到大淡入；倒计时从显现完成时开始，不包含前面的角色动作。
func play(won: bool) -> void:
    title.text = "Victory" if won else "Defeated"
    title.add_theme_color_override("font_color", Color("f4d17f") if won else Color("ef8272"))
    title.pivot_offset = title.size * 0.5
    title.scale = Vector2.ONE * 0.8
    title.modulate.a = 0.0
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.set_parallel(true)
    tween.tween_property(title, "modulate:a", 1.0, reveal_duration)
    tween.tween_property(title, "scale", Vector2.ONE, reveal_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.chain().tween_interval(hold_duration)
    tween.chain().tween_callback(func(): finished.emit())

extends Control
## 원형 타이머. ratio가 0에서 1로 차오르며, 원이 다 차면 시간 종료를 뜻한다.

var ratio: float = 0.0:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.size = size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)


func set_seconds(seconds: int) -> void:
	if _label:
		_label.text = str(seconds) if seconds > 0 else ""


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 3.0
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.22, 0.22, 0.28), 4.0)
	if ratio > 0.0:
		var col := Color(0.92, 0.82, 0.5).lerp(Color(0.92, 0.25, 0.2), clampf((ratio - 0.5) / 0.5, 0.0, 1.0))
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * ratio, 48, col, 4.0)

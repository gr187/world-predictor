extends StaticBody2D
## 전자문(플레이스홀더). requires 조건이 충족되면 열린다.
## requires가 "power"이면 전력 복구, 그 외 문자열이면 같은 이름의 맵 상태(flag)가 켜졌을 때.

const GameState := preload("res://scripts/game_state.gd")

var size := Vector2(14, 70)
var requires := "power"
var closed_label := "전력 필요"

var _open := false
var _shape: CollisionShape2D
var _vis: ColorRect
var _label: Label


func _ready() -> void:
	add_to_group("door")
	collision_layer = 1
	collision_mask = 0

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
	add_child(_shape)

	_vis = ColorRect.new()
	_vis.size = size
	add_child(_vis)

	_label = Label.new()
	_label.text = closed_label
	_label.position = Vector2(-20, -16)
	_label.add_theme_font_size_override("font_size", 8)
	add_child(_label)

	_apply(_wanted())


func is_open() -> bool:
	return _open


func _wanted() -> bool:
	if requires == "power":
		return GameState.power_on()
	return GameState.has_flag(requires)


func _physics_process(_delta: float) -> void:
	var want := _wanted()
	if want != _open:
		_apply(want)


func _apply(open: bool) -> void:
	_open = open
	_shape.set_deferred("disabled", open)
	_vis.color = Color(0.2, 0.3, 0.25, 0.35) if open else Color(0.5, 0.2, 0.2)
	_label.visible = not open

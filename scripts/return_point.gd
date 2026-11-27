extends Area2D
## 귀환 장치(플레이스홀더). 가까이 가서 E를 누르면 시뮬레이션을 끝내고 현실로 돌아가 보고한다.

signal activated

var _inside := false
var _prompt: Label


func _ready() -> void:
	add_to_group("return_point")
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	add_child(shape)

	var marker := ColorRect.new()
	marker.size = Vector2(14, 22)
	marker.position = Vector2(-7, -11)
	marker.color = Color(0.35, 0.8, 0.9)
	add_child(marker)

	_prompt = Label.new()
	_prompt.text = "[E] 귀환하여 보고"
	_prompt.position = Vector2(-38, -34)
	_prompt.add_theme_font_size_override("font_size", 9)
	_prompt.visible = false
	add_child(_prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = true
		_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = false
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _inside and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		activated.emit()

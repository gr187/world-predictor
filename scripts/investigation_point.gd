extends Area2D
## 조사 지점(플레이스홀더). 가까이 가서 E를 누르면 단서를 얻는다.

signal investigated(new_ids: Array)

const GameState := preload("res://scripts/game_state.gd")

var clue_ids: Array = []

var _inside := false
var _marker: ColorRect
var _prompt: Label


func _ready() -> void:
	add_to_group("investigation")
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 30)
	shape.shape = rect
	add_child(shape)

	_marker = ColorRect.new()
	_marker.size = Vector2(8, 8)
	_marker.position = Vector2(-4, -4)
	_marker.rotation = deg_to_rad(45)
	add_child(_marker)

	_prompt = Label.new()
	_prompt.text = "[E] 조사"
	_prompt.position = Vector2(-22, -30)
	_prompt.add_theme_font_size_override("font_size", 9)
	add_child(_prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh()


func is_done() -> bool:
	var book = GameState.get_book()
	for id in clue_ids:
		if not book.has(id):
			return false
	return true


func _refresh() -> void:
	var done := is_done()
	_marker.color = Color(0.35, 0.35, 0.38) if done else Color(0.95, 0.78, 0.3)
	_prompt.visible = _inside and not done


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = true
		_refresh()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = false
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not _inside or not event.is_action_pressed("interact"):
		return
	if is_done():
		return
	var book = GameState.get_book()
	var new_ids: Array = []
	for id in clue_ids:
		if book.collect(id):
			new_ids.append(id)
	_refresh()
	if not new_ids.is_empty():
		investigated.emit(new_ids)
		get_viewport().set_input_as_handled()

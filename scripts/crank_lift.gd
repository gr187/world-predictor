extends AnimatableBody2D
## 크랭크 승강기(플레이스홀더). 발판 위에서 E를 누르면 손으로 돌려 오르내린다.
## needs_power가 true면 전력이 복구되어야 움직인다 (케이블카).
## E: 멈춰 있으면 출발, 움직이는 중이면 정지. 다시 E를 누르면 반대 방향으로 간다.

signal message(text: String)

const GameState := preload("res://scripts/game_state.gd")

var top_y := 0.0          ## 위쪽 끝에서의 발판 표면 y
var bottom_y := 0.0       ## 아래쪽 끝에서의 발판 표면 y
var speed := 45.0
var needs_power := false
var width := 48.0

var _dir := 0             ## -1 위, +1 아래, 0 정지
var _last_dir := 0        ## 마지막으로 움직인 방향
var _inside := false
var _prompt: Label


func setup(x: float, top_surface_y: float, bottom_surface_y: float, powered: bool = false) -> void:
	top_y = top_surface_y
	bottom_y = bottom_surface_y
	needs_power = powered
	position = Vector2(x, bottom_surface_y)


func _ready() -> void:
	add_to_group("moving")
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 6)
	shape.shape = rect
	shape.position = Vector2(0, 3)
	add_child(shape)

	var vis := ColorRect.new()
	vis.size = Vector2(width, 6)
	vis.position = Vector2(-width / 2.0, 0)
	vis.color = Color(0.5, 0.6, 0.7) if needs_power else Color(0.6, 0.5, 0.35)
	add_child(vis)

	# 발판 위에 선 사람을 감지하는 영역(발판과 함께 움직인다)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var ashape := CollisionShape2D.new()
	var arect := RectangleShape2D.new()
	arect.size = Vector2(width + 8.0, 40)
	ashape.shape = arect
	ashape.position = Vector2(0, -18)
	area.add_child(ashape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

	_prompt = Label.new()
	_prompt.text = "[E] 전력 승강기" if needs_power else "[E] 크랭크"
	_prompt.position = Vector2(-26, -34)
	_prompt.add_theme_font_size_override("font_size", 9)
	_prompt.visible = false
	add_child(_prompt)


func is_moving() -> bool:
	return _dir != 0


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = true
		_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_inside = false
		_prompt.visible = false


func _physics_process(delta: float) -> void:
	if _dir == 0:
		return
	var ny := position.y + _dir * speed * delta
	if ny <= top_y:
		ny = top_y
		_dir = 0
	elif ny >= bottom_y:
		ny = bottom_y
		_dir = 0
	position.y = ny


func _unhandled_input(event: InputEvent) -> void:
	if not _inside or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if needs_power and not GameState.power_on():
		message.emit("전력이 들어오지 않는다.")
		return
	if _dir != 0:
		_dir = 0
		return
	_dir = -_last_dir if _last_dir != 0 else -1
	_last_dir = _dir

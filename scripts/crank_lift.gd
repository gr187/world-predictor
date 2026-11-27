extends AnimatableBody2D
## 크랭크 승강기(플레이스홀더). 발판 위에서 E를 누르면 손으로 돌려 오르내린다.
## needs_power가 true면 전력이 복구되어야 움직인다 (케이블카).
## E: 멈춰 있으면 출발, 움직이는 중이면 정지. 다시 E를 누르면 반대 방향으로 간다.
## 두 정류장(위·아래) 근처에서 E를 누르면 승강기가 그쪽으로 내려오거나 올라온다. (한쪽에 남아도 갇히지 않게)

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
var _near_top := false      ## 위쪽 정류장 근처에 서 있다
var _near_bottom := false   ## 아래쪽 정류장 근처에 서 있다
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

	_make_call_areas.call_deferred()


## 정류장마다 승강기를 부르는 영역을 만든다. 승강기와 함께 움직이지 않도록 같은 부모 아래에 둔다.
func _make_call_areas() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for is_top in [true, false]:
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(width + 8.0, 40)
		shape.shape = rect
		area.add_child(shape)
		area.position = Vector2(position.x, (top_y if is_top else bottom_y) - 18.0)
		area.body_entered.connect(_on_call_entered.bind(is_top))
		area.body_exited.connect(_on_call_exited.bind(is_top))
		parent.add_child(area)


func _on_call_entered(body: Node, is_top: bool) -> void:
	if body.is_in_group("player"):
		if is_top:
			_near_top = true
		else:
			_near_bottom = true


func _on_call_exited(body: Node, is_top: bool) -> void:
	if body.is_in_group("player"):
		if is_top:
			_near_top = false
		else:
			_near_bottom = false


func is_moving() -> bool:
	return _dir != 0


func at_top() -> bool:
	return absf(position.y - top_y) < 0.5


func at_bottom() -> bool:
	return absf(position.y - bottom_y) < 0.5


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
	if not event.is_action_pressed("interact"):
		return
	if _inside:
		get_viewport().set_input_as_handled()
		if needs_power and not GameState.power_on():
			message.emit("전력이 들어오지 않는다.")
			return
		if _dir != 0:
			_dir = 0
			return
		_dir = -_last_dir if _last_dir != 0 else -1
		_last_dir = _dir
		return

	# 발판 위가 아니라 정류장 근처라면 승강기를 부른다.
	if _near_top or _near_bottom:
		get_viewport().set_input_as_handled()
		if needs_power and not GameState.power_on():
			message.emit("전력이 들어오지 않는다.")
			return
		if _dir != 0:
			return
		var want_top := _near_top
		if (want_top and at_top()) or (not want_top and at_bottom()):
			message.emit("승강기가 이미 여기 있다.")
			return
		_dir = -1 if want_top else 1
		_last_dir = _dir
		message.emit("승강기를 부른다.")

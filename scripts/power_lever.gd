extends Area2D
## 레버(플레이스홀더). 가까이 가서 E를 누르면 올린다. 한 번 올리면 다시 내릴 수 없다.
## permanent가 false면 이번 시뮬레이션에서만 유지되고(전력 레버), true면 죽어도 유지된다(지름길).

signal message(text: String)

const GameState := preload("res://scripts/game_state.gd")
const SaveGame := preload("res://scripts/save_game.gd")

var flag_name := "lever_a"
var permanent := false
var is_power_lever := true     ## 전력 복구용 레버인가 (안내 문구가 달라진다)

var _inside := false
var _handle: ColorRect
var _prompt: Label


func _ready() -> void:
	add_to_group("lever")
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 30)
	shape.shape = rect
	add_child(shape)

	var base := ColorRect.new()
	base.size = Vector2(14, 6)
	base.position = Vector2(-7, 9)
	base.color = Color(0.3, 0.3, 0.35)
	add_child(base)

	_handle = ColorRect.new()
	_handle.size = Vector2(4, 16)
	add_child(_handle)

	_prompt = Label.new()
	_prompt.text = "[E] 레버"
	_prompt.position = Vector2(-18, -34)
	_prompt.add_theme_font_size_override("font_size", 9)
	_prompt.visible = false
	add_child(_prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh()


func is_pulled() -> bool:
	return GameState.has_flag(flag_name)


func _refresh() -> void:
	# 올리면 손잡이가 위로 서고 초록색, 내려져 있으면 기울어진 붉은색
	if is_pulled():
		_handle.position = Vector2(-2, -8)
		_handle.color = Color(0.4, 0.9, 0.5)
	else:
		_handle.position = Vector2(-2, -2)
		_handle.color = Color(0.85, 0.35, 0.3)
	_prompt.visible = _inside and not is_pulled()


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
	get_viewport().set_input_as_handled()
	if is_pulled():
		message.emit("이미 올려 둔 레버다.")
		return
	GameState.set_flag(flag_name, permanent)
	if permanent:
		SaveGame.autosave()   # 지름길은 죽어도 유지되므로 저장한다
	_refresh()
	if not is_power_lever:
		message.emit("어디선가 잠금이 풀리는 소리가 났다. (지름길이 열렸다)")
	elif GameState.power_on():
		message.emit("전력이 복구되었다!")
	else:
		message.emit("레버를 올렸다. 전력 %d / %d" % [GameState.power_levers_on(), GameState.POWER_LEVERS_REQUIRED])

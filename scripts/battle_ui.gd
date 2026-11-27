extends CanvasLayer
## 전투 화면(플레이스홀더). 전투 규칙은 battle_logic.gd가 담당한다.
## 매 턴 선택지 3개가 나오고, 5초 안에 고르지 않으면 그중 하나가 자동으로 선택된다.

signal finished(won: bool)

const BattleLogic := preload("res://scripts/battle_logic.gd")
const CircleTimer := preload("res://scripts/circle_timer.gd")

const TURN_TIME := 5.0       ## 한 턴의 제한 시간(초)
const RESULT_PAUSE := 1.4    ## 결과를 읽을 시간(이 동안은 타이머가 멈춘다)
const KEYS := [KEY_1, KEY_2, KEY_3]

var logic
var _over := false
var _turn_active := false
var _time_left := TURN_TIME
var _busy_time := 0.0

var _enemy_label: Label
var _tell_label: Label
var _log_label: Label
var _player_label: Label
var _timer   ## circle_timer.gd 인스턴스
var _buttons: Array[Button] = []
var _continue: Button


func setup(enemy_data: Dictionary, clue_level: int) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	logic = BattleLogic.new(enemy_data, clue_level)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.size = Vector2(480, 270)
	add_child(dim)

	_enemy_label = _make_label(Vector2(20, 14), Vector2(440, 24), 14, HORIZONTAL_ALIGNMENT_CENTER)
	_tell_label = _make_label(Vector2(40, 68), Vector2(380, 50), 13, HORIZONTAL_ALIGNMENT_CENTER)
	_tell_label.modulate = Color(0.95, 0.85, 0.6)
	_log_label = _make_label(Vector2(40, 124), Vector2(400, 66), 11, HORIZONTAL_ALIGNMENT_CENTER)
	_log_label.modulate = Color(0.75, 0.78, 0.85)
	_player_label = _make_label(Vector2(20, 248), Vector2(300, 20), 11, HORIZONTAL_ALIGNMENT_LEFT)

	_timer = CircleTimer.new()
	_timer.position = Vector2(428, 48)
	_timer.size = Vector2(44, 44)
	add_child(_timer)

	for i in 3:
		var b := Button.new()
		b.position = Vector2(30.0 + 155.0 * i, 200)
		b.size = Vector2(110, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_on_choice.bind(i))
		add_child(b)
		_buttons.append(b)

	_continue = Button.new()
	_continue.text = "계속"
	_continue.position = Vector2(185, 206)
	_continue.size = Vector2(110, 32)
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.visible = false
	_continue.add_theme_font_size_override("font_size", 12)
	_continue.pressed.connect(_on_continue)
	add_child(_continue)

	_log_label.text = "%s이(가) 앞을 막아선다." % enemy_data["name"]
	_begin_turn()


func _make_label(pos: Vector2, sz: Vector2, font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


## 새 턴 시작: 징후와 선택지를 보여 주고 타이머를 5초로 되돌린다.
func _begin_turn() -> void:
	_turn_active = true
	_time_left = TURN_TIME
	_timer.ratio = 0.0
	_timer.set_seconds(int(ceil(_time_left)))
	_tell_label.text = logic.get_tell()
	for i in _buttons.size():
		var b := _buttons[i]
		if i < logic.offer.size():
			var id: String = logic.offer[i]
			var def: Dictionary = logic.ACTIONS[id]
			b.visible = true
			b.text = "%s [%d]\n집중 %d" % [def["name"], i + 1, def["cost"]]
			b.disabled = not logic.is_usable(id)
		else:
			b.visible = false
	_refresh_status()


func _refresh_status() -> void:
	_enemy_label.text = "%s   HP %d" % [logic.data["name"], logic.enemy_hp]
	_player_label.text = "HP %d / %d      집중 %d / %d" % [
		logic.player_hp, logic.PLAYER_MAX_HP, logic.focus, logic.FOCUS_MAX]


func _process(delta: float) -> void:
	if logic == null or logic.over:
		return
	if _busy_time > 0.0:
		_busy_time -= delta
		if _busy_time <= 0.0:
			_begin_turn()
		return
	if not _turn_active:
		return
	_time_left -= delta
	_timer.ratio = 1.0 - _time_left / TURN_TIME
	_timer.set_seconds(maxi(int(ceil(_time_left)), 0))
	if _time_left <= 0.0:
		_on_timeout()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if logic.over:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_continue()
		return
	for i in KEYS.size():
		if event.keycode == KEYS[i]:
			_on_choice(i)
			get_viewport().set_input_as_handled()
			return


## 버튼/숫자 키로 고른 경우. 결과 표시 중이거나 쓸 수 없는 선택지면 무시한다.
func _on_choice(index: int) -> void:
	if not _turn_active or index >= logic.offer.size():
		return
	choose(logic.offer[index])


func choose(action: String) -> void:
	if _over:
		return
	var result: Dictionary = logic.play(action)
	if result["invalid"]:
		return
	_show_result(result)


func _on_timeout() -> void:
	_show_result(logic.play_timeout())


func _show_result(result: Dictionary) -> void:
	_turn_active = false
	var lines: Array = result["lines"]
	_log_label.text = "\n".join(lines)
	_refresh_status()
	if logic.over:
		_end()
		return
	# 결과를 읽을 시간을 준 뒤 다음 턴을 시작한다.
	_busy_time = RESULT_PAUSE
	_tell_label.text = ""
	_timer.ratio = 0.0
	_timer.set_seconds(0)
	for b in _buttons:
		b.disabled = true


func _end() -> void:
	_over = true
	_tell_label.text = ""
	_timer.ratio = 0.0
	_timer.set_seconds(0)
	for b in _buttons:
		b.visible = false
	_continue.visible = true
	if logic.winner == "player":
		_log_label.text += "\n%s의 움직임이 멈췄다." % logic.data["name"]
	else:
		_log_label.text += "\n시뮬레이션이 강제 종료된다…"


func _on_continue() -> void:
	if not _over:
		return
	_over = false  # 중복 입력 방지
	finished.emit(logic.winner == "player")

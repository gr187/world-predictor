extends CanvasLayer
## 전투 화면(플레이스홀더). 전투 규칙은 battle_logic.gd가 담당한다.

signal finished(won: bool)

const BattleLogic := preload("res://scripts/battle_logic.gd")
const ACTIONS := [
	["attack", "공격", KEY_1],
	["defend", "방어", KEY_2],
	["dodge", "회피", KEY_3],
]

var logic
var _over := false
var _enemy_label: Label
var _tell_label: Label
var _log_label: Label
var _player_label: Label
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

	_enemy_label = _make_label(Vector2(20, 18), Vector2(440, 40), 14, HORIZONTAL_ALIGNMENT_CENTER)
	_tell_label = _make_label(Vector2(40, 80), Vector2(400, 50), 13, HORIZONTAL_ALIGNMENT_CENTER)
	_tell_label.modulate = Color(0.95, 0.85, 0.6)
	_log_label = _make_label(Vector2(40, 140), Vector2(400, 60), 11, HORIZONTAL_ALIGNMENT_CENTER)
	_log_label.modulate = Color(0.75, 0.78, 0.85)
	_player_label = _make_label(Vector2(20, 246), Vector2(200, 20), 11, HORIZONTAL_ALIGNMENT_LEFT)

	var x := 60.0
	for a in ACTIONS:
		var b := Button.new()
		b.text = "%s [%d]" % [a[1], int(a[2]) - KEY_0]
		b.position = Vector2(x, 208)
		b.size = Vector2(90, 28)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(choose.bind(a[0]))
		add_child(b)
		_buttons.append(b)
		x += 135.0

	_continue = Button.new()
	_continue.text = "계속"
	_continue.position = Vector2(195, 208)
	_continue.size = Vector2(90, 28)
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.visible = false
	_continue.add_theme_font_size_override("font_size", 12)
	_continue.pressed.connect(_on_continue)
	add_child(_continue)

	_log_label.text = "%s이(가) 앞을 막아선다." % enemy_data["name"]
	_refresh()


func _make_label(pos: Vector2, sz: Vector2, font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


func _refresh() -> void:
	_enemy_label.text = "%s   HP %d" % [logic.data["name"], logic.enemy_hp]
	_player_label.text = "HP %d / %d" % [logic.player_hp, logic.PLAYER_MAX_HP]
	_tell_label.text = logic.get_tell() if not logic.over else ""


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _over:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_continue()
		return
	for a in ACTIONS:
		if event.keycode == a[2]:
			choose(a[0])
			get_viewport().set_input_as_handled()
			return


func choose(action: String) -> void:
	if _over:
		return
	var result: Dictionary = logic.play(action)
	var lines: Array = result["lines"]
	_log_label.text = "\n".join(lines)
	_refresh()
	if logic.over:
		_end()


func _end() -> void:
	_over = true
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

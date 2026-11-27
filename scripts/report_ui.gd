extends CanvasLayer
## 상사 보고 화면(플레이스홀더). 현실 거점(3D)이 생기기 전까지 귀환 후 이 화면이 열린다.
## 흐름: 원인 선택 → 근거 카드 첨부 → 등급·코멘트·힌트 → 보급품 선택 → 다음 시뮬레이션
## 점수는 보여 주지 않고 등급과 한 줄 코멘트만 보여 준다.

signal finished

enum Step { CAUSE, EVIDENCE, RESULT, SUPPLY, DONE }

const ReportLogic := preload("res://scripts/report_logic.gd")
const GameState := preload("res://scripts/game_state.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const MAX_CARDS := 3

var book
var logic
var reason := "return"          ## "return"(귀환 장치) / "defeat"(전투 패배)
var step: int = Step.CAUSE
var result: Dictionary = {}
var unlocked_now := false       ## 이번 보고로 다음 세계가 새로 열렸는가

var _cause_id := ""
var _cause_index := 0
var _checked_cards: Array = []     ## 첨부한 카드 번호(book.cards 인덱스)
var _checked_supplies: Array = []  ## 고른 보급품 id
var _items: Array = []
var _title: Label
var _list: ItemList
var _detail: Label
var _msg: Label
var _hint: Label
var _primary: Button
var _secondary: Button


func setup(the_book, the_reason: String = "return") -> void:
	book = the_book
	reason = the_reason
	logic = ReportLogic.new()
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 9

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 0.97)
	dim.size = Vector2(480, 270)
	add_child(dim)

	_title = _label(Vector2(20, 10), Vector2(440, 22), 14)
	_list = ItemList.new()
	_list.position = Vector2(20, 38)
	_list.size = Vector2(210, 186)
	_list.allow_search = false
	_list.add_theme_font_size_override("font_size", 10)
	_list.item_selected.connect(_on_selected)
	_list.item_activated.connect(_on_activated)
	add_child(_list)
	_detail = _label(Vector2(244, 38), Vector2(220, 186), 11)
	_msg = _label(Vector2(20, 228), Vector2(200, 16), 10)
	_msg.modulate = Color(0.95, 0.85, 0.6)

	# 마우스로도 진행할 수 있는 버튼 (키보드와 같은 동작)
	_primary = _button(Vector2(350, 224), Vector2(110, 20), func(): handle_key(KEY_ENTER))
	_secondary = _button(Vector2(232, 224), Vector2(110, 20), func(): _on_secondary())
	_hint = _label(Vector2(20, 246), Vector2(445, 20), 9)
	_hint.modulate = Color(0.6, 0.62, 0.7)

	_enter(Step.CAUSE)


func _button(pos: Vector2, sz: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(action)
	add_child(b)
	return b


func _on_secondary() -> void:
	if step == Step.CAUSE:
		handle_key(KEY_N)
	elif step == Step.EVIDENCE:
		handle_key(KEY_ESCAPE)


func _label(pos: Vector2, sz: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


# ---------------------------------------------------------------- 화면 구성

func _enter(new_step: int, keep_index: int = 0) -> void:
	step = new_step
	_msg.text = ""
	_items.clear()
	_list.clear()
	_list.visible = true

	match step:
		Step.CAUSE:
			_title.text = "상사 보고 - 멸망 원인"
			for c in logic.causes():
				_items.append(c["id"])
				_list.add_item(c["text"])
			_hint.text = "↑↓ 선택     Enter 이 원인으로 보고     N 보고 없이 재도전"
		Step.EVIDENCE:
			_title.text = "상사 보고 - 근거 첨부   (%d/%d장)" % [_checked_cards.size(), MAX_CARDS]
			for i in book.cards.size():
				_items.append(i)
				var mark := "[v] " if _checked_cards.has(i) else "[  ] "
				_list.add_item("%s%s" % [mark, book.statements[book.cards[i]["statement"]]["text"]])
			_hint.text = "Space 카드 선택/해제 (최대 3장)     Enter 제출     Esc 뒤로"
		Step.RESULT:
			_title.text = "상사 보고 - 결과"
			_list.visible = false
			_hint.text = "Enter 계속"
		Step.SUPPLY:
			_title.text = "보급품 선택   (%d/%d개)" % [_checked_supplies.size(), _supply_limit()]
			for s in logic.supplies():
				_items.append(s["id"])
				var mark := "[v] " if _checked_supplies.has(s["id"]) else "[  ] "
				_list.add_item("%s%s - %s" % [mark, s["name"], s["desc"]])
			_hint.text = "Space 선택/해제     Enter 확정"
		Step.DONE:
			_title.text = "다음 시뮬레이션"
			_list.visible = false
			_hint.text = "Enter 시작"

	_refresh_buttons()
	_refresh_detail()
	if not _items.is_empty():
		var i := clampi(keep_index, 0, _items.size() - 1)
		_list.select(i)
		_list.ensure_current_is_visible()
		_list.grab_focus()


func _refresh_buttons() -> void:
	_secondary.visible = step == Step.CAUSE or step == Step.EVIDENCE
	match step:
		Step.CAUSE:
			_primary.text = "이 원인으로 보고"
			_secondary.text = "보고 없이 재도전"
		Step.EVIDENCE:
			_primary.text = "제출"
			_secondary.text = "뒤로"
		Step.RESULT:
			_primary.text = "계속"
		Step.SUPPLY:
			_primary.text = "확정"
		Step.DONE:
			_primary.text = "시작"


func _supply_limit() -> int:
	return mini(int(result.get("supply_count", 0)), logic.supplies().size())


func _refresh_detail() -> void:
	match step:
		Step.CAUSE:
			var intro: String = logic.data["intro_defeat"] if reason == "defeat" else logic.data["intro_return"]
			_detail.text = "%s\n\n수집한 단서 %d / %d\n추론 카드 %d장\n\n멸망 원인으로 무엇을 보고할까?" % [
				intro, book.count(), book.total(), book.cards.size()]
		Step.EVIDENCE:
			if book.cards.is_empty():
				_detail.text = "첨부할 추론 카드가 없다.\n\nEnter를 누르면 근거 없이 제출한다."
			else:
				_detail.text = "결론을 뒷받침하는 추론 카드를 최대 %d장 골라 첨부한다.\n\n선택하지 않아도 제출할 수 있다." % MAX_CARDS
		Step.RESULT:
			var text := "등급  %s\n\n%s" % [result["grade"], result["comment"]]
			text += "\n\n%s" % (logic.data["pass_text"] if result["passed"] else logic.data["fail_text"])
			if unlocked_now:
				text += "\n\n" + logic.data["unlock_text"] % [GameState.unlocked_world, GameState.unlocked_world]
			if result["hint"] != "":
				text += "\n\n힌트: " + result["hint"]
			_detail.text = text
		Step.SUPPLY:
			_detail.text = "등급 %s: 보급품을 %d개 가져갈 수 있다.\n다음 시뮬레이션에서만 쓸 수 있다." % [result["grade"], _supply_limit()]
		Step.DONE:
			var names: Array = []
			for id in GameState.pending_supplies:
				names.append(logic.supply_name(id))
			var s := "다음 시뮬레이션을 시작한다."
			if not names.is_empty():
				s += "\n\n가져가는 보급품\n - " + "\n - ".join(names)
			_detail.text = s


func _on_selected(_index: int) -> void:
	pass


func _on_activated(index: int) -> void:
	match step:
		Step.CAUSE:
			_choose_cause(index)
		Step.EVIDENCE:
			_toggle_card(index)
		Step.SUPPLY:
			_toggle_supply(index)


# ---------------------------------------------------------------- 입력

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if handle_key(event.keycode):
			get_viewport().set_input_as_handled()


func _selected_index() -> int:
	var sel := _list.get_selected_items()
	return -1 if sel.is_empty() else sel[0]


## 키 입력을 처리한다. 처리했으면 true. (테스트에서도 직접 호출한다)
func handle_key(code: int) -> bool:
	_msg.text = ""
	var sel := _selected_index()
	var is_enter := code == KEY_ENTER or code == KEY_KP_ENTER
	match step:
		Step.CAUSE:
			if is_enter:
				_choose_cause(sel)
				return true
			if code == KEY_N:
				_skip()
				return true
		Step.EVIDENCE:
			if code == KEY_SPACE:
				_toggle_card(sel)
				return true
			if is_enter:
				_submit()
				return true
			if code == KEY_ESCAPE:
				_enter(Step.CAUSE, _cause_index)
				return true
		Step.RESULT:
			if is_enter:
				_after_result()
				return true
		Step.SUPPLY:
			if code == KEY_SPACE:
				_toggle_supply(sel)
				return true
			if is_enter:
				_confirm_supplies()
				return true
		Step.DONE:
			if is_enter:
				finished.emit()
				return true
	return false


# ---------------------------------------------------------------- 단계별 동작

func _choose_cause(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	_cause_id = String(_items[index])
	_cause_index = index
	_checked_cards.clear()
	_enter(Step.EVIDENCE)


func _toggle_card(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var card_no := int(_items[index])
	if _checked_cards.has(card_no):
		_checked_cards.erase(card_no)
	elif _checked_cards.size() >= MAX_CARDS:
		_msg.text = "카드는 최대 %d장까지 첨부할 수 있다." % MAX_CARDS
		return
	else:
		_checked_cards.append(card_no)
	_enter(Step.EVIDENCE, index)


func _submit() -> void:
	result = logic.evaluate(book, _cause_id, _checked_cards)
	GameState.last_grade = result["grade"]
	unlocked_now = false
	if result["passed"]:
		unlocked_now = GameState.unlock_next_world()
	_checked_supplies.clear()
	SaveGame.autosave()   # 등급과 해금 상태 저장
	_enter(Step.RESULT)


func _after_result() -> void:
	if _supply_limit() > 0:
		_enter(Step.SUPPLY)
	else:
		GameState.pending_supplies = []
		_enter(Step.DONE)


func _toggle_supply(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var id := String(_items[index])
	if _checked_supplies.has(id):
		_checked_supplies.erase(id)
	elif _checked_supplies.size() >= _supply_limit():
		_msg.text = "보급품은 %d개까지 고를 수 있다." % _supply_limit()
		return
	else:
		_checked_supplies.append(id)
	_enter(Step.SUPPLY, index)


func _confirm_supplies() -> void:
	if _checked_supplies.size() != _supply_limit():
		_msg.text = "보급품을 %d개 골라야 한다." % _supply_limit()
		return
	GameState.pending_supplies = _checked_supplies.duplicate()
	SaveGame.autosave()   # 받은 보급품 저장
	_enter(Step.DONE)


## 보고 없이 재도전. 등급, 보급품, 힌트는 없다.
func _skip() -> void:
	result = {}
	unlocked_now = false
	GameState.pending_supplies = []
	_enter(Step.DONE)

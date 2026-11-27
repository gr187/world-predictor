extends CanvasLayer
## 단서 수첩 화면(플레이스홀더).
## 단서 목록 + 믿음/보류/의심 표시 + 단서 연결(모순/뒷받침) + 추론 카드 만들기.
## 표시나 결론이 맞는지는 알려 주지 않는다. 숨은 신뢰도와 정답 여부는 보여 주지 않는다.

signal closed

enum Mode { LIST, LINK_PICK, LINK_RELATION, INFER_PICK, CONCLUDE, CARDS }

const MARK_NAMES := {"trust": "믿음", "hold": "보류", "doubt": "의심"}
const MARK_TAGS := {"trust": "[+]", "hold": "[ ]", "doubt": "[-]"}
const RELATION_NAMES := {"contradict": "모순", "support": "뒷받침"}

var book
var mode: int = Mode.LIST
var _items: Array = []         ## 목록에 표시 중인 항목의 id (단서/결론 id 또는 카드 번호)
var _anchor := ""              ## 연결을 시작한 단서
var _target := ""              ## 연결할 상대 단서
var _checked: Array = []       ## 추론 카드에 쓸 단서
var _title: Label
var _list: ItemList
var _detail: Label
var _msg: Label
var _hint: Label


func setup(the_book) -> void:
	book = the_book
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.06, 0.95)
	dim.size = Vector2(480, 270)
	add_child(dim)

	_title = _make_label(Vector2(20, 10), Vector2(440, 22), 14)

	_list = ItemList.new()
	_list.position = Vector2(20, 38)
	_list.size = Vector2(190, 186)
	_list.allow_search = false
	_list.add_theme_font_size_override("font_size", 10)
	_list.item_selected.connect(_on_selected)
	_list.item_activated.connect(_on_activated)
	add_child(_list)

	_detail = _make_label(Vector2(226, 38), Vector2(236, 186), 10)
	_msg = _make_label(Vector2(20, 228), Vector2(440, 16), 10)
	_msg.modulate = Color(0.95, 0.85, 0.6)
	_hint = _make_label(Vector2(20, 246), Vector2(445, 20), 9)
	_hint.modulate = Color(0.6, 0.62, 0.7)

	_enter_mode(Mode.LIST)


func _make_label(pos: Vector2, sz: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


# ---------------------------------------------------------------- 화면 구성

func _enter_mode(new_mode: int, keep_index: int = 0) -> void:
	mode = new_mode
	_msg.text = ""
	_items.clear()
	_list.clear()

	match mode:
		Mode.LIST, Mode.LINK_PICK, Mode.INFER_PICK:
			for c in book.collected():
				_items.append(c["id"])
				_list.add_item(_clue_line(c))
				var idx := _list.item_count - 1
				if book.get_mark(c["id"]) == "trust":
					_list.set_item_custom_fg_color(idx, Color(0.6, 0.9, 0.6))
				elif book.get_mark(c["id"]) == "doubt":
					_list.set_item_custom_fg_color(idx, Color(0.95, 0.5, 0.5))
		Mode.CONCLUDE:
			for id in book.statements:
				_items.append(id)
				_list.add_item(book.statements[id]["text"])
		Mode.CARDS:
			for i in book.cards.size():
				_items.append(i)
				_list.add_item("카드 %d: %s" % [i + 1, book.statements[book.cards[i]["statement"]]["text"]])
		Mode.LINK_RELATION:
			pass

	_update_title()
	_update_hint()
	if _items.is_empty():
		_show_empty()
		return
	_list.visible = true
	var i := clampi(keep_index, 0, _items.size() - 1)
	_select(i)
	_list.grab_focus()


func _show_empty() -> void:
	_list.visible = mode == Mode.LINK_RELATION
	match mode:
		Mode.CARDS:
			_detail.text = "아직 만든 추론 카드가 없다.\n\n단서 목록에서 R 키로 단서 2~3개를 묶어 결론을 확정할 수 있다."
		_:
			_detail.text = "아직 모은 단서가 없다.\n\n맵의 노란 표시에 다가가 E 키로 조사할 수 있다."


func _clue_line(c: Dictionary) -> String:
	var prefix := ""
	if mode == Mode.INFER_PICK:
		prefix = "[v] " if _checked.has(c["id"]) else "[  ] "
	else:
		prefix = MARK_TAGS[book.get_mark(c["id"])] + " "
	return "%s[%s] %s" % [prefix, c["type"], c["source"]]


func _update_title() -> void:
	match mode:
		Mode.CARDS:
			_title.text = "추론 카드   %d장" % book.cards.size()
		Mode.INFER_PICK:
			_title.text = "추론 카드 만들기 - 단서 고르기   (%d/%d개 선택)" % [_checked.size(), book.CARD_MAX]
		Mode.CONCLUDE:
			_title.text = "추론 카드 만들기 - 결론 고르기"
		Mode.LINK_PICK, Mode.LINK_RELATION:
			_title.text = "단서 연결"
		_:
			_title.text = "단서 수첩   %d / %d     추론 카드 %d장" % [book.count(), book.total(), book.cards.size()]


func _update_hint() -> void:
	match mode:
		Mode.LIST:
			_hint.text = "↑↓ 선택   Z 믿음  X 보류  C 의심   V 연결   R 추론 카드 만들기   Tab 카드 목록   Q 닫기"
		Mode.LINK_PICK:
			_hint.text = "이어 줄 단서를 고르고 Enter     Esc 취소"
		Mode.LINK_RELATION:
			_hint.text = "1 모순     2 뒷받침     3 연결 해제     Esc 취소"
		Mode.INFER_PICK:
			_hint.text = "Space 단서 선택/해제 (2~3개)     Enter 다음     Esc 취소"
		Mode.CONCLUDE:
			_hint.text = "↑↓ 결론 선택     Enter 확정     Esc 뒤로"
		Mode.CARDS:
			_hint.text = "↑↓ 선택     Del 삭제     Tab 단서 목록     Esc 단서 목록"


## 목록에서 항목을 고르고 상세 내용을 갱신한다.
func _select(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	_list.select(index)
	_list.ensure_current_is_visible()
	_on_selected(index)


func _selected_index() -> int:
	var sel := _list.get_selected_items()
	return -1 if sel.is_empty() else sel[0]


func _on_selected(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	match mode:
		Mode.LIST, Mode.LINK_PICK, Mode.INFER_PICK:
			_detail.text = _clue_detail(String(_items[index]))
		Mode.CONCLUDE:
			_detail.text = _conclude_detail(String(_items[index]))
		Mode.CARDS:
			_detail.text = _card_detail(int(_items[index]))


func _on_activated(index: int) -> void:
	# Enter/더블클릭: 모드에 따라 항목을 확정한다.
	match mode:
		Mode.LINK_PICK:
			_pick_link_target(index)
		Mode.INFER_PICK:
			_toggle_checked(index)
		Mode.CONCLUDE:
			_confirm_card(index)


func _clue_detail(id: String) -> String:
	var c: Dictionary = book.all[id]
	var text := "종류: %s\n출처: %s\n시점: %s\n\n%s\n\n판단: %s" % [
		c["type"], c["source"], c["time"], c["text"], MARK_NAMES[book.get_mark(id)]]
	var ls: Array = book.links_of(id)
	if not ls.is_empty():
		text += "\n\n연결"
		for l in ls:
			text += "\n - %s: %s" % [RELATION_NAMES[l["relation"]], book.all[l["other"]]["source"]]
	return text


func _conclude_detail(statement_id: String) -> String:
	var names: Array = []
	for id in _checked:
		names.append(book.all[id]["source"])
	return "근거 단서\n - %s\n\n결론\n%s" % ["\n - ".join(names), book.statements[statement_id]["text"]]


func _card_detail(index: int) -> String:
	var card: Dictionary = book.cards[index]
	var names: Array = []
	for id in card["clues"]:
		names.append(book.all[id]["source"])
	return "결론\n%s\n\n근거 단서\n - %s" % [book.statements[card["statement"]]["text"], "\n - ".join(names)]


# ---------------------------------------------------------------- 입력

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("notebook"):
		get_viewport().set_input_as_handled()
		closed.emit()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if handle_key(event.keycode):
			get_viewport().set_input_as_handled()


## 키 입력을 처리한다. 처리했으면 true. (테스트에서도 직접 호출한다)
func handle_key(code: int) -> bool:
	_msg.text = ""
	var sel := _selected_index()
	match mode:
		Mode.LIST:
			match code:
				KEY_Z: return _set_mark(sel, "trust")
				KEY_X: return _set_mark(sel, "hold")
				KEY_C: return _set_mark(sel, "doubt")
				KEY_V: return _begin_link(sel)
				KEY_R: return _begin_infer()
				KEY_TAB:
					_enter_mode(Mode.CARDS)
					return true
				KEY_ESCAPE:
					closed.emit()
					return true
		Mode.LINK_PICK:
			if code == KEY_ENTER or code == KEY_KP_ENTER:
				_pick_link_target(sel)
				return true
			if code == KEY_ESCAPE:
				_enter_mode(Mode.LIST, _items.find(_anchor))
				return true
		Mode.LINK_RELATION:
			match code:
				KEY_1: return _finish_link("contradict")
				KEY_2: return _finish_link("support")
				KEY_3: return _finish_link("none")
				KEY_ESCAPE:
					_enter_mode(Mode.LIST)
					return true
		Mode.INFER_PICK:
			match code:
				KEY_SPACE:
					_toggle_checked(sel)
					return true
				KEY_ENTER, KEY_KP_ENTER:
					return _go_conclude()
				KEY_ESCAPE:
					_checked.clear()
					_enter_mode(Mode.LIST)
					return true
		Mode.CONCLUDE:
			if code == KEY_ENTER or code == KEY_KP_ENTER:
				_confirm_card(sel)
				return true
			if code == KEY_ESCAPE:
				_enter_mode(Mode.INFER_PICK)
				return true
		Mode.CARDS:
			match code:
				KEY_DELETE:
					if sel >= 0 and book.remove_card(int(_items[sel])):
						_enter_mode(Mode.CARDS, sel)
						_msg.text = "추론 카드를 지웠다."
					return true
				KEY_TAB, KEY_ESCAPE:
					_enter_mode(Mode.LIST)
					return true
	return false


# ---------------------------------------------------------------- 믿음/의심

func _set_mark(sel: int, mark: String) -> bool:
	if sel < 0:
		return true
	book.set_mark(String(_items[sel]), mark)
	_enter_mode(Mode.LIST, sel)
	return true


# ---------------------------------------------------------------- 연결

func _begin_link(sel: int) -> bool:
	if sel < 0:
		return true
	if _items.size() < 2:
		_msg.text = "연결하려면 단서가 2개 이상 필요하다."
		return true
	_anchor = String(_items[sel])
	_enter_mode(Mode.LINK_PICK, sel)
	_msg.text = "'%s'와 이어 줄 단서를 고른다." % book.all[_anchor]["source"]
	return true


func _pick_link_target(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var id := String(_items[index])
	if id == _anchor:
		_msg.text = "같은 단서끼리는 연결할 수 없다."
		return
	_target = id
	mode = Mode.LINK_RELATION
	_msg.text = ""
	_update_title()
	_update_hint()
	var cur: String = book.get_relation(_anchor, _target)
	_detail.text = "'%s'\n와(과)\n'%s'\n\n의 관계는?\n\n현재: %s" % [
		book.all[_anchor]["source"], book.all[_target]["source"],
		RELATION_NAMES[cur] if cur != "" else "연결 없음"]


func _finish_link(relation: String) -> bool:
	book.set_link(_anchor, _target, relation)
	var keep: int = _items.find(_anchor)
	_enter_mode(Mode.LIST, keep)
	_msg.text = "연결을 해제했다." if relation == "none" else "연결을 기록했다."
	return true


# ---------------------------------------------------------------- 추론 카드

func _begin_infer() -> bool:
	if _items.size() < book.CARD_MIN:
		_msg.text = "추론 카드를 만들려면 단서가 2개 이상 필요하다."
		return true
	_checked.clear()
	_enter_mode(Mode.INFER_PICK)
	return true


func _toggle_checked(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var id := String(_items[index])
	if _checked.has(id):
		_checked.erase(id)
	elif _checked.size() >= book.CARD_MAX:
		_msg.text = "단서는 최대 %d개까지 고를 수 있다." % book.CARD_MAX
		return
	else:
		_checked.append(id)
	var keep := index
	var saved_msg := _msg.text
	_enter_mode(Mode.INFER_PICK, keep)
	_msg.text = saved_msg


func _go_conclude() -> bool:
	if _checked.size() < book.CARD_MIN:
		_msg.text = "단서를 %d~%d개 골라야 한다." % [book.CARD_MIN, book.CARD_MAX]
		return true
	_enter_mode(Mode.CONCLUDE)
	return true


func _confirm_card(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var ok: bool = book.add_card(_checked, String(_items[index]))
	_checked.clear()
	_enter_mode(Mode.LIST)
	# 결론이 맞는지는 알려 주지 않는다. 보고서에서 평가한다.
	_msg.text = "추론 카드를 만들었다." if ok else "이미 같은 카드가 있다."

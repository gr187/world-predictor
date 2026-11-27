extends CanvasLayer
## 단서 수첩 화면(플레이스홀더). 모은 단서의 종류·출처·시점·내용을 보여 준다.
## 숨은 신뢰도는 보여 주지 않는다.

signal closed

var _clues: Array = []
var _list: ItemList
var _detail: Label


func setup(book) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8
	_clues = book.collected()

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.06, 0.95)
	dim.size = Vector2(480, 270)
	add_child(dim)

	var title := _make_label(Vector2(20, 12), Vector2(440, 22), 14)
	title.text = "단서 수첩   %d / %d" % [book.count(), book.total()]

	_list = ItemList.new()
	_list.position = Vector2(20, 42)
	_list.size = Vector2(190, 196)
	_list.allow_search = false
	_list.add_theme_font_size_override("font_size", 10)
	add_child(_list)

	_detail = _make_label(Vector2(226, 42), Vector2(236, 196), 11)

	var hint := _make_label(Vector2(20, 246), Vector2(440, 18), 10)
	hint.text = "↑ ↓ 선택     Q 닫기"
	hint.modulate = Color(0.6, 0.62, 0.7)

	if _clues.is_empty():
		_list.visible = false
		_detail.text = "아직 모은 단서가 없다.\n\n맵의 노란 표시에 다가가 E 키로 조사할 수 있다."
		return

	for c in _clues:
		_list.add_item("[%s] %s" % [c["type"], c["source"]])
	_list.item_selected.connect(_show_detail)
	_list.select(0)
	_show_detail(0)
	_list.grab_focus()


func _make_label(pos: Vector2, sz: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


func _show_detail(index: int) -> void:
	var c: Dictionary = _clues[index]
	_detail.text = "종류: %s\n출처: %s\n시점: %s\n\n%s" % [
		c["type"], c["source"], c["time"], c["text"]]


func _input(event: InputEvent) -> void:
	var is_close := event.is_action_pressed("notebook")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		is_close = true
	if is_close:
		get_viewport().set_input_as_handled()
		closed.emit()

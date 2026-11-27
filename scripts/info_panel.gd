extends CanvasLayer
## 글을 한 쪽씩 보여 주는 화면. 인트로, 조작 안내 등에 쓴다.
## Enter / Space / 클릭: 다음 쪽(마지막 쪽이면 닫힘)   Esc: 바로 닫기

signal closed

const UiKit := preload("res://scripts/ui_kit.gd")

var pages: Array = []
var index := 0
var _title: Label
var _body: Label
var _count: Label
var _button: Button
var _button_text := "계속"


func setup(title: String, the_pages: Array, button_text: String = "계속") -> void:
	pages = the_pages
	_button_text = button_text
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30

	UiKit.dim(self, Color(0.03, 0.03, 0.05, 0.97))
	_title = UiKit.label(self, title, Vector2(30, 24), Vector2(420, 24), 14)
	_title.modulate = Color(0.95, 0.85, 0.6)
	_body = UiKit.label(self, "", Vector2(40, 64), Vector2(400, 150), 12)
	_count = UiKit.label(self, "", Vector2(30, 240), Vector2(150, 18), 9)
	_count.modulate = Color(0.6, 0.62, 0.7)
	_button = UiKit.button(self, button_text, Vector2(340, 232), Vector2(110, 26), 12, advance)
	_button.focus_mode = Control.FOCUS_NONE
	_show_page()


func _show_page() -> void:
	_body.text = String(pages[index]) if not pages.is_empty() else ""
	_count.text = "%d / %d     Esc 건너뛰기" % [index + 1, pages.size()] if pages.size() > 1 else "Esc 닫기"
	_button.text = _button_text if index >= pages.size() - 1 else "다음"


func advance() -> void:
	if index >= pages.size() - 1:
		closed.emit()
		return
	index += 1
	_show_page()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		advance()

extends CanvasLayer
## 일시정지 메뉴. Esc로 열고 닫는다.

signal resumed
signal to_title
signal quit_game

const UiKit := preload("res://scripts/ui_kit.gd")
const InfoPanel := preload("res://scripts/info_panel.gd")

var _buttons: Array[Button] = []
var _guide: CanvasLayer = null


func setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20

	UiKit.dim(self, Color(0, 0, 0, 0.7))
	var title := UiKit.label(self, "일시정지", Vector2(0, 50), Vector2(480, 30), 20, HORIZONTAL_ALIGNMENT_CENTER)
	title.modulate = Color(0.95, 0.85, 0.6)

	var labels := ["계속하기", "조작 방법", "처음 화면으로", "게임 종료"]
	var actions := [resume, show_controls, func(): to_title.emit(), func(): quit_game.emit()]
	for i in labels.size():
		var b := UiKit.button(self, labels[i], Vector2(180, 100.0 + 32.0 * i), Vector2(120, 26), 12, actions[i])
		_buttons.append(b)
	_buttons[0].grab_focus()
	UiKit.label(self, "진행 상황은 자동으로 저장됩니다.", Vector2(0, 240), Vector2(480, 16), 9, HORIZONTAL_ALIGNMENT_CENTER).modulate = Color(0.6, 0.62, 0.7)


func resume() -> void:
	resumed.emit()


func show_controls() -> void:
	if _guide != null:
		return
	_guide = InfoPanel.new()
	add_child(_guide)
	_guide.setup("조작 방법", [UiKit.CONTROLS_TEXT], "닫기")
	_guide.closed.connect(_close_controls)


func _close_controls() -> void:
	if _guide:
		_guide.queue_free()
		_guide = null
	_buttons[1].grab_focus()


func _input(event: InputEvent) -> void:
	if _guide != null:
		return   # 조작 방법 화면이 Esc를 처리한다
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume()

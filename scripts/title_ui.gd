extends Control
## 타이틀 화면: 시작하기 / 이어하기 / 조작 방법 / 종료.
## 새로 시작하면 짧은 인트로를 보여 준 뒤 세계 1로 들어간다.

const UiKit := preload("res://scripts/ui_kit.gd")
const InfoPanel := preload("res://scripts/info_panel.gd")
const GameState := preload("res://scripts/game_state.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const WORLD_SCENE := "res://scenes/world1.tscn"

var _buttons: Dictionary = {}
var _message: Label
var _overlay: CanvasLayer = null
var _confirm_box: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(480, 270)

	var bg := _Backdrop.new()
	bg.size = Vector2(480, 270)
	add_child(bg)

	var title := UiKit.label(self, "세계 예측기", Vector2(0, 38), Vector2(480, 50), 36, HORIZONTAL_ALIGNMENT_CENTER)
	title.modulate = Color(0.95, 0.88, 0.7)
	var sub := UiKit.label(self, "멸망한 세계를 조사하고, 그 이유를 추론하라", Vector2(0, 92), Vector2(480, 18), 11, HORIZONTAL_ALIGNMENT_CENTER)
	sub.modulate = Color(0.75, 0.75, 0.82)

	var names := ["new", "continue", "controls", "quit"]
	var texts := ["시작하기", "이어하기", "조작 방법", "종료"]
	var actions := [start_new_game, continue_game, show_controls, quit_game]
	for i in names.size():
		var b := UiKit.button(self, texts[i], Vector2(180, 134.0 + 28.0 * i), Vector2(120, 24), 12, actions[i])
		_buttons[names[i]] = b
	_buttons["continue"].disabled = not SaveGame.exists()
	(_buttons["continue"] if not _buttons["continue"].disabled else _buttons["new"]).grab_focus()

	_message = UiKit.label(self, "", Vector2(0, 250), Vector2(480, 14), 9, HORIZONTAL_ALIGNMENT_CENTER)
	_message.modulate = Color(0.95, 0.75, 0.6)
	var ver := UiKit.label(self, "프로토타입", Vector2(400, 254), Vector2(76, 12), 8, HORIZONTAL_ALIGNMENT_RIGHT)
	ver.modulate = Color(0.5, 0.5, 0.58)


# ---------------------------------------------------------------- 동작

func start_new_game() -> void:
	if SaveGame.exists():
		_show_confirm()
	else:
		_begin_new()


## 저장된 진행이 있으면 지워지므로 한 번 더 묻는다.
func _show_confirm() -> void:
	if _confirm_box != null:
		return
	_confirm_box = Control.new()
	_confirm_box.size = Vector2(480, 270)
	add_child(_confirm_box)
	UiKit.dim(_confirm_box, Color(0, 0, 0, 0.8))
	UiKit.label(_confirm_box, "저장된 진행이 있습니다.\n새로 시작하면 지금까지의 진행이 지워집니다.\n계속할까요?", Vector2(60, 90), Vector2(360, 60), 12, HORIZONTAL_ALIGNMENT_CENTER)
	var yes := UiKit.button(_confirm_box, "새로 시작", Vector2(120, 170), Vector2(100, 26), 12, _confirm_yes)
	UiKit.button(_confirm_box, "취소", Vector2(260, 170), Vector2(100, 26), 12, _confirm_no)
	_buttons["confirm_yes"] = yes
	yes.grab_focus()


func _confirm_yes() -> void:
	_close_confirm()
	_begin_new()


func _confirm_no() -> void:
	_close_confirm()
	_buttons["new"].grab_focus()


func _close_confirm() -> void:
	if _confirm_box:
		_confirm_box.queue_free()
		_confirm_box = null
	_buttons.erase("confirm_yes")


func _begin_new() -> void:
	SaveGame.delete()
	GameState.reset()
	_show_overlay("세계 예측기", UiKit.INTRO_PAGES, "시작", _enter_game)


func continue_game() -> void:
	if not SaveGame.exists():
		return
	if SaveGame.load_into_state():
		_enter_game()
	else:
		_message.text = "저장 파일을 읽을 수 없습니다. 새로 시작해 주세요."


func show_controls() -> void:
	_show_overlay("조작 방법", [UiKit.CONTROLS_TEXT], "닫기", Callable())


func quit_game() -> void:
	get_tree().quit()


func _show_overlay(title: String, pages: Array, button_text: String, then: Callable) -> void:
	if _overlay != null:
		return
	_overlay = InfoPanel.new()
	add_child(_overlay)
	_overlay.setup(title, pages, button_text)
	_overlay.closed.connect(_on_overlay_closed.bind(then))


func _on_overlay_closed(then: Callable) -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	if then.is_valid():
		then.call()


## 세계 1로 들어간다. 이때부터 진행 상황이 자동 저장된다.
func _enter_game() -> void:
	SaveGame.autosave_enabled = true
	GameState.pending_guide = not GameState.seen_guide
	SaveGame.save()
	get_tree().change_scene_to_file(WORLD_SCENE)


## 배경: 어두운 하늘, 희미한 해, 폐허가 된 도시의 실루엣. (그래픽 단계에서 그림으로 바꾼다)
class _Backdrop extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.055, 0.075))
		draw_rect(Rect2(0, 120, size.x, 150), Color(0.1, 0.075, 0.07))
		draw_circle(Vector2(370, 150), 34.0, Color(0.34, 0.2, 0.12, 0.55))
		draw_circle(Vector2(370, 150), 22.0, Color(0.5, 0.3, 0.16, 0.6))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var x := -10.0
		while x < size.x + 10.0:
			var w := rng.randf_range(18.0, 44.0)
			var h := rng.randf_range(40.0, 120.0)
			draw_rect(Rect2(x, size.y - h, w, h), Color(0.035, 0.032, 0.045))
			if rng.randf() < 0.5:
				draw_rect(Rect2(x + w * 0.3, size.y - h - 8.0, 3.0, 8.0), Color(0.035, 0.032, 0.045))
			x += w + rng.randf_range(0.0, 6.0)
		draw_rect(Rect2(0, 238, size.x, 32), Color(0.02, 0.02, 0.03))

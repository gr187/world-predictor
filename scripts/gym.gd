extends Node2D
## 장치 시험장. 이동 장치 4종(사다리, 크랭크 승강기, 스파크 구간, 전력 레버·전자문)을 한 곳에서 시험한다.
## 실행: godot --path game scenes/gym.tscn      (R: 새 시뮬레이션 — 이번 판 맵 상태 초기화, 지름길은 유지)

const Kit := preload("res://scripts/level_kit.gd")
const GameState := preload("res://scripts/game_state.gd")

const FLOOR_Y := 240.0
const WORLD_W := 1300

var player: CharacterBody2D
var hint: Label
var toast: Label
var _toast_tween: Tween
var lift: AnimatableBody2D
var power_door: StaticBody2D
var shortcut_door: StaticBody2D
var lever_a: Area2D
var lever_b: Area2D
var shortcut_lever: Area2D


func _ready() -> void:
	GameState.begin_simulation()   # 이번 판 맵 상태를 초기화한다 (지름길은 남는다)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.position = Vector2(-200, -400)
	bg.size = Vector2(WORLD_W + 400, 900)
	bg.z_index = -10
	add_child(bg)

	# --- 바닥과 벽 ---
	Kit.platform(self, Rect2(0, FLOOR_Y, WORLD_W, 30))
	Kit.platform(self, Rect2(-20, -300, 20, 600))
	Kit.platform(self, Rect2(WORLD_W, -300, 20, 600))

	# --- 1. 사다리: 점프로는 못 오르는 높이 ---
	Kit.platform(self, Rect2(138, 160, 122, 10))      # 낮은 턱 (표면 y=160)
	Kit.ladder(self, 130, 160, FLOOR_Y)               # 바닥 → 낮은 턱
	Kit.platform(self, Rect2(262, 80, 110, 10))       # 높은 턱 (표면 y=80)
	Kit.ladder(self, 252, 80, 160)                    # 낮은 턱 → 높은 턱
	lever_b = Kit.lever(self, Vector2(330, 80 - 15), "lever_b")

	# --- 2. 크랭크 승강기: 높은 턱으로 가는 다른 길 ---
	lift = Kit.lift(self, 420, 110, FLOOR_Y - 2)
	Kit.platform(self, Rect2(446, 110, 150, 10))      # 승강기 위쪽 턱 (표면 y=110)
	lever_a = Kit.lever(self, Vector2(540, 110 - 15), "lever_a")

	# --- 3. 스파크 구간: 방전 타이밍 ---
	Kit.sparks(self, Vector2(680, FLOOR_Y - 28), Vector2(40, 28), 0.0)
	Kit.sparks(self, Vector2(770, FLOOR_Y - 28), Vector2(40, 28), 0.9)
	Kit.sparks(self, Vector2(860, FLOOR_Y - 28), Vector2(40, 28), 1.8)

	# --- 4. 전력 문과 지름길 문 ---
	power_door = Kit.door(self, Rect2(960, FLOOR_Y - 70, 14, 70), "power", "전력 필요")
	shortcut_lever = Kit.lever(self, Vector2(1030, FLOOR_Y - 15), "gym_shortcut", true, false)
	shortcut_door = Kit.door(self, Rect2(1100, FLOOR_Y - 70, 14, 70), "gym_shortcut", "잠김")

	var goal := ColorRect.new()
	goal.color = Color(0.35, 0.8, 0.9)
	goal.size = Vector2(14, 22)
	goal.position = Vector2(1200, FLOOR_Y - 22)
	add_child(goal)

	player = Kit.player(self, Vector2(40, FLOOR_Y - 12))
	player.shocked.connect(func(): _show_toast("방전! 마지막 안전한 곳으로 밀려났다."))
	Kit.camera(player, 0, WORLD_W, -100, int(FLOOR_Y) + 30)

	for node in [lever_a, lever_b, shortcut_lever, lift]:
		node.message.connect(_show_toast)

	hint = Label.new()
	hint.position = Vector2(8, 6)
	hint.add_theme_font_size_override("font_size", 9)
	toast = Label.new()
	toast.position = Vector2(40, 40)
	toast.size = Vector2(400, 20)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 11)
	toast.modulate.a = 0.0
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	layer.add_child(toast)
	add_child(layer)


func _process(_delta: float) -> void:
	hint.text = "A/D 이동  Space 점프  W/S 사다리  E 조작  R 새 판\n전력 %d / %d   지름길 %s" % [
		GameState.power_levers_on(), GameState.POWER_LEVERS_REQUIRED,
		"열림" if GameState.has_flag("gym_shortcut") else "잠김"]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _show_toast(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)

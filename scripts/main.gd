extends Node2D
## 프로토타입 테스트 레벨. 도형만으로 이동·점프·카메라·전투를 확인한다.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const BattleUI := preload("res://scripts/battle_ui.gd")

const LEVEL_WIDTH := 1800
const FLOOR_Y := 240

var player: CharacterBody2D
var enemies_data: Dictionary = {}
var clue_level := 0   ## 테스트용: F1로 전환. 나중에는 단서 수첩에서 계산한다.
var hint: Label


func _ready() -> void:
	enemies_data = _load_enemies()

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.position = Vector2(-200, -400)
	bg.size = Vector2(LEVEL_WIDTH + 400, 900)
	bg.z_index = -10
	add_child(bg)

	# 바닥과 발판들
	_platform(Rect2(0, FLOOR_Y, 600, 30))
	_platform(Rect2(600, FLOOR_Y, 300, 30), "wet")    # 젖은 바닥 (미끄러움 확인용)
	_platform(Rect2(900, FLOOR_Y, 300, 30), "mud")    # 진흙 바닥 (느려짐 확인용)
	_platform(Rect2(1200, FLOOR_Y, LEVEL_WIDTH - 1200, 30))
	_platform(Rect2(220, 190, 70, 10))
	_platform(Rect2(340, 150, 70, 10))
	_platform(Rect2(480, 190, 90, 10))
	_platform(Rect2(700, 170, 60, 10))
	_platform(Rect2(820, 130, 60, 10))
	_platform(Rect2(980, 200, 120, 10))
	_platform(Rect2(1200, 160, 80, 10))
	_platform(Rect2(1340, 110, 80, 10))
	_platform(Rect2(1500, 180, 120, 10))
	# 양쪽 끝 벽
	_platform(Rect2(-20, -200, 20, 500))
	_platform(Rect2(LEVEL_WIDTH, -200, 20, 500))

	player = CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.position = Vector2(40, FLOOR_Y - 12)
	player.add_to_group("player")
	add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0
	cam.limit_right = LEVEL_WIDTH
	cam.limit_bottom = FLOOR_Y + 30
	cam.limit_top = -200
	player.add_child(cam)

	_spawn_enemy("guard_robot", 330, 260, 440)
	_spawn_enemy("guard_robot", 1300, 1250, 1450)

	hint = Label.new()
	hint.position = Vector2(8, 6)
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	add_child(layer)
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	# 테스트용: 단서 단계 전환 (0=모호한 징후, 1=구체적인 징후)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		clue_level = 1 - clue_level
		_update_hint()


func _update_hint() -> void:
	hint.text = "A/D 이동   Space 점프   적에게 닿으면 전투   [F1] 단서 단계: %d" % clue_level


func _load_enemies() -> Dictionary:
	var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if f == null:
		push_error("enemies.json을 열 수 없습니다")
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _spawn_enemy(id: String, x: float, pmin: float, pmax: float) -> void:
	var e := EnemyScript.new()
	e.enemy_id = id
	e.position = Vector2(x, FLOOR_Y - 10)
	e.patrol_min = pmin
	e.patrol_max = pmax
	e.touched.connect(_on_enemy_touched)
	add_child(e)


func _on_enemy_touched(enemy: Area2D) -> void:
	var data: Dictionary = enemies_data.get(enemy.enemy_id, {})
	if data.is_empty():
		return
	var ui := BattleUI.new()
	ui.name = "BattleUI"
	add_child(ui)
	ui.setup(data, clue_level)
	ui.finished.connect(_on_battle_finished.bind(enemy, ui))
	get_tree().paused = true


func _on_battle_finished(won: bool, enemy: Area2D, ui: CanvasLayer) -> void:
	ui.queue_free()
	get_tree().paused = false
	if won:
		enemy.queue_free()   # 임시: 이긴 적은 사라진다 (스토리 확정 후 변경)
	else:
		get_tree().reload_current_scene()   # 임시: 현실 귀환 대신 시뮬레이션 재시작


func _platform(rect: Rect2, surface := "normal") -> void:
	var body := StaticBody2D.new()
	if surface != "normal":
		body.set_meta("surface", surface)
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.size / 2.0
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.size = rect.size
	vis.color = Color(0.22, 0.24, 0.3)
	if surface == "wet":
		vis.color = Color(0.2, 0.3, 0.45)
	elif surface == "mud":
		vis.color = Color(0.32, 0.25, 0.18)
	body.add_child(vis)
	add_child(body)

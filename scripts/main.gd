extends Node2D
## 프로토타입 테스트 레벨. 도형만으로 이동·점프·카메라·전투를 확인한다.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const BattleUI := preload("res://scripts/battle_ui.gd")
const PointScript := preload("res://scripts/investigation_point.gd")
const NotebookUI := preload("res://scripts/notebook_ui.gd")
const GameState := preload("res://scripts/game_state.gd")
const ReportUI := preload("res://scripts/report_ui.gd")
const ReturnPoint := preload("res://scripts/return_point.gd")
const ReportLogic := preload("res://scripts/report_logic.gd")

const LEVEL_WIDTH := 1800
const FLOOR_Y := 240

var player: CharacterBody2D
var enemies_data: Dictionary = {}
var clue_level := 0   ## 임시: F1로 전환. 단서와의 연결 규칙은 나중에 확정한다.
var hint: Label
var toast: Label
var _toast_tween: Tween
var _notebook: CanvasLayer
var _report: CanvasLayer


func _ready() -> void:
	GameState.begin_simulation()   # 보고에서 받은 보급품을 이번 시뮬레이션에 적용
	enemies_data = _load_enemies()
	_build_level()
	_build_hud()


## 레벨(바닥, 플레이어, 카메라, 적, 조사 지점, 귀환 장치)을 만든다.
## 기본은 일렬 테스트 맵이고, 실제 세계 맵은 이 함수를 바꿔서 쓴다. (world1_main.gd)
func _build_level() -> void:
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

	# 귀환 장치: 맵 끝에서 시뮬레이션을 마치고 보고하러 돌아간다.
	var ret := ReturnPoint.new()
	ret.position = Vector2(1765, FLOOR_Y - 12)
	ret.activated.connect(_open_report.bind("return"))
	add_child(ret)

	# 테스트용 조사 지점: 단서 16개를 맵에 일렬로 배치한다. (실제 세계 1 구역 배치는 레벨 단계에서)
	var ids: Array = GameState.get_book().all.keys()
	for i in ids.size():
		_spawn_point([ids[i]], 100.0 + 105.0 * i)


## 화면 표시(안내 문구, 알림)를 만든다.
func _build_hud() -> void:
	hint = Label.new()
	hint.position = Vector2(8, 6)
	hint.add_theme_font_size_override("font_size", 10)
	toast = Label.new()
	toast.position = Vector2(40, 30)
	toast.size = Vector2(400, 20)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 11)
	toast.modulate.a = 0.0
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	layer.add_child(toast)
	add_child(layer)
	_update_hint()


func _unhandled_input(event: InputEvent) -> void:
	# 임시: 전투 징후 단계 전환 (0=모호한 징후, 1=구체적인 징후)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		clue_level = 1 - clue_level
		_update_hint()
	elif event.is_action_pressed("notebook") and not get_tree().paused:
		_open_notebook()


func _update_hint() -> void:
	hint.text = "A/D 이동  Space 점프  E 조사  Q 수첩  [F1] 징후 단계(임시): %d" % clue_level
	if not GameState.active_supplies.is_empty():
		var rl := ReportLogic.new()
		var names: Array = []
		for id in GameState.active_supplies:
			names.append(rl.supply_name(id))
		hint.text += "\n보급품: " + ", ".join(names)


func _spawn_point(ids: Array, x: float) -> void:
	_spawn_point_at(ids, Vector2(x, FLOOR_Y - 8))


func _spawn_point_at(ids: Array, pos: Vector2) -> Area2D:
	var p := PointScript.new()
	p.clue_ids = ids
	p.position = pos
	p.investigated.connect(_on_investigated)
	add_child(p)
	return p


## 맵 로더가 쓰는 배치 함수들 (위치는 중심 좌표)
func _spawn_enemy_at(id: String, pos: Vector2, half_range: float) -> Area2D:
	var e := EnemyScript.new()
	e.enemy_id = id
	e.position = pos
	e.patrol_min = pos.x - half_range
	e.patrol_max = pos.x + half_range
	e.touched.connect(_on_enemy_touched)
	add_child(e)
	return e


func _spawn_return_at(pos: Vector2) -> Area2D:
	var ret := ReturnPoint.new()
	ret.position = pos
	ret.activated.connect(_open_report.bind("return"))
	add_child(ret)
	return ret


func _on_investigated(new_ids: Array) -> void:
	var book = GameState.get_book()
	var names: Array = []
	for id in new_ids:
		names.append(book.all[id]["source"])
	_show_toast("단서 획득: %s   (%d/%d)" % [", ".join(names), book.count(), book.total()])


func _show_toast(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)


func _open_notebook() -> void:
	_notebook = NotebookUI.new()
	_notebook.name = "Notebook"
	add_child(_notebook)
	_notebook.setup(GameState.get_book())
	_notebook.closed.connect(_close_notebook)
	get_tree().paused = true


func _close_notebook() -> void:
	if _notebook:
		_notebook.queue_free()
		_notebook = null
	get_tree().paused = false


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
	ui.setup(data, clue_level, GameState.active_supplies)
	ui.finished.connect(_on_battle_finished.bind(enemy, ui))
	get_tree().paused = true


func _on_battle_finished(won: bool, enemy: Area2D, ui: CanvasLayer) -> void:
	ui.queue_free()
	get_tree().paused = false
	if won:
		enemy.queue_free()   # 임시: 이긴 적은 사라진다 (스토리 확정 후 변경)
	else:
		_open_report("defeat")   # 강제 종료되어 현실로 돌아와 보고한다


## 현실로 돌아와 상사에게 보고한다. 끝나면 새 시뮬레이션을 시작한다.
func _open_report(reason: String) -> void:
	if _report != null or get_tree().paused:
		return
	_report = ReportUI.new()
	_report.name = "ReportUI"
	add_child(_report)
	_report.setup(GameState.get_book(), reason)
	_report.finished.connect(_on_report_finished)
	get_tree().paused = true


func _on_report_finished() -> void:
	if _report:
		_report.queue_free()
		_report = null
	get_tree().paused = false
	get_tree().reload_current_scene()   # 단서·보급품은 GameState에 남아 있다


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

extends SceneTree
## 이동 장치 4종(사다리, 크랭크 승강기, 스파크 구간, 전력 레버·전자문) 테스트:
## godot --headless --path game -s tests/test_mechanics.gd

const GameState := preload("res://scripts/game_state.gd")
const Kit := preload("res://scripts/level_kit.gd")
const SparkScript := preload("res://scripts/spark_zone.gd")

var fails := 0
var done := false
var gym
var player: CharacterBody2D
var shocks := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("통과 " if ok else "실패 "), name, "  ", detail)
	if not ok:
		fails += 1


func _init() -> void:
	await _run()
	check("끝까지 실행됨", done)
	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)


# ---------------------------------------------------------------- 도우미

func frames(n: int) -> void:
	for i in n:
		await physics_frame


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)


func hold(action: String, n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)


## 플레이어를 옮긴다. set_safe가 true면 그 자리를 '마지막 안전한 위치'로도 기록한다.
func teleport(pos: Vector2, set_safe: bool = true) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	if set_safe:
		player.last_safe_pos = pos
	await frames(4)


func feet() -> float:
	return player.global_position.y + 11.0


func load_gym() -> void:
	var old = current_scene
	if old != null:
		reload_current_scene()
		var waited := 0
		while (current_scene == null or current_scene == old) and waited < 40:
			await physics_frame
			waited += 1
		await frames(3)
	else:
		var g = load("res://scenes/gym.tscn").instantiate()
		root.add_child(g)
		current_scene = g
		await frames(3)
	gym = current_scene
	player = gym.player
	shocks = 0
	player.shocked.connect(func(): shocks += 1)


# ---------------------------------------------------------------- 테스트

func _run() -> void:
	GameState.reset()
	await load_gym()

	await _test_ladder()
	await _test_lift()
	await _test_sparks()
	await _test_power()
	await _test_persistence()
	done = true


func _test_ladder() -> void:
	# 사다리 1: 바닥(240) → 낮은 턱(160), x=130
	await teleport(Vector2(130, 229))
	check("사다리 근처에서 W를 누르기 전엔 타지 않음", not player.climbing)
	Input.action_press("climb_up")
	await frames(10)
	check("W를 누르면 사다리를 타기 시작", player.climbing)
	check("위로 올라감", feet() < 238.0, "feet=%.1f" % feet())
	var n := 0
	while player.climbing and n < 300:
		await physics_frame
		n += 1
	Input.action_release("climb_up")
	await frames(4)
	check("맨 위에 도착하면 사다리에서 내려 꼭대기에 섬", not player.climbing and absf(feet() - 160.0) < 2.0 and player.is_on_floor(), "feet=%.1f" % feet())

	Input.action_press("climb_up")
	await frames(8)
	Input.action_release("climb_up")
	check("꼭대기에서 W를 눌러도 더 오르지 않음", not player.climbing and absf(feet() - 160.0) < 2.0)

	# 꼭대기에서 아래로 내려가기 (한쪽 방향 발판 통과)
	Input.action_press("climb_down")
	await frames(10)
	check("꼭대기에서 S를 누르면 발판을 통과해 내려가기 시작", player.climbing and feet() > 162.0, "feet=%.1f" % feet())
	n = 0
	while player.climbing and n < 300:
		await physics_frame
		n += 1
	Input.action_release("climb_down")
	await frames(4)
	check("맨 아래에 도착하면 바닥에 섬", not player.climbing and absf(feet() - 240.0) < 2.0 and player.is_on_floor(), "feet=%.1f" % feet())

	# 점프로 뛰어내리기
	Input.action_press("climb_up")
	await frames(20)
	Input.action_release("climb_up")
	var was_climbing: bool = player.climbing
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check("사다리 위에서 점프하면 뛰어내림", was_climbing and not player.climbing and player.velocity.y < 0.0)
	await frames(60)

	# 사다리가 없는 곳
	await teleport(Vector2(300, 229))
	await hold("climb_up", 15)
	check("사다리가 없는 곳에서는 W를 눌러도 타지 않음", not player.climbing)

	# 사다리 2: 낮은 턱(160) → 높은 턱(80), 그리고 높은 턱 위를 걸을 수 있다
	await teleport(Vector2(252, 149))
	Input.action_press("climb_up")
	n = 0
	await frames(5)
	while player.climbing and n < 300:
		await physics_frame
		n += 1
	Input.action_release("climb_up")
	await frames(4)
	check("두 번째 사다리로 높은 턱(표면 80)에 오름", absf(feet() - 80.0) < 2.0 and player.is_on_floor(), "feet=%.1f" % feet())
	await hold("move_right", 40)
	check("높은 턱 위를 걸어서 레버 쪽으로 갈 수 있음", player.global_position.x > 290.0 and absf(feet() - 80.0) < 2.0, "x=%.1f" % player.global_position.x)


func _test_lift() -> void:
	var lift = gym.lift
	await teleport(Vector2(420, 238.0 - 12.0))
	check("승강기 발판 위에서 조작 가능", lift._inside)
	check("승강기는 처음엔 정지, 아래쪽", not lift.is_moving() and absf(lift.position.y - 238.0) < 0.5)
	await press("interact")
	check("E를 누르면 승강기가 움직이기 시작", lift.is_moving())
	await frames(20)
	check("올라가는 중", lift.position.y < 237.0, "y=%.1f" % lift.position.y)
	check("승강기에 탄 플레이어도 함께 올라감", player.global_position.y < 226.0 and player.is_on_floor(), "y=%.1f" % player.global_position.y)

	await press("interact")
	var stopped_y: float = lift.position.y
	await frames(10)
	check("움직이는 중에 E를 누르면 정지", not lift.is_moving() and absf(lift.position.y - stopped_y) < 0.5)

	await press("interact")
	await frames(20)
	check("정지 후 E를 누르면 반대 방향(아래)으로 감", lift.position.y > stopped_y, "%.1f → %.1f" % [stopped_y, lift.position.y])

	# 아래쪽 끝까지 내려가 멈춘 뒤, 다시 E를 누르면 위쪽 끝까지 올라간다
	var n := 0
	while lift.is_moving() and n < 400:
		await physics_frame
		n += 1
	check("아래쪽 끝(표면 238)에서 자동으로 멈춤", absf(lift.position.y - 238.0) < 0.5 and not lift.is_moving(), "y=%.1f" % lift.position.y)
	await press("interact")
	n = 0
	while lift.is_moving() and n < 400:
		await physics_frame
		n += 1
	check("위쪽 끝(표면 110)까지 올라가면 자동으로 멈춤", absf(lift.position.y - 110.0) < 0.5 and not lift.is_moving(), "y=%.1f" % lift.position.y)
	check("플레이어가 위쪽 턱 높이에 있음", absf(feet() - 110.0) < 3.0, "feet=%.1f" % feet())
	await hold("move_right", 25)
	check("위쪽 턱으로 걸어서 내릴 수 있음", player.global_position.x > 446.0 and absf(feet() - 110.0) < 2.0, "x=%.1f" % player.global_position.x)

	# 전력이 필요한 승강기(케이블카)
	GameState.run_flags = {}
	var powered = Kit.lift(gym, 1250, 150, 238, true)
	var msgs: Array = []
	powered.message.connect(func(t): msgs.append(t))
	await teleport(Vector2(1250, 226))
	await press("interact")
	check("전력이 없으면 전력 승강기는 움직이지 않음", not powered.is_moving() and msgs.size() == 1)
	GameState.set_flag("lever_a")
	GameState.set_flag("lever_b")
	await press("interact")
	check("전력이 복구되면 전력 승강기가 움직임", powered.is_moving())
	GameState.run_flags = {}
	powered.queue_free()


func _test_sparks() -> void:
	var zone = get_nodes_in_group("spark_zone")[0]
	check("스파크 구간 3개", get_nodes_in_group("spark_zone").size() == 3)
	check("주기: 대기 → 경고 → 방전",
		_state_at(zone, 0.5) == SparkScript.State.IDLE and _state_at(zone, 1.6) == SparkScript.State.WARN and _state_at(zone, 2.2) == SparkScript.State.ACTIVE)

	await teleport(Vector2(650, 229))
	zone.force_state(SparkScript.State.IDLE)
	await teleport(Vector2(700, 229), false)   # 안전한 위치는 구간 앞(650)으로 남겨 둔다
	zone.force_state(SparkScript.State.IDLE)
	await frames(8)
	check("대기 중에는 지나가도 안전", shocks == 0 and player.stunned == 0.0 and player.hazard_count == 1)
	check("구간 안에서는 안전한 위치를 갱신하지 않음", absf(player.last_safe_pos.x - 650.0) < 1.0, "safe=%.1f" % player.last_safe_pos.x)
	zone.force_state(SparkScript.State.WARN)
	await frames(8)
	check("경고(번쩍임) 중에도 아직 안전", shocks == 0)
	zone.force_state(SparkScript.State.ACTIVE)
	await frames(3)
	check("방전 중에 닿으면 피격", shocks == 1 and player.stunned > 0.0)
	check("마지막 안전한 위치(구간 앞)로 밀려남", player.global_position.x < 680.0 and absf(player.global_position.x - 650.0) < 2.0, "x=%.1f" % player.global_position.x)
	await frames(4)   # 구간을 벗어났다는 신호가 도착할 시간
	check("피격 후에는 구간 밖이라 hazard_count 0", player.hazard_count == 0)
	Input.action_press("move_right")
	await frames(10)
	check("피격 직후에는 움직일 수 없음", absf(player.global_position.x - 650.0) < 3.0)
	Input.action_release("move_right")
	await frames(70)
	check("경직이 풀림", player.stunned == 0.0)

	# 연속 피격 방지: 경직 중에는 다시 맞지 않는다
	await teleport(Vector2(650, 229))
	await teleport(Vector2(700, 229), false)
	var before := shocks
	zone.force_state(SparkScript.State.ACTIVE)
	await frames(30)
	check("방전이 이어지는 동안에도 피격은 한 번만 처리", shocks == before + 1, "피격 %d회" % (shocks - before))

	# 주기가 흐르면 방전이 반복된다
	zone.cycle_time = 0.0
	var states := {}
	for i in 170:
		await physics_frame
		states[zone.get_state()] = true
	check("시간이 흐르면 세 상태를 모두 거침", states.size() == 3)


func _state_at(zone, t: float) -> int:
	var old: float = zone.cycle_time
	zone.cycle_time = t
	var s: int = zone.get_state()
	zone.cycle_time = old
	return s


func _test_power() -> void:
	await load_gym()
	GameState.reset()
	await load_gym()
	check("처음엔 전력 0/2, 전자문 닫힘", GameState.power_levers_on() == 0 and not gym.power_door.is_open())

	# 닫힌 문에 막힌다
	await teleport(Vector2(930, 229))
	await hold("move_right", 70)
	check("닫힌 전자문은 지나갈 수 없음", player.global_position.x < 960.0, "x=%.1f" % player.global_position.x)

	# 레버 A (승강기 위쪽 턱)
	await teleport(Vector2(540, 98))
	await press("interact")
	check("레버 A를 올리면 전력 1/2", GameState.has_flag("lever_a") and GameState.power_levers_on() == 1 and not GameState.power_on())
	check("전력이 부족하면 문은 닫힌 채", not gym.power_door.is_open())
	await press("interact")
	check("이미 올린 레버는 다시 올라가지 않음", GameState.power_levers_on() == 1 and gym.toast.text.contains("이미"))

	# 레버 B (사다리로 오른 높은 턱)
	await teleport(Vector2(330, 69))
	await press("interact")
	check("레버 B까지 올리면 전력 복구", GameState.power_on() and gym.toast.text.contains("전력이 복구"))
	await frames(4)
	check("전력이 복구되면 전자문이 열림", gym.power_door.is_open() and gym.power_door._shape.disabled)

	await teleport(Vector2(930, 229))
	await hold("move_right", 70)
	check("열린 전자문은 지나갈 수 있음", player.global_position.x > 980.0, "x=%.1f" % player.global_position.x)

	# 레버 범위 밖에서는 동작하지 않음
	GameState.run_flags = {}
	await teleport(Vector2(100, 229))
	await press("interact")
	check("레버에서 먼 곳에서 E를 눌러도 아무 일 없음", GameState.power_levers_on() == 0)


func _test_persistence() -> void:
	GameState.reset()
	await load_gym()
	check("처음엔 지름길 문 닫힘", not gym.shortcut_door.is_open())

	# 전력 레버(이번 판)와 지름길 레버(영구) 모두 올린다
	await teleport(Vector2(540, 98))
	await press("interact")
	await teleport(Vector2(330, 69))
	await press("interact")
	await teleport(Vector2(1030, 229))
	await press("interact")
	await frames(4)
	check("지름길 레버를 올리면 영구 상태로 저장", GameState.permanent_flags.has("gym_shortcut") and not GameState.run_flags.has("gym_shortcut"))
	check("지름길 문이 열림", gym.shortcut_door.is_open())
	check("지름길 안내 문구", gym.toast.text.contains("지름길"))
	check("전력도 복구됨", GameState.power_on() and gym.power_door.is_open())

	# 새 시뮬레이션(죽은 뒤 재시작과 같은 경로): 전력은 초기화되고 지름길은 유지된다
	await load_gym()
	check("새 판: 전력 레버 초기화", GameState.power_levers_on() == 0 and not GameState.power_on())
	check("새 판: 전자문 다시 닫힘", not gym.power_door.is_open())
	check("새 판: 지름길은 유지되어 문이 열려 있음", GameState.has_flag("gym_shortcut") and gym.shortcut_door.is_open())
	check("새 판: 레버 손잡이 상태도 반영", not gym.lever_a.is_pulled() and gym.shortcut_lever.is_pulled())

	# 새 게임(전체 초기화)
	GameState.reset()
	check("전체 초기화하면 지름길도 사라짐", not GameState.has_flag("gym_shortcut"))

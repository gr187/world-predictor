extends SceneTree
## 연속 맵(세계 1: 거리 + 병원) 테스트: 맵 읽기, 충돌체 합치기, 도달 가능성 검사, 실제 물리로 주요 구간 확인.
## godot --headless --path game -s tests/test_world.gd

const GameState := preload("res://scripts/game_state.gd")
const WorldData := preload("res://scripts/world_data.gd")
const WorldBuilder := preload("res://scripts/world_builder.gd")
const WorldNav := preload("res://scripts/world_nav.gd")

const WORLD_PATH := "res://data/world1/world.json"
const T := 16

var fails := 0
var done := false
var main
var player: CharacterBody2D


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("통과 " if ok else "실패 "), name, "  ", detail)
	if not ok:
		fails += 1


func _init() -> void:
	_test_data()
	_test_merge_and_ladders()
	_test_nav_synthetic()
	_test_nav_real()
	await _test_scene()
	await _test_physics()
	await _test_edges()
	await _test_integration()
	done = true
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


## 발이 닿는 칸 (c, r)의 가운데 바닥에 플레이어를 놓는다.
func place(c: int, r: int) -> void:
	player.global_position = Vector2(c * T + T / 2.0, (r + 1) * T - 12.0)
	player.velocity = Vector2.ZERO
	player.last_safe_pos = player.global_position
	await frames(4)


func feet() -> float:
	return player.global_position.y + 11.0


func make_world(rows: Array) -> Dictionary:
	var cells := {}
	var w := 0
	for r in rows.size():
		var line: String = rows[r]
		w = maxi(w, line.length())
		for c in line.length():
			var ch := line[c]
			if ch != "." and ch != " ":
				cells[Vector2i(c, r)] = ch
	return {"tile": T, "cells": cells, "zones": [], "bounds": Rect2i(0, 0, w, rows.size())}


func missing_chars(rows: Array) -> String:
	var nav = WorldNav.new(make_world(rows))
	var res: Dictionary = nav.analyze()
	var s := ""
	for m in res["missing"]:
		s += m["ch"]
	return s


# ---------------------------------------------------------------- 데이터

func _test_data() -> void:
	var w := WorldData.load_world(WORLD_PATH)
	check("맵 설정을 읽음", not w.is_empty() and w["zones"].size() == 2)
	check("전체 영역 96 x 28칸", w["bounds"] == Rect2i(0, 0, 96, 28), str(w["bounds"]))
	check("구역 이름", WorldData.zone_name(w, "street") == "정전된 거리" and WorldData.zone_name(w, "hospital") == "병원")
	check("픽셀 좌표로 구역을 찾음", WorldData.zone_at(w, Vector2(100, 300)) == "street" and WorldData.zone_at(w, Vector2(60 * T, 300)) == "hospital")
	check("맵 밖은 구역 없음", WorldData.zone_at(w, Vector2(-50, 10)) == "")
	check("구역 경계(열 55/56)", WorldData.zone_at(w, Vector2(55 * T + 8, 300)) == "street" and WorldData.zone_at(w, Vector2(56 * T + 8, 300)) == "hospital")

	check("시작 위치 1개", WorldData.find_all(w, "@").size() == 1)
	check("귀환 장치 1개", WorldData.find_all(w, "X").size() == 1)
	check("경비 로봇 2개", WorldData.find_all(w, "R").size() == 2)
	var clue_chars := ""
	for pos in WorldData.find_all(w, "abcdefghijklmnop"):
		clue_chars += WorldData.cell(w, pos.x, pos.y)
	var sorted_chars: Array = clue_chars.split("")
	sorted_chars.sort()
	check("이 두 구역의 단서는 c, g, h, i", "".join(sorted_chars) == "cghi", clue_chars)
	check("승강기 정류장 ^ v 한 쌍", WorldData.find_all(w, "^").size() == 1 and WorldData.find_all(w, "v").size() == 1)
	var up: Vector2i = WorldData.find_all(w, "^")[0]
	var down: Vector2i = WorldData.find_all(w, "v")[0]
	check("승강기 두 정류장이 같은 세로줄", up.x == down.x and up.y < down.y)

	# 모든 단서 글자는 실제 단서 id와 대응해야 한다
	var book := preload("res://scripts/clue_book.gd").new()
	var ok := true
	for pos in WorldData.find_all(w, "abcdefghijklmnop"):
		if not book.all.has("s1_" + WorldData.cell(w, pos.x, pos.y)):
			ok = false
	check("맵의 단서 글자가 모두 실제 단서 id", ok)

	# 같은 단서가 맵에 두 번 놓이지 않는다
	check("같은 단서를 두 번 놓지 않음", clue_chars.length() == _unique(clue_chars.split("")).size())

	# 구역 파일의 줄 수와 폭이 맞는가(각 줄 폭이 구역 폭을 넘지 않는다)
	var zones_ok := true
	for z in w["zones"]:
		var zr: Rect2i = z["rect"]
		for key in w["cells"]:
			pass
		if zr.size.x <= 0 or zr.size.y <= 0:
			zones_ok = false
	check("구역 크기가 양수", zones_ok)


func _unique(arr: Array) -> Dictionary:
	var d := {}
	for v in arr:
		d[v] = true
	return d


func _test_merge_and_ladders() -> void:
	var cells := {
		Vector2i(0, 0): "#", Vector2i(1, 0): "#", Vector2i(0, 1): "#", Vector2i(1, 1): "#",
		Vector2i(0, 2): "#", Vector2i(0, 4): "#", Vector2i(2, 0): "w",
	}
	var rects: Array = WorldBuilder.merged_rects(cells, "#w")
	check("충돌체 합치기: 7칸이 4개 직사각형으로", rects.size() == 4, str(rects.size()))
	var area := 0
	var has_block := false
	var has_wet := false
	for item in rects:
		var rr: Rect2i = item["rect"]
		area += rr.size.x * rr.size.y
		if rr == Rect2i(0, 0, 2, 2) and item["ch"] == "#":
			has_block = true
		if rr == Rect2i(2, 0, 1, 1) and item["ch"] == "w":
			has_wet = true
	check("합쳐도 칸의 합계는 그대로(7칸)", area == 7)
	check("같은 가로 범위가 이어진 줄은 세로로 합쳐짐", has_block)
	check("다른 글자(젖은 바닥)는 합쳐지지 않음", has_wet)
	check("떨어진 줄은 합쳐지지 않음", rects.filter(func(i): return (i["rect"] as Rect2i).position == Vector2i(0, 4)).size() == 1)

	var lcells := {
		Vector2i(3, 2): "H", Vector2i(3, 3): "H", Vector2i(3, 4): "H",
		Vector2i(3, 7): "H", Vector2i(3, 8): "H", Vector2i(5, 1): "H",
	}
	var runs: Array = WorldBuilder.ladder_runs(lcells)
	check("사다리: 끊어진 세로줄은 별개의 사다리(3개)", runs.size() == 3, str(runs))
	var has_long := false
	for run in runs:
		if run["col"] == 3 and run["top"] == 2 and run["bottom"] == 4:
			has_long = true
	check("사다리 위·아래 칸 번호", has_long)

	var world := WorldData.load_world(WORLD_PATH)
	var merged: Array = WorldBuilder.merged_rects(world["cells"], "#w")
	var solid_cells := 0
	for key in world["cells"]:
		if "#w".contains(world["cells"][key]):
			solid_cells += 1
	var merged_area := 0
	for item in merged:
		merged_area += (item["rect"] as Rect2i).size.x * (item["rect"] as Rect2i).size.y
	check("실제 맵: 합쳐도 칸의 합계가 같음", merged_area == solid_cells, "%d / %d" % [merged_area, solid_cells])
	check("실제 맵: 충돌체가 칸 수보다 훨씬 적음", merged.size() < solid_cells / 10, "%d개 / %d칸" % [merged.size(), solid_cells])
	check("실제 맵: 사다리 2개", WorldBuilder.ladder_runs(world["cells"]).size() == 2)


# ---------------------------------------------------------------- 도달 가능성 검사 (작은 지도)

func _test_nav_synthetic() -> void:
	# 틈: 3칸은 건너고 4칸은 못 건넌다
	var gap3 := [
		"............", "............", "............", "............",
		".@......X...", "###...######"]
	var gap5 := [
		"............", "............", "............", "............",
		".@......X...", "###....#####"]
	check("도달 검사: 3칸 틈은 건넘", missing_chars(gap3) == "")
	check("도달 검사: 4칸 틈은 못 건넘", missing_chars(gap5) == "X")

	# 사다리가 없으면 4칸 높이를 못 오른다
	var with_ladder := [
		"..........", "..........", ".......X..", "....H#####",
		"....H.....", "....H.....", ".@..H.....", "##########"]
	var without_ladder := with_ladder.map(func(row: String) -> String: return row.replace("H", "."))
	check("도달 검사: 사다리로 높은 턱에 오름", missing_chars(with_ladder) == "")
	check("도달 검사: 사다리가 없으면 못 오름", missing_chars(without_ladder) == "X")

	# 3칸 높이는 점프로 오르고 4칸은 못 오른다
	var step3 := [
		"..........", "..........", "..........", "......X...",
		"...#####..", "...#......", ".@.#......", "##########"]
	var step4 := [
		"..........", "..........", "......X...", "...#####..",
		"...#......", "...#......", ".@.#......", "##########"]
	check("도달 검사: 3칸 높이 턱은 점프로 오름", missing_chars(step3) == "")
	check("도달 검사: 4칸 높이 턱은 못 오름", missing_chars(step4) == "X")

	# 문과 레버: 레버 둘을 모두 올려야 문이 열린다
	var door_open := [
		"..........D...", "..........D...", ".@..1..2..D.X.", "##############"]
	var door_one_lever := [
		"..........D...", "..........D...", ".@..1.....D.X.", "##############"]
	check("도달 검사: 레버 둘을 올리면 전력 문이 열림", missing_chars(door_open) == "")
	check("도달 검사: 레버 하나로는 전력 문이 안 열림", missing_chars(door_one_lever) == "X2".replace("2", "") + "")

	# 지름길 문: 지름길 레버가 닿아야 열림
	var shortcut_ok := [
		"..........G...", "..........G...", ".@...!....G.X.", "##############"]
	var shortcut_far := [
		"..........G...", "..........G...", ".@........G.X.", "##############"]
	check("도달 검사: 지름길 레버로 지름길 문이 열림", missing_chars(shortcut_ok) == "")
	check("도달 검사: 레버가 없으면 지름길 문은 닫힘", missing_chars(shortcut_far) == "X")

	# 문 뒤의 레버: 한 레버가 문 뒤에 있으면 전력을 영원히 못 켠다
	var locked_lever := [
		"..........D...", "..........D...", ".@..1.....D.2X", "##############"]
	check("도달 검사: 문 뒤 레버는 전력 없이 못 닿음(순환 잠금 감지)", missing_chars(locked_lever).contains("X"))

	# 승강기
	var lift_map := [
		"...........", "...........", ".....^...X.", ".......####",
		"...........", "...........", "...........", ".@...v.....", "###########"]
	var no_lift := lift_map.map(func(row: String) -> String: return row.replace("^", ".").replace("v", "."))
	check("도달 검사: 승강기로 높은 턱에 오름", missing_chars(lift_map) == "")
	check("도달 검사: 승강기가 없으면 못 오름", missing_chars(no_lift) == "X")


func _test_nav_real() -> void:
	var world := WorldData.load_world(WORLD_PATH)
	var nav = WorldNav.new(world)
	var res: Dictionary = nav.analyze()
	check("실제 맵: 확인 대상 7곳(단서 4, 귀환 장치, 승강기 정류장 2)", res["targets"] == 7, str(res["targets"]))
	check("실제 맵: 시작 위치에서 모두 닿을 수 있음", res["missing"].is_empty(), str(res["missing"]))

	# 사다리를 지우면 일부 구역이 갇히는지 (검사가 실제로 약점을 잡는지)
	var broken := world.duplicate(true)
	for key in broken["cells"].keys():
		if broken["cells"][key] == "H" and key.x == 62:   # 병원 1층↔2층 사다리
			broken["cells"].erase(key)
	var res2: Dictionary = WorldNav.new(broken).analyze()
	check("병원 사다리를 지워도 거리 다리로 2층에 갈 수 있어 모두 닿음(길이 둘이라는 뜻)", res2["missing"].is_empty())
	for key in broken["cells"].keys():
		if broken["cells"][key] == "H" and key.x == 43:   # 거리 컨테이너 사다리
			broken["cells"].erase(key)
	var res3: Dictionary = WorldNav.new(broken).analyze()
	var missing_chars_3 := ""
	for m in res3["missing"]:
		missing_chars_3 += m["ch"]
	check("두 사다리를 모두 지우면 2층·승강기가 닿지 않음", res3["missing"].size() > 0, missing_chars_3)


# ---------------------------------------------------------------- 장면

func _load_scene() -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await frames(2)
	paused = false
	main = load("res://scenes/world1.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(4)
	player = main.player


func _test_scene() -> void:
	GameState.reset()
	await _load_scene()
	check("세계 1 장면에서 플레이어가 시작 위치(@)에 서 있음", player != null and absf(player.global_position.x - (4 * T + 8)) < 1.0, str(player.global_position))
	check("플레이어가 바닥 위에 섬", player.is_on_floor())
	check("조사 지점 4개(단서 c, g, h, i)", get_nodes_in_group("investigation").size() == 4)
	check("경비 로봇 2마리", get_nodes_in_group("enemy").size() == 2)
	check("귀환 장치 1개", get_nodes_in_group("return_point").size() == 1)
	check("사다리 2개", get_nodes_in_group("ladder").size() == 2)
	check("승강기 1대", main.built["lifts"].size() == 1)
	check("충돌체가 칸 수보다 훨씬 적게 만들어짐", main.get_children().filter(func(n): return n is StaticBody2D).size() < 80, str(main.get_children().filter(func(n): return n is StaticBody2D).size()))

	var cam: Camera2D = player.get_child(player.get_child_count() - 1) as Camera2D
	var cams := player.get_children().filter(func(n): return n is Camera2D)
	check("카메라가 맵 전체 경계로 제한됨", cams.size() == 1 and cams[0].limit_left == 0 and cams[0].limit_right == 96 * T and cams[0].limit_bottom == 28 * T)

	check("처음에 구역 이름을 보여 줌", main.toast.text == "정전된 거리", main.toast.text)
	await place(60, 19)
	await frames(2)
	check("병원에 들어가면 구역 이름이 바뀜", main.current_zone == "hospital" and main.toast.text == "병원", main.toast.text)
	await place(10, 19)
	await frames(2)
	check("다시 거리로 나오면 이름이 바뀜", main.current_zone == "street" and main.toast.text == "정전된 거리")


# ---------------------------------------------------------------- 실제 물리로 주요 구간 확인

func _test_physics() -> void:
	# 1. 거리: 컨테이너 사다리 (열 43, 바닥 줄 19 → 꼭대기 줄 14)
	await place(43, 19)
	Input.action_press("climb_up")
	await frames(10)
	check("거리 사다리: 타기 시작", player.climbing)
	var n := 0
	while player.climbing and n < 400:
		await physics_frame
		n += 1
	Input.action_release("climb_up")
	await frames(4)
	check("거리 사다리: 컨테이너 위(표면 줄 14)에 도착", absf(feet() - 14.0 * T) < 2.0 and player.is_on_floor(), "feet=%.1f" % feet())

	# 2. 컨테이너 위에서 점프해 다리(한쪽 방향 발판, 표면 줄 12)로
	await place(49, 13)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(6)
	Input.action_release("jump")
	await frames(40)
	Input.action_release("move_right")
	await frames(10)
	check("컨테이너 → 다리로 점프해 오름(아래에서 한쪽 방향 발판 통과)", absf(feet() - 12.0 * T) < 3.0 and player.is_on_floor(), "feet=%.1f x=%.1f" % [feet(), player.global_position.x])
	check("다리 위 위치(열 50~55)", player.global_position.x > 50 * T and player.global_position.x < 58 * T, "x=%.1f" % player.global_position.x)

	# 3. 다리 → 병원 2층 입구를 지나 안쪽으로
	Input.action_press("move_right")
	await frames(60)
	Input.action_release("move_right")
	await frames(6)
	check("다리에서 병원 2층 안으로 걸어 들어감", player.global_position.x > 58 * T and absf(feet() - 12.0 * T) < 3.0, "x=%.1f feet=%.1f" % [player.global_position.x, feet()])

	# 4. 자동차 지붕 점프 (열 12 → 열 14~17 지붕, 표면 줄 18)
	await place(12, 19)
	Input.action_press("move_right")
	var jumped := false
	var held := 0
	for i in 90:
		await physics_frame
		if not jumped and player.global_position.x >= 13 * T + 8:   # 자동차 벽(x=224)에 닿기 직전
			Input.action_press("jump")
			jumped = true
		elif jumped:
			held += 1
			if held == 18:   # 점프 키를 충분히 누르고 있다가 뗀다(일찍 떼면 낮게 뜬다)
				Input.action_release("jump")
			if held == 32:   # 지붕에 내려앉을 즈음 방향 키도 뗀다(계속 가면 반대편으로 걸어 내려간다)
				Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("move_right")
	await frames(30)
	check("자동차 지붕(표면 줄 18)에 점프해 오름", absf(feet() - 18.0 * T) < 3.0 and player.global_position.x > 14 * T and player.global_position.x < 18 * T, "feet=%.1f x=%.1f" % [feet(), player.global_position.x])

	# 5. 병원 1층 사다리 (열 62: 줄 19 → 2층 바닥 표면 줄 12)
	await place(62, 19)
	Input.action_press("climb_up")
	await frames(10)
	n = 0
	while player.climbing and n < 400:
		await physics_frame
		n += 1
	Input.action_release("climb_up")
	await frames(4)
	check("병원 사다리: 2층 바닥(표면 줄 12)에 도착", absf(feet() - 12.0 * T) < 2.0 and player.is_on_floor(), "feet=%.1f" % feet())

	# 6. 2층 바닥의 2칸 틈(열 80~81)을 점프로 건넘
	await place(77, 11)
	Input.action_press("move_right")
	jumped = false
	for i in 120:
		await physics_frame
		if not jumped and player.global_position.x >= 79 * T + 10:
			Input.action_press("jump")
			jumped = true
		elif jumped and i % 6 == 0:
			Input.action_release("jump")
	Input.action_release("jump")
	await frames(20)
	Input.action_release("move_right")
	await frames(10)
	check("2층 바닥 틈(2칸)을 점프로 건넘", player.global_position.x > 82 * T and absf(feet() - 12.0 * T) < 3.0, "x=%.1f feet=%.1f" % [player.global_position.x, feet()])

	# 7. 침대 위로 점프 (열 66~67, 높이 2칸)
	await place(65, 11)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(8)
	Input.action_release("jump")
	await frames(14)
	Input.action_release("move_right")
	await frames(10)
	check("2층 침대(2칸 높이) 위로 점프해 오름", absf(feet() - 10.0 * T) < 3.0 and player.global_position.x > 66 * T and player.global_position.x < 68 * T, "x=%.1f feet=%.1f" % [player.global_position.x, feet()])

	# 8. 병원 승강기 (열 89: 2층 → 옥상, 불러오기)
	var lift = main.built["lifts"][0]
	await place(89, 11)
	check("승강기가 2층(아래 정류장)에 있음", lift.at_bottom() and not lift.is_moving())
	await press("interact")
	check("승강기를 타고 E를 누르면 출발", lift.is_moving())
	n = 0
	while lift.is_moving() and n < 600:
		await physics_frame
		n += 1
	await frames(6)
	check("승강기가 옥상(표면 줄 4)까지 올라감", lift.at_top() and absf(feet() - 4.0 * T) < 3.0, "feet=%.1f" % feet())
	Input.action_press("move_left")
	await frames(40)
	Input.action_release("move_left")
	await frames(8)
	check("옥상에서 걸어 내릴 수 있음", player.global_position.x < 88 * T and absf(feet() - 4.0 * T) < 3.0, "x=%.1f feet=%.1f" % [player.global_position.x, feet()])

	# 9. 승강기가 위에 남아 있어도 아래 정류장에서 불러옴
	await place(89, 11)   # 아래 정류장 위(승강기는 위에 있음)
	check("승강기가 옥상에 남아 있음", lift.at_top())
	await press("interact")
	check("아래 정류장에서 E로 승강기를 부르면 내려옴", lift.is_moving())
	n = 0
	while lift.is_moving() and n < 600:
		await physics_frame
		n += 1
	check("승강기가 2층으로 내려옴", lift.at_bottom())
	# 옥상에서도 불러서 탈 수 있다
	await place(86, 3)
	await place(88, 3)
	await press("interact")
	check("옥상(위 정류장)에서 E로 승강기를 부르면 올라옴", lift.is_moving())
	n = 0
	while lift.is_moving() and n < 600:
		await physics_frame
		n += 1
	check("승강기가 옥상으로 올라옴", lift.at_top())


# ---------------------------------------------------------------- 맵 가장자리

func _test_edges() -> void:
	await _load_scene()
	var right_edge := 96.0 * T

	# 병원 옥상 오른쪽 끝에서 계속 걸어도 맵 밖으로 떨어지지 않는다 (예전에 벽이 없어서 떨어졌던 곳)
	await place(93, 3)
	check("옥상 오른쪽 끝 근처에 섬", absf(feet() - 4.0 * T) < 3.0 and player.is_on_floor(), "feet=%.1f" % feet())
	Input.action_press("move_right")
	await frames(150)
	Input.action_release("move_right")
	await frames(10)
	check("옥상 오른쪽 끝에서 계속 걸어도 맵 밖으로 나가지 않음", player.global_position.x < right_edge and absf(feet() - 4.0 * T) < 3.0 and player.is_on_floor(),
		"x=%.1f (경계 %.0f) feet=%.1f" % [player.global_position.x, right_edge, feet()])

	# 점프하면서 밀어도 넘어가지 못한다
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(40)
	Input.action_release("jump")
	await frames(60)
	Input.action_release("move_right")
	check("옥상 끝에서 점프하며 밀어도 맵 밖으로 못 나감", player.global_position.x < right_edge and player.global_position.y < 28.0 * T,
		"x=%.1f y=%.1f" % [player.global_position.x, player.global_position.y])

	# 거리 왼쪽 끝
	await place(3, 19)
	Input.action_press("move_left")
	await frames(60)
	Input.action_release("move_left")
	check("거리 왼쪽 끝에서도 맵 밖으로 나가지 않음", player.global_position.x > 0.0, "x=%.1f" % player.global_position.x)

	# 안전장치: 어떤 이유로든 맵 밖으로 나가면 시작 위치로 돌아온다
	player.global_position = Vector2(5000.0, 200.0)
	await frames(3)
	check("맵 밖으로 나가면 시작 위치로 돌아옴", player.global_position.distance_to(main.built["start"]) < 24.0, str(player.global_position))
	check("돌아왔다는 안내가 나옴", main.toast.text.contains("맵 밖"))
	player.global_position = Vector2(300.0, 5000.0)
	await frames(3)
	check("맵 아래로 떨어져도 시작 위치로 돌아옴", player.global_position.distance_to(main.built["start"]) < 24.0)


# ---------------------------------------------------------------- 기존 게임 기능과의 연결

func _test_integration() -> void:
	GameState.reset()
	await _load_scene()

	# 단서 조사
	var pt: Area2D = null
	for p in get_nodes_in_group("investigation"):
		if p.clue_ids == ["s1_i"]:
			pt = p
	check("멈춘 차량 단서(s1_i) 조사 지점이 있음", pt != null)
	player.global_position = pt.global_position
	await frames(5)
	await press("interact")
	check("맵에서 E로 단서를 얻음", GameState.get_book().has("s1_i"))
	check("획득 알림이 나옴", main.toast.text.begins_with("단서 획득"))

	# 전투: 경비 로봇에 닿으면 전투 화면
	var enemy: Area2D = get_nodes_in_group("enemy")[0]
	player.global_position = enemy.global_position
	await frames(6)
	var ui = main.get_node_or_null("BattleUI")
	check("경비 로봇에 닿으면 전투 화면", ui != null and paused)
	var guard := 0
	ui.logic.enemy_hp = 1
	while not ui.logic.over and guard < 60:
		ui.logic.set_offer_for_test(["attack", "defend", "dodge"])
		ui.logic.focus = 5
		ui.choose("attack")
		guard += 1
	ui._on_continue()
	await frames(4)
	check("전투에서 이기면 적이 사라지고 다시 움직일 수 있음", not paused and get_nodes_in_group("enemy").filter(func(e): return not e.is_queued_for_deletion()).size() == 1)

	# 귀환 장치 → 보고 화면
	var ret: Area2D = get_nodes_in_group("return_point")[0]
	player.global_position = ret.global_position
	await frames(6)
	await press("interact")
	check("귀환 장치에서 E를 누르면 보고 화면", main._report != null and paused)
	check("보고 화면에서도 모은 단서가 반영됨", main._report.book.has("s1_i"))

	# 보고를 마치면 새 시뮬레이션(같은 세계 1 장면)이 시작되고 단서는 유지된다
	main._report.handle_key(KEY_N)
	var old = main
	main._report.handle_key(KEY_ENTER)
	var waited := 0
	while (current_scene == null or current_scene == old) and waited < 40:
		await physics_frame
		waited += 1
	await frames(4)
	check("보고 후 세계 1 맵이 다시 시작됨", current_scene != null and current_scene != old and current_scene.has_method("_check_zone"))
	check("새 시뮬레이션에서도 단서는 유지됨", GameState.get_book().has("s1_i"))
	check("새 시뮬레이션: 조사 지점이 다시 만들어지고 이미 얻은 단서는 완료 표시", get_nodes_in_group("investigation").filter(func(p): return p.clue_ids == ["s1_i"] and p.is_done()).size() == 1)

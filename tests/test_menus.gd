extends SceneTree
## 타이틀 → 인트로 → 세계 1 → 조작 안내 → 일시정지 → 이어하기 흐름 테스트:
## godot --headless --path game -s tests/test_menus.gd

const GameState := preload("res://scripts/game_state.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const TEST_PATH := "user://test_menus_save.json"

var fails := 0
var done := false


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("통과 " if ok else "실패 "), name, "  ", detail)
	if not ok:
		fails += 1


func _init() -> void:
	SaveGame.path = TEST_PATH
	SaveGame.autosave_enabled = false
	SaveGame.delete()
	GameState.reset()
	await _run()
	SaveGame.delete()
	SaveGame.autosave_enabled = false
	GameState.reset()
	check("끝까지 실행됨", done)
	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)


## 실제 키보드의 Esc 키를 누른 것처럼 보낸다. (화면마다 키 이벤트와 동작 이벤트를 따로 처리하므로)
func press_esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	var up := InputEventKey.new()
	up.keycode = KEY_ESCAPE
	up.physical_keycode = KEY_ESCAPE
	up.pressed = false
	Input.parse_input_event(up)
	await frames(1)


## 새 장면으로 바뀔 때까지 기다린다.
func wait_scene_change(old) -> void:
	var waited := 0
	while (current_scene == null or current_scene == old) and waited < 60:
		await physics_frame
		waited += 1
	await frames(4)


func open_title() -> Node:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await frames(2)
	paused = false
	var t = load("res://scenes/title.tscn").instantiate()
	root.add_child(t)
	current_scene = t
	await frames(3)
	return t


func overlay_of(node: Node):
	for c in node.get_children():
		if c is CanvasLayer and c.has_method("advance"):
			return c
	return null


func _run() -> void:
	# ---------------------------------------------------------------- 타이틀
	var title = await open_title()
	check("타이틀 버튼 4개", title._buttons.has("new") and title._buttons.has("continue") and title._buttons.has("controls") and title._buttons.has("quit"))
	check("저장이 없으면 이어하기가 비활성", title._buttons["continue"].disabled)
	check("시작하기 버튼에 포커스(키보드로 바로 선택 가능)", title._buttons["new"].has_focus())

	title.show_controls()
	await frames(2)
	var ov = overlay_of(title)
	check("조작 방법 화면이 열림", ov != null and ov.pages[0].contains("A / D") and ov.pages[0].contains("Esc"))
	ov.advance()
	await frames(3)
	check("조작 방법 화면이 닫힘", overlay_of(title) == null)

	# ---------------------------------------------------------------- 새로 시작: 인트로 → 세계 1
	title.start_new_game()
	await frames(2)
	ov = overlay_of(title)
	check("저장이 없으면 확인 없이 인트로가 나옴", ov != null and ov.pages.size() == 3 and not title._buttons.has("confirm_yes"))
	check("인트로에 세계 예측기 소개가 들어 있음", String(ov.pages[1]).contains("세계 예측기"))
	var old = current_scene
	ov.advance()
	ov.advance()
	check("인트로 마지막 쪽 버튼은 '시작'", ov._button.text == "시작")
	ov.advance()
	await wait_scene_change(old)
	var world = current_scene
	check("세계 1 장면으로 이동", world != null and world != old and world.has_method("_check_zone"))
	check("이때부터 자동 저장이 켜짐", SaveGame.autosave_enabled)
	check("시작과 함께 저장 파일이 만들어짐", SaveGame.exists())

	# ---------------------------------------------------------------- 첫 조작 안내
	await frames(3)
	check("처음 들어오면 조작 안내가 뜨고 게임이 멈춤", world._guide != null and paused)
	check("조작 안내를 봤다고 기록됨", GameState.seen_guide)
	world._guide.advance()
	await frames(3)
	check("조작 안내를 닫으면 게임이 다시 움직임", world._guide == null and not paused)
	check("조작 안내를 본 기록이 저장됨", _saved_seen_guide())

	# ---------------------------------------------------------------- 일시정지
	await press_esc()
	check("Esc를 누르면 일시정지 메뉴", world._pause != null and paused)
	await press_esc()
	check("Esc를 다시 누르면 닫힘", world._pause == null and not paused)

	await press_esc()
	var pm = world._pause
	pm.show_controls()
	await frames(2)
	check("일시정지 메뉴에서 조작 방법을 볼 수 있음", pm._guide != null)
	await press_esc()
	await frames(2)
	check("조작 방법 화면에서 Esc는 그 화면만 닫음(게임으로 돌아가지 않음)", pm._guide == null and world._pause != null and paused)
	pm.resume()
	await frames(2)
	check("계속하기로 게임에 돌아옴", world._pause == null and not paused)

	# 다른 화면이 열려 있을 때는 일시정지 메뉴가 겹쳐 열리지 않는다
	world._open_notebook()
	await frames(2)
	await press_esc()
	check("수첩이 열려 있으면 Esc는 일시정지 메뉴를 열지 않음", world._pause == null)
	world._close_notebook()
	await frames(2)

	# ---------------------------------------------------------------- 진행 후 처음 화면으로 → 이어하기
	GameState.get_book().collect("s1_i")
	GameState.get_book().set_mark("s1_i", "trust")
	world._open_pause()
	await frames(2)
	old = current_scene
	world._pause.to_title.emit()
	await wait_scene_change(old)
	title = current_scene
	check("처음 화면으로 돌아옴", title != null and title.has_method("start_new_game"))
	check("저장이 생겼으니 이어하기가 활성", not title._buttons["continue"].disabled)
	check("처음 화면으로 갈 때 진행이 저장됨", _saved_clue_count() == 1)

	GameState.reset()   # 프로그램을 껐다 켠 것처럼 상태를 비운다
	check("(껐다 켠 상태: 수첩이 비어 있음)", GameState.get_book().count() == 0)
	old = current_scene
	title.continue_game()
	await wait_scene_change(old)
	world = current_scene
	await frames(3)
	check("이어하기: 세계 1로 들어옴", world != null and world.has_method("_check_zone"))
	check("이어하기: 모았던 단서와 표시가 돌아옴", GameState.get_book().has("s1_i") and GameState.get_book().get_mark("s1_i") == "trust")
	check("이어하기: 이미 본 조작 안내는 다시 안 뜸", world._guide == null and not paused)
	check("이어하기: 조사 지점도 완료 표시", get_nodes_in_group("investigation").filter(func(p): return p.clue_ids == ["s1_i"] and p.is_done()).size() == 1)

	# ---------------------------------------------------------------- 새로 시작 (저장이 있을 때는 확인)
	old = current_scene
	world._go_title()
	await wait_scene_change(old)
	title = current_scene
	title.start_new_game()
	await frames(2)
	check("저장이 있으면 새로 시작하기 전에 확인", title._buttons.has("confirm_yes") and overlay_of(title) == null)
	title._confirm_no()
	await frames(3)
	check("취소하면 저장은 그대로", SaveGame.exists() and _saved_clue_count() == 1 and not title._buttons.has("confirm_yes"))
	title.start_new_game()
	await frames(2)
	title._confirm_yes()
	await frames(2)
	check("확인하면 저장이 지워지고 인트로가 나옴", not SaveGame.exists() and overlay_of(title) != null and GameState.get_book().count() == 0)
	overlay_of(title).closed.emit()   # 인트로를 건너뛰면
	await frames(4)
	check("인트로를 건너뛰어도 새 게임이 시작됨", current_scene != title and current_scene.has_method("_check_zone"))

	# ---------------------------------------------------------------- 깨진 저장 파일
	var w2 = current_scene
	w2._go_title()
	await frames(6)
	var t2 = current_scene
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("깨진 파일")
	f.close()
	t2.continue_game()
	await frames(3)
	check("깨진 저장 파일이면 안내만 하고 타이틀에 남음", current_scene == t2 and t2._message.text.contains("읽을 수 없습니다"))

	done = true


func _saved_seen_guide() -> bool:
	var f := FileAccess.open(TEST_PATH, FileAccess.READ)
	if f == null:
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d is Dictionary and bool(d["state"]["seen_guide"])


func _saved_clue_count() -> int:
	var f := FileAccess.open(TEST_PATH, FileAccess.READ)
	if f == null:
		return -1
	var d: Variant = JSON.parse_string(f.get_as_text())
	return (d["clues"]["order"] as Array).size() if d is Dictionary else -1

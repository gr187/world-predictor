extends SceneTree
## 조사 → 수첩 → 장면 재시작 후 유지 흐름 테스트:
## godot --headless --path game -s tests/test_investigation_flow.gd

const GameState := preload("res://scripts/game_state.gd")

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("통과 " if ok else "실패 "), name)
	if not ok:
		fails += 1


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	await physics_frame


func first_point() -> Area2D:
	var best: Area2D = null
	for p in get_nodes_in_group("investigation"):
		if best == null or p.position.x < best.position.x:
			best = p
	return best


func _init() -> void:
	GameState.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	await physics_frame

	var points := get_nodes_in_group("investigation")
	check("조사 지점 16개 배치", points.size() == 16)

	var book = GameState.get_book()
	var p: Area2D = first_point()
	check("처음엔 조사하지 않은 상태", not p.is_done() and book.count() == 0)

	# 멀리 있을 때 E를 눌러도 아무 일 없음
	main.player.global_position = Vector2(1770, 200)   # 마지막 조사 지점(x=1675)에서 충분히 먼 곳
	for i in 5:
		await physics_frame
	await press("interact")
	check("범위 밖에서 E를 눌러도 획득 없음", book.count() == 0)

	# 지점 위로 이동해서 E
	main.player.global_position = p.global_position
	for i in 5:
		await physics_frame
	await press("interact")
	check("범위 안에서 E를 누르면 단서 획득", book.count() == 1 and p.is_done())
	check("획득 알림 표시", main.toast.modulate.a > 0.0 and main.toast.text.begins_with("단서 획득"))
	await press("interact")
	check("같은 지점을 다시 조사해도 중복 없음", book.count() == 1)

	# 수첩 열기/닫기
	await press("notebook")
	var nb = main.get_node_or_null("Notebook")
	check("Q로 수첩 열림 + 일시정지", nb != null and paused)
	await press("notebook")
	await physics_frame
	check("Q로 수첩 닫힘 + 일시정지 해제", not paused and main._notebook == null)

	# 전투 중에는 수첩이 열리지 않음
	paused = true
	await press("notebook")
	check("일시정지 중에는 수첩이 새로 열리지 않음", main.get_node_or_null("Notebook") == null or main.get_node("Notebook").is_queued_for_deletion())
	paused = false

	# 장면을 다시 불러와도 단서 유지 (죽었을 때 시뮬레이션 재시작과 같은 경로)
	var old_main = main
	reload_current_scene()
	var waited := 0
	while (current_scene == null or current_scene == old_main) and waited < 30:
		await physics_frame
		waited += 1
	var new_main = current_scene
	check("장면이 새로 불러와짐", new_main != null and new_main != old_main)
	check("재시작 후에도 단서 유지", GameState.get_book().count() == 1)
	var p2: Area2D = first_point()
	check("재시작 후 조사한 지점은 완료 표시", p2 != null and p2.is_done())

	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)

extends SceneTree
## 전투 화면의 5초 타이머·선택지 흐름 테스트:
## godot --headless --path game -s tests/test_battle_timer.gd

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("통과 " if ok else "실패 "), name, "  ", detail)
	if not ok:
		fails += 1


func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	await physics_frame

	var target: Area2D = get_nodes_in_group("enemy")[0]
	main.player.global_position = target.global_position
	for i in 5:
		await physics_frame
	var ui = main.get_node_or_null("BattleUI")
	if ui == null:
		check("전투 화면 생성", false)
		quit(1)
		return

	check("첫 턴부터 선택지 3개", ui.logic.offer.size() == 3)
	check("첫 턴 타이머 5초, 진행 중", ui._turn_active and absf(ui._time_left - 5.0) < 0.2)
	check("선택지 버튼 3개 표시", ui._buttons.filter(func(b): return b.visible).size() == 3)

	# 시간이 흐르면 원이 차오른다
	ui._process(2.5)
	check("2.5초 경과: 원이 절반 근처까지 참", absf(ui._timer.ratio - 0.5) < 0.1, "ratio=%.2f" % ui._timer.ratio)
	check("아직 턴이 넘어가지 않음", ui.logic.turn == 0)

	# 5초가 지나면 자동 선택
	ui._process(3.0)
	check("5초 경과: 자동으로 한 턴 진행", ui.logic.turn == 1)
	check("자동 선택 문구가 로그에 표시", ui._log_label.text.begins_with("시간이 다 됐다"))
	check("결과 표시 중에는 타이머 멈춤", not ui._turn_active and ui._busy_time > 0.0)

	# 결과 표시 중에는 입력 무시
	var t: int = ui.logic.turn
	ui._on_choice(0)
	check("결과 표시 중 선택 무시", ui.logic.turn == t)

	# 결과 표시 후 다음 턴 시작
	ui._process(ui.RESULT_PAUSE + 0.1)
	check("결과 표시 후 다음 턴 시작, 타이머 5초로 리셋", ui._turn_active and absf(ui._time_left - 5.0) < 0.2)

	# 직접 선택하면 즉시 진행
	var first: String = ui.logic.offer[0]
	if ui.logic.is_usable(first):
		ui._on_choice(0)
		check("선택하면 즉시 한 턴 진행", ui.logic.turn == t + 1)
	else:
		check("(첫 번째 선택지가 잠겨 있어 건너뜀)", true)

	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)

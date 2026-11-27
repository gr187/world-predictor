extends SceneTree
## 보고서 시스템 테스트(점수·등급·보급품 로직, 보고 화면 흐름):
## godot --headless --path game -s tests/test_report.gd

const ClueBook := preload("res://scripts/clue_book.gd")
const GameState := preload("res://scripts/game_state.gd")
const ReportLogic := preload("res://scripts/report_logic.gd")
const BattleLogic := preload("res://scripts/battle_logic.gd")

var fails := 0
var done := false
var enemy_data: Dictionary


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("통과 " if ok else "실패 "), name, "  ", detail)
	if not ok:
		fails += 1


func _init() -> void:
	var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	enemy_data = parsed["guard_robot"]

	_test_data()
	_test_scoring()
	_test_state_and_supplies()
	await _test_ui()
	check("끝까지 실행됨", done)
	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)


# ---------------------------------------------------------------- 도우미

func full_book(perfect_marks: bool):
	var b = ClueBook.new()
	for id in b.all:
		b.collect(id)
		if perfect_marks:
			var truth: String = b.all[id]["truth"]
			if truth == "valid":
				b.set_mark(id, "trust")
			elif truth == "false" or truth == "mistaken":
				b.set_mark(id, "doubt")
	return b


func add_cards(b, list: Array) -> void:
	for pair in list:
		b.add_card(pair[0], pair[1])


func wait_reload(old) -> void:
	var waited := 0
	while (current_scene == null or current_scene == old) and waited < 40:
		await physics_frame
		waited += 1


func fresh_main():
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await physics_frame
		await physics_frame
	paused = false
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	current_scene = m
	await physics_frame
	await physics_frame
	return m


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	await physics_frame


# ---------------------------------------------------------------- 데이터

func _test_data() -> void:
	var rl = ReportLogic.new()
	check("원인 후보 4개", rl.causes().size() == 4)
	var scores := []
	for c in rl.causes():
		scores.append(int(c["score"]))
	scores.sort()
	check("원인 점수 0/15/20/40", scores == [0, 15, 20, 40])
	check("정답 원인이 목록의 첫 번째가 아님(순서로 정답이 드러나지 않음)", rl.causes()[0]["score"] != 40)
	check("보급품 3종", rl.supplies().size() == 3)
	var book = ClueBook.new()
	var ok := true
	for id in book.statements:
		var st: Dictionary = book.statements[id]
		if not st.has("supports"):
			ok = false
		elif bool(st["valid"]) and st["supports"].is_empty():
			ok = false
		elif not bool(st["valid"]) and not st["supports"].is_empty():
			ok = false
	check("참인 결론에는 뒷받침하는 원인이 있고 거짓 결론에는 없음", ok)


# ---------------------------------------------------------------- 점수

func _test_scoring() -> void:
	var rl = ReportLogic.new()
	var good_cards := [
		[["s1_d", "s1_p"], "s1_inf_structure"],
		[["s1_e", "s1_o"], "s1_inf_warning"],
		[["s1_l", "s1_k"], "s1_inf_coverup"],
	]

	# 완벽한 보고
	var b = full_book(true)
	add_cards(b, good_cards)
	var r: Dictionary = rl.evaluate(b, "storm_gap", [0, 1, 2])
	check("완벽한 보고: 결론 40, 근거 40", r["conclusion"] == 40 and r["evidence"] == 40)
	check("판단력 18.75 (11+3+0.5×2=15 → 20×15/16)", absf(r["judgment"] - 18.75) < 0.001, str(r["judgment"]))
	check("S 등급, 승인, 보급품 2개", r["grade"] == "S" and r["passed"] and r["supply_count"] == 2)
	check("S 등급은 칭찬 코멘트", String(r["comment"]).begins_with("훌륭하군.") and String(r["comment"]).contains("빈틈이 없는"))
	check("단서를 다 모았으면 힌트 없음", r["hint"] == "")

	# 같은 근거라도 엉뚱한 원인을 고르면 근거가 무관해진다
	r = rl.evaluate(b, "attack", [0, 1, 2])
	check("오답 원인: 결론 0, 근거도 0(뒷받침하지 않음)", r["conclusion"] == 0 and r["evidence"] == 0)
	check("오답 원인: D 등급, 보류, 보급품 0", r["grade"] == "D" and not r["passed"] and r["supply_count"] == 0)
	check("오답 원인: 가장 약한 요소는 결론", r["weakest"] == "conclusion" and String(r["comment"]).contains("현장 기록"))

	# 모든 단서를 보류로 둔 경우
	b = full_book(false)
	add_cards(b, good_cards)
	r = rl.evaluate(b, "storm_gap", [1])
	# 부분 참 단서 2개를 보류하면 +0.5씩이라 모두 보류해도 판단력은 20×1/16 = 1.25
	check("보류만 한 보고: 판단력 1.25, 총 56.25점 B 승인",
		absf(r["judgment"] - 1.25) < 0.001 and absf(r["total"] - 56.25) < 0.001 and r["grade"] == "B" and r["passed"], str(r["total"]))
	check("B 등급 보급품 1개", r["supply_count"] == 1)
	check("가장 약한 요소는 판단력(코멘트가 판단을 짚음)", r["weakest"] == "judgment" and String(r["comment"]).contains("출처와 시점"))

	r = rl.evaluate(b, "aging", [0])
	check("노후 설비 + 방호 카드: 결론 20, 근거 15 → C, 보류", r["conclusion"] == 20 and r["evidence"] == 15 and r["grade"] == "C" and not r["passed"], str(r["total"]))
	r = rl.evaluate(b, "storm_only", [])
	check("근거 없이 폭풍 단독: 결론 15, 근거 0", r["conclusion"] == 15 and r["evidence"] == 0)

	# 거짓 카드 감점과 하한
	b = full_book(false)
	add_cards(b, [[["s1_a", "s1_b"], "s1_inf_attack"], [["s1_e", "s1_o"], "s1_inf_warning"]])
	r = rl.evaluate(b, "storm_gap", [0, 1])
	check("거짓 카드 -10, 참인 카드 +15 → 근거 5", r["evidence"] == 5, str(r["evidence"]))
	add_cards(b, [[["s1_a", "s1_c"], "s1_inf_sabotage"], [["s1_a", "s1_n"], "s1_inf_held"]])
	r = rl.evaluate(b, "storm_gap", [0, 2, 3])
	check("거짓 카드만 붙이면 근거는 0 아래로 내려가지 않음", r["evidence"] == 0)

	b = full_book(false)
	add_cards(b, [[["s1_d", "s1_b"], "s1_inf_structure"]])
	r = rl.evaluate(b, "storm_gap", [0])
	check("참이지만 근거가 부족한 카드는 +5", r["evidence"] == 5, str(r["evidence"]))
	r = rl.evaluate(b, "storm_gap", [7])
	check("없는 카드 번호는 무시", r["evidence"] == 0)

	# 판단력 세부
	b = ClueBook.new()
	b.collect("s1_a")   # 거짓
	b.collect("s1_b")   # 참
	b.collect("s1_g")   # 부분 참
	b.set_mark("s1_a", "trust")
	b.set_mark("s1_b", "doubt")
	b.set_mark("s1_g", "trust")
	check("거짓을 믿고 참을 의심하면 판단력 0", rl.judgment_score(b) == 0.0)
	b.set_mark("s1_a", "doubt")
	b.set_mark("s1_b", "trust")
	b.set_mark("s1_g", "hold")
	check("거짓 의심 +1, 참 믿음 +1, 부분 참 보류 +0.5 → 20×2.5/3", absf(rl.judgment_score(b) - 20.0 * 2.5 / 3.0) < 0.001)
	check("단서가 없으면 판단력 0(0으로 나누지 않음)", rl.judgment_score(ClueBook.new()) == 0.0)

	# 힌트
	b = full_book(false)
	var b2 = ClueBook.new()
	check("단서가 없으면 첫 단서의 힌트", rl.pick_hint(b2) == b2.all["s1_a"]["hint"])
	b2.collect("s1_a")
	check("모은 단서는 힌트에서 제외", rl.pick_hint(b2) == b2.all["s1_b"]["hint"])

	# 등급 경계
	var edge := {85.0: "S", 84.99: "A", 70.0: "A", 69.99: "B", 50.0: "B", 49.99: "C", 30.0: "C", 29.99: "D", 0.0: "D"}
	var edge_ok := true
	for v in edge:
		if rl.grade_for(v) != edge[v]:
			edge_ok = false
	check("등급 경계값", edge_ok)
	check("B 이상만 승인", rl.grade_passes("S") and rl.grade_passes("A") and rl.grade_passes("B") and not rl.grade_passes("C") and not rl.grade_passes("D"))
	check("보급품 개수 S2 A2 B1 C1 D0",
		rl.supply_count("S") == 2 and rl.supply_count("A") == 2 and rl.supply_count("B") == 1 and rl.supply_count("C") == 1 and rl.supply_count("D") == 0)

	# 정답을 모르면서 찍어서는 높은 등급을 받기 어렵다
	var best_blind := 0.0
	for cause in ["attack", "aging", "storm_gap", "storm_only"]:
		var bb = full_book(false)
		best_blind = maxf(best_blind, float(rl.evaluate(bb, cause, [])["total"]))
	check("카드도 표시도 없이는 최고 41.25점(C, 승인 보류)", absf(best_blind - 41.25) < 0.001 and rl.grade_for(best_blind) == "C", str(best_blind))


# ---------------------------------------------------------------- 상태와 보급품

func _test_state_and_supplies() -> void:
	GameState.reset()
	GameState.pending_supplies = ["suit", "kit"]
	GameState.begin_simulation()
	check("시뮬 시작 시 보급품이 적용되고 대기 목록은 비워짐",
		GameState.active_supplies == ["suit", "kit"] and GameState.pending_supplies.is_empty())
	GameState.begin_simulation()
	check("보급품은 한 번의 시뮬레이션에서만 유효", GameState.active_supplies.is_empty())
	check("다음 세계 해금(처음)", GameState.unlock_next_world() and GameState.unlocked_world == 2)
	check("같은 보고로 두 번 열리지 않음", not GameState.unlock_next_world() and GameState.unlocked_world == 2)
	GameState.reset()
	check("reset은 모두 초기화", GameState.unlocked_world == 1 and GameState.last_grade == "" and GameState.active_supplies.is_empty())

	# 보급품이 전투에 반영된다
	var plain = BattleLogic.new(enemy_data, 0, 1)
	check("보급품 없음: 체력 5, 집중 3, 치료 2", plain.max_hp == 5 and plain.player_hp == 5 and plain.focus == 3 and plain.heal_amount == 2)
	var geared = BattleLogic.new(enemy_data, 0, 1, ["suit", "battery", "kit"])
	check("방호복: 최대 체력 +1", geared.max_hp == 6 and geared.player_hp == 6)
	check("집중 배터리: 시작 집중 +2(최대 5)", geared.focus == 5)
	check("응급 키트: 치료량 +1", geared.heal_amount == 3)
	geared.player_hp = 2
	geared.set_intent_for_test("defend")
	geared.set_offer_for_test(["heal"])
	geared.play("heal")
	check("응급 키트로 체력 2 → 5 회복", geared.player_hp == 5, str(geared.player_hp))
	geared.player_hp = 5
	geared.roll_offer()
	check("최대 체력이 6이라 체력 5에서도 치료가 나올 수 있음", _offer_can_have_heal(geared))
	var only_battery = BattleLogic.new(enemy_data, 0, 1, ["battery"])
	check("배터리만: 체력과 치료량은 그대로", only_battery.max_hp == 5 and only_battery.heal_amount == 2 and only_battery.focus == 5)


func _offer_can_have_heal(b) -> bool:
	for i in 200:
		b.player_hp = 5
		b.focus = 5
		b.roll_offer()
		if b.offer.has("heal"):
			return true
	return false


# ---------------------------------------------------------------- 화면 흐름

func _test_ui() -> void:
	# --- 좋은 보고: 원인 → 카드 → 결과 → 보급품 → 시작 ---
	GameState.reset()
	var book = full_book(true)
	GameState.reset()
	book = GameState.get_book()
	for id in book.all:
		book.collect(id)
		var truth: String = book.all[id]["truth"]
		if truth == "valid":
			book.set_mark(id, "trust")
		elif truth == "false" or truth == "mistaken":
			book.set_mark(id, "doubt")
	add_cards(book, [
		[["s1_d", "s1_p"], "s1_inf_structure"],
		[["s1_e", "s1_o"], "s1_inf_warning"],
		[["s1_l", "s1_k"], "s1_inf_coverup"],
	])

	var main = await fresh_main()
	main._open_report("return")
	var rpt = main._report
	check("보고 화면 열림 + 일시정지", rpt != null and paused and rpt.step == rpt.Step.CAUSE)
	check("원인 후보 4개 표시", rpt._items.size() == 4)
	check("귀환 인사 표시", rpt._detail.text.begins_with("돌아왔군"))
	main._open_report("return")
	check("보고 화면은 중복으로 열리지 않음", main.get_children().filter(func(n): return n.name.begins_with("ReportUI")).size() == 1)

	var idx: int = rpt._items.find("storm_gap")
	rpt._list.select(idx)
	rpt.handle_key(KEY_ENTER)
	check("원인을 고르면 근거 첨부 단계, 카드 3장 표시", rpt.step == rpt.Step.EVIDENCE and rpt._items.size() == 3)
	rpt.handle_key(KEY_ESCAPE)
	check("Esc로 뒤로 가면 고른 원인이 그대로 선택됨", rpt.step == rpt.Step.CAUSE and rpt._selected_index() == idx)
	rpt.handle_key(KEY_ENTER)
	for i in 3:
		rpt._list.select(i)
		rpt.handle_key(KEY_SPACE)
	check("카드 3장 첨부", rpt._checked_cards.size() == 3 and rpt._list.get_item_text(0).begins_with("[v]"))
	rpt._list.select(0)
	rpt.handle_key(KEY_SPACE)
	check("카드 선택 해제", rpt._checked_cards.size() == 2)
	rpt._list.select(0)
	rpt.handle_key(KEY_SPACE)
	rpt.handle_key(KEY_ENTER)
	check("제출하면 결과 단계", rpt.step == rpt.Step.RESULT and rpt.result["grade"] == "S")
	check("결과 화면에 등급과 코멘트, 승인 문구", rpt._detail.text.contains("등급  S") and rpt._detail.text.contains("승인한다"))
	check("결과 화면에 점수 숫자는 나오지 않음", not rpt._detail.text.contains("98") and not rpt._detail.text.contains("점"))
	check("첫 승인으로 세계 2 해금 안내", GameState.unlocked_world == 2 and rpt._detail.text.contains("세계 2"))
	check("마지막 보고 등급 기록", GameState.last_grade == "S")

	rpt.handle_key(KEY_ENTER)
	check("S 등급: 보급품 2개 선택 단계", rpt.step == rpt.Step.SUPPLY and rpt._supply_limit() == 2)
	rpt.handle_key(KEY_ENTER)
	check("보급품을 덜 고르고 확정하면 거절", rpt.step == rpt.Step.SUPPLY and rpt._msg.text != "")
	for i in 3:
		rpt._list.select(i)
		rpt.handle_key(KEY_SPACE)
	check("보급품은 2개까지만 선택됨", rpt._checked_supplies.size() == 2)
	rpt._list.select(1)
	rpt.handle_key(KEY_SPACE)   # 배터리 해제
	rpt._list.select(2)
	rpt.handle_key(KEY_SPACE)   # 응급 키트 선택 → 방호복 + 응급 키트
	rpt.handle_key(KEY_ENTER)
	check("보급품 확정 → 다음 시뮬레이션 단계", rpt.step == rpt.Step.DONE and GameState.pending_supplies == ["suit", "kit"], str(GameState.pending_supplies))

	var old_main = main
	rpt.handle_key(KEY_ENTER)
	await wait_reload(old_main)
	main = current_scene
	check("보고가 끝나면 새 시뮬레이션이 시작됨", main != null and main != old_main and not paused)
	check("받은 보급품이 새 시뮬레이션에 적용됨", GameState.active_supplies == ["suit", "kit"] and GameState.pending_supplies.is_empty())
	check("화면에 보급품 표시", main.hint.text.contains("보급품: 방호복, 응급 키트"))
	check("단서·표시·카드는 유지됨", GameState.get_book().count() == 16 and GameState.get_book().cards.size() == 3)

	# 새 시뮬레이션의 전투에서 보급품이 적용된다
	var target: Area2D = get_nodes_in_group("enemy")[0]
	main.player.global_position = target.global_position
	for i in 5:
		await physics_frame
	var bui = main.get_node_or_null("BattleUI")
	check("전투에 보급품 적용(체력 6, 치료량 3)", bui != null and bui.logic.max_hp == 6 and bui.logic.heal_amount == 3)

	# --- 전투 패배 → 보고 ---
	bui.logic.over = true
	bui.logic.winner = "enemy"
	bui._end()
	bui._on_continue()
	await physics_frame
	await physics_frame
	check("전투에서 지면 시뮬레이션이 바로 재시작되지 않고 보고 화면이 열림",
		main._report != null and paused and main._report.reason == "defeat")
	check("패배 보고 인사말", main._report._detail.text.begins_with("시뮬레이션이 강제 종료됐더군"))

	# --- 낮은 보고: 원인 오답, 카드 없음 ---
	rpt = main._report
	rpt._list.select(rpt._items.find("attack"))
	rpt.handle_key(KEY_ENTER)
	check("카드가 있어도 첨부하지 않고 제출 가능", rpt.step == rpt.Step.EVIDENCE)
	rpt.handle_key(KEY_ENTER)
	check("오답 원인 보고: D 등급", rpt.result["grade"] == "D" and rpt.result["conclusion"] == 0)
	check("승인 보류 문구, 이미 열린 세계는 다시 안내하지 않음", rpt._detail.text.contains("승인은 보류") and not rpt._detail.text.contains("접근 권한"))
	check("단서를 다 모았으면 힌트 줄 없음", not rpt._detail.text.contains("힌트"))
	rpt.handle_key(KEY_ENTER)
	check("D 등급은 보급품 없이 바로 다음 단계", rpt.step == rpt.Step.DONE and GameState.pending_supplies.is_empty())
	old_main = main
	rpt.handle_key(KEY_ENTER)
	await wait_reload(old_main)
	main = current_scene
	check("보급품 없이 재시작, 이전 보급품은 사라짐", main != old_main and GameState.active_supplies.is_empty())

	# --- 처음 보는 사람의 낮은 보고: 힌트가 나오고 승인 보류 ---
	GameState.reset()
	GameState.get_book().collect("s1_b")
	main = await fresh_main()
	main._open_report("return")
	rpt = main._report
	rpt._list.select(rpt._items.find("aging"))
	rpt.handle_key(KEY_ENTER)
	check("카드가 없을 때 안내 문구", rpt._detail.text.contains("첨부할 추론 카드가 없다"))
	rpt.handle_key(KEY_ENTER)
	check("단서가 부족하면 힌트가 나옴", rpt._detail.text.contains("힌트: ") and rpt._detail.text.contains("시청과 방송국"))
	check("승인 보류면 세계는 열리지 않음", GameState.unlocked_world == 1)

	# --- 보고 없이 재도전 ---
	GameState.reset()
	main = await fresh_main()
	main._open_report("return")
	rpt = main._report
	rpt.handle_key(KEY_N)
	check("N: 보고 없이 재도전(등급·보급품 없음)", rpt.step == rpt.Step.DONE and rpt.result.is_empty() and GameState.last_grade == "")
	old_main = main
	rpt.handle_key(KEY_ENTER)
	await wait_reload(old_main)
	check("보고 없이도 새 시뮬레이션이 시작됨", current_scene != old_main and not paused)

	# --- 귀환 장치 ---
	main = await fresh_main()
	var ret: Area2D = get_nodes_in_group("return_point")[0]
	main.player.global_position = ret.global_position
	for i in 5:
		await physics_frame
	await press("interact")
	check("귀환 장치에서 E를 누르면 보고 화면", main._report != null and main._report.reason == "return" and paused)

	# 마우스용 버튼도 키보드와 같게 동작한다
	main._report._primary.pressed.emit()
	check("버튼으로도 진행(이 원인으로 보고)", main._report.step == main._report.Step.EVIDENCE)
	main._report._secondary.pressed.emit()
	check("버튼으로 뒤로", main._report.step == main._report.Step.CAUSE)

	done = true

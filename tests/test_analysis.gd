extends SceneTree
## 단서 분석(믿음/의심, 연결, 추론 카드) 로직과 수첩 UI 흐름 테스트:
## godot --headless --path game -s tests/test_analysis.gd

const ClueBook := preload("res://scripts/clue_book.gd")
const GameState := preload("res://scripts/game_state.gd")

var fails := 0
var ui_done := false   ## _test_ui가 중간에 중단되지 않고 끝까지 갔는지


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("통과 " if ok else "실패 "), name, "  ", detail)
	if not ok:
		fails += 1


func _init() -> void:
	_test_data()
	_test_book()
	await _test_ui()
	check("수첩 UI 테스트가 끝까지 실행됨", ui_done)
	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)


# ---------------------------------------------------------------- 데이터

func _test_data() -> void:
	var book = ClueBook.new()
	check("추론 결론 후보 8개", book.statements.size() == 8, str(book.statements.size()))
	var valid_n := 0
	var bad: Array = []
	for id in book.statements:
		var st: Dictionary = book.statements[id]
		if bool(st["valid"]):
			valid_n += 1
			if st["requires"].is_empty():
				bad.append(id + ":근거 없음")
			for alt in st["requires"]:
				for need in alt:
					if not book.all.has(need):
						bad.append(id + ":없는 단서 " + need)
		if str(st["text"]).is_empty():
			bad.append(id + ":문장 없음")
	check("참인 결론 5개, 거짓 결론 3개", valid_n == 5 and book.statements.size() - valid_n == 3)
	check("결론의 근거 단서가 모두 실제 단서", bad.is_empty(), str(bad))
	# 결론 목록의 앞쪽에 참인 결론이 몰려 정답이 드러나지 않도록 섞여 있는가
	var first_three_valid := 0
	var i := 0
	for id in book.statements:
		if i < 3 and bool(book.statements[id]["valid"]):
			first_three_valid += 1
		i += 1
	check("결론 순서가 섞여 있음(앞 3개가 모두 참이 아님)", first_three_valid < 3)


# ---------------------------------------------------------------- 수첩 로직

func _test_book() -> void:
	var b = ClueBook.new()
	for id in ["s1_a", "s1_b", "s1_d", "s1_p", "s1_e", "s1_o"]:
		b.collect(id)

	check("처음엔 모든 단서가 보류", b.get_mark("s1_a") == "hold")
	check("믿음 표시", b.set_mark("s1_a", "trust") and b.get_mark("s1_a") == "trust")
	check("의심 표시", b.set_mark("s1_a", "doubt") and b.get_mark("s1_a") == "doubt")
	check("잘못된 표시값은 거부", not b.set_mark("s1_a", "great") and b.get_mark("s1_a") == "doubt")
	check("모으지 않은 단서는 표시 불가", not b.set_mark("s1_c", "trust"))

	check("연결 없음", b.get_relation("s1_a", "s1_b") == "")
	check("모순 연결", b.set_link("s1_a", "s1_b", "contradict") and b.get_relation("s1_a", "s1_b") == "contradict")
	check("연결은 방향과 상관없음", b.get_relation("s1_b", "s1_a") == "contradict")
	check("연결 덮어쓰기(뒷받침)", b.set_link("s1_b", "s1_a", "support") and b.get_relation("s1_a", "s1_b") == "support")
	check("연결은 한 쌍에 하나만", b.links.size() == 1)
	check("양쪽 단서에서 연결이 보임", b.links_of("s1_a").size() == 1 and b.links_of("s1_b")[0]["other"] == "s1_a")
	check("연결 해제", b.set_link("s1_a", "s1_b", "none") and b.get_relation("s1_a", "s1_b") == "" and b.links.is_empty())
	check("자기 자신과는 연결 불가", not b.set_link("s1_a", "s1_a", "support"))
	check("모으지 않은 단서와는 연결 불가", not b.set_link("s1_a", "s1_c", "support"))
	check("잘못된 관계값은 거부", not b.set_link("s1_a", "s1_b", "weird"))

	check("카드: 단서 2개 가능", b.add_card(["s1_d", "s1_p"], "s1_inf_structure"))
	check("카드: 같은 카드는 중복 불가(순서 달라도)", not b.add_card(["s1_p", "s1_d"], "s1_inf_structure"))
	check("카드: 단서 1개는 불가", not b.add_card(["s1_d"], "s1_inf_structure"))
	check("카드: 단서 4개는 불가", not b.add_card(["s1_a", "s1_b", "s1_d", "s1_p"], "s1_inf_structure"))
	check("카드: 단서 3개 가능", b.add_card(["s1_a", "s1_b", "s1_d"], "s1_inf_attack"))
	check("카드: 모으지 않은 단서 불가", not b.add_card(["s1_d", "s1_c"], "s1_inf_structure"))
	check("카드: 단서 중복 선택 불가", not b.add_card(["s1_d", "s1_d"], "s1_inf_structure"))
	check("카드: 없는 결론 불가", not b.add_card(["s1_d", "s1_p"], "nope"))
	check("카드 2장 저장됨", b.cards.size() == 2)

	check("평가: 근거가 충분한 참인 결론 = valid", b.evaluate_card(b.cards[0]) == "valid")
	check("평가: 거짓 결론 = wrong", b.evaluate_card(b.cards[1]) == "wrong")
	b.add_card(["s1_d", "s1_b"], "s1_inf_structure")
	check("평가: 참이지만 근거 부족 = unsupported", b.evaluate_card(b.cards[2]) == "unsupported")
	b.add_card(["s1_e", "s1_o", "s1_a"], "s1_inf_warning")
	check("평가: 근거 외 단서가 섞여도 필요한 근거가 있으면 valid", b.evaluate_card(b.cards[3]) == "valid")

	check("카드 삭제", b.remove_card(0) and b.cards.size() == 3)
	check("없는 카드 삭제 불가", not b.remove_card(9))


# ---------------------------------------------------------------- 수첩 화면

func _test_ui() -> void:
	GameState.reset()
	var book = GameState.get_book()
	for id in ["s1_a", "s1_b", "s1_d", "s1_p", "s1_e", "s1_o"]:
		book.collect(id)

	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	await physics_frame

	main._open_notebook()
	var nb = main._notebook
	check("수첩 열림, 단서 6개 표시", nb != null and nb._items.size() == 6 and paused)

	# 믿음/보류/의심
	nb._select(0)
	nb.handle_key(KEY_Z)
	check("Z: 믿음", book.get_mark("s1_a") == "trust" and nb._selected_index() == 0)
	nb.handle_key(KEY_C)
	check("C: 의심", book.get_mark("s1_a") == "doubt")
	nb.handle_key(KEY_X)
	check("X: 보류", book.get_mark("s1_a") == "hold")
	nb.handle_key(KEY_Z)
	check("목록에 표시가 반영됨", nb._list.get_item_text(0).begins_with("[+]"))

	# 연결
	nb._select(0)
	nb.handle_key(KEY_V)
	check("V: 연결 모드", nb.mode == nb.Mode.LINK_PICK)
	nb._select(1)
	nb.handle_key(KEY_ENTER)
	check("상대 단서를 고르면 관계 선택", nb.mode == nb.Mode.LINK_RELATION)
	nb.handle_key(KEY_1)
	check("1: 모순 연결 기록", book.get_relation("s1_a", "s1_b") == "contradict" and nb.mode == nb.Mode.LIST)
	check("상세에 연결이 표시됨", nb._detail.text.contains("모순"))
	nb._select(0)
	nb.handle_key(KEY_V)
	nb._select(1)
	nb.handle_key(KEY_ENTER)
	nb.handle_key(KEY_2)
	check("2: 뒷받침으로 바꿈", book.get_relation("s1_a", "s1_b") == "support")
	nb._select(0)
	nb.handle_key(KEY_V)
	nb._select(1)
	nb.handle_key(KEY_ENTER)
	nb.handle_key(KEY_3)
	check("3: 연결 해제", book.get_relation("s1_a", "s1_b") == "")
	nb._select(0)
	nb.handle_key(KEY_V)
	nb._select(0)
	nb.handle_key(KEY_ENTER)
	check("자기 자신은 고를 수 없음", nb.mode == nb.Mode.LINK_PICK)
	nb.handle_key(KEY_ESCAPE)
	check("Esc: 연결 취소", nb.mode == nb.Mode.LIST and book.links.is_empty())

	# 추론 카드
	nb.handle_key(KEY_R)
	check("R: 단서 고르기 모드", nb.mode == nb.Mode.INFER_PICK)
	nb.handle_key(KEY_ENTER)
	check("단서를 안 고르고 Enter: 진행 불가", nb.mode == nb.Mode.INFER_PICK and nb._msg.text != "")
	nb._select(2)   # s1_d
	nb.handle_key(KEY_SPACE)
	nb.handle_key(KEY_ENTER)
	check("단서 1개만 고르면 진행 불가", nb.mode == nb.Mode.INFER_PICK)
	nb._select(3)   # s1_p
	nb.handle_key(KEY_SPACE)
	check("선택한 단서가 목록에 표시됨", nb._list.get_item_text(2).begins_with("[v]") and nb._list.get_item_text(3).begins_with("[v]"))
	nb._select(0)
	nb.handle_key(KEY_SPACE)
	nb._select(1)
	nb.handle_key(KEY_SPACE)
	check("단서는 최대 3개까지", nb._checked.size() == 3)
	nb._select(0)
	nb.handle_key(KEY_SPACE)
	nb.handle_key(KEY_ENTER)
	check("Enter: 결론 고르기 모드, 결론 8개", nb.mode == nb.Mode.CONCLUDE and nb._items.size() == 8)

	nb.handle_key(KEY_ESCAPE)
	check("Esc: 단서 고르기로 돌아가며 선택 유지", nb.mode == nb.Mode.INFER_PICK and nb._checked.size() == 2)
	nb.handle_key(KEY_ENTER)
	nb._select(nb._items.find("s1_inf_structure"))
	nb.handle_key(KEY_ENTER)
	check("Enter: 카드 확정", book.cards.size() == 1 and nb.mode == nb.Mode.LIST)
	var msg_valid: String = nb._msg.text
	check("카드 확정 안내 표시", msg_valid == "추론 카드를 만들었다.")

	# 틀린 결론으로 만들어도 같은 안내만 나온다 (정답 여부 비공개)
	nb.handle_key(KEY_R)
	nb._select(0)
	nb.handle_key(KEY_SPACE)
	nb._select(1)
	nb.handle_key(KEY_SPACE)
	nb.handle_key(KEY_ENTER)
	nb._select(nb._items.find("s1_inf_attack"))
	nb.handle_key(KEY_ENTER)
	check("틀린 결론도 같은 안내(정답 여부 비공개)", nb._msg.text == msg_valid and book.cards.size() == 2)
	check("저장된 카드의 평가는 따로 확인 가능",
		book.evaluate_card(book.cards[0]) == "valid" and book.evaluate_card(book.cards[1]) == "wrong")

	# 카드 목록
	nb.handle_key(KEY_TAB)
	check("Tab: 카드 목록", nb.mode == nb.Mode.CARDS and nb._items.size() == 2)
	check("카드 상세에 결론과 근거 단서 표시", nb._detail.text.contains("결론") and nb._detail.text.contains("근거 단서"))
	nb.handle_key(KEY_DELETE)
	check("Del: 카드 삭제", book.cards.size() == 1)
	nb.handle_key(KEY_TAB)
	check("Tab: 단서 목록으로 복귀", nb.mode == nb.Mode.LIST)

	# 닫기
	nb.handle_key(KEY_ESCAPE)
	await physics_frame
	await physics_frame
	check("Esc: 수첩 닫힘", not paused and main._notebook == null)

	# 장면을 다시 불러와도 분석 결과가 유지됨
	reload_current_scene()
	var waited := 0
	while (current_scene == null or current_scene == main) and waited < 30:
		await physics_frame
		waited += 1
	check("장면이 새로 불러와짐", current_scene != null and current_scene != main)
	var book2 = GameState.get_book()
	check("재시작 후에도 표시·카드 유지", book2.get_mark("s1_a") == "trust" and book2.cards.size() == 1)

	# 단서가 하나도 없을 때도 수첩이 깨지지 않는다
	GameState.reset()
	var main2 = current_scene
	main2._open_notebook()
	var nb2 = main2._notebook
	var keys := [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_R, KEY_TAB, KEY_DELETE, KEY_TAB, KEY_ENTER, KEY_SPACE]
	for k in keys:
		nb2.handle_key(k)
	check("단서가 없어도 모든 키 입력이 안전함", nb2.mode == nb2.Mode.LIST and nb2._items.is_empty())
	check("단서가 없으면 안내 문구 표시", nb2._detail.text.contains("아직 모은 단서가 없다"))
	nb2.handle_key(KEY_R)
	check("단서가 부족하면 추론 카드를 만들 수 없음", nb2.mode == nb2.Mode.LIST and nb2._msg.text != "")
	ui_done = true

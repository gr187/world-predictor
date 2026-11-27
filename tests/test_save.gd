extends SceneTree
## 저장·불러오기 테스트: godot --headless --path game -s tests/test_save.gd
## 실제 저장 파일(user://save.json)을 건드리지 않도록 시험용 경로를 쓴다.

const GameState := preload("res://scripts/game_state.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const TEST_PATH := "user://test_save.json"

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("통과 " if ok else "실패 "), name, "  ", detail)
	if not ok:
		fails += 1


func write_raw(text: String) -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func snapshot() -> String:
	return JSON.stringify(SaveGame.to_dict(), "", true)


## 진행 상태를 채운다 (저장 대상 전부)
func fill_state() -> void:
	GameState.reset()
	var b = GameState.get_book()
	for id in ["s1_a", "s1_b", "s1_d", "s1_p", "s1_e", "s1_o"]:
		b.collect(id)
	b.set_mark("s1_a", "doubt")
	b.set_mark("s1_b", "trust")
	b.set_link("s1_a", "s1_b", "contradict")
	b.set_link("s1_d", "s1_p", "support")
	b.add_card(["s1_d", "s1_p"], "s1_inf_structure")
	b.add_card(["s1_e", "s1_o"], "s1_inf_warning")
	GameState.unlocked_world = 2
	GameState.last_grade = "B"
	GameState.pending_supplies = ["suit", "kit"]
	GameState.set_flag("world1_shortcut", true)   # 영구
	GameState.set_flag("lever_a")                 # 이번 판만
	GameState.active_supplies = ["battery"]       # 이번 판만
	GameState.seen_guide = true


func _init() -> void:
	SaveGame.path = TEST_PATH
	SaveGame.autosave_enabled = false
	SaveGame.delete()

	check("저장 파일이 없으면 불러오기는 false", not SaveGame.exists() and not SaveGame.load_into_state())

	# --- 저장 후 불러오기 ---
	fill_state()
	var before := snapshot()
	check("저장 성공, 파일 생김", SaveGame.save() and SaveGame.exists())
	check("임시 파일이 남지 않음", not FileAccess.file_exists(TEST_PATH + ".tmp"))

	GameState.reset()
	check("초기화하면 수첩이 비어 있음", GameState.get_book().count() == 0 and GameState.unlocked_world == 1)
	check("불러오기 성공", SaveGame.load_into_state())
	var b = GameState.get_book()
	check("단서와 획득 순서 복원", b.order == ["s1_a", "s1_b", "s1_d", "s1_p", "s1_e", "s1_o"])
	check("믿음/의심 표시 복원", b.get_mark("s1_a") == "doubt" and b.get_mark("s1_b") == "trust" and b.get_mark("s1_d") == "hold")
	check("단서 연결 복원", b.get_relation("s1_a", "s1_b") == "contradict" and b.get_relation("s1_d", "s1_p") == "support")
	check("추론 카드 복원", b.cards.size() == 2 and b.evaluate_card(b.cards[0]) == "valid")
	check("열린 세계·마지막 등급 복원", GameState.unlocked_world == 2 and GameState.last_grade == "B")
	check("받아 둔 보급품 복원", GameState.pending_supplies == ["suit", "kit"])
	check("지름길(영구)은 복원", GameState.permanent_flags.has("world1_shortcut"))
	check("이번 판 맵 상태는 저장하지 않음", GameState.run_flags.is_empty())
	check("적용 중이던 보급품은 저장하지 않음", GameState.active_supplies.is_empty())
	check("조작 안내를 봤다는 기록 복원", GameState.seen_guide)
	check("저장 → 불러오기 → 다시 저장한 내용이 같음", snapshot() == before)

	# 덮어쓰기를 반복해도 정상
	check("같은 위치에 여러 번 저장", SaveGame.save() and SaveGame.save() and SaveGame.load_into_state())

	# --- 자동 저장 ---
	SaveGame.delete()
	SaveGame.autosave()
	check("자동 저장이 꺼져 있으면 파일을 만들지 않음", not SaveGame.exists())
	SaveGame.autosave_enabled = true
	SaveGame.autosave()
	check("자동 저장이 켜져 있으면 저장함", SaveGame.exists())
	SaveGame.autosave_enabled = false

	# --- 깨진 파일은 거부하고 현재 상태를 그대로 둔다 ---
	var bad_cases := {
		"JSON이 아닌 내용": "이건 저장 파일이 아님",
		"빈 객체": "{}",
		"배열": "[1, 2, 3]",
		"버전이 다름": '{"version": 99, "clues": {}, "state": {}}',
		"clues 없음": '{"version": 1, "state": {}}',
		"없는 단서 id": '{"version": 1, "clues": {"order": ["nope"]}, "state": {}}',
		"단서 중복": '{"version": 1, "clues": {"order": ["s1_a", "s1_a"]}, "state": {}}',
		"order가 문자열": '{"version": 1, "clues": {"order": "s1_a"}, "state": {}}',
		"모으지 않은 단서에 표시": '{"version": 1, "clues": {"order": ["s1_a"], "marks": {"s1_b": "trust"}}, "state": {}}',
		"잘못된 표시값": '{"version": 1, "clues": {"order": ["s1_a"], "marks": {"s1_a": "great"}}, "state": {}}',
		"모으지 않은 단서끼리 연결": '{"version": 1, "clues": {"order": ["s1_a"], "links": [{"a": "s1_a", "b": "s1_b", "relation": "support"}]}, "state": {}}',
		"연결 관계가 잘못됨": '{"version": 1, "clues": {"order": ["s1_a", "s1_b"], "links": [{"a": "s1_a", "b": "s1_b", "relation": "weird"}]}, "state": {}}',
		"카드 단서가 1개": '{"version": 1, "clues": {"order": ["s1_a"], "cards": [{"clues": ["s1_a"], "statement": "s1_inf_attack"}]}, "state": {}}',
		"없는 결론의 카드": '{"version": 1, "clues": {"order": ["s1_a", "s1_b"], "cards": [{"clues": ["s1_a", "s1_b"], "statement": "nope"}]}, "state": {}}',
		"열린 세계 범위 밖": '{"version": 1, "clues": {}, "state": {"unlocked_world": 9}}',
		"등급이 잘못됨": '{"version": 1, "clues": {}, "state": {"last_grade": "Z"}}',
		"없는 보급품": '{"version": 1, "clues": {}, "state": {"pending_supplies": ["bomb"]}}',
		"지름길 이름이 숫자": '{"version": 1, "clues": {}, "state": {"permanent_flags": [5]}}',
	}
	for name in bad_cases:
		GameState.reset()
		GameState.get_book().collect("s1_c")   # 현재 상태 표시용
		GameState.unlocked_world = 3
		write_raw(bad_cases[name])
		var ok_load := SaveGame.load_into_state()
		check("깨진 파일 거부: " + name, not ok_load and GameState.get_book().has("s1_c") and GameState.unlocked_world == 3)

	# 최소한의 올바른 파일은 읽힌다 (빈 진행)
	write_raw('{"version": 1, "clues": {}, "state": {}}')
	GameState.reset()
	check("최소한의 올바른 저장 파일은 불러와짐", SaveGame.load_into_state() and GameState.get_book().count() == 0 and GameState.unlocked_world == 1)

	# 정리
	SaveGame.delete()
	check("삭제하면 파일이 없어짐", not SaveGame.exists())
	GameState.reset()
	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)

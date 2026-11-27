extends SceneTree
## Dialogue Manager 도입 확인(스모크 테스트): 전역이 로드되고 대화를 만들어 진행할 수 있는가.
## 우리 게임의 대화 시스템 자체는 다음 단계에서 만든다.
## godot --headless --path game -s tests/test_dialogue_addon.gd

const GameState := preload("res://scripts/game_state.gd")

var fails := 0
var done := false


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("통과 " if ok else "실패 "), name, "  ", detail)
	if not ok:
		fails += 1


## 대화에서 우리 게임 상태를 읽고 바꾸는 데 쓸 다리(임시 형태)
class Bridge:
	func has_clue(id: String) -> bool:
		return GameState.get_book().has(id)

	func give_clue(id: String) -> void:
		GameState.get_book().collect(id)

	func unlock_shortcut(flag: String) -> void:
		GameState.set_flag(flag, true)


func _init() -> void:
	await process_frame
	await process_frame
	GameState.reset()

	var dm = root.get_node_or_null("DialogueManager")
	check("DialogueManager 전역이 로드됨", dm != null)
	if dm == null:
		quit(1)
		return

	var text := "~ start\n노인: 안녕하게.\n- 증거를 보여 준다 [if has_clue(\"s1_f\") /]\n\t$> give_clue(\"s1_c\")\n\t$> unlock_shortcut(\"elder_key\")\n\t노인: 열쇠를 가져가게.\n\t=> END\n- 떠난다 => END\n"
	var res = dm.create_resource_from_text(text)
	check("텍스트에서 대화 리소스를 만듦", res != null)

	var bridge := Bridge.new()
	var line = await dm.get_next_dialogue_line(res, "start", [bridge])
	check("한글 대사와 인물 이름", line != null and line.character == "노인" and line.text == "안녕하게.")
	var allowed := 0
	for r in line.responses:
		if r.is_allowed:
			allowed += 1
	check("단서가 없으면 증거 제시 선택지는 허용되지 않음", line.responses.size() == 2 and allowed == 1, "전체 %d 허용 %d" % [line.responses.size(), allowed])

	# 우리 게임의 단서 수첩 상태가 대화 조건으로 쓰인다
	GameState.get_book().collect("s1_f")
	line = await dm.get_next_dialogue_line(res, "start", [bridge])
	allowed = 0
	var evidence = null
	for r in line.responses:
		if r.is_allowed:
			allowed += 1
		if r.text.begins_with("증거를"):
			evidence = r
	check("수첩에 단서(s1_f)가 있으면 증거 제시 선택지가 열림", allowed == 2 and evidence != null)

	# 선택하면 대화가 우리 게임 상태(단서, 영구 지름길)를 바꾼다
	var next = await dm.get_next_dialogue_line(res, evidence.next_id, [bridge])
	check("대화 동작으로 단서가 수첩에 들어옴", GameState.get_book().has("s1_c"))
	check("대화 동작으로 지름길(영구 상태)이 열림", GameState.permanent_flags.has("elder_key") and not GameState.run_flags.has("elder_key"))
	check("선택 후 대사", next != null and next.text == "열쇠를 가져가게.")
	var end = await dm.get_next_dialogue_line(res, next.next_id, [bridge])
	check("대화가 끝남", end == null)

	GameState.reset()
	done = true
	check("끝까지 실행됨", done)
	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)

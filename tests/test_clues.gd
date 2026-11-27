extends SceneTree
## 단서 데이터·수첩 로직 테스트: godot --headless --path game -s tests/test_clues.gd

const ClueBook := preload("res://scripts/clue_book.gd")
const GameState := preload("res://scripts/game_state.gd")

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("통과 " if ok else "실패 "), name, "  ", detail)
	if not ok:
		fails += 1


func _init() -> void:
	var book = ClueBook.new()
	check("세계 1 단서 16개", book.total() == 16, str(book.total()))

	var bad: Array = []
	for id in book.all:
		var c: Dictionary = book.all[id]
		var good: bool = c.has_all(["world", "type", "source", "time", "text", "truth", "hint"]) \
			and str(c["hint"]).length() > 0 \
			and c["type"] in ClueBook.TYPES \
			and c["time"] in ClueBook.TIMES \
			and c["truth"] in ClueBook.TRUTHS \
			and str(c["text"]).length() > 0 and str(c["source"]).length() > 0
		if not good:
			bad.append(id)
	check("모든 단서의 필드와 값이 유효", bad.is_empty(), str(bad))

	var types_used := {}
	var truths_used := {}
	for id in book.all:
		types_used[book.all[id]["type"]] = true
		truths_used[book.all[id]["truth"]] = true
	check("단서 종류 4가지 모두 사용", types_used.size() == 4)
	check("신뢰도 4가지 모두 사용", truths_used.size() == 4)

	check("처음엔 모은 단서 없음", book.count() == 0 and book.collected().is_empty())
	check("새 단서 획득", book.collect("s1_b") and book.has("s1_b"))
	check("같은 단서 중복 획득 불가", not book.collect("s1_b") and book.count() == 1)
	check("없는 단서 획득 불가", not book.collect("nope") and book.count() == 1)
	book.collect("s1_a")
	var got: Array = book.collected()
	check("획득 순서 유지", got.size() == 2 and got[0]["id"] == "s1_b" and got[1]["id"] == "s1_a")

	# 장면을 다시 불러와도 유지되는 상태
	GameState.reset()
	var gs = GameState.get_book()
	gs.collect("s1_d")
	check("GameState가 같은 수첩을 유지", GameState.get_book() == gs and GameState.get_book().has("s1_d"))
	GameState.reset()
	check("reset하면 비워짐", GameState.get_book().count() == 0)

	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)

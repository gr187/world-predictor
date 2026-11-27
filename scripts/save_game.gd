extends RefCounted
## 진행 상황 저장·불러오기. 파일은 user://save.json (Windows: %APPDATA%\Godot\app_userdata\<프로젝트 이름>\).
##
## 저장하는 것: 모은 단서, 믿음/의심 표시, 단서 연결, 추론 카드, 열린 세계, 마지막 보고 등급,
##              받아 둔 보급품, 지름길(영구 맵 상태), 조작 안내를 봤는지
## 저장하지 않는 것: 이번 판의 맵 상태(전력 레버 등), 지금 적용 중인 보급품 → 새 시뮬레이션마다 초기화되는 값이기 때문
##
## 파일이 깨졌거나 내용이 이상하면 불러오지 않고(false) 현재 상태를 그대로 둔다.

const GameState := preload("res://scripts/game_state.gd")
const ClueBook := preload("res://scripts/clue_book.gd")
const ReportLogic := preload("res://scripts/report_logic.gd")

const VERSION := 1
const GRADES := ["", "S", "A", "B", "C", "D"]

static var path := "user://save.json"
static var autosave_enabled := false   ## 실제 플레이(타이틀에서 시작)일 때만 켠다. 테스트·시험장에서는 꺼 둔다.


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(path)


static func to_dict() -> Dictionary:
	var book = GameState.get_book()
	var order: Array = []
	for id in book.order:
		order.append(id)
	return {
		"version": VERSION,
		"clues": {
			"order": order,
			"marks": book.marks.duplicate(),
			"links": book.links.duplicate(true),
			"cards": book.cards.duplicate(true),
		},
		"state": {
			"current_world": GameState.current_world,
			"unlocked_world": GameState.unlocked_world,
			"last_grade": GameState.last_grade,
			"pending_supplies": GameState.pending_supplies.duplicate(),
			"permanent_flags": GameState.permanent_flags.keys(),
			"seen_guide": GameState.seen_guide,
		},
	}


## 저장 중에 꺼져도 기존 파일이 깨지지 않게, 임시 파일에 쓴 뒤 바꿔치기한다.
static func save() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("저장 파일을 쓸 수 없습니다: " + tmp)
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("저장 파일을 바꿀 수 없습니다: %d" % err)
		return false
	return true


## 진행이 바뀌는 때(단서 획득, 보고 등)에 부른다. 실제 플레이에서만 저장한다.
static func autosave() -> void:
	if autosave_enabled:
		save()


## 저장 파일을 읽어 현재 상태에 적용한다. 문제가 있으면 아무것도 바꾸지 않고 false.
static func load_into_state() -> bool:
	if not exists():
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed
	if int(data.get("version", -1)) != VERSION:
		return false
	var clues: Variant = data.get("clues")
	var state: Variant = data.get("state")
	if not (clues is Dictionary) or not (state is Dictionary):
		return false

	# 새 수첩을 만들어 하나씩 검증하며 채운다. 하나라도 이상하면 통째로 거부.
	var book = ClueBook.new()
	var order: Variant = clues.get("order", [])
	if not (order is Array):
		return false
	for id in order:
		if not (id is String) or not book.collect(id):
			return false

	var marks: Variant = clues.get("marks", {})
	if not (marks is Dictionary):
		return false
	for id in marks:
		if not (marks[id] is String) or not book.set_mark(String(id), String(marks[id])):
			return false

	var links: Variant = clues.get("links", [])
	if not (links is Array):
		return false
	for l in links:
		if not (l is Dictionary) or not (l.get("a") is String) or not (l.get("b") is String) or not (l.get("relation") is String):
			return false
		if not book.set_link(l["a"], l["b"], l["relation"]) or l["relation"] == "none":
			return false

	var cards: Variant = clues.get("cards", [])
	if not (cards is Array):
		return false
	for c in cards:
		if not (c is Dictionary) or not (c.get("clues") is Array) or not (c.get("statement") is String):
			return false
		if not book.add_card(c["clues"], c["statement"]):
			return false

	var cur := int(state.get("current_world", 1))
	var unlocked := int(state.get("unlocked_world", 1))
	if cur < 1 or cur > GameState.WORLD_COUNT or unlocked < 1 or unlocked > GameState.WORLD_COUNT:
		return false
	var grade: Variant = state.get("last_grade", "")
	if not (grade is String) or not GRADES.has(grade):
		return false

	var known_supplies: Array = []
	for s in ReportLogic.new().supplies():
		known_supplies.append(s["id"])
	var supplies: Variant = state.get("pending_supplies", [])
	if not (supplies is Array):
		return false
	var supplies_out: Array = []
	for s in supplies:
		if not (s is String) or not known_supplies.has(s):
			return false
		supplies_out.append(s)

	var flags: Variant = state.get("permanent_flags", [])
	if not (flags is Array):
		return false
	var flags_out := {}
	for flag in flags:
		if not (flag is String):
			return false
		flags_out[flag] = true

	# 검증 통과: 적용
	GameState.set_book(book)
	GameState.current_world = cur
	GameState.unlocked_world = unlocked
	GameState.last_grade = grade
	GameState.pending_supplies = supplies_out
	GameState.permanent_flags = flags_out
	GameState.seen_guide = bool(state.get("seen_guide", false))
	GameState.run_flags = {}
	GameState.active_supplies = []
	return true

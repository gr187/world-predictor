extends RefCounted
## 단서 수첩 데이터. 모은 단서, 믿음/의심 표시, 단서 사이의 연결, 추론 카드를 기록한다.
## 숨은 신뢰도("truth")와 결론의 정답 여부("valid")는 UI에 노출하지 않는다. 평가는 보고서 단계에서 한다.

const TYPES := ["증언", "기록", "환경", "물증"]
const TIMES := ["사건 전", "사건 중", "사건 후"]
const TRUTHS := ["valid", "partial", "mistaken", "false"]
const MARKS := ["trust", "hold", "doubt"]            ## 믿음 / 보류 / 의심
const RELATIONS := ["contradict", "support"]         ## 모순 / 뒷받침
const CARD_MIN := 2
const CARD_MAX := 3

var all: Dictionary = {}          ## id -> 단서 데이터
var statements: Dictionary = {}   ## id -> 추론 결론 후보 데이터
var order: Array[String] = []     ## 획득 순서
var marks: Dictionary = {}        ## id -> 믿음/보류/의심 (없으면 보류)
var links: Array = []             ## {"a", "b", "relation"} (a < b)
var cards: Array = []             ## {"clues": Array, "statement": String}


func _init(path: String = "res://data/clues.json", statements_path: String = "res://data/inferences.json") -> void:
	all = _load_dict(path)
	statements = _load_dict(statements_path)


func _load_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("데이터를 열 수 없습니다: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func total() -> int:
	return all.size()


func count() -> int:
	return order.size()


func has(id: String) -> bool:
	return order.has(id)


## 새로 얻었으면 true, 이미 있거나 없는 단서면 false.
func collect(id: String) -> bool:
	if not all.has(id) or order.has(id):
		return false
	order.append(id)
	return true


## 획득 순서대로 단서 데이터(id 포함)를 돌려준다.
func collected() -> Array:
	var result: Array = []
	for id in order:
		var c: Dictionary = (all[id] as Dictionary).duplicate()
		c["id"] = id
		result.append(c)
	return result


# ---------------------------------------------------------------- 믿음/의심 표시

func get_mark(id: String) -> String:
	return marks.get(id, "hold")


func set_mark(id: String, mark: String) -> bool:
	if not has(id) or not MARKS.has(mark):
		return false
	marks[id] = mark
	return true


# ---------------------------------------------------------------- 연결(모순/뒷받침)

## 두 단서의 연결 관계. 없으면 "".
func get_relation(a: String, b: String) -> String:
	var i := _link_index(a, b)
	return "" if i < 0 else String(links[i]["relation"])


## relation: "contradict", "support", "none"(연결 해제). 잘못된 입력이면 false.
func set_link(a: String, b: String, relation: String) -> bool:
	if a == b or not has(a) or not has(b):
		return false
	if relation != "none" and not RELATIONS.has(relation):
		return false
	var i := _link_index(a, b)
	if i >= 0:
		links.remove_at(i)
	if relation != "none":
		links.append({"a": mini_str(a, b), "b": maxi_str(a, b), "relation": relation})
	return true


## id와 연결된 단서들: [{"other": id, "relation": r}]
func links_of(id: String) -> Array:
	var result: Array = []
	for l in links:
		if l["a"] == id:
			result.append({"other": l["b"], "relation": l["relation"]})
		elif l["b"] == id:
			result.append({"other": l["a"], "relation": l["relation"]})
	return result


func _link_index(a: String, b: String) -> int:
	var lo := mini_str(a, b)
	var hi := maxi_str(a, b)
	for i in links.size():
		if links[i]["a"] == lo and links[i]["b"] == hi:
			return i
	return -1


static func mini_str(a: String, b: String) -> String:
	return a if a < b else b


static func maxi_str(a: String, b: String) -> String:
	return b if a < b else a


# ---------------------------------------------------------------- 추론 카드

## 단서 2~3개를 묶어 결론을 확정한다. 정답 여부는 알려 주지 않는다.
func add_card(clue_ids: Array, statement_id: String) -> bool:
	if not statements.has(statement_id):
		return false
	var ids: Array = []
	for id in clue_ids:
		if not has(id) or ids.has(id):
			return false
		ids.append(id)
	if ids.size() < CARD_MIN or ids.size() > CARD_MAX:
		return false
	ids.sort()
	for c in cards:
		if c["statement"] == statement_id and c["clues"] == ids:
			return false
	cards.append({"clues": ids, "statement": statement_id})
	return true


func remove_card(index: int) -> bool:
	if index < 0 or index >= cards.size():
		return false
	cards.remove_at(index)
	return true


## 보고서·테스트용. UI에는 보여 주지 않는다.
## "wrong": 사실이 아닌 결론 / "unsupported": 사실이지만 근거 단서가 부족 / "valid": 근거가 충분한 참인 결론
func evaluate_card(card: Dictionary) -> String:
	var st: Dictionary = statements.get(card["statement"], {})
	if st.is_empty() or not bool(st["valid"]):
		return "wrong"
	var have: Array = card["clues"]
	for alt in st["requires"]:
		var ok := true
		for need in alt:
			if not have.has(need):
				ok = false
		if ok:
			return "valid"
	return "unsupported"

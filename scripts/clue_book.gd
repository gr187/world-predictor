extends RefCounted
## 단서 수첩 데이터. 어떤 단서를 모았는지 기록한다. (숨은 신뢰도 "truth"는 UI에 노출하지 않는다)

const TYPES := ["증언", "기록", "환경", "물증"]
const TIMES := ["사건 전", "사건 중", "사건 후"]
const TRUTHS := ["valid", "partial", "mistaken", "false"]

var all: Dictionary = {}          ## id -> 단서 데이터
var order: Array[String] = []     ## 획득 순서


func _init(path: String = "res://data/clues.json") -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("단서 데이터를 열 수 없습니다: " + path)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		all = parsed


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

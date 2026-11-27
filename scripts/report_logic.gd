extends RefCounted
## 보고서 평가. 결론(40) + 근거(40) + 판단력(20) = 100점. 수치는 모두 임시값.
## 설계: design/03_보고서_설계.md

const CONCLUSION_MAX := 40
const EVIDENCE_MAX := 40
const JUDGMENT_MAX := 20
const EVIDENCE_VALID := 15        ## 참이고 근거가 충분하며 고른 원인을 뒷받침하는 카드
const EVIDENCE_UNSUPPORTED := 5   ## 참이지만 근거가 부족한 카드
const EVIDENCE_WRONG := -10       ## 거짓 결론 카드

var data: Dictionary = {}


func _init(path: String = "res://data/report.json") -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("보고서 데이터를 열 수 없습니다: " + path)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		data = parsed


func causes() -> Array:
	return data["causes"]


func supplies() -> Array:
	return data["supplies"]


func supply_name(id: String) -> String:
	for s in supplies():
		if s["id"] == id:
			return s["name"]
	return id


func conclusion_score(cause_id: String) -> int:
	for c in causes():
		if c["id"] == cause_id:
			return int(c["score"])
	return 0


## card_indices: book.cards의 인덱스 목록
func evidence_score(book, cause_id: String, card_indices: Array) -> int:
	var sum := 0
	for i in card_indices:
		if i < 0 or i >= book.cards.size():
			continue
		var card: Dictionary = book.cards[i]
		var verdict: String = book.evaluate_card(card)
		if verdict == "wrong":
			sum += EVIDENCE_WRONG
			continue
		var supports: Array = book.statements[card["statement"]].get("supports", [])
		if not supports.has(cause_id):
			continue
		sum += EVIDENCE_VALID if verdict == "valid" else EVIDENCE_UNSUPPORTED
	return clampi(sum, 0, EVIDENCE_MAX)


## 수집한 단서에 대한 믿음/의심 표시가 숨은 신뢰도와 얼마나 맞는가.
func judgment_score(book) -> float:
	var n: int = book.count()
	if n == 0:
		return 0.0
	var sum := 0.0
	for id in book.order:
		var truth: String = book.all[id]["truth"]
		var mark: String = book.get_mark(id)
		match truth:
			"valid":
				if mark == "trust": sum += 1.0
				elif mark == "doubt": sum -= 1.0
			"false", "mistaken":
				if mark == "doubt": sum += 1.0
				elif mark == "trust": sum -= 1.0
			"partial":
				if mark == "hold": sum += 0.5
	return JUDGMENT_MAX * maxf(sum, 0.0) / n


func grade_for(total: float) -> String:
	for g in data["grades"]:
		if total >= float(g["min"]):
			return g["grade"]
	return "D"


func grade_passes(grade: String) -> bool:
	var order: Array = []
	for g in data["grades"]:
		order.append(g["grade"])
	return order.find(grade) <= order.find(data["unlock_grade"])


func supply_count(grade: String) -> int:
	return int(data["supply_count"].get(grade, 0))


## 아직 모으지 못한 단서 중 첫 번째의 힌트. 다 모았으면 "".
func pick_hint(book) -> String:
	for id in book.all:
		if not book.has(id):
			return String(book.all[id].get("hint", ""))
	return ""


func evaluate(book, cause_id: String, card_indices: Array) -> Dictionary:
	var conclusion := conclusion_score(cause_id)
	var evidence := evidence_score(book, cause_id, card_indices)
	var judgment := judgment_score(book)
	var total := float(conclusion + evidence) + judgment
	var grade := grade_for(total)

	# 비율이 가장 낮은 요소(동률이면 결론, 근거, 판단력 순)
	var ratios := {
		"conclusion": float(conclusion) / CONCLUSION_MAX,
		"evidence": float(evidence) / EVIDENCE_MAX,
		"judgment": judgment / JUDGMENT_MAX,
	}
	var weakest := "conclusion"
	for k in ["evidence", "judgment"]:
		if ratios[k] < ratios[weakest]:
			weakest = k

	var comment: String
	if grade == "S":
		comment = "%s %s" % [data["openers"][grade], data["praise"]]
	else:
		comment = "%s %s" % [data["openers"][grade], data["weak"][weakest]]

	return {
		"conclusion": conclusion, "evidence": evidence, "judgment": judgment,
		"total": total, "grade": grade, "passed": grade_passes(grade),
		"weakest": weakest, "comment": comment, "hint": pick_hint(book),
		"supply_count": supply_count(grade),
	}

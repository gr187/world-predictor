extends RefCounted
## 맵 도달 가능성 검사(타일 기반 근사). 시작 위치에서 모든 단서·귀환 장치·레버에 닿을 수 있는지 확인한다.
##
## 플레이어를 '1칸 폭, 2칸 높이'로 보고, 발이 놓인 칸(feet)의 좌표로 위치를 나타낸다.
## 할 수 있는 움직임(보수적으로 잡음):
##  - 걷기, 모서리에서 떨어지기
##  - 점프: 올라가는 높이 3칸 이하, 가로 거리는 높이가 클수록 줄어든다 (같은 높이·아래로는 4칸, +1칸 3칸, +2칸 2칸, +3칸 1칸)
##  - 사다리 오르내리기, 승강기 타기(두 정류장 사이)
##  - 문과 레버: 전력 레버 둘이 닿으면 전력 문이 열리고, 지름길 레버가 닿으면 지름길 문이 열린다(고정점 반복).
## 실제 물리와 완전히 같지는 않으므로, 핵심 구간은 물리 테스트로 따로 확인한다.

const WorldBuilder := preload("res://scripts/world_builder.gd")

const TARGET_CHARS := "abcdefghijklmnopX12!^v"
const MAX_JUMP_UP := 3

var cells: Dictionary = {}
var bounds := Rect2i()
var power := false
var shortcut := false

var _ladders: Array = []          ## {"col", "top", "bottom"} (칸 번호)
var _lifts: Array = []            ## {"col", "up", "down"} (발 칸 줄 번호)
var _standable_rows: Dictionary = {}   ## 열 -> 서 있을 수 있는 줄 목록


func _init(world: Dictionary) -> void:
	cells = world["cells"]
	bounds = world["bounds"]
	_ladders = WorldBuilder.ladder_runs(cells)
	var ups := {}
	var downs := {}
	for key in cells:
		if cells[key] == "^":
			ups[key.x] = key.y
		elif cells[key] == "v":
			downs[key.x] = key.y
	for col in ups:
		if downs.has(col):
			_lifts.append({"col": col, "up": ups[col], "down": downs[col]})


# ---------------------------------------------------------------- 칸 판정

func _ch(c: int, r: int) -> String:
	return String(cells.get(Vector2i(c, r), ""))


func solid(c: int, r: int) -> bool:
	if c < bounds.position.x or c >= bounds.end.x:
		return true
	match _ch(c, r):
		"#", "w":
			return true
		"D":
			return not power
		"G":
			return not shortcut
	return false


## 발 아래 칸(row)이 설 수 있는 바닥인가
func has_support(c: int, row: int) -> bool:
	if solid(c, row):
		return true
	var ch := _ch(c, row)
	if ch == "-":
		return true
	if ch == "H" and _ch(c, row - 1) != "H":
		return true   # 사다리 꼭대기
	for l in _lifts:
		if absi(c - int(l["col"])) <= 1 and (row == int(l["up"]) + 1 or row == int(l["down"]) + 1):
			return true   # 승강기 발판이 서는 높이
	return false


func standable(c: int, r: int) -> bool:
	if r < bounds.position.y or r >= bounds.end.y:
		return false
	return not solid(c, r) and not solid(c, r - 1) and has_support(c, r + 1)


func _rebuild_standable() -> void:
	_standable_rows.clear()
	for c in range(bounds.position.x, bounds.end.x):
		var rows: Array = []
		for r in range(bounds.position.y, bounds.end.y):
			if standable(c, r):
				rows.append(r)
		_standable_rows[c] = rows


# ---------------------------------------------------------------- 이동

func neighbors(n: Vector2i) -> Array:
	var out: Array = []
	var c := n.x
	var r := n.y

	# 사다리: 맨 위(꼭대기에 선 칸)부터 맨 아래 칸까지 한 칸씩 오르내림
	for lad in _ladders:
		if lad["col"] == c and r >= int(lad["top"]) - 1 and r <= int(lad["bottom"]):
			if r - 1 >= int(lad["top"]) - 1:
				out.append(Vector2i(c, r - 1))
			if r + 1 <= int(lad["bottom"]):
				out.append(Vector2i(c, r + 1))

	# 승강기: 두 정류장 사이 (발판 폭 3칸 어디에 서 있어도 같은 칸으로 이동)
	for l in _lifts:
		if absi(c - int(l["col"])) <= 1:
			if r == int(l["up"]):
				out.append(Vector2i(c, int(l["down"])))
			elif r == int(l["down"]):
				out.append(Vector2i(c, int(l["up"])))

	if not standable(c, r):
		return out

	# 걷기 / 모서리에서 떨어지기
	for d in [-1, 1]:
		var c2: int = c + d
		if solid(c2, r) or solid(c2, r - 1):
			continue
		if standable(c2, r):
			out.append(Vector2i(c2, r))
		else:
			var rr := r + 1
			while rr < bounds.end.y and not solid(c2, rr):
				if standable(c2, rr):
					out.append(Vector2i(c2, rr))
					break
				rr += 1

	# 점프
	for c2 in range(c - 4, c + 5):
		if c2 == c:
			continue
		for r2 in _standable_rows.get(c2, []):
			var dr: int = r - r2   # 양수면 위로 올라감
			if dr > MAX_JUMP_UP:
				continue
			var limit := 4
			if dr == 1:
				limit = 3
			elif dr == 2:
				limit = 2
			elif dr == 3:
				limit = 1
			if absi(c2 - c) > limit:
				continue
			if _jump_clear(c, r, c2, r2):
				out.append(Vector2i(c2, r2))
	return out


## 점프 경로에 막힌 칸이 없는가 (경로가 지나는 직사각형 안)
func _jump_clear(c: int, r: int, c2: int, r2: int) -> bool:
	var top := mini(r, r2) - 1
	for col in range(mini(c, c2), maxi(c, c2) + 1):
		var bottom := maxi(r, r2)
		if col == c:
			bottom = r
		elif col == c2:
			bottom = r2
		for row in range(top, bottom + 1):
			if solid(col, row):
				return false
	return true


func reach(start: Vector2i) -> Dictionary:
	_rebuild_standable()
	var seen := {start: true}
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var n: Vector2i = queue[head]
		head += 1
		for m in neighbors(n):
			if not seen.has(m):
				seen[m] = true
				queue.append(m)
	return seen


## 시작 위치(@)에서 닿을 수 있는 곳을 구한다. 레버로 열리는 문까지 고려해 상태가 안정될 때까지 반복한다.
## 반환: {"reached", "missing": [{"ch", "pos"}], "power", "shortcut", "targets": 확인한 칸 수}
func analyze() -> Dictionary:
	var start := Vector2i(-1, -1)
	for key in cells:
		if cells[key] == "@":
			start = key
	if start.x < 0:
		return {"reached": {}, "missing": [], "power": false, "shortcut": false, "targets": 0, "error": "시작 위치(@) 없음"}

	power = false
	shortcut = false
	var seen: Dictionary = {}
	for i in 8:
		seen = reach(start)
		var lever_a := false
		var lever_b := false
		var lever_s := false
		for key in cells:
			if not seen.has(key):
				continue
			match cells[key]:
				"1": lever_a = true
				"2": lever_b = true
				"!": lever_s = true
		var new_power := lever_a and lever_b
		if new_power == power and lever_s == shortcut:
			break
		power = new_power
		shortcut = lever_s

	var missing: Array = []
	var targets := 0
	for key in cells:
		var ch: String = cells[key]
		if TARGET_CHARS.contains(ch):
			targets += 1
			if not seen.has(key):
				missing.append({"ch": ch, "pos": key})
	return {"reached": seen, "missing": missing, "power": power, "shortcut": shortcut, "targets": targets}

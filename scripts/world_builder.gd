extends RefCounted
## 읽어 온 맵(world_data.gd)을 실제 노드(바닥, 사다리, 장치, 단서, 적...)로 만든다.
## host는 레벨을 소유한 장면(main.gd 계열)이며, 단서·적·귀환 장치를 놓는 함수를 제공해야 한다.

const Kit := preload("res://scripts/level_kit.gd")
const WorldData := preload("res://scripts/world_data.gd")

const T := 16.0
const ENEMY_PATROL := 48.0           ## 경비 로봇이 시작 위치에서 좌우로 오가는 거리(픽셀)
const SPARK_PHASE_STEP := 0.9        ## 스파크 구간마다 주기를 엇갈리게 하는 간격(초)

const ZONE_TINTS := [
	Color(0.075, 0.075, 0.105),
	Color(0.085, 0.095, 0.095),
	Color(0.095, 0.08, 0.085),
	Color(0.08, 0.09, 0.075),
]


## 반환: {"player": 플레이어, "start": 시작 위치, "lifts": [승강기], "bounds": 픽셀 영역 Rect2}
static func build(world: Dictionary, host: Node) -> Dictionary:
	var cells: Dictionary = world["cells"]
	var b: Rect2i = world["bounds"]
	var pixel_bounds := Rect2(Vector2(b.position) * T, Vector2(b.size) * T)

	# 배경(맵 전체) + 구역마다 살짝 다른 색
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08)
	bg.position = pixel_bounds.position - Vector2(400, 400)
	bg.size = pixel_bounds.size + Vector2(800, 800)
	bg.z_index = -20
	host.add_child(bg)
	var zi := 0
	for z in world["zones"]:
		var tint := ColorRect.new()
		var zr: Rect2i = z["rect"]
		tint.color = ZONE_TINTS[zi % ZONE_TINTS.size()]
		tint.position = Vector2(zr.position) * T
		tint.size = Vector2(zr.size) * T
		tint.z_index = -19
		host.add_child(tint)
		zi += 1

	# 맵 가장자리 벽: 지도 바깥으로 걸어 나가거나 떨어지지 못하게 한다. (카메라도 이 경계에서 멈춘다)
	var margin := 400.0
	var wall := 32.0
	Kit.platform(host, Rect2(pixel_bounds.position.x - wall, pixel_bounds.position.y - margin, wall, pixel_bounds.size.y + margin * 2.0))
	Kit.platform(host, Rect2(pixel_bounds.end.x, pixel_bounds.position.y - margin, wall, pixel_bounds.size.y + margin * 2.0))
	Kit.platform(host, Rect2(pixel_bounds.position.x - wall, pixel_bounds.end.y, pixel_bounds.size.x + wall * 2.0, wall))

	# 바닥·벽·젖은 바닥
	for item in merged_rects(cells, "#w"):
		var rr: Rect2i = item["rect"]
		Kit.platform(host, _px(rr), "wet" if item["ch"] == "w" else "normal")

	# 한쪽 방향 발판(윗면 4픽셀만 충돌)
	for item in merged_rects(cells, "-"):
		var rr: Rect2i = item["rect"]
		var r := _px(rr)
		Kit.one_way(host, Rect2(r.position, Vector2(r.size.x, 4)))

	# 사다리: 세로로 이어진 H 칸
	for lad in ladder_runs(cells):
		Kit.ladder(host, lad["col"] * T + T / 2.0, lad["top"] * T, (lad["bottom"] + 1) * T)

	# 스파크 구간
	var i := 0
	for item in merged_rects(cells, "S"):
		var rr: Rect2i = item["rect"]
		var r := _px(rr)
		Kit.sparks(host, r.position, r.size, SPARK_PHASE_STEP * i)
		i += 1

	# 문
	for item in merged_rects(cells, "D"):
		var r := _px(item["rect"])
		Kit.door(host, r, "power", "전력 필요")
	for item in merged_rects(cells, "G"):
		var r := _px(item["rect"])
		Kit.door(host, r, "world1_shortcut", "잠김")

	# 레버
	var devices: Array = []
	for pos in WorldData.find_all(world, "12!"):
		var ch: String = cells[pos]
		var at := _feet_pos(pos, 15.0)
		var lever: Area2D
		match ch:
			"1": lever = Kit.lever(host, at, "lever_a")
			"2": lever = Kit.lever(host, at, "lever_b")
			_: lever = Kit.lever(host, at, "world1_shortcut", true, false)
		devices.append(lever)

	# 크랭크 승강기: 같은 세로줄의 ^(위)와 v(아래)
	var lifts: Array = []
	var ups := {}
	var downs := {}
	for pos in WorldData.find_all(world, "^"):
		ups[pos.x] = pos.y
	for pos in WorldData.find_all(world, "v"):
		downs[pos.x] = pos.y
	for col in ups:
		if not downs.has(col):
			push_error("승강기 위 정류장(^)에 짝이 되는 아래 정류장(v)이 없습니다: 칸 %d" % col)
			continue
		var lift := Kit.lift(host, col * T + T / 2.0, (ups[col] + 1) * T, (downs[col] + 1) * T)
		lifts.append(lift)
		devices.append(lift)
	for col in downs:
		if not ups.has(col):
			push_error("승강기 아래 정류장(v)에 짝이 되는 위 정류장(^)이 없습니다: 칸 %d" % col)

	for d in devices:
		if host.has_method("_show_toast"):
			d.message.connect(host._show_toast)

	# 단서 조사 지점: a~p
	for pos in WorldData.find_all(world, "abcdefghijklmnop"):
		var ch: String = cells[pos]
		host._spawn_point_at(["s1_" + ch], _feet_pos(pos, 8.0))

	# 적, 귀환 장치
	for pos in WorldData.find_all(world, "R"):
		host._spawn_enemy_at("guard_robot", _feet_pos(pos, 10.0), ENEMY_PATROL)
	for pos in WorldData.find_all(world, "X"):
		host._spawn_return_at(_feet_pos(pos, 12.0))

	# 플레이어와 카메라
	var starts := WorldData.find_all(world, "@")
	if starts.is_empty():
		push_error("플레이어 시작 위치(@)가 없습니다")
		starts = [Vector2i(b.position.x + 2, b.position.y + 2)]
	var start := _feet_pos(starts[0], 12.0)
	var player := Kit.player(host, start)
	Kit.camera(player, int(pixel_bounds.position.x), int(pixel_bounds.end.x), int(pixel_bounds.position.y), int(pixel_bounds.end.y))

	return {"player": player, "start": start, "lifts": lifts, "bounds": pixel_bounds}


## 칸 좌표 영역 → 픽셀 영역
static func _px(r: Rect2i) -> Rect2:
	return Rect2(Vector2(r.position) * T, Vector2(r.size) * T)


## 발이 닿는 칸 pos의 가운데에서, 바닥 표면 위로 up픽셀 올라간 지점
static func _feet_pos(pos: Vector2i, up: float) -> Vector2:
	return Vector2(pos.x * T + T / 2.0, (pos.y + 1) * T - up)


## 같은 글자가 이어진 칸들을 가로로 묶고, 같은 가로 범위가 연속된 줄은 세로로 합친 직사각형 목록.
## 반환: [{"ch": 글자, "rect": Rect2i}]
static func merged_rects(cells: Dictionary, chars: String) -> Array:
	var by_row := {}
	for key in cells:
		var ch: String = cells[key]
		if chars.contains(ch):
			if not by_row.has(key.y):
				by_row[key.y] = {}
			by_row[key.y][key.x] = ch

	var rows: Array = by_row.keys()
	rows.sort()
	var active := {}        # "c0,c1,글자" -> [시작 줄, 끝 줄]
	var done: Array = []
	var prev_r := -999999
	for r in rows:
		var cols: Array = by_row[r].keys()
		cols.sort()
		var runs: Array = []
		var i := 0
		while i < cols.size():
			var c0: int = cols[i]
			var run_ch: String = by_row[r][c0]
			var c1 := c0
			while i + 1 < cols.size() and cols[i + 1] == c1 + 1 and by_row[r][cols[i + 1]] == run_ch:
				i += 1
				c1 = cols[i]
			runs.append([c0, c1, run_ch])
			i += 1

		var next_active := {}
		for run in runs:
			var k := "%d,%d,%s" % [run[0], run[1], run[2]]
			if r == prev_r + 1 and active.has(k):
				var span: Array = active[k]
				span[1] = r
				next_active[k] = span
				active.erase(k)
			else:
				next_active[k] = [r, r]
		for k in active:
			done.append(_span_to_rect(k, active[k]))
		active = next_active
		prev_r = r
	for k in active:
		done.append(_span_to_rect(k, active[k]))
	return done


static func _span_to_rect(key: String, span: Array) -> Dictionary:
	var parts := key.split(",")
	var c0 := int(parts[0])
	var c1 := int(parts[1])
	return {"ch": parts[2], "rect": Rect2i(c0, int(span[0]), c1 - c0 + 1, int(span[1]) - int(span[0]) + 1)}


## 세로로 이어진 H 칸 → [{"col", "top", "bottom"}] (top, bottom은 칸 번호)
static func ladder_runs(cells: Dictionary) -> Array:
	var by_col := {}
	for key in cells:
		if cells[key] == "H":
			if not by_col.has(key.x):
				by_col[key.x] = []
			by_col[key.x].append(key.y)
	var runs: Array = []
	for col in by_col:
		var rows: Array = by_col[col]
		rows.sort()
		var start: int = rows[0]
		var prev: int = rows[0]
		for i in range(1, rows.size()):
			if rows[i] != prev + 1:
				runs.append({"col": col, "top": start, "bottom": prev})
				start = rows[i]
			prev = rows[i]
		runs.append({"col": col, "top": start, "bottom": prev})
	return runs

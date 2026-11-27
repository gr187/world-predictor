extends RefCounted
## 글자 격자 맵 읽기. 구역 파일(.txt)들을 world.json의 위치에 맞춰 하나의 큰 격자로 합친다.
##
## 격자 기호 (한 칸 = 16px, 한 글자 = 한 칸)
##   . 또는 공백  빈 칸
##   #  단단한 벽·바닥        w  젖은 바닥(미끄러움, 단단함)
##   -  한쪽 방향 발판(아래에서 뛰어올라 통과, 위에서 섬)
##   H  사다리 (세로로 이어진 칸이 한 개의 사다리. 맨 위 칸의 윗면이 사다리 꼭대기 높이)
##   S  스파크 구간 (이어진 칸이 하나의 구간)
##   D  전력 문(전력 복구 시 열림)        G  지름길 문(지름길 레버를 올리면 열림)
##   1 2  전력 레버 A, B        !  지름길 레버(영구)
##   ^ v  크랭크 승강기의 위/아래 정류장. 같은 세로줄에 하나씩, 승강기 발판이 서는 칸(발 닿는 칸)에 쓴다.
##   a~p  단서 조사 지점 (a = s1_a ... p = s1_p)
##   R  경비 로봇     X  귀환 장치     @  플레이어 시작 위치
## 줄이 ';'로 시작하면 설명(주석)이며 칸으로 세지 않는다. 마지막의 빈 줄도 칸으로 세지 않는다.

const TILE := 16

const SOLID_CHARS := "#w"


## 반환: {"tile", "cells": {Vector2i: 글자}, "zones": [{"id","name","rect": Rect2i}], "bounds": Rect2i}
static func load_world(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("맵 설정을 열 수 없습니다: " + path)
		return {}
	var cfg: Variant = JSON.parse_string(f.get_as_text())
	if not (cfg is Dictionary):
		push_error("맵 설정이 올바르지 않습니다: " + path)
		return {}

	var cells: Dictionary = {}
	var zones: Array = []
	var base_dir := path.get_base_dir()
	var min_c := 1 << 30
	var min_r := 1 << 30
	var max_c := -(1 << 30)
	var max_r := -(1 << 30)

	for z in cfg["zones"]:
		var zf := FileAccess.open(base_dir.path_join(String(z["file"])), FileAccess.READ)
		if zf == null:
			push_error("구역 파일을 열 수 없습니다: " + String(z["file"]))
			continue
		var rows: Array = []
		for line in zf.get_as_text().split("\n"):
			var l := String(line).trim_suffix("\r")
			if l.begins_with(";"):
				continue
			rows.append(l)
		while not rows.is_empty() and String(rows[-1]).strip_edges() == "":
			rows.pop_back()

		var width := 0
		for r in rows.size():
			var line: String = rows[r]
			width = maxi(width, line.length())
			for c in line.length():
				var ch := line[c]
				if ch == "." or ch == " " or ch == "\t":
					continue
				cells[Vector2i(int(z["col"]) + c, int(z["row"]) + r)] = ch

		var rect := Rect2i(int(z["col"]), int(z["row"]), width, rows.size())
		zones.append({"id": String(z["id"]), "name": String(z["name"]), "rect": rect})
		min_c = mini(min_c, rect.position.x)
		min_r = mini(min_r, rect.position.y)
		max_c = maxi(max_c, rect.end.x)
		max_r = maxi(max_r, rect.end.y)

	var bounds := Rect2i(min_c, min_r, max_c - min_c, max_r - min_r)
	return {"tile": TILE, "cells": cells, "zones": zones, "bounds": bounds}


## 칸 (c, r)의 글자. 없으면 "".
static func cell(world: Dictionary, c: int, r: int) -> String:
	return String((world["cells"] as Dictionary).get(Vector2i(c, r), ""))


## 이 칸들 중 chars에 포함된 글자의 위치 목록 [Vector2i]. 왼쪽 위부터 읽는 순서.
static func find_all(world: Dictionary, chars: String) -> Array:
	var found: Array = []
	for key in world["cells"]:
		if chars.contains(String(world["cells"][key])):
			found.append(key)
	found.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return found


## 픽셀 좌표가 속한 구역의 id. 어느 구역에도 없으면 "".
static func zone_at(world: Dictionary, pos: Vector2) -> String:
	var c := int(floor(pos.x / TILE))
	var r := int(floor(pos.y / TILE))
	for z in world["zones"]:
		if (z["rect"] as Rect2i).has_point(Vector2i(c, r)):
			return z["id"]
	return ""


static func zone_name(world: Dictionary, id: String) -> String:
	for z in world["zones"]:
		if z["id"] == id:
			return z["name"]
	return ""

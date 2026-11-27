extends RefCounted
## 맵을 만들 때 쓰는 도구 모음. 장치 시험장과 이후 실제 맵이 함께 쓴다.

const PlayerScript := preload("res://scripts/player.gd")
const LadderScript := preload("res://scripts/ladder.gd")
const LiftScript := preload("res://scripts/crank_lift.gd")
const SparkScript := preload("res://scripts/spark_zone.gd")
const LeverScript := preload("res://scripts/power_lever.gd")
const DoorScript := preload("res://scripts/electric_door.gd")


static func platform(parent: Node, rect: Rect2, surface: String = "normal") -> StaticBody2D:
	var body := StaticBody2D.new()
	if surface != "normal":
		body.set_meta("surface", surface)
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.size / 2.0
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.size = rect.size
	vis.color = Color(0.22, 0.24, 0.3)
	if surface == "wet":
		vis.color = Color(0.2, 0.3, 0.45)
	elif surface == "mud":
		vis.color = Color(0.32, 0.25, 0.18)
	body.add_child(vis)
	parent.add_child(body)
	return body


static func player(parent: Node, pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.set_script(PlayerScript)
	p.position = pos
	p.add_to_group("player")
	parent.add_child(p)
	return p


static func camera(p: Node, left: int, right: int, top: int, bottom: int) -> Camera2D:
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = left
	cam.limit_right = right
	cam.limit_top = top
	cam.limit_bottom = bottom
	p.add_child(cam)
	return cam


static func ladder(parent: Node, x: float, top_y: float, bottom_y: float) -> Area2D:
	var l := LadderScript.new()
	l.setup(x, top_y, bottom_y)
	parent.add_child(l)
	return l


static func lift(parent: Node, x: float, top_y: float, bottom_y: float, powered: bool = false) -> AnimatableBody2D:
	var l := LiftScript.new()
	l.setup(x, top_y, bottom_y, powered)
	parent.add_child(l)
	return l


## pos는 구간의 왼쪽 위 모서리
static func sparks(parent: Node, pos: Vector2, size: Vector2, phase: float = 0.0) -> Area2D:
	var s := SparkScript.new()
	s.position = pos
	s.size = size
	s.cycle_time = phase
	parent.add_child(s)
	return s


static func lever(parent: Node, pos: Vector2, flag: String, permanent: bool = false, is_power: bool = true) -> Area2D:
	var l := LeverScript.new()
	l.position = pos
	l.flag_name = flag
	l.permanent = permanent
	l.is_power_lever = is_power
	parent.add_child(l)
	return l


## rect의 왼쪽 위 모서리가 위치. requires는 "power" 또는 맵 상태 이름
static func door(parent: Node, rect: Rect2, requires: String = "power", label: String = "전력 필요") -> StaticBody2D:
	var d := DoorScript.new()
	d.position = rect.position
	d.size = rect.size
	d.requires = requires
	d.closed_label = label
	parent.add_child(d)
	return d

extends Area2D
## 사다리(플레이스홀더). 꼭대기에는 한쪽 방향 발판이 있어 위에 설 수 있고, 아래로 내려갈 때는 통과한다.
## 위치: 사다리 중심 x, 꼭대기 표면 y, 맨 아래 y (모두 전역 좌표)

var top_y := 0.0
var bottom_y := 0.0


func setup(x: float, top: float, bottom: float) -> void:
	top_y = top
	bottom_y = bottom
	position = Vector2(x, top)


func _ready() -> void:
	add_to_group("ladder")
	collision_layer = 8
	collision_mask = 0

	var height := bottom_y - top_y
	# 감지 영역: 꼭대기 위 8픽셀부터 맨 아래까지 (꼭대기에 서 있어도 겹치도록)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, height + 8.0)
	shape.shape = rect
	shape.position = Vector2(0, (height + 8.0) / 2.0 - 8.0)
	add_child(shape)

	# 꼭대기 발판 (한쪽 방향: 위에서만 설 수 있다)
	var top := StaticBody2D.new()
	top.collision_layer = 16
	top.collision_mask = 0
	var tshape := CollisionShape2D.new()
	var trect := RectangleShape2D.new()
	trect.size = Vector2(16, 4)
	tshape.shape = trect
	tshape.position = Vector2(0, 2)
	tshape.one_way_collision = true
	top.add_child(tshape)
	add_child(top)
	queue_redraw()


func _draw() -> void:
	var height := bottom_y - top_y
	var col := Color(0.6, 0.5, 0.32)
	draw_line(Vector2(-5, 0), Vector2(-5, height), col, 2.0)
	draw_line(Vector2(5, 0), Vector2(5, height), col, 2.0)
	var y := 4.0
	while y < height:
		draw_line(Vector2(-5, y), Vector2(5, y), col, 1.0)
		y += 8.0

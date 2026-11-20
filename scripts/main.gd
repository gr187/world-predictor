extends Node2D
## 프로토타입 테스트 레벨. 도형만으로 이동·점프·카메라를 확인한다.

const PlayerScript := preload("res://scripts/player.gd")

const LEVEL_WIDTH := 1800
const FLOOR_Y := 240


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.position = Vector2(-200, -400)
	bg.size = Vector2(LEVEL_WIDTH + 400, 900)
	bg.z_index = -10
	add_child(bg)

	# 바닥과 발판들
	_platform(Rect2(0, FLOOR_Y, 600, 30))
	_platform(Rect2(600, FLOOR_Y, 300, 30), "wet")    # 젖은 바닥 (미끄러움 확인용)
	_platform(Rect2(900, FLOOR_Y, 300, 30), "mud")    # 진흙 바닥 (느려짐 확인용)
	_platform(Rect2(1200, FLOOR_Y, LEVEL_WIDTH - 1200, 30))
	_platform(Rect2(220, 190, 70, 10))
	_platform(Rect2(340, 150, 70, 10))
	_platform(Rect2(480, 190, 90, 10))
	_platform(Rect2(700, 170, 60, 10))
	_platform(Rect2(820, 130, 60, 10))
	_platform(Rect2(980, 200, 120, 10))
	_platform(Rect2(1200, 160, 80, 10))
	_platform(Rect2(1340, 110, 80, 10))
	_platform(Rect2(1500, 180, 120, 10))
	# 양쪽 끝 벽
	_platform(Rect2(-20, -200, 20, 500))
	_platform(Rect2(LEVEL_WIDTH, -200, 20, 500))

	var player := CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.position = Vector2(40, FLOOR_Y - 12)
	add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0
	cam.limit_right = LEVEL_WIDTH
	cam.limit_bottom = FLOOR_Y + 30
	cam.limit_top = -200
	player.add_child(cam)

	var hint := Label.new()
	hint.text = "A/D 이동   Space 점프"
	hint.position = Vector2(8, 6)
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	add_child(layer)


func _platform(rect: Rect2, surface := "normal") -> void:
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
	add_child(body)

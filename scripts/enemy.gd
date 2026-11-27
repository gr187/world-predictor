extends Area2D
## 맵 위의 적(플레이스홀더). 플레이어와 부딪히면 touched 신호를 보낸다.

signal touched(enemy: Area2D)

var enemy_id := "guard_robot"
var patrol_min := 0.0
var patrol_max := 0.0
var speed := 25.0

var _dir := 1.0
var _triggered := false


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 20)
	shape.shape = rect
	add_child(shape)
	var body := ColorRect.new()
	body.size = Vector2(16, 20)
	body.position = Vector2(-8, -10)
	body.color = Color(0.7, 0.25, 0.2)
	add_child(body)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if patrol_max <= patrol_min:
		return
	position.x += _dir * speed * delta
	if position.x > patrol_max:
		_dir = -1.0
	elif position.x < patrol_min:
		_dir = 1.0


func _on_body_entered(_body: Node) -> void:
	if _triggered:
		return
	_triggered = true
	touched.emit(self)

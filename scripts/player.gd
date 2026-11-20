extends CharacterBody2D
## 플레이스홀더 주인공. 수치는 임시값이며 조작감 확인 후 조정한다.

const SPEED := 110.0
const ACCEL := 900.0
const FRICTION := 1100.0
const JUMP_VELOCITY := -300.0
const GRAVITY := 900.0
const FALL_GRAVITY_MULT := 1.5
const JUMP_CUT := 0.5          ## 점프 키를 일찍 떼면 상승 속도를 줄이는 비율
const COYOTE_TIME := 0.10      ## 발판에서 떨어진 직후에도 점프 가능한 시간
const JUMP_BUFFER := 0.10      ## 착지 직전 미리 누른 점프 입력 유지 시간

## 바닥 재질별 이동 보정. 발판(StaticBody2D)의 meta "surface" 값으로 지정한다.
## 값은 임시이며 환경(비, 진흙, 얼음 등)을 만들 때 조정한다.
const SURFACES := {
	"normal": {"accel": 1.0, "friction": 1.0, "speed": 1.0},
	"wet": {"accel": 0.5, "friction": 0.25, "speed": 1.0},
	"mud": {"accel": 0.8, "friction": 1.5, "speed": 0.7},
}

## 구역 단위 환경 보정(비 오는 구역 등). 해당 구역이 설정/해제한다.
var env_accel_mult := 1.0
var env_friction_mult := 1.0
var env_speed_mult := 1.0

var surface := "normal"
var _coyote := 0.0
var _buffer := 0.0


func _update_surface() -> void:
	surface = "normal"
	if not is_on_floor():
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y < -0.7:
			var body := col.get_collider()
			if body and body.has_meta("surface"):
				surface = body.get_meta("surface")
			return


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 22)
	shape.shape = rect
	add_child(shape)

	var body := ColorRect.new()
	body.size = Vector2(10, 22)
	body.position = Vector2(-5, -11)
	body.color = Color(0.85, 0.85, 0.8)
	add_child(body)


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")

	# 중력 (내려올 때 더 빠르게)
	if not is_on_floor():
		var g := GRAVITY * (FALL_GRAVITY_MULT if velocity.y > 0.0 else 1.0)
		velocity.y += g * delta

	# 코요테 타임, 점프 버퍼
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0

	# 가변 점프 높이
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	# 수평 이동 (바닥 재질 x 구역 환경 보정)
	var s: Dictionary = SURFACES.get(surface, SURFACES["normal"])
	var accel: float = ACCEL * float(s["accel"]) * env_accel_mult
	var friction: float = FRICTION * float(s["friction"]) * env_friction_mult
	var max_speed: float = SPEED * float(s["speed"]) * env_speed_mult
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * max_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	_update_surface()

extends CharacterBody2D
## 플레이스홀더 주인공. 수치는 임시값이며 조작감 확인 후 조정한다.
## 이동·점프 + 사다리 오르기 + 스파크(방전) 피격 시 안전한 위치로 복귀.

signal shocked

const SPEED := 110.0
const ACCEL := 900.0
const FRICTION := 1100.0
const JUMP_VELOCITY := -300.0
const GRAVITY := 900.0
const FALL_GRAVITY_MULT := 1.5
const JUMP_CUT := 0.5          ## 점프 키를 일찍 떼면 상승 속도를 줄이는 비율
const COYOTE_TIME := 0.10      ## 발판에서 떨어진 직후에도 점프 가능한 시간
const JUMP_BUFFER := 0.10      ## 착지 직전 미리 누른 점프 입력 유지 시간

const HALF_H := 11.0           ## 몸 높이의 절반 (발 위치 계산용)
const CLIMB_SPEED := 60.0      ## 사다리 오르내리는 속도
const LADDER_COOLDOWN := 0.25  ## 사다리에서 뛰어내린 뒤 다시 붙잡기까지의 시간
const STUN_TIME := 0.9         ## 방전에 맞은 뒤 움직일 수 없는 시간

const MASK_NORMAL := 1 | 16    ## 바닥(1) + 사다리 꼭대기 발판(16)
const MASK_CLIMB := 1          ## 사다리를 타는 동안은 꼭대기 발판을 통과한다

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
var climbing := false
var stunned := 0.0               ## 남은 경직 시간
var hazard_count := 0            ## 지금 몸이 겹쳐 있는 스파크 구간의 수 (스파크 구간이 설정)
var last_safe_pos := Vector2.ZERO  ## 방전에 맞았을 때 돌아갈 마지막 안전한 위치

var _coyote := 0.0
var _buffer := 0.0
var _sensor: Area2D
var _ladder = null               ## 지금 타고 있는 사다리
var _ladder_cooldown := 0.0
var _candidate := Vector2.ZERO   ## 다음 프레임에 '안전한 위치'로 확정될 후보
var _has_candidate := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = MASK_NORMAL
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

	# 사다리를 감지하는 센서
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 8
	var sshape := CollisionShape2D.new()
	var srect := RectangleShape2D.new()
	srect.size = Vector2(4, 18)
	sshape.shape = srect
	_sensor.add_child(sshape)
	add_child(_sensor)

	last_safe_pos = global_position


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


func _physics_process(delta: float) -> void:
	_ladder_cooldown = maxf(_ladder_cooldown - delta, 0.0)
	stunned = maxf(stunned - delta, 0.0)
	var can_act := stunned <= 0.0

	if climbing:
		_climb_step()
		return
	if can_act and _try_start_climb():
		return

	var dir := Input.get_axis("move_left", "move_right") if can_act else 0.0

	# 중력 (내려올 때 더 빠르게)
	if not is_on_floor():
		var g := GRAVITY * (FALL_GRAVITY_MULT if velocity.y > 0.0 else 1.0)
		velocity.y += g * delta

	# 코요테 타임, 점프 버퍼
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	if can_act and Input.is_action_just_pressed("jump"):
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
	_update_safe_pos()


# ---------------------------------------------------------------- 사다리

func _find_ladder():
	var best = null
	var best_d := 9999.0
	for a in _sensor.get_overlapping_areas():
		if a.is_in_group("ladder"):
			var d := absf(a.global_position.x - global_position.x)
			if d < best_d:
				best = a
				best_d = d
	return best


## W/S를 눌렀고 사다리가 겹쳐 있으면 타기 시작한다.
func _try_start_climb() -> bool:
	if _ladder_cooldown > 0.0:
		return false
	var up := Input.is_action_pressed("climb_up")
	var down := Input.is_action_pressed("climb_down")
	if up == down:
		return false
	var lad = _find_ladder()
	if lad == null:
		return false
	var feet := global_position.y + HALF_H
	if up and feet <= lad.top_y + 1.0:
		return false   # 이미 맨 위에 서 있다
	if down and feet >= lad.bottom_y - 1.0:
		return false   # 이미 맨 아래에 있다
	climbing = true
	_ladder = lad
	velocity = Vector2.ZERO
	global_position.x = lad.global_position.x
	collision_mask = MASK_CLIMB
	return true


func _climb_step() -> void:
	if not is_instance_valid(_ladder):
		_end_climb()
		return
	var dir_y := Input.get_axis("climb_up", "climb_down")

	# 점프로 사다리에서 뛰어내린다.
	if Input.is_action_just_pressed("jump"):
		var dx := Input.get_axis("move_left", "move_right")
		_end_climb()
		velocity = Vector2(dx * SPEED, JUMP_VELOCITY * 0.7)
		_ladder_cooldown = LADDER_COOLDOWN
		move_and_slide()
		return

	velocity = Vector2(0.0, dir_y * CLIMB_SPEED)
	move_and_slide()

	var feet := global_position.y + HALF_H
	if feet <= _ladder.top_y + 0.5 and dir_y <= 0.0:
		# 맨 위에 도착: 꼭대기 발판 위에 선다.
		global_position.y = _ladder.top_y - HALF_H - 0.1
		velocity = Vector2.ZERO
		_end_climb()
	elif feet >= _ladder.bottom_y - 1.0 and dir_y >= 0.0:
		# 맨 아래에 도착
		velocity = Vector2.ZERO
		_end_climb()


func _end_climb() -> void:
	climbing = false
	_ladder = null
	collision_mask = MASK_NORMAL


# ---------------------------------------------------------------- 방전(스파크)

## 안전하게 서 있던 마지막 위치를 기억한다. 스파크 구간 안, 움직이는 발판 위는 제외.
## 겹침 신호(hazard_count)는 한두 프레임 늦게 오므로, 스파크 구간과 겹치는지는 몸 위치로 직접 비교한다.
## 구간에 닿기 직전 위치를 쓰기 위해 위치를 한 프레임 늦게 확정한다.
func _update_safe_pos() -> void:
	if stunned > 0.0 or not is_on_floor() or not _standing_on_fixed_ground() or _touching_spark_zone():
		_has_candidate = false
		return
	if _has_candidate:
		last_safe_pos = _candidate
	_candidate = global_position
	_has_candidate = true


## 몸(여유 2픽셀 포함)이 스파크 구간과 겹치는가
func _touching_spark_zone() -> bool:
	var body_rect := Rect2(global_position - Vector2(5, HALF_H), Vector2(10, HALF_H * 2.0)).grow(2.0)
	for z in get_tree().get_nodes_in_group("spark_zone"):
		if Rect2(z.global_position, z.size).intersects(body_rect):
			return true
	return false


func _standing_on_fixed_ground() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y < -0.7:
			var node := col.get_collider() as Node
			return node != null and not node.is_in_group("moving")
	return false


## 스파크에 맞았을 때: 잠시 움직일 수 없고 마지막 안전한 위치로 돌아간다. (전투 체력은 깎지 않는다)
func hit_by_hazard() -> void:
	if stunned > 0.0:
		return
	stunned = STUN_TIME
	if climbing:
		_end_climb()
	velocity = Vector2.ZERO
	global_position = last_safe_pos
	shocked.emit()

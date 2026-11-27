extends Area2D
## 스파크 구간(플레이스홀더). 끊어진 전선이 주기적으로 방전한다.
## 대기 1.4초 → 번쩍임(경고) 0.5초 → 방전 0.7초를 반복. 방전 중에 닿으면 마지막 안전한 위치로 밀려난다.
## 구역은 왼쪽 위 모서리가 위치(position)이다.

enum State { IDLE, WARN, ACTIVE }

const IDLE_TIME := 1.4
const WARN_TIME := 0.5
const ACTIVE_TIME := 0.7
const CYCLE := IDLE_TIME + WARN_TIME + ACTIVE_TIME

var size := Vector2(40, 28)
var cycle_time := 0.0          ## 주기 안에서의 현재 시각. 시작 오프셋으로 구간마다 엇갈리게 한다.

var _vis: ColorRect
var _players: Array = []


func _ready() -> void:
	add_to_group("spark_zone")
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)

	_vis = ColorRect.new()
	_vis.size = size
	add_child(_vis)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visual()


func get_state() -> int:
	var t := fposmod(cycle_time, CYCLE)
	if t < IDLE_TIME:
		return State.IDLE
	if t < IDLE_TIME + WARN_TIME:
		return State.WARN
	return State.ACTIVE


## 테스트용: 주기 안에서 원하는 상태의 한가운데로 시각을 맞춘다.
func force_state(state: int) -> void:
	match state:
		State.IDLE:
			cycle_time = IDLE_TIME * 0.5
		State.WARN:
			cycle_time = IDLE_TIME + WARN_TIME * 0.5
		State.ACTIVE:
			cycle_time = IDLE_TIME + WARN_TIME + ACTIVE_TIME * 0.5


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _players.has(body):
		_players.append(body)
		body.hazard_count += 1


func _on_body_exited(body: Node) -> void:
	if _players.has(body):
		_players.erase(body)
		body.hazard_count = maxi(body.hazard_count - 1, 0)


func _physics_process(delta: float) -> void:
	cycle_time += delta
	_update_visual()
	if get_state() == State.ACTIVE:
		for p in _players.duplicate():
			if is_instance_valid(p):
				p.hit_by_hazard()


func _update_visual() -> void:
	match get_state():
		State.IDLE:
			_vis.color = Color(0.45, 0.4, 0.15, 0.3)
		State.WARN:
			var blink := int(fposmod(cycle_time, CYCLE) * 12.0) % 2 == 0
			_vis.color = Color(1.0, 0.85, 0.2, 0.8) if blink else Color(0.6, 0.5, 0.15, 0.3)
		State.ACTIVE:
			_vis.color = Color(1.0, 0.97, 0.6, 0.95)

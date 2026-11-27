extends RefCounted
## 장면을 다시 불러와도 유지되어야 하는 상태. (죽어도 단서는 유지된다는 설계 때문)
## 저장 파일로 내보내는 기능은 아직 없다.

const ClueBook := preload("res://scripts/clue_book.gd")

const WORLD_COUNT := 3

static var _book: RefCounted = null
static var current_world := 1          ## 지금 조사 중인 세계
static var unlocked_world := 1         ## 갈 수 있는 가장 높은 세계
static var last_grade := ""            ## 마지막 보고 등급
static var pending_supplies: Array = []  ## 보고에서 받은, 다음 시뮬레이션에 가져갈 보급품
static var active_supplies: Array = []   ## 지금 시뮬레이션에 적용 중인 보급품


static func get_book() -> RefCounted:
	if _book == null:
		_book = ClueBook.new()
	return _book


## 새 시뮬레이션이 시작될 때: 받아 둔 보급품을 적용하고 비운다.
static func begin_simulation() -> void:
	active_supplies = pending_supplies.duplicate()
	pending_supplies = []


## 보고가 승인되면 다음 세계를 연다. 새로 열렸으면 true.
static func unlock_next_world() -> bool:
	var next := current_world + 1
	if next > WORLD_COUNT or unlocked_world >= next:
		return false
	unlocked_world = next
	return true


static func reset() -> void:
	_book = null
	current_world = 1
	unlocked_world = 1
	last_grade = ""
	pending_supplies = []
	active_supplies = []

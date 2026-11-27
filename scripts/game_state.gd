extends RefCounted
## 장면을 다시 불러와도 유지되어야 하는 상태. (죽어도 단서는 유지된다는 설계 때문)
## 저장 파일로 내보내는 기능은 아직 없다.

const ClueBook := preload("res://scripts/clue_book.gd")

const WORLD_COUNT := 3
const POWER_LEVERS_REQUIRED := 2   ## 전력을 복구하려면 올려야 하는 레버 수

static var _book: RefCounted = null
static var current_world := 1          ## 지금 조사 중인 세계
static var unlocked_world := 1         ## 갈 수 있는 가장 높은 세계
static var last_grade := ""            ## 마지막 보고 등급
static var pending_supplies: Array = []  ## 보고에서 받은, 다음 시뮬레이션에 가져갈 보급품
static var active_supplies: Array = []   ## 지금 시뮬레이션에 적용 중인 보급품
static var run_flags: Dictionary = {}        ## 이번 시뮬레이션에서만 유효한 맵 상태 (전력 레버 등)
static var permanent_flags: Dictionary = {}  ## 죽어도 유지되는 맵 상태 (열쇠로 연 지름길 등)
static var seen_guide := false         ## 조작 안내를 이미 봤는가 (저장됨)
static var pending_guide := false      ## 이번에 장면이 시작될 때 조작 안내를 띄울 것인가 (저장 안 됨, 타이틀이 설정)


static func get_book() -> RefCounted:
	if _book == null:
		_book = ClueBook.new()
	return _book


## 저장 파일을 불러올 때 수첩을 통째로 바꾼다.
static func set_book(book: RefCounted) -> void:
	_book = book


## 새 시뮬레이션이 시작될 때: 받아 둔 보급품을 적용하고, 이번 판 맵 상태를 초기화한다.
## 지름길(permanent_flags)은 그대로 남는다.
static func begin_simulation() -> void:
	active_supplies = pending_supplies.duplicate()
	pending_supplies = []
	run_flags = {}


# ---------------------------------------------------------------- 맵 상태

static func set_flag(flag: String, permanent: bool = false) -> void:
	if permanent:
		permanent_flags[flag] = true
	else:
		run_flags[flag] = true


static func has_flag(flag: String) -> bool:
	return run_flags.has(flag) or permanent_flags.has(flag)


## 올려진 전력 레버의 수 ("lever_"로 시작하는 이번 판 상태)
static func power_levers_on() -> int:
	var n := 0
	for k in run_flags:
		if String(k).begins_with("lever_"):
			n += 1
	return n


static func power_on() -> bool:
	return power_levers_on() >= POWER_LEVERS_REQUIRED


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
	run_flags = {}
	permanent_flags = {}
	seen_guide = false
	pending_guide = false

extends "res://scripts/main.gd"
## 세계 1 장면: 글자 격자 맵(data/world1/)을 읽어 하나의 큰 연속 맵으로 만든다.
## 전투·수첩·보고서·귀환 등 나머지는 main.gd와 같다.
## 실행: godot --path game scenes/world1.tscn

const WorldData := preload("res://scripts/world_data.gd")
const WorldBuilder := preload("res://scripts/world_builder.gd")

const WORLD_PATH := "res://data/world1/world.json"

var world: Dictionary = {}
var built: Dictionary = {}
var current_zone := ""


func _build_level() -> void:
	world = WorldData.load_world(WORLD_PATH)
	if world.is_empty():
		return
	built = WorldBuilder.build(world, self)
	player = built["player"]


func _build_hud() -> void:
	super._build_hud()
	_check_zone()


func _physics_process(_delta: float) -> void:
	_check_out_of_bounds()
	_check_zone()


## 만에 하나 맵 밖으로 나가면(경계 벽 틈 등) 시작 위치로 되돌린다.
func _check_out_of_bounds() -> void:
	if built.is_empty() or player == null:
		return
	var area: Rect2 = (built["bounds"] as Rect2).grow(48.0)
	if not area.has_point(player.global_position):
		player.global_position = built["start"]
		player.velocity = Vector2.ZERO
		player.last_safe_pos = built["start"]
		if toast != null:
			_show_toast("맵 밖으로 나가서 시작 위치로 돌아왔다.")


## 다른 구역에 들어가면 구역 이름을 잠깐 보여 준다.
func _check_zone() -> void:
	if world.is_empty() or player == null or toast == null:
		return
	var zone_id := WorldData.zone_at(world, player.global_position)
	if zone_id != "" and zone_id != current_zone:
		current_zone = zone_id
		_show_toast(WorldData.zone_name(world, zone_id))

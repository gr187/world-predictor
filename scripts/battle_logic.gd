extends RefCounted
## 전투 규칙. UI와 분리해 헤드리스 테스트가 가능하게 한다. 수치는 모두 임시값.
## 설계: design/02_전투_설계.md

const PLAYER_MAX_HP := 5
const NORMAL_DAMAGE := 1
const STRONG_DAMAGE := 2
const DODGE_VS_NORMAL := 0.8
const DODGE_VS_STRONG := 0.4
const ACTION_NAMES := {"attack": "일반 공격", "strong": "강한 공격", "defend": "방어"}

var rng := RandomNumberGenerator.new()
var data: Dictionary
var clue_level := 0          ## 0=모호한 징후, 1 이상=구체적인 징후
var player_hp := PLAYER_MAX_HP
var enemy_hp := 0
var over := false
var winner := ""             ## "player" 또는 "enemy"
var advantage := false       ## 회피로 빈틈을 파악한 다음 턴 공격 강화
var last_player_damage := 0
var intent := ""             ## 적이 실제로 할 행동 (UI에 직접 보여 주지 않는다)
var tell_action := ""        ## 징후 문장이 가리키는 행동 (reliability 확률로 어긋날 수 있다)
var tell_text := ""


func _init(enemy_data: Dictionary, clue: int = 0, seed_value: int = -1) -> void:
	data = enemy_data
	clue_level = clue
	enemy_hp = int(data["hp"])
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	next_intent()


func get_tell() -> String:
	return tell_text


func next_intent() -> void:
	var weights: Dictionary = data["weights"]
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := rng.randf() * total
	intent = ""
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			intent = k
			break
	if intent == "":
		intent = weights.keys()[0]
	tell_action = intent
	if rng.randf() > float(data["reliability"]):
		var others: Array = weights.keys().filter(func(a): return a != intent)
		if not others.is_empty():
			tell_action = others[rng.randi() % others.size()]
	_pick_tell()


## 테스트용: 적의 행동과 징후를 직접 지정한다.
func set_intent_for_test(action: String, tell_a: String = "") -> void:
	intent = action
	tell_action = tell_a if tell_a != "" else action
	_pick_tell()


func _pick_tell() -> void:
	var level: String = "clear" if clue_level >= 1 else "vague"
	var pool: Array = data["tells"][tell_action][level]
	tell_text = pool[rng.randi() % pool.size()]


func play(player_action: String) -> Dictionary:
	var lines: Array[String] = []
	if over:
		return {"lines": lines, "player_damage": 0, "enemy_damage": 0, "enemy_action": ""}

	var e: String = intent
	var base: int = STRONG_DAMAGE if e == "strong" else NORMAL_DAMAGE
	# 연속으로 큰 피해를 받지 않게 한다.
	if e == "strong" and last_player_damage >= STRONG_DAMAGE:
		base = NORMAL_DAMAGE
	var had_adv := advantage
	advantage = false
	var to_player := 0
	var to_enemy := 0

	lines.append("%s의 %s!" % [data["name"], ACTION_NAMES[e]])

	match player_action:
		"attack":
			if e == "defend":
				lines.append("공격이 막혔다.")
			else:
				to_enemy = 2 if had_adv else 1
				to_player = base
				lines.append("공격이 들어갔다. 반격을 받았다.")
		"defend":
			if e == "defend":
				lines.append("서로 상대를 지켜볼 뿐이다.")
			else:
				to_player = maxi(base - 1, 0)
				if to_player == 0:
					lines.append("충격을 완전히 막아 냈다.")
				else:
					lines.append("충격을 일부 막아 냈다.")
		"dodge":
			if e == "defend":
				advantage = true
				lines.append("상대의 빈틈을 파악했다. 다음 공격이 강해진다.")
			else:
				var chance: float = DODGE_VS_NORMAL if e == "attack" else DODGE_VS_STRONG
				if rng.randf() < chance:
					lines.append("공격을 피했다.")
				else:
					to_player = base
					lines.append("피하지 못했다.")

	player_hp = maxi(player_hp - to_player, 0)
	enemy_hp = maxi(enemy_hp - to_enemy, 0)
	last_player_damage = to_player

	if enemy_hp <= 0:
		over = true
		winner = "player"
	elif player_hp <= 0:
		over = true
		winner = "enemy"
	else:
		next_intent()

	return {"lines": lines, "player_damage": to_player, "enemy_damage": to_enemy, "enemy_action": e}

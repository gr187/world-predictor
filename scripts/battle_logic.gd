extends RefCounted
## 전투 규칙. UI와 분리해 헤드리스 테스트가 가능하게 한다. 수치는 모두 임시값.
## 설계: design/02_전투_설계.md (v0.2)

const PLAYER_MAX_HP := 5
const NORMAL_DAMAGE := 1
const STRONG_DAMAGE := 2
const DODGE_VS_NORMAL := 0.8
const DODGE_VS_STRONG := 0.4
const HEAL_AMOUNT := 2

const FOCUS_MAX := 5
const FOCUS_START := 3
const FOCUS_REGEN := 1
const OFFER_SIZE := 3

const ACTION_NAMES := {"attack": "일반 공격", "strong": "강한 공격", "defend": "방어"}  ## 적 행동 이름
## 플레이어 행동 풀. 비용은 자원("집중")을 소모한다.
const ACTIONS := {
	"attack": {"name": "공격", "cost": 1},
	"defend": {"name": "방어", "cost": 0},
	"dodge": {"name": "회피", "cost": 1},
	"smash": {"name": "강타", "cost": 2},
	"heal": {"name": "치료", "cost": 2},
}

var rng := RandomNumberGenerator.new()
var data: Dictionary
var clue_level := 0          ## 0=모호한 징후, 1 이상=구체적인 징후
var max_hp := PLAYER_MAX_HP    ## 보급품(방호복)으로 늘어날 수 있다
var heal_amount := HEAL_AMOUNT ## 보급품(응급 키트)으로 늘어날 수 있다
var player_hp := PLAYER_MAX_HP
var enemy_hp := 0
var focus := FOCUS_START
var turn := 0                ## 지금까지 진행한 턴 수
var over := false
var winner := ""             ## "player" 또는 "enemy"
var advantage := false       ## 회피로 빈틈을 파악한 다음 턴 공격 강화
var last_player_damage := 0
var intent := ""             ## 적이 실제로 할 행동 (UI에 직접 보여 주지 않는다)
var tell_action := ""        ## 징후 문장이 가리키는 행동 (reliability 확률로 어긋날 수 있다)
var tell_text := ""
var offer: Array = []        ## 이번 턴에 화면에 나오는 선택지 id


## supplies: 보급품 id 목록 ("suit" 최대 체력 +1, "battery" 시작 집중 +2, "kit" 치료량 +1)
func _init(enemy_data: Dictionary, clue: int = 0, seed_value: int = -1, supplies: Array = []) -> void:
	data = enemy_data
	clue_level = clue
	enemy_hp = int(data["hp"])
	if supplies.has("suit"):
		max_hp += 1
	if supplies.has("kit"):
		heal_amount += 1
	if supplies.has("battery"):
		focus = mini(focus + 2, FOCUS_MAX)
	player_hp = max_hp
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	next_intent()
	roll_offer()


func get_tell() -> String:
	return tell_text


# ---------------------------------------------------------------- 선택지

## 지금 쓸 수 있는가 (자원이 충분하고, 효과가 있는가)
func is_usable(id: String) -> bool:
	if not ACTIONS.has(id):
		return false
	if int(ACTIONS[id]["cost"]) > focus:
		return false
	if id == "heal" and player_hp >= max_hp:
		return false
	return true


## 이번 턴 선택지에 있고 지금 쓸 수 있는가
func can_play(id: String) -> bool:
	return not over and offer.has(id) and is_usable(id)


## 이번 턴의 선택지를 정한다. 적 데이터에 options.fixed가 있으면 그 목록을 그대로 쓴다.
## (스토리상 필요한 전투에서 상황에 맞는 선택지를 고정하기 위함)
func roll_offer() -> void:
	var opts: Dictionary = data.get("options", {})
	var fixed: Array = opts.get("fixed", [])
	if not fixed.is_empty():
		offer = fixed.duplicate()
		return

	# 효과가 없는 선택지(체력이 가득일 때 치료 등)는 후보에서 뺀다.
	var ids: Array = ACTIONS.keys()
	var candidates: Array = []
	for id in ids:
		if id == "heal" and player_hp >= max_hp:
			continue
		candidates.append(id)
	# 무작위로 섞은 뒤 앞에서 OFFER_SIZE개를 고른다.
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var picked: Array = candidates.slice(0, OFFER_SIZE)

	# 지금 쓸 수 있는 선택지가 하나도 없으면 비용 0인 방어를 끼워 넣는다.
	var any_usable := false
	for id in picked:
		if is_usable(id):
			any_usable = true
	if not any_usable:
		picked[picked.size() - 1] = "defend"

	# 버튼 위치가 매번 달라지지 않도록 행동 풀의 순서대로 정렬한다.
	picked.sort_custom(func(a, b): return ids.find(a) < ids.find(b))
	offer = picked


## 테스트용: 이번 턴 선택지를 직접 지정한다.
func set_offer_for_test(list: Array) -> void:
	offer = list.duplicate()


# ---------------------------------------------------------------- 적 행동

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


# ---------------------------------------------------------------- 턴 진행

func _invalid() -> Dictionary:
	var lines: Array[String] = []
	return {"lines": lines, "player_damage": 0, "enemy_damage": 0, "enemy_action": "",
		"invalid": true, "timed_out": false, "healed": 0, "action": ""}


## 플레이어가 선택지를 골랐을 때. 선택지에 없거나 쓸 수 없으면 invalid 결과를 돌려준다.
func play(player_action: String) -> Dictionary:
	if not can_play(player_action):
		return _invalid()
	return _resolve(player_action, false)


## 제한 시간이 끝났을 때. 화면에 떠 있고 지금 쓸 수 있는 선택지 중에서 무작위로 고른다.
func play_timeout() -> Dictionary:
	if over:
		return _invalid()
	var usable: Array = offer.filter(func(id): return is_usable(id))
	var action: String = "defend"   # 쓸 수 있는 선택지가 없으면 비용 0인 방어
	if not usable.is_empty():
		action = usable[rng.randi() % usable.size()]
	return _resolve(action, true)


func _resolve(player_action: String, timed_out: bool) -> Dictionary:
	var lines: Array[String] = []

	var e: String = intent
	var base: int = STRONG_DAMAGE if e == "strong" else NORMAL_DAMAGE
	# 연속으로 큰 피해를 받지 않게 한다.
	if e == "strong" and last_player_damage >= STRONG_DAMAGE:
		base = NORMAL_DAMAGE
	var had_adv := advantage
	advantage = false
	var to_player := 0
	var to_enemy := 0

	focus = maxi(focus - int(ACTIONS[player_action]["cost"]), 0)
	if timed_out:
		lines.append("시간이 다 됐다! 당황해서 몸이 먼저 움직였다. (%s)" % ACTIONS[player_action]["name"])
	lines.append("%s의 %s!" % [data["name"], ACTION_NAMES[e]])

	match player_action:
		"attack":
			if e == "defend":
				lines.append("공격이 막혔다.")
			else:
				to_enemy = 2 if had_adv else 1
				to_player = base
				lines.append("공격이 들어갔다. 반격을 받았다.")
		"smash":
			if e == "defend":
				lines.append("강타가 막혔다.")
			else:
				to_enemy = 3 if had_adv else 2
				to_player = base
				lines.append("강타가 적중했다. 반격을 받았다.")
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
		"heal":
			if e == "defend":
				lines.append("상대가 지켜보는 사이 상처를 처치했다.")
			else:
				to_player = base
				lines.append("처치하는 중에 공격을 받았다.")

	# 치료는 피해보다 먼저 적용한다.
	var healed := 0
	if player_action == "heal":
		healed = mini(heal_amount, max_hp - player_hp)
		player_hp += healed
		if healed > 0:
			lines.append("체력을 %d 회복했다." % healed)

	player_hp = maxi(player_hp - to_player, 0)
	enemy_hp = maxi(enemy_hp - to_enemy, 0)
	last_player_damage = to_player
	turn += 1

	if enemy_hp <= 0:
		over = true
		winner = "player"
	elif player_hp <= 0:
		over = true
		winner = "enemy"
	else:
		focus = mini(focus + FOCUS_REGEN, FOCUS_MAX)
		next_intent()
		roll_offer()

	return {"lines": lines, "player_damage": to_player, "enemy_damage": to_enemy,
		"enemy_action": e, "invalid": false, "timed_out": timed_out, "healed": healed,
		"action": player_action}

extends SceneTree
## 전투 규칙 테스트: godot --headless --path game -s tests/test_battle.gd

const BattleLogic := preload("res://scripts/battle_logic.gd")

var fails := 0
var enemy_data: Dictionary


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("통과 " if ok else "실패 "), name, "  ", detail)
	if not ok:
		fails += 1


func fresh(action: String, clue: int = 0, seed_value: int = 1):
	var b = BattleLogic.new(enemy_data, clue, seed_value)
	b.set_intent_for_test(action)
	return b


## 선택지와 자원을 보장한 뒤 행동을 실행한다. (규칙 테스트에서 선택지 변동의 영향을 없애기 위함)
func act(b, action: String) -> Dictionary:
	b.set_offer_for_test([action])
	b.focus = BattleLogic.FOCUS_MAX
	return b.play(action)


func _init() -> void:
	var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	enemy_data = parsed["guard_robot"]

	# --- 조합표 ---
	var b = fresh("attack")
	var r: Dictionary = act(b, "attack")
	check("공격 vs 일반공격: 서로 1피해", r["player_damage"] == 1 and r["enemy_damage"] == 1)

	b = fresh("strong")
	r = act(b, "attack")
	check("공격 vs 강공격: 나 2피해, 적 1피해", r["player_damage"] == 2 and r["enemy_damage"] == 1)

	b = fresh("defend")
	r = act(b, "attack")
	check("공격 vs 방어: 서로 피해 없음", r["player_damage"] == 0 and r["enemy_damage"] == 0)

	b = fresh("attack")
	r = act(b, "defend")
	check("방어 vs 일반공격: 피해 0", r["player_damage"] == 0)

	b = fresh("strong")
	r = act(b, "defend")
	check("방어 vs 강공격: 피해 1", r["player_damage"] == 1)

	b = fresh("defend")
	r = act(b, "dodge")
	check("회피 vs 방어: 빈틈 파악", b.advantage and r["player_damage"] == 0)
	b.set_intent_for_test("attack")
	r = act(b, "attack")
	check("빈틈 후 공격: 적 2피해", r["enemy_damage"] == 2)
	check("빈틈은 한 번만 적용", not b.advantage)

	# --- 강타 ---
	b = fresh("attack")
	r = act(b, "smash")
	check("강타 vs 일반공격: 적 2피해, 나 1피해", r["enemy_damage"] == 2 and r["player_damage"] == 1)
	b = fresh("defend")
	r = act(b, "smash")
	check("강타 vs 방어: 막힘", r["enemy_damage"] == 0 and r["player_damage"] == 0)

	# --- 치료 ---
	b = fresh("defend")
	b.player_hp = 3
	r = act(b, "heal")
	check("치료 vs 방어: 체력 +2", b.player_hp == 5 and r["healed"] == 2)
	b = fresh("attack")
	b.player_hp = 3
	r = act(b, "heal")
	check("치료 vs 일반공격: +2 후 1피해", b.player_hp == 4)
	b = fresh("defend")
	b.player_hp = 4
	act(b, "heal")
	check("치료는 최대 체력을 넘지 않음", b.player_hp == 5)

	# --- 연속 큰 피해 제한 ---
	b = fresh("strong")
	act(b, "attack")
	b.set_intent_for_test("strong")
	r = act(b, "attack")
	check("강공격 연속 시 두 번째는 1피해로 제한", r["player_damage"] == 1)

	# --- 자원 ---
	b = fresh("defend")
	check("시작 자원 3", b.focus == BattleLogic.FOCUS_START)
	b.set_offer_for_test(["attack", "defend", "dodge"])
	b.play("attack")
	check("공격 비용 1 소모 후 턴 종료 시 +1 회복", b.focus == 3, "focus=%d" % b.focus)
	b.set_offer_for_test(["attack", "defend", "dodge"])
	b.set_intent_for_test("defend")
	b.play("defend")
	check("방어는 비용 0, 회복만 적용", b.focus == 4)
	b.focus = 5
	b.set_offer_for_test(["defend"])
	b.set_intent_for_test("defend")
	b.play("defend")
	check("자원은 최대치를 넘지 않음", b.focus == 5)

	b = fresh("attack")
	b.focus = 1
	b.set_offer_for_test(["smash", "defend", "attack"])
	var before_hp: int = b.player_hp
	r = b.play("smash")
	check("자원이 모자라면 선택 불가(상태 변화 없음)",
		r["invalid"] and b.focus == 1 and b.player_hp == before_hp and b.turn == 0)

	b = fresh("attack")
	b.set_offer_for_test(["attack", "defend", "dodge"])
	r = b.play("smash")
	check("선택지에 없는 행동은 선택 불가", r["invalid"] and b.turn == 0)

	# --- 선택지 뽑기 ---
	var seen_heal_full := false
	var seen_heal_hurt := false
	var dup_or_size_bad := false
	var counts_offer := {}
	var rb = BattleLogic.new(enemy_data, 0, 21)
	for i in 600:
		rb.player_hp = BattleLogic.PLAYER_MAX_HP
		rb.focus = 5
		rb.roll_offer()
		if rb.offer.has("heal"):
			seen_heal_full = true
		if rb.offer.size() != 3 or rb.offer.size() != _unique_count(rb.offer):
			dup_or_size_bad = true
		for id in rb.offer:
			counts_offer[id] = int(counts_offer.get(id, 0)) + 1
		rb.player_hp = 2
		rb.roll_offer()
		if rb.offer.has("heal"):
			seen_heal_hurt = true
	check("선택지는 항상 3개, 중복 없음", not dup_or_size_bad)
	check("체력이 가득이면 치료는 나오지 않음", not seen_heal_full)
	check("체력이 줄면 치료가 나올 수 있음", seen_heal_hurt)
	check("체력 가득일 때 선택지 4종이 고르게 나옴",
		counts_offer.size() == 4 and counts_offer.values().all(func(c): return absf(float(c) / 600.0 - 0.75) < 0.07),
		str(counts_offer))

	var always_defend := true
	for i in 500:
		rb.focus = 0
		rb.roll_offer()
		if not rb.offer.has("defend"):
			always_defend = false
	check("자원 0이어도 쓸 수 있는 선택지(방어)가 항상 있음", always_defend)

	var fixed_data: Dictionary = enemy_data.duplicate(true)
	fixed_data["options"] = {"fixed": ["attack", "defend", "dodge"]}
	var fb = BattleLogic.new(fixed_data, 0, 5)
	var fixed_ok := true
	for i in 50:
		fb.roll_offer()
		if fb.offer != ["attack", "defend", "dodge"]:
			fixed_ok = false
	check("고정 선택지 목록은 그대로 나옴", fixed_ok)

	# --- 시간 종료 자동 선택 ---
	b = fresh("attack")
	b.focus = 1
	b.set_offer_for_test(["smash", "heal", "attack"])   # 체력 가득이라 치료 불가, 자원 1이라 강타 불가
	r = b.play_timeout()
	check("시간 종료: 쓸 수 있는 것(공격)만 자동 선택", r["timed_out"] and r["action"] == "attack")
	check("시간 종료 문구 표시", String(r["lines"][0]).begins_with("시간이 다 됐다"))

	var pick_counts := {"attack": 0, "defend": 0, "dodge": 0}
	for i in 3000:
		var tb = BattleLogic.new(enemy_data, 0, 1000 + i)
		tb.set_offer_for_test(["attack", "defend", "dodge"])
		pick_counts[tb.play_timeout()["action"]] += 1
	check("시간 종료 자동 선택이 선택지에 고르게 분포",
		pick_counts.values().all(func(c): return absf(float(c) / 3000.0 - 1.0 / 3.0) < 0.04), str(pick_counts))

	b = fresh("attack")
	b.focus = 0
	b.set_offer_for_test(["smash", "attack"])
	r = b.play_timeout()
	check("쓸 수 있는 선택지가 전혀 없으면 방어로 처리", r["action"] == "defend")

	# --- 회피 성공률 ---
	for case in [["attack", 0.8], ["strong", 0.4]]:
		var ok_count := 0
		var trials := 2000
		var rng_b = BattleLogic.new(enemy_data, 0, 7)
		for i in trials:
			rng_b.player_hp = 99
			rng_b.last_player_damage = 0
			rng_b.set_intent_for_test(case[0])
			var res: Dictionary = act(rng_b, "dodge")
			if res["player_damage"] == 0:
				ok_count += 1
		var rate := float(ok_count) / trials
		check("회피 성공률 (%s)" % case[0], absf(rate - float(case[1])) < 0.04, "측정 %.3f" % rate)

	# --- 적 행동 분포 (가중치 5:2:3) ---
	var counts := {"attack": 0, "strong": 0, "defend": 0}
	rb = BattleLogic.new(enemy_data, 0, 11)
	var n := 4000
	for i in n:
		rb.next_intent()
		counts[rb.intent] += 1
	check("행동 분포 일반공격 50%", absf(float(counts["attack"]) / n - 0.5) < 0.04, str(counts))
	check("행동 분포 강공격 20%", absf(float(counts["strong"]) / n - 0.2) < 0.04)
	check("행동 분포 방어 30%", absf(float(counts["defend"]) / n - 0.3) < 0.04)

	# --- 징후 신뢰도 ---
	var match_count := 0
	for i in n:
		rb.next_intent()
		if rb.tell_action == rb.intent:
			match_count += 1
	check("징후 신뢰도 85%", absf(float(match_count) / n - 0.85) < 0.03, "측정 %.3f" % (float(match_count) / n))

	# --- 단서 단계별 징후 ---
	var tells: Dictionary = enemy_data["tells"]
	check("모호한 징후: 일반공격과 강공격이 구분되지 않음",
		tells["attack"]["vague"] == tells["strong"]["vague"])
	check("구체적인 징후: 일반공격과 강공격이 구분됨",
		tells["attack"]["clear"] != tells["strong"]["clear"])
	var vb = BattleLogic.new(enemy_data, 0, 3)
	vb.set_intent_for_test("strong")
	check("단서 0이면 모호한 징후 문장 사용", vb.get_tell() in tells["strong"]["vague"])
	var cb = BattleLogic.new(enemy_data, 1, 3)
	cb.set_intent_for_test("strong")
	check("단서 1이면 구체적인 징후 문장 사용", cb.get_tell() in tells["strong"]["clear"])

	# --- 전투 종료 ---
	b = fresh("defend")
	b.enemy_hp = 1
	b.set_intent_for_test("attack")
	act(b, "attack")
	check("적 체력 0이면 승리", b.over and b.winner == "player")
	r = act(b, "attack")
	check("종료 후 행동은 무시됨", r["player_damage"] == 0 and r["lines"].is_empty())
	r = b.play_timeout()
	check("종료 후 시간 종료도 무시됨", r["invalid"])

	b = fresh("attack")
	b.player_hp = 1
	act(b, "attack")
	check("플레이어 체력 0이면 패배", b.over and b.winner == "enemy")

	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)


func _unique_count(arr: Array) -> int:
	var seen := {}
	for v in arr:
		seen[v] = true
	return seen.size()

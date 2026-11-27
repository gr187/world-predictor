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


func _init() -> void:
	var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	enemy_data = parsed["guard_robot"]

	# --- 조합표 ---
	var b = fresh("attack")
	var r: Dictionary = b.play("attack")
	check("공격 vs 일반공격: 서로 1피해", r["player_damage"] == 1 and r["enemy_damage"] == 1)

	b = fresh("strong")
	r = b.play("attack")
	check("공격 vs 강공격: 나 2피해, 적 1피해", r["player_damage"] == 2 and r["enemy_damage"] == 1)

	b = fresh("defend")
	r = b.play("attack")
	check("공격 vs 방어: 서로 피해 없음", r["player_damage"] == 0 and r["enemy_damage"] == 0)

	b = fresh("attack")
	r = b.play("defend")
	check("방어 vs 일반공격: 피해 0", r["player_damage"] == 0)

	b = fresh("strong")
	r = b.play("defend")
	check("방어 vs 강공격: 피해 1", r["player_damage"] == 1)

	b = fresh("defend")
	r = b.play("dodge")
	check("회피 vs 방어: 빈틈 파악", b.advantage and r["player_damage"] == 0)
	b.set_intent_for_test("attack")
	r = b.play("attack")
	check("빈틈 후 공격: 적 2피해", r["enemy_damage"] == 2)
	check("빈틈은 한 번만 적용", not b.advantage)

	# --- 연속 큰 피해 제한 ---
	b = fresh("strong")
	b.play("attack")
	b.set_intent_for_test("strong")
	r = b.play("attack")
	check("강공격 연속 시 두 번째는 1피해로 제한", r["player_damage"] == 1)

	# --- 회피 성공률 ---
	for case in [["attack", 0.8], ["strong", 0.4]]:
		var ok_count := 0
		var trials := 2000
		var rng_b = BattleLogic.new(enemy_data, 0, 7)
		for i in trials:
			rng_b.player_hp = 99
			rng_b.last_player_damage = 0
			rng_b.set_intent_for_test(case[0])
			var res: Dictionary = rng_b.play("dodge")
			if res["player_damage"] == 0:
				ok_count += 1
		var rate := float(ok_count) / trials
		check("회피 성공률 (%s)" % case[0], absf(rate - float(case[1])) < 0.04, "측정 %.3f" % rate)

	# --- 적 행동 분포 (가중치 5:2:3) ---
	var counts := {"attack": 0, "strong": 0, "defend": 0}
	var rb = BattleLogic.new(enemy_data, 0, 11)
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
	b.play("attack")
	check("적 체력 0이면 승리", b.over and b.winner == "player")
	r = b.play("attack")
	check("종료 후 행동은 무시됨", r["player_damage"] == 0 and r["lines"].is_empty())

	b = fresh("attack")
	b.player_hp = 1
	b.play("attack")
	check("플레이어 체력 0이면 패배", b.over and b.winner == "enemy")

	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)

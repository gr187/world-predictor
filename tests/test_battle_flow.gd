extends SceneTree
## 맵 접촉 → 전투 화면 → 종료까지의 흐름 테스트:
## godot --headless --path game -s tests/test_battle_flow.gd

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("통과 " if ok else "실패 "), name)
	if not ok:
		fails += 1


func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	await physics_frame

	var player: CharacterBody2D = main.player
	var enemies := get_nodes_in_group("enemy")
	check("적 2마리 배치", enemies.size() == 2)
	var target: Area2D = enemies[0]

	check("시작 시 일시정지 아님", not paused)
	player.global_position = target.global_position
	for i in 5:
		await physics_frame

	var ui = main.get_node_or_null("BattleUI")
	check("접촉하면 전투 화면 생성", ui != null)
	check("전투 중 게임 일시정지", paused)
	if ui == null:
		quit(1)
		return

	# 이기도록 적 체력을 1로 두고 공격만 반복
	ui.logic.enemy_hp = 1
	var guard := 0
	while not ui.logic.over and guard < 60:
		ui.choose("attack")
		guard += 1
	check("전투가 승리로 끝남", ui.logic.over and ui.logic.winner == "player")

	ui._on_continue()
	await physics_frame
	await physics_frame
	check("종료 후 일시정지 해제", not paused)
	check("이긴 적은 맵에서 사라짐", not is_instance_valid(target) or target.is_queued_for_deletion())
	check("전투 화면 정리됨", main.get_node_or_null("BattleUI") == null or main.get_node("BattleUI").is_queued_for_deletion())

	print("결과: ", "전체 통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)

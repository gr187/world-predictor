extends SceneTree
## 헤드리스 테스트: godot --headless --path game -s tests/test_player.gd

func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	var player: CharacterBody2D = null
	for c in main.get_children():
		if c is CharacterBody2D:
			player = c
	var fails := 0
	if player == null:
		print("FAIL: player 없음"); quit(1); return

	for i in 90:
		await physics_frame
	var landed := player.is_on_floor()
	print("착지: ", landed, " y=", player.position.y)
	if not landed: fails += 1

	var y0 := player.position.y
	Input.action_press("jump")
	var min_y := y0
	for i in 30:
		await physics_frame
		min_y = minf(min_y, player.position.y)
	Input.action_release("jump")
	print("점프 높이: ", y0 - min_y)
	if y0 - min_y < 30.0: fails += 1

	for i in 90:
		await physics_frame
	var x0 := player.position.x
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
	Input.action_release("move_right")
	print("우측 이동 거리: ", player.position.x - x0)
	if player.position.x - x0 < 50.0: fails += 1

	print("결과: ", "통과" if fails == 0 else "실패 %d건" % fails)
	quit(fails)

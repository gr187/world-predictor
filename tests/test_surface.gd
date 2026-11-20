extends SceneTree
## 재질별 정지 거리 비교: godot --headless --path game -s tests/test_surface.gd

func _slide(main: Node, player: CharacterBody2D, start_x: float) -> Array:
	player.position = Vector2(start_x, 200)
	player.velocity = Vector2.ZERO
	for i in 40:
		await physics_frame
	Input.action_press("move_right")
	for i in 40:
		await physics_frame
	var speed := player.velocity.x
	var surf: String = player.surface
	Input.action_release("move_right")
	var x_release := player.position.x
	for i in 90:
		await physics_frame
	return [surf, speed, player.position.x - x_release]

func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	var player: CharacterBody2D
	for c in main.get_children():
		if c is CharacterBody2D: player = c
	var normal = await _slide(main, player, 100)
	var wet = await _slide(main, player, 620)
	var mud = await _slide(main, player, 920)
	print("normal: ", normal)
	print("wet:    ", wet)
	print("mud:    ", mud)
	var ok: bool = wet[2] > normal[2] * 2.0 and mud[1] < normal[1] and wet[0] == "wet" and mud[0] == "mud"
	print("결과: ", "통과" if ok else "실패")
	quit(0 if ok else 1)

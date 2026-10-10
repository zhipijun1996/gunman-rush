extends SceneTree
func _initialize() -> void:
	call_deferred("run_check")

func run_check() -> void:
	var packed: PackedScene = load("res://assets/characters/courier/courier_visual.tscn")
	var visual = packed.instantiate()
	root.add_child(visual)
	for state in visual.STATES:
		visual.set_state(state)
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			visual.set_aim_direction(direction)
			visual.set_facing(direction.x)
			visual._process(0.1)
			assert(is_finite(visual.get_node("WeaponArm").rotation))
	assert(visual.state == &"death")
	print("PASS courier six states and cardinal aim directions")
	quit(0)

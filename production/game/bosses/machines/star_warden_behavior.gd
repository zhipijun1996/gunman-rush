extends MachineBossBehavior
## Lock the mirror rack on the target before the arm unfolds. A fan has its
## own projectiles; only the physical sweep/weight use the machine's hit slab.
func _prepare() -> void:
	super()
	if move_id != &"mirror_fan": return
	attack_origin = actor.motor.global_position + Vector2.UP*11
	locked_direction = attack_origin.direction_to(controller.motor.global_position)
	attack_goal = attack_origin + locked_direction * machine.reach
	footprint = Vector2(16,16)

func advance(delta: float) -> bool:
	var warmup := state == &"telegraph"
	var accepted := super(delta)
	if warmup and state == &"attack" and move_id == &"mirror_fan": _fire()
	return accepted

func _damage_player(rect: Rect2) -> void:
	if move_id != &"mirror_fan": super(rect)

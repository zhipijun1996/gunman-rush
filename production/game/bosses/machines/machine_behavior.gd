class_name MachineBossBehavior
extends ArenaBossBehavior

func attack_sound() -> StringName:
	return &"enemy_shot" if move_id == &"curtain" else &"boss_impact"

func strike_category() -> StringName:
	return &"phase_light" if move_id == &"curtain" else &"machine_solid"

func advance_body(delta: float) -> void:
	if move_id == &"rail":
		actor.motor.move_and_collide((attack_goal - actor.motor.global_position).limit_length(machine.attack_speed*delta))

func configure_head(at: Vector2, player: Vector2, side: int) -> void:
	match move_id:
		&"rail":
			footprint = machine.collision_size
			attack_origin = at
			var bound := machine.arena_half_width - footprint.x/2
			attack_goal = Vector2(clampf(at.x+side*machine.reach,home.x-bound,home.x+bound),at.y)
		&"sweep", &"backswing":
			footprint = Vector2(46,26)
			attack_origin = Vector2(at.x+side*18,floor_y-27)
			attack_goal = attack_origin+locked_direction*machine.reach
		&"gantry":
			footprint = Vector2(58,44)
			attack_origin = Vector2(home.x-side*machine.reach,floor_y-31)
			attack_goal = Vector2(home.x+side*machine.reach,floor_y-31)
		&"left_weight", &"right_weight", &"stamp":
			var lane := clampf(player.x,home.x-machine.reach,home.x+machine.reach)
			if move_id == &"left_weight": lane = minf(lane,home.x-95)
			if move_id == &"right_weight": lane = maxf(lane,home.x+95)
			footprint = Vector2(94,42) if move_id==&"stamp" else Vector2(68,48)
			attack_origin = Vector2(lane,floor_y-235)
			attack_goal = Vector2(lane,floor_y-footprint.y/2)
		&"curtain":
			footprint = Vector2(18,220)
			attack_origin = Vector2(home.x-side*machine.reach,floor_y-110)
			attack_goal = Vector2(home.x+side*machine.reach,floor_y-110)

func active_rect(fraction: float) -> Rect2:
	var t := clampf(fraction,0,1)
	var center := attack_origin.lerp(attack_goal,t)
	if move_id==&"rail": center = actor.motor.global_position
	elif move_id in [&"left_weight",&"right_weight",&"stamp"]: center = attack_origin.lerp(attack_goal,t*t)
	return Rect2(center-footprint/2,footprint)


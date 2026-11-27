extends ArenaBossBehavior
## The pendulum travels on a fixed, visible rail. A high rail and a low
## return are interleaved after the first phase. Only light accepts Q.
func configure_head(_at: Vector2, _target: Vector2, side: int) -> void:
	var lift := 40 if move_id==&"low_arc" else 156
	var reach := machine.reach
	if move_id == &"phase_scan":
		attack_origin = Vector2(home.x-side*reach,floor_y-130)
		attack_goal = Vector2(home.x+side*reach,floor_y-130)
		footprint = Vector2(22,258)
	else:
		attack_origin = Vector2(home.x-side*reach,floor_y-lift)
		attack_goal = Vector2(home.x+side*reach,floor_y-lift)
		footprint = Vector2(48,38)

func active_rect(t: float) -> Rect2:
	var center := attack_origin.lerp(attack_goal,t)
	if move_id != &"phase_scan": center.y -= 76*sin(PI*t)
	return Rect2(center-footprint/2,footprint)

func strike_category() -> StringName:
	return &"phase_light" if move_id==&"phase_scan" else &"machine_solid"

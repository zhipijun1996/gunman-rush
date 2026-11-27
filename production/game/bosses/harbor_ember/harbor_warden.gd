extends ArenaBossBehavior
## The head of a cast stays on its visible chain. After half life the guard
## alternates its low cast with an overhead anchor aimed at the last seen lane.
func configure_head(at: Vector2, target: Vector2, side: int) -> void:
	if move_id==&"anchor":
		footprint=Vector2(55,38)
		var x:=clampf(target.x,home.x-machine.reach,home.x+machine.reach)
		attack_origin=Vector2(x,floor_y-192)
		attack_goal=Vector2(x,floor_y-19)
	else:
		footprint=Vector2(49,17)
		attack_origin=at+Vector2(side*38,10)
		attack_goal=Vector2(home.x+side*machine.reach,floor_y-28)

func active_rect(t: float) -> Rect2:
	var center:=attack_origin.lerp(attack_goal,t*t if move_id==&"anchor" else sin(t*PI))
	return Rect2(center-footprint/2,footprint)

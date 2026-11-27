extends ArenaBossBehavior
## The furnace telegraphs the affected side before the clinker leaves the bowl.
## The physical clinker and bellows remain dangerous during a protected recoil.
func configure_head(at: Vector2, target: Vector2, side: int) -> void:
	if move_id==&"clinker":
		footprint=Vector2(35,30)
		attack_origin=at-Vector2(0,24)
		attack_goal=Vector2(clampf(target.x,home.x-machine.reach,home.x+machine.reach),floor_y-16)
	else:
		footprint=Vector2(54,40)
		attack_origin=Vector2(home.x+side*56,floor_y-22)
		attack_goal=Vector2(home.x+side*machine.reach,floor_y-22)

func active_rect(t: float) -> Rect2:
	var center:=attack_origin.lerp(attack_goal,t)
	if move_id==&"clinker": center.y-=178*sin(t*PI)
	return Rect2(center-footprint/2,footprint)

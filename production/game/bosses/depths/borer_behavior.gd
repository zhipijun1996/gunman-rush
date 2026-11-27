extends ArenaBossBehavior

func configure_head(at: Vector2, _player: Vector2, side: int) -> void:
	if move_id==&"shale":
		footprint=Vector2(40,26)
		attack_origin=Vector2(at.x+side*68,floor_y-140)
		attack_goal=Vector2(at.x+side*260,floor_y-13)
		return
	footprint=Vector2(76,44)
	attack_origin=Vector2(at.x+side*65,floor_y-31)
	var extension := 248 if move_id==&"bore" else 183
	attack_goal=attack_origin+Vector2(side*extension,0)

func hit_rects(fraction: float) -> Array[Rect2]:
	var t := clampf(fraction,0,1)
	if move_id==&"shale":
		var debris: Array[Rect2]=[]
		for offset: float in [0,48,96]:
			var p := Vector2(lerpf(attack_origin.x,attack_goal.x,t)+locked_direction.x*offset,lerpf(attack_origin.y,attack_goal.y,t*t))
			debris.append(Rect2(p-footprint/2,footprint))
		return debris
	return [active_rect(t)]

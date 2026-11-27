extends ArenaBossBehavior
## Each fruit ejects three distinct spores. The gaps between them stay safe.
func attack_sound() -> StringName:
	return &"enemy_shot" if move_id!=&"stonefall" else &"boss_impact"

func strike_category() -> StringName:
	return &"machine_solid" if move_id==&"stonefall" else &"spore"

func configure_head(at: Vector2, player: Vector2, side: int) -> void:
	if move_id==&"stonefall":
		footprint=Vector2(66,36)
		var lane := clampf(player.x,home.x+machine.engagement_span().x+36,home.x+machine.engagement_span().y-36)
		attack_origin=Vector2(lane,floor_y-150)
		attack_goal=Vector2(lane,floor_y-18)
		return
	footprint=Vector2(18,18)
	attack_origin=at+Vector2(side*42,-16)
	attack_goal=Vector2(clampf(player.x+side*75,home.x+machine.engagement_span().x+10,home.x+machine.engagement_span().y-10),floor_y-26)

func hit_rects(fraction: float) -> Array[Rect2]:
	var t := clampf(fraction,0,1)
	if move_id==&"stonefall":
		return [Rect2(attack_origin.lerp(attack_goal,t*t)-footprint/2,footprint)]
	var bodies: Array[Rect2]=[]
	for fan: int in [-1,0,1]:
		var spread := float(fan)*46 if move_id==&"fan" else float(fan)*28
		var flight := attack_origin.lerp(attack_goal+Vector2(spread,0),t)
		flight.y -= sin(PI*t)*(65+fan*28)
		bodies.append(Rect2(flight-footprint/2,footprint))
	return bodies

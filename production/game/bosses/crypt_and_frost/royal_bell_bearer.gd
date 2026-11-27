extends ArenaBossBehavior
## The bronze shoulder stays toward the committed blow until the bell is lifted.
func configure_head(_at:Vector2, player:Vector2, _side:int) -> void:
	var span:=machine.engagement_span()
	var hit_x:=clampf(player.x,home.x+span.x+64,home.x+span.y-64)
	attack_origin=Vector2(hit_x,floor_y-159)
	attack_goal=Vector2(hit_x,floor_y-22)

func hit_rects(fraction:float) -> Array[Rect2]:
	var t:=clampf(fraction,0,1)
	var bell:=attack_origin.lerp(attack_goal,pow(minf(t*2.8,1),2))
	var areas:Array[Rect2]=[Rect2(bell-Vector2(32,22),Vector2(64,44))]
	if move_id==&"fall_and_echo":
		var travel:=clampf((t-.34)/.66,0,1)
		for side:int in [-1,1]:
			var y:=floor_y-(112 if side==int(locked_direction.x) else 18)
			var center:=Vector2(attack_goal.x+side*travel*284,y)
			areas.append(Rect2(center-Vector2(12,12),Vector2(24,24) if travel>0 else Vector2.ZERO))
	return areas

extends ArenaBossBehavior
## The outer mirrors reflect the same cue across the floor; the open middle
## remains available during a column fall and above the converging low strike.
func attack_sound() -> StringName:
	return &"bell"

func configure_head(_at:Vector2,player:Vector2,_side:int) -> void:
	var span:=machine.engagement_span()
	attack_origin=Vector2(clampf(player.x,home.x+span.x+80,home.x+span.y-80),floor_y-18)
	attack_goal=Vector2(2*home.x-attack_origin.x,floor_y-18)
	attack_goal.x=clampf(attack_goal.x,home.x+span.x+80,home.x+span.y-80)

func hit_rects(fraction:float) -> Array[Rect2]:
	var t:=clampf(fraction,0,1)
	var areas:Array[Rect2]=[]
	if move_id==&"mirror_fall":
		for i in 2:
			var center:=attack_origin if i==0 else attack_goal
			center.y-=146*(1-pow(clampf(t*1.8-i*.64,0,1),2))
			areas.append(Rect2(center-Vector2(17,22),Vector2(34,44)))
	else:
		for side:int in [-1,1]:
			var center:=home+Vector2(side*lerpf(335,25,t),0)
			center.y=floor_y-(89 if move_id==&"split_note" and side==int(locked_direction.x) else 19)
			areas.append(Rect2(center-Vector2(16,13),Vector2(32,26)))
	return areas

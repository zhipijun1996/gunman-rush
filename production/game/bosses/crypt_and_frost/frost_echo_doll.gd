extends ArenaBossBehavior
## The copy stands on the ice before either arm moves. Both planted pivots
## swing the same arc, half a beat apart. The upper copy is a phase-two variation.
const ARM_TIME:=.48
var echo_live:=false

func attack_sound() -> StringName:
	return &"bell"

func configure_head(at:Vector2,player:Vector2,side:int) -> void:
	attack_origin=Vector2(at.x+side*12,floor_y-50)
	attack_goal=Vector2(clampf(player.x,home.x+machine.engagement_span().x+75,home.x+machine.engagement_span().y-75),floor_y-50)
	if move_id==&"upper_echo": attack_goal.y-=90
	echo_live=false

func arm_center(pivot:Vector2,t:float) -> Vector2:
	var swing:=lerpf(-1.03,1.03,t)
	return pivot+Vector2(locked_direction.x*cos(swing)*78,sin(swing)*44)

func hit_rects(fraction:float) -> Array[Rect2]:
	var rects:Array[Rect2]=[]
	for i in 2:
		var t:=(fraction-i*(1.0-ARM_TIME))/ARM_TIME
		var pivot:=attack_origin if i==0 else attack_goal
		var center:=arm_center(pivot,clampf(t,0,1))
		var size:=Vector2(30,28) if t>=0 and t<=1 else Vector2.ZERO
		rects.append(Rect2(center-size/2,size))
	return rects

func advance_body(_delta:float) -> void:
	if not echo_live and state_time/machine.attack_duration>=1-ARM_TIME:
		echo_live=true
		damage_spent=false

func _damage_player(rect:Rect2) -> void:
	if rect.has_area(): super._damage_player(rect)

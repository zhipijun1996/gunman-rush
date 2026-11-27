extends ArenaBossBehavior
## Three feathers hang motionless until their own beat. Each commits to the
## player's original perch. The broken wing leaves an exposed landing window.
var quills: Array[Vector2] = []
var ends: Array[Vector2] = []
var perch := Vector2.ZERO

func configure_head(at: Vector2, target: Vector2, side: int) -> void:
	if move_id == &"dive":
		perch = at
		attack_origin = at
		attack_goal = Vector2(clampf(target.x,home.x-435,home.x+435),floor_y-49)
		footprint = machine.collision_size * .77
		return
	quills.clear()
	ends.clear()
	var sign_x := -side if phases.phase == 2 else side
	for i in 3:
		var pivot := Vector2(clampf(target.x + sign_x*(i-1)*120,home.x-427,home.x+427),minf(target.y-145,home.y-38)-absf(i-1)*22)
		quills.append(pivot)
		ends.append(pivot + pivot.direction_to(Vector2(target.x+(i-1)*65,target.y+12))*510)
	attack_origin = quills[0]
	attack_goal = ends[0]
	footprint = Vector2(16,24)

func hit_rects(t: float) -> Array[Rect2]:
	if move_id == &"dive": return [Rect2(actor.motor.global_position-footprint/2,footprint)]
	var hits: Array[Rect2] = []
	for i in quills.size():
		var age := (t-i*.20)/.54
		var center := quills[i].lerp(ends[i],clampf(age,0,1))
		hits.append(Rect2(center-footprint/2,footprint if age>=0 and age<=1 else Vector2.ZERO))
	return hits

func advance_body(_delta: float) -> void:
	if move_id == &"dive":
		var t := clampf(state_time/machine.attack_duration,0,1)
		actor.motor.global_position = perch.lerp(attack_goal,smoothstep(0,.80,t))

func advance(delta: float) -> bool:
	if state == &"recovery" and move_id == &"dive" and state_time > machine.recovery_duration*.72:
		actor.motor.global_position = actor.motor.global_position.move_toward(home,delta*630)
	return super(delta)

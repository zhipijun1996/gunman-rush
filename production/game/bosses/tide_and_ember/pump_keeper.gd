extends ArenaBossBehavior
## The three floor nozzles remain fixed even when the target changes platform.
const NOZZLES := {&"port":-308.0,&"keel":0.0,&"starboard":312.0}

func warning_seconds() -> float:
	return machine.telegraph_duration+0.32 if phases.phase==3 and (pattern_step%2)==0 else machine.telegraph_duration

func attack_sound() -> StringName:
	return &"bell"

func configure_head(_at: Vector2,_player: Vector2,_side: int) -> void:
	var offset: float=NOZZLES[move_id]
	attack_origin = Vector2(home.x+offset,floor_y-3)
	attack_goal = attack_origin+Vector2.UP*156
	footprint = Vector2(82,156)

func active_rect(fraction: float) -> Rect2:
	var t := clampf(fraction,0,1)
	var height := lerpf(12,footprint.y,minf(1,t*3.5))
	return Rect2(attack_origin-Vector2(footprint.x/2,height),Vector2(footprint.x,height))

class_name WorldCamera
extends Camera2D
## One continuous camera policy; room handoff owns the only snap.
var target: PlayerMotor
var bounds:=Rect2()
var settings: Dictionary
var dead_zone: Vector2
var lead:=0.0
func _ready() -> void:
	process_physics_priority=1250
	zoom=Vector2.ONE*float(settings.zoom)
	dead_zone=Vector2(settings.dead_zone[0],settings.dead_zone[1])
	position_smoothing_enabled=false
func bounded(value: Vector2) -> Vector2:
	var half:=get_viewport_rect().size/(2*zoom)
	return Vector2(bounds.get_center().x if bounds.size.x<half.x*2 else clampf(value.x,bounds.position.x+half.x,bounds.end.x-half.x),bounds.get_center().y if bounds.size.y<half.y*2 else clampf(value.y,bounds.position.y+half.y,bounds.end.y-half.y))
func enter_room(value: Rect2) -> void:
	bounds=value;lead=0
	global_position=bounded(target.global_position+Vector2(0,float(settings.vertical_offset)))
	reset_smoothing();force_update_scroll()
func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not bounds.has_area(): return
	lead=lerpf(lead,clampf(target.velocity.x/float(settings.lead_speed),-1,1)*float(settings.lead_distance),1-exp(-delta/float(settings.lead_seconds)))
	var desired:=target.global_position+Vector2(lead,float(settings.vertical_offset))
	var error:=desired-global_position
	var goal:=global_position+Vector2(signf(error.x)*maxf(0,absf(error.x)-dead_zone.x),signf(error.y)*maxf(0,absf(error.y)-dead_zone.y))
	var vertical_time:=lerpf(float(settings.vertical_seconds),float(settings.fall_seconds),clampf(target.velocity.y/float(settings.fall_speed),0,1))
	global_position=bounded(Vector2(lerpf(global_position.x,goal.x,1-exp(-delta/float(settings.horizontal_seconds))),lerpf(global_position.y,goal.y,1-exp(-delta/vertical_time))))

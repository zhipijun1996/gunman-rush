class_name WorldCamera
extends Camera2D
## One follow policy with authored room/arena envelopes; never changes combat zoom.
var target: PlayerMotor
var room: FixedWorldRoom
var bounds:=Rect2()
var world_bounds:=Rect2()
var chamber_bounds:=Rect2()
var settings: Dictionary
var lead:=0.0
func _ready() -> void:
	process_physics_priority=1250
	zoom=Vector2.ONE*float(settings.zoom)
	position_smoothing_enabled=false
func enclosed() -> bool:
	return is_instance_valid(room) and (bool(room.contract.camera.get("enclosed",false)) or arena_active())
func arena_active() -> bool:
	return is_instance_valid(room) and room.arena_bounds.has_area() and ((room.battle_started and not room.battle_finished) or room.arena_bounds.has_point(target.position))
func bounded(value: Vector2) -> Vector2:
	var half:=get_viewport_rect().size/(2*zoom)
	var factor:=float(settings.small_room_factor) if enclosed() else 1.0
	return Vector2(bounds.get_center().x if bounds.size.x<half.x*2*factor else clampf(value.x,bounds.position.x+half.x,bounds.end.x-half.x),bounds.get_center().y if bounds.size.y<half.y*2*factor else clampf(value.y,bounds.position.y+half.y,bounds.end.y-half.y))
func enter_room(value: Rect2) -> void:
	world_bounds=value
	chamber_bounds=WorldRoomSpace.camera_envelope(room.contract.world_geometry,target.position,Rect2())
	bounds=room.arena_bounds if arena_active() else chamber_bounds
	lead=0
	global_position=bounded(target.global_position+Vector2(0,float(settings.vertical_offset)))
	reset_smoothing();force_update_scroll()
func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not bounds.has_area(): return
	chamber_bounds=WorldRoomSpace.camera_envelope(room.contract.world_geometry,target.position,chamber_bounds)
	var envelope:=room.arena_bounds if arena_active() else chamber_bounds
	var weight:=1-exp(-delta/float(settings.zone_seconds))
	bounds=Rect2(bounds.position.lerp(envelope.position,weight),bounds.size.lerp(envelope.size,weight))
	if bounds.position.distance_to(envelope.position)+bounds.size.distance_to(envelope.size)<.05: bounds=envelope
	var dead: Array=settings.enclosed_dead_zone if enclosed() else settings.dead_zone
	var dead_zone:=Vector2(dead[0],dead[1])
	var look:=float(settings.enclosed_lead_distance if enclosed() else settings.lead_distance)
	lead=lerpf(lead,clampf(target.velocity.x/float(settings.lead_speed),-1,1)*look,1-exp(-delta/float(settings.lead_seconds)))
	var desired:=target.global_position+Vector2(lead,float(settings.vertical_offset))
	var error:=desired-global_position
	var goal:=global_position+Vector2(signf(error.x)*maxf(0,absf(error.x)-dead_zone.x),signf(error.y)*maxf(0,absf(error.y)-dead_zone.y))
	if arena_active():
		# Keep the landing floor in view while the current viewport also fits the player.
		var half_height:=get_viewport_rect().size.y/(2*zoom.y)
		goal.y=minf(bounds.end.y-half_height,target.global_position.y+half_height-float(settings.arena_headroom))
	var vertical_time:=lerpf(float(settings.vertical_seconds),float(settings.fall_seconds),clampf(target.velocity.y/float(settings.fall_speed),0,1))
	global_position=bounded(Vector2(lerpf(global_position.x,goal.x,1-exp(-delta/float(settings.horizontal_seconds))),lerpf(global_position.y,goal.y,1-exp(-delta/vertical_time))))
	# A concave chamber turn can move the envelope farther than one screen.
	# Smooth the scenery, but never let that interpolation lose the actor.
	var visible_half:=get_viewport_rect().size/(2*zoom)
	if not arena_active():
		global_position.x=clampf(global_position.x,target.global_position.x-visible_half.x+48,target.global_position.x+visible_half.x-48)
		global_position.y=clampf(global_position.y,target.global_position.y-visible_half.y+48,target.global_position.y+visible_half.y-64)
	if arena_active():
		# Recoil can outrun the smooth floor preference. Actor visibility wins at
		# the arena edge, even when its sprite needs a little space above it.
		var half_height:=get_viewport_rect().size.y/(2*zoom.y)
		var margin:=float(settings.arena_headroom)
		global_position.y=clampf(global_position.y,target.global_position.y-half_height+float(settings.arena_footroom),target.global_position.y+half_height-margin)
		force_update_scroll()

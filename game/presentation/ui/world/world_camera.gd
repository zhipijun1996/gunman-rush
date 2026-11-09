class_name WorldCamera
extends Camera2D
## Sole formal view owner: composition -> target -> damping -> safe projection -> shake.
var target: PlayerMotor
var controller: PlayerController
var room: FixedWorldRoom
var settings: Dictionary
var bounds := Rect2()
var zones := WorldCameraZones.new()
var frame: Dictionary = {}
var base_center := Vector2.ZERO
var follow_anchor := Vector2.ZERO
var observation_direction := 1.0
var lead := 0.0
var action_offset := Vector2.ZERO
var look_offset := 0.0
var vertical_focus := 0.0
var _rise_speed := 1.0
var looking := false
var fall_catchup := false
var legal_centers := Rect2()
var _direction_candidate := 0.0
var _direction_age := 0.0
var _look_age := 0.0
var _look_direction := 0.0
var _look_blocked := false
var _activity_serial := 0
var _fall_blend := 0.0
var _composition := Vector2.ZERO
var _takeover: Dictionary = {}
var _token := 0
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _elapsed := 0.0
var _initialized := false
var _display_current := Rect2()
var _last_zone := ""
var _last_ordinary := Vector2.ZERO
var _zone_bias := Vector2.ZERO

func _ready() -> void:
	process_physics_priority=1250
	position_smoothing_enabled=false
	zoom=Vector2.ONE*float(settings.zoom)
	if controller!=null:
		controller.router.cancelled.connect(_cancel_input)
		controller.jump_ability.jumped.connect(_cancel_look)
		controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, _shot_id: int) -> void:_cancel_look())
func _cancel_input(_reason: String) -> void:
	_look_age=0;_look_blocked=false;looking=false
func _cancel_look() -> void:
	_look_age=0;_look_blocked=true;looking=false

func enter_room(_physical_bounds: Rect2) -> void:
	zones.configure(room,settings)
	reset_view()
func reset_view() -> void:
	zones.select_initial(target.global_position)
	lead=0;observation_direction=1;action_offset=Vector2.ZERO;look_offset=0;looking=false
	_direction_candidate=0;_direction_age=0;_look_age=0;_look_direction=0;_look_blocked=false
	fall_catchup=false;_fall_blend=0;_takeover.clear();_token+=1
	_shake_time=0;_shake_strength=0;offset=Vector2.ZERO
	_activity_serial=controller.router.camera_activity_serial if controller!=null else 0
	follow_anchor=target.global_position
	frame=zones.update(target.global_position,0)
	_composition=_zone_offset(frame.a)
	vertical_focus=0;_rise_speed=1
	base_center=target.global_position+_composition
	_last_zone="";_zone_bias=Vector2.ZERO
	_display_current=Rect2()
	_initialized=true
	_step(0,true)
	reset_smoothing();force_update_scroll()

func begin_takeover(owner: Node, point: Vector2, display: Rect2, seconds: float=.3) -> int:
	if not is_instance_valid(owner) or not point.is_finite() or not display.has_area():return -1
	_token+=1
	_takeover={"owner":weakref(owner),"point":point,"display":display,"seconds":maxf(.02,seconds)}
	_cancel_look()
	return _token
func end_takeover(token: int) -> void:
	if token==_token:_takeover.clear()
func shake(strength: float, duration: float) -> void:
	_shake_strength=minf(maxf(_shake_strength,strength),float(settings.shake_max))
	_shake_duration=maxf(.01,duration);_shake_time=_shake_duration
func _physics_process(delta: float) -> void:
	if _initialized and is_instance_valid(target) and is_instance_valid(room):_step(delta,false)

func _step(delta: float, snap: bool) -> void:
	_elapsed+=delta
	frame=zones.update(target.global_position,delta)
	if not _takeover.is_empty() and _takeover.owner.get_ref()==null:_takeover.clear()
	var t:=float(frame.blend)
	var a: Dictionary=frame.a
	var b: Dictionary=frame.b
	var custom_zoom:=lerpf(float(a.get("zoom",settings.zoom)),float(b.get("zoom",settings.zoom)),t)
	zoom=Vector2.ONE*(custom_zoom if snap else lerpf(zoom.x,custom_zoom,_weight(delta,float(settings.zoom_seconds))))
	var half:=get_viewport_rect().size/(2*zoom)
	if not snap:_advance_observation(delta,half)
	var dead:=Vector2(float(settings.dead_zone_width)*half.x*2,float(settings.dead_zone_height)*half.y*2)
	var error:=target.global_position-follow_anchor
	follow_anchor+=Vector2(signf(error.x)*maxf(0,absf(error.x)-dead.x),signf(error.y)*maxf(0,absf(error.y)-dead.y))
	var composition:=_zone_offset(a).lerp(_zone_offset(b),t)
	_composition=composition if snap else _composition.lerp(composition,_weight(delta,float(settings.zone_seconds)))
	_advance_vertical_focus(delta,half,snap)
	var neutral:=follow_anchor+_composition+Vector2(lead,vertical_focus)+action_offset
	var ordinary:=_compose(a,neutral,half).lerp(_compose(b,neutral,half),t)
	var display_a:=_display(a,half)
	var display_b:=_display(b,half)
	bounds=Rect2(display_a.position.lerp(display_b.position,t),display_a.size.lerp(display_b.size,t))
	# Only the declared local passage may relax the two zones' boundaries.
	if not frame.portal.is_empty():
		var passage:=FixedWorldProvider.rect(frame.portal.display)
		var expansion:=sin(PI*t)
		bounds=Rect2(bounds.position.lerp(passage.position,expansion),bounds.size.lerp(passage.size,expansion))
	if snap or not _display_current.has_area():_display_current=bounds
	else:
		var ease:=_weight(delta,float(settings.arena_seconds if a.get("arena",false) else settings.zone_seconds))
		_display_current=Rect2(_display_current.position.lerp(bounds.position,ease),_display_current.size.lerp(bounds.size,ease))
	bounds=_display_current
	var zone_key:=str(frame.a.id)+":"+str(frame.b.id)
	if not snap and not _last_zone.is_empty() and zone_key!=_last_zone:
		_zone_bias+=_last_ordinary-ordinary
	_zone_bias*=1.0-_weight(delta,float(settings.zone_seconds))
	ordinary+=_zone_bias
	_last_ordinary=ordinary;_last_zone=zone_key
	var proposed:=_door_goal(ordinary,half)
	var takeover_seconds:=0.0
	if not _takeover.is_empty():
		proposed=_takeover.point;bounds=_takeover.display;takeover_seconds=float(_takeover.seconds)
	var limits:=WorldCameraZones.center_range(bounds,half)
	limits=_door_constraints(limits,half)
	_update_look(delta,a,b,half)
	proposed.y+=look_offset
	# All offsets, door planes and body visibility share this final legal range.
	legal_centers=_with_player_visibility(limits,half)
	proposed=proposed.clamp(legal_centers.position,legal_centers.end)
	var tx:=float(settings.horizontal_seconds)
	var ty:=lerpf(float(settings.vertical_seconds),float(settings.fall_seconds),_fall_blend)
	if a.get("arena",false):tx=float(settings.arena_seconds);ty=tx
	if takeover_seconds>0:tx=takeover_seconds;ty=takeover_seconds
	if snap:base_center=proposed
	else:base_center=Vector2(lerpf(base_center.x,proposed.x,_weight(delta,tx)),lerpf(base_center.y,proposed.y,_weight(delta,ty)))
	base_center=base_center.clamp(legal_centers.position,legal_centers.end)
	var tremor:=Vector2.ZERO
	if _shake_time>0:
		_shake_time=maxf(0,_shake_time-delta)
		var strength:=_shake_strength*_shake_time/_shake_duration
		tremor=Vector2(sin(_elapsed*83),sin(_elapsed*109+.7))*strength
	# Camera2D.offset is never used: actual final view is bounded, including shake.
	global_position=(base_center+tremor).clamp(legal_centers.position,legal_centers.end)
	force_update_scroll()
	room.update_camera_concealment(zones.active_id,frame)

func _advance_observation(delta: float, half: Vector2) -> void:
	var input_axis:=controller.router.axis if controller!=null else 0.0
	if absf(input_axis)>=float(settings.direction_input_threshold):
		observation_direction=signf(input_axis);_direction_age=0;_direction_candidate=0
	elif target.damage_remaining<=0 and absf(target.velocity.x)>=float(settings.trend_speed):
		var direction:=signf(target.velocity.x)
		if _direction_candidate!=direction:_direction_candidate=direction;_direction_age=0
		_direction_age+=delta
		if _direction_age>=float(settings.trend_confirm_seconds):observation_direction=direction
	else:_direction_age=0;_direction_candidate=0
	lead=lerpf(lead,observation_direction*half.x*2*float(settings.lookahead_width),_weight(delta,float(settings.lead_seconds)))
	# Generic high-speed motion response: no per-ability camera state machine.
	var speed:=target.velocity.length()
	var fast:=maxf(0,speed-float(settings.action_speed_threshold))
	var wanted:=target.velocity.normalized()*minf(fast*float(settings.action_seconds),half.x*float(settings.action_max_half_width)) if target.damage_remaining<=0 else Vector2.ZERO
	wanted.y=0 # One phase-aware vertical target owns all airborne anticipation.
	if target.velocity.y>=float(settings.fall_enter_speed):fall_catchup=true
	elif target.velocity.y<=float(settings.fall_exit_speed) or target.is_on_floor():fall_catchup=false
	_fall_blend=lerpf(_fall_blend,1.0 if fall_catchup else 0.0,_weight(delta,float(settings.fall_blend_seconds)))
	action_offset=action_offset.lerp(wanted,_weight(delta,float(settings.action_blend_seconds)))

func _advance_vertical_focus(delta: float, half: Vector2, snap: bool) -> void:
	var grounded:=target.is_on_floor()
	# Authored composition and the follow anchor are never animated by jump phases.
	var amplitude:=minf(float(settings.vertical_focus_max),half.y*2*float(settings.vertical_focus_height))
	var wanted:=-amplitude
	var seconds:=float(settings.landing_focus_seconds if grounded else settings.vertical_focus_seconds)
	if _composition.y>0:
		# Explicit descent surveys retain their established fast-fall landing preview.
		wanted=_fall_blend*half.y*2*float(settings.fall_look_height)
		seconds=float(settings.action_blend_seconds)
	else:
		if grounded:_rise_speed=1
		else:
			_rise_speed=maxf(_rise_speed,-target.velocity.y)
			if target.velocity.y<0:
				wanted=-amplitude*smoothstep(0,1,clampf(-target.velocity.y/_rise_speed,0,1))
			else:
				wanted=amplitude*smoothstep(0,1,clampf(target.velocity.y/float(settings.fall_enter_speed),0,1))
	if frame.a.get("arena",false):wanted=0
	vertical_focus=wanted if snap else lerpf(vertical_focus,wanted,_weight(delta,seconds))

func _compose(zone: Dictionary, neutral: Vector2, half: Vector2) -> Vector2:
	var profile:=str(zone.get("profile","bounded_follow"))
	var display:=FixedWorldProvider.rect(zone.display)
	var anchor:=FixedWorldProvider.point(zone.get("anchor",[display.get_center().x,display.get_center().y]))
	var ranges:=FixedWorldProvider.point(zone.get("follow_range",settings.templates[profile]))
	var result:=neutral
	for axis: int in 2:
		# A fixed arena too large for the viewport gets finite travel on that axis.
		var limit:=ranges[axis]
		if profile=="fixed_arena":limit=maxf(limit,(display.size[axis]-half[axis]*2)*.5)
		if limit>=0:result[axis]=clampf(neutral[axis],anchor[axis]-limit,anchor[axis]+limit)
	return result
func _zone_offset(zone: Dictionary) -> Vector2:
	return FixedWorldProvider.point(zone.get("offset",settings.composition_offset))
func _display(zone: Dictionary, half: Vector2) -> Rect2:
	var result:=FixedWorldProvider.rect(zone.display)
	# Authored small-room fill extends beyond the physical boundary. No zoom fitting.
	for axis: int in 2:
		if result.size[axis]<2*half[axis]:
			result.position[axis]=result.get_center()[axis]-half[axis]
			result.size[axis]=2*half[axis]
	return result
func _door_goal(value: Vector2, half: Vector2) -> Vector2:
	if str(frame.a.id)=="arena" or not _takeover.is_empty():return value
	var result:=value
	for door: Dictionary in room.doors:
		var portal:=FixedWorldProvider.point(door.position_candidate.local_world_units)
		var axis:=1 if str(door.direction) in ["up","down"] else 0
		if absf(target.global_position[1-axis]-portal[1-axis])>float(settings.door_across) or absf(target.global_position[axis]-portal[axis])>half[axis]*float(settings.door_approach):continue
		var depth:=absf(target.global_position[axis]-portal[axis])
		var across:=absf(target.global_position[1-axis]-portal[1-axis])
		var influence:=(1.0-smoothstep(half[axis]*.6,half[axis]*float(settings.door_approach),depth))*(1.0-smoothstep(float(settings.door_across)*.5,float(settings.door_across),across))
		var edge_center:=portal[axis]+half[axis]*(1 if str(door.direction) in ["up","left"] else -1)
		result[axis]=lerpf(result[axis],edge_center,influence)
	return result
func _door_constraints(limits: Rect2, half: Vector2) -> Rect2:
	if str(frame.a.id)=="arena" or not _takeover.is_empty():return limits
	var low:=limits.position;var high:=limits.end
	for door: Dictionary in room.doors:
		var portal:=FixedWorldProvider.point(door.position_candidate.local_world_units)
		var axis:=1 if str(door.direction) in ["up","down"] else 0
		var across:=absf(target.global_position[1-axis]-portal[1-axis])
		var depth:=absf(target.global_position[axis]-portal[axis])
		if across>float(settings.door_across) or depth>half[axis]*float(settings.door_approach):continue
		var side:=1.0 if str(door.direction) in ["up","left"] else -1.0
		var edge_center:=portal[axis]+side*half[axis]
		if side>0:low[axis]=maxf(low[axis],edge_center)
		else:high[axis]=minf(high[axis],edge_center)
		if low[axis]>high[axis]:low[axis]=edge_center;high[axis]=edge_center
	return Rect2(low,high-low)
func _with_player_visibility(limits: Rect2, half: Vector2) -> Rect2:
	var margin:=FixedWorldProvider.point(settings.player_margin)
	var low:=limits.position.max(target.global_position-half+margin)
	var high:=limits.end.min(target.global_position+half-margin)
	for axis: int in 2:
		if low[axis]>high[axis]:
			# Invalid authoring cannot reveal beyond a secret's legal display.
			var nearest:=clampf(target.global_position[axis],limits.position[axis],limits.end[axis])
			low[axis]=nearest;high[axis]=nearest
	return Rect2(low,high-low)
func _update_look(delta: float, a: Dictionary, b: Dictionary, half: Vector2) -> void:
	var request:=controller.router.camera_look_axis if controller!=null else 0.0
	var active:=controller==null or controller.active
	var attack:=controller!=null and (controller.router.aim_engaged or controller.router.focus_heal_held() or controller.router.camera_activity_serial!=_activity_serial)
	if controller!=null:_activity_serial=controller.router.camera_activity_serial
	var still:=target.is_on_floor() and absf(target.velocity.x)<=float(settings.look_stationary_speed) and absf(target.velocity.y)<1 and (controller==null or absf(controller.router.axis)<.1)
	if is_zero_approx(request) and (controller==null or absf(controller.router.look_axis)<.35):_look_blocked=false
	elif not still or attack or not active or not _takeover.is_empty():_look_blocked=true
	var allowed:=bool(a.get("look_up" if request<0 else "look_down",true)) and bool(b.get("look_up" if request<0 else "look_down",true))
	if not still or not allowed or _look_blocked or is_zero_approx(request):_look_age=0;looking=false
	else:
		if signf(request)!=_look_direction:_look_age=0
		_look_direction=signf(request);_look_age+=delta
		looking=_look_age>=float(settings.look_delay_seconds)
	var desired:=signf(request)*half.y*2*float(settings.look_height) if looking else 0.0
	# Per-zone legal look center range is independent of normal locked follow axes.
	if looking:
		var view_range_a: Array=a.get("look_y",[-1e12,1e12])
		var view_range_b: Array=b.get("look_y",[-1e12,1e12])
		desired=clampf(base_center.y+desired,maxf(view_range_a[0],view_range_b[0]),minf(view_range_a[1],view_range_b[1]))-base_center.y
	look_offset=lerpf(look_offset,desired,_weight(delta,float(settings.look_seconds)))
static func _weight(delta: float, seconds: float) -> float:
	return 1.0-exp(-delta/maxf(.001,seconds))

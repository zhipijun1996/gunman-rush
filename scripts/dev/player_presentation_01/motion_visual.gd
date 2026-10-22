class_name PlayerMotionCandidateVisual
extends UnderworldPlayer
## Opt-in development consumer of the actual actor. Protected Underworld/body
## resources remain unchanged. Inherited accepted state/aim/muzzle are read only.
const CANDIDATE_TEXTURE := preload("res://assets/player_presentation_01/motion_v1/motion_source.png")
const CLIP_DATA := preload("res://resources/player_presentation_01/motion_clip_data.gd")
@export var profile: PlayerMotionCandidateProfile = preload("res://resources/player_presentation_01/motion_v1.tres")
var candidate_enabled := true
var _clips: Dictionary = {}
var _gait_distance := 0.0
var _previous_position := Vector2.ZERO
var _airborne_observed := false
var _fall_peak := 0.0
var _dust: Array[Dictionary] = []
var accepted_jumps := 0
var accepted_lands := 0
var dust_peak := 0
var displayed_frame := 0
var displayed_state := "idle"
var _session_id := -1

func _ready() -> void:
	super._ready()
	process_priority = 5
	process_physics_priority = 5 # Observe after the real Controller has moved.
	_clips = CLIP_DATA.DATA.duplicate(true)
	_previous_position = motor.global_position
	_session_id = controller.session_id
	if profile == null or not profile.valid(): candidate_enabled = false
	controller.jump_ability.jumped.connect(_accepted_jump)
	controller.died.connect(func() -> void: _dust.clear())

func set_candidate_enabled(value: bool) -> void:
	candidate_enabled = value and profile != null and profile.valid()
	_dust.clear()
	queue_redraw()

func _accepted_jump() -> void:
	if _dead: return
	accepted_jumps += 1
	_airborne_observed = true
	_fall_peak = 0.0
	_spawn_dust(false, 0.0)

func _accepted_landing() -> void:
	super._accepted_landing()
	if _dead or not _airborne_observed: return
	accepted_lands += 1
	_spawn_dust(true, _fall_peak)
	_airborne_observed = false
	_fall_peak = 0.0

func _segment_returned() -> void:
	super._segment_returned()
	_dust.clear()
	_previous_position = motor.global_position
	_airborne_observed = false
	_fall_peak = 0.0

func _physics_process(delta: float) -> void:
	if controller.session_id != _session_id:
		_session_id = controller.session_id
		_dust.clear()
		_gait_distance = 0.0
		_airborne_observed = false
		_fall_peak = 0.0
		_previous_position = motor.global_position
	if not motor.is_on_floor():
		_airborne_observed = true
		_fall_peak = maxf(_fall_peak, motor.velocity.y)
	# Integrate actual accepted locomotion distance; old renderer multiplies the
	# entire elapsed state by the *current* velocity, which jumps phase on ramps.
	var travelled := motor.global_position.x - _previous_position.x
	if motor.is_on_floor() and absf(motor.normal_velocity.x) > 10 and signf(travelled) == signf(motor.normal_velocity.x):
		_gait_distance += minf(absf(travelled), absf(motor.normal_velocity.x) * delta)
	_previous_position = motor.global_position

func _process(delta: float) -> void:
	super._process(delta)
	if _dead: _dust.clear()
	for i: int in range(_dust.size() - 1, -1, -1):
		_dust[i].age += delta
		if _dust[i].age >= _dust[i].duration: _dust.remove_at(i)
	queue_redraw()

func _spawn_dust(landing: bool, speed: float) -> void:
	if not candidate_enabled or profile == null: return
	var count := profile.landing_particles if landing else profile.takeoff_particles
	var duration := profile.landing_seconds if landing else profile.takeoff_seconds
	var intensity := clampf(speed / motor.tuning.max_normal_fall_speed, 0.25, 1.0) if landing else 0.3
	var origin := motor.to_global(Vector2(0, 18))
	for i: int in count:
		if _dust.size() >= profile.particle_cap: break
		var side := -1.0 if i % 2 == 0 else 1.0
		var rank := float(i / 2)
		_dust.append({"origin":origin,"velocity":Vector2(side * (profile.dust_spread_speed + rank * 6) * (0.7 + intensity), -profile.dust_lift_speed - fmod(rank * 9, 18)), "age":0.0, "duration":duration, "size":profile.dust_particle_size + fmod(rank, 2), "landing":landing})
	dust_peak = maxi(dust_peak, _dust.size())

func candidate_receipt() -> Dictionary:
	return {"enabled":candidate_enabled,"state":displayed_state,"frame":displayed_frame,"gait_distance":_gait_distance,"accepted_jumps":accepted_jumps,"accepted_lands":accepted_lands,"dust_count":_dust.size(),"dust_peak":dust_peak,"muzzle":(motor.get_node("CourierVisual") as CourierVisual).visible_muzzle_position(),"foot_world":motor.to_global(Vector2(0,18)),"source":"idle_fall new frames;run original pixels with distance phase only;run art rework unverified"}

func _draw() -> void:
	if not candidate_enabled:
		super._draw()
		return
	if _build.is_empty() or _clips.is_empty(): return
	displayed_state = animation_state
	if animation_state in ["idle", "fall"] and not _dead:
		var frames: Array = _clips.frames[animation_state]
		var fps := profile.idle_fps if animation_state == "idle" else profile.fall_fps
		displayed_frame = posmod(int(_state_age * fps), frames.size())
		var entry: Dictionary = frames[displayed_frame]
		var r: Array = entry.rect
		var pivot: Array = entry.pivot
		var factor := UnderworldActors.HUMANOID_HEIGHT / float(_clips.reference_body_height)
		var target := Rect2(Vector2(-float(pivot[0]),-float(pivot[1])) * factor + Vector2(0,18), Vector2(r[2],r[3]) * factor)
		draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
		draw_texture_rect_region(CANDIDATE_TEXTURE,target,Rect2(r[0],r[1],r[2],r[3]))
		draw_set_transform(Vector2.ZERO)
	else:
		# Existing run pixels remain the fallback after two source-art rejections.
		var frames: Array = _frames_by_state[animation_state]
		displayed_frame = posmod(int(_gait_distance / profile.gait_cycle_distance * frames.size()), frames.size()) if animation_state == "run" else frame_index
		var entry: Dictionary = frames[displayed_frame]
		var r: Array = entry.rect
		var factor := UnderworldActors.HUMANOID_HEIGHT / float(_build.standing_body_source_height)
		var canvas: Array = _build.canvas
		var pivot: Array = _build.anchor
		var target := Rect2(Vector2(-float(pivot[0]),-float(pivot[1])) * factor + Vector2(0,18),Vector2(canvas[0],canvas[1]) * factor)
		draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
		draw_texture_rect_region(RUN_SHEET if entry.atlas == "run_sheet.png" else STATES_SHEET,target,Rect2(r[0],r[1],r[2],r[3]))
		draw_set_transform(Vector2.ZERO)
	if _dead: return
	# Preserve the actual formal upper-body and grapple anchor, without setters.
	if _hurt_remaining > 0:
		var age := feedback.hurt_seconds - _hurt_remaining
		for i: int in 8:
			var direction := Vector2.from_angle(i * TAU / 8 + .2)
			var point := to_local(_hurt_origin) + direction * (5 + age * 65)
			draw_line(point,point + direction * 3,Color("ead8a3",1 - age / feedback.hurt_seconds),2,false)
	var anchor := motor.get_node("CourierVisual") as CourierVisual
	var muzzle := to_local(anchor.visible_muzzle_position())
	var aim := controller.router.aim_direction.normalized()
	if aim.is_zero_approx(): aim = anchor.aim_direction
	var hand := Vector2(facing * 4,-1)
	draw_line(hand,muzzle,Color("101816"),4,false)
	draw_line(hand + aim * 8 - Vector2(0,2),muzzle - Vector2(0,2),Color("9b7740"),2,false)
	if _flash > 0: draw_rect(Rect2(muzzle + aim * 4 - Vector2(2,2),Vector2(6,6)),Color("ead8a3"))
	PlayerFeedback.draw_grapple(self,controller,to_global(hand))
	for item: Dictionary in _dust:
		var age := float(item.age)
		var ratio := age / float(item.duration)
		var point := to_local(item.origin + item.velocity * age + Vector2(0,18 * age * age)).snapped(Vector2(1,1))
		var color := profile.dust_color
		color.a = (1 - ratio) * 0.8
		var size := float(item.size) * (1 + ratio)
		draw_rect(Rect2(point - Vector2(size,size / 2),Vector2(size * 2,size)),color)

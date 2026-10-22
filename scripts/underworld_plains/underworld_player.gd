class_name UnderworldPlayer
extends PixelPlainsActor
## Actual generated body keyframes. Body faces accepted locomotion; the existing
## weapon remains independent, using CourierVisual's authoritative muzzle.
const BUILD_PATH := "res://assets/underworld_plains/player_animation/animation_build.json"
const RUN_SHEET := preload("res://assets/underworld_plains/player_animation/run_sheet.png")
const STATES_SHEET := preload("res://assets/underworld_plains/player_animation/states_sheet.png")
var animation_state := "idle"
var frame_index := 0
var facing := 1.0
var _state_age := 0.0
var _landing_remaining := 0.0
var _build: Dictionary = {}
var feedback: DamageFeedbackDefinition = preload("res://resources/damage/feedback.tres")
var _damage_flash_remaining := 0.0
var _hurt_origin := Vector2.ZERO
var _accepted_hurt_count := 0
var _return_fade_remaining := 0.0
var return_echo_count := 0
var _frames_by_state: Dictionary = {}
## Pixel consumers disable Adapter processing, but its accepted-event callbacks
## still pose the hidden Courier used by the authoritative weapon muzzle.
@export var recover_weapon_anchor := true
var _anchor_recoil_remaining := 0.0
var _anchor_session := -1

func _ready() -> void:
	super._ready()
	_build = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH))
	for frame: Dictionary in _build.frames:
		var state: String = frame.state
		if not _frames_by_state.has(state): _frames_by_state[state] = []
		_frames_by_state[state].append(frame)
	controller.landed.connect(_accepted_landing)
	controller.segment_returned.connect(_segment_returned)
	controller.shoot_ability.shot_fired.connect(_accepted_weapon_shot)
	_anchor_session = controller.session_id
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _accepted_weapon_shot(_direction: Vector2, _shot_id: int) -> void:
	if _dead or controller.actor_resources.health.terminal: return
	# Courier's existing shot_pose owns the kick. Only its recovery was missing
	# while the legacy Adapter's per-frame state selection was disabled.
	_anchor_recoil_remaining = PlayerVisualAdapter.RECOIL_POSE_SECONDS

func _accepted_landing() -> void:
	if not _dead: _landing_remaining = .16

func _segment_returned() -> void:
	_anchor_recoil_remaining = 0.0
	# HP commits before the synchronous segment relocation. Keep an actual old
	# body silhouette in the old world while the safe-spawn body fades in.
	if _hurt_remaining > 0 and not _frames_by_state.is_empty():
		var frame: Dictionary = _frames_by_state["hurt"][0]
		var r: Array = frame.rect
		var echo := DamageReturnEcho.new()
		echo.name = "AcceptedEnvironmentReturnEcho"
		echo.source = STATES_SHEET
		echo.source_rect = Rect2(r[0],r[1],r[2],r[3])
		var factor := UnderworldActors.HUMANOID_HEIGHT/float(_build.standing_body_source_height)
		echo.destination = Rect2(Vector2(-float(_build.anchor[0]),-float(_build.anchor[1]))*factor+Vector2(0,18),Vector2(_build.canvas[0],_build.canvas[1])*factor)
		echo.facing = facing
		echo.duration = feedback.return_transition_seconds
		motor.get_parent().add_child(echo)
		echo.global_position = _hurt_origin
		return_echo_count += 1
		_return_fade_remaining = echo.duration
	_landing_remaining = 0.0
	_state_age = 0.0
	frame_index = 0
	_hurt_origin = motor.global_position

func _health_changed(result: ActorResourceResult) -> void:
	super._health_changed(result)
	if result == null or result.status != ActorResourceResult.Status.APPLIED or result.operation != &"damage" or result.amount_applied >= 0: return
	_anchor_recoil_remaining = 0.0
	if result.snapshot.terminal:
		_damage_flash_remaining = 0.0
		return
	_hurt_remaining = feedback.hurt_seconds
	_damage_flash_remaining = feedback.flash_seconds
	_hurt_origin = motor.global_position
	_accepted_hurt_count += 1

func _process(delta: float) -> void:
	super._process(delta)
	if controller.session_id != _anchor_session:
		_anchor_session = controller.session_id
		_anchor_recoil_remaining = 0.0
	_anchor_recoil_remaining = maxf(0.0, _anchor_recoil_remaining-delta)
	_damage_flash_remaining = maxf(0, _damage_flash_remaining-delta)
	_return_fade_remaining = maxf(0, _return_fade_remaining-delta)
	var flash_on := _damage_flash_remaining > 0 and int((feedback.flash_seconds-_damage_flash_remaining)*feedback.flash_frequency)%2 == 0
	modulate = Color(1,.62,.48,.52) if flash_on and not _dead else Color.WHITE
	if _return_fade_remaining > 0: modulate.a *= lerpf(.25,1.0,1-_return_fade_remaining/feedback.return_transition_seconds)
	if _build.is_empty(): return
	_landing_remaining = maxf(0.0, _landing_remaining-delta)
	# normal_velocity is the Motor's accepted locomotion channel; recoil and aim
	# cannot make an A-held body look right. At rest retain the last move facing.
	if not _dead:
		if absf(motor.normal_velocity.x)>5.0:
			facing = signf(motor.normal_velocity.x)
		elif controller.active and absf(controller.router.sample_axes())>.1:
			facing = signf(controller.router.sample_axes())
	var next := _select_state()
	if next != animation_state:
		animation_state = next
		_state_age = 0.0
	else:
		_state_age += delta
	var clip: Dictionary = _build.animations[animation_state]
	var count: int = _frames_by_state[animation_state].size()
	var fps := float(clip.fps)
	if animation_state == "run":
		# One full authored gait follows travelled locomotion at ordinary speeds.
		fps = clampf(absf(motor.normal_velocity.x) / 96.0 * count, 10.0, 24.0)
	var wanted := int(_state_age*fps)
	frame_index = posmod(wanted,count) if bool(clip.loop) else mini(wanted,count-1)
	_recover_weapon_anchor()

func _recover_weapon_anchor() -> void:
	if not recover_weapon_anchor or _dead or _hurt_remaining > 0.0 or _anchor_recoil_remaining > 0.0: return
	var anchor := motor.get_node("CourierVisual") as CourierVisual
	if anchor.state in [&"hurt", &"recoil", &"machine_recoil", &"death"]:
		anchor.set_state(&"idle")

func _select_state() -> String:
	if _dead: return "death"
	if _hurt_remaining>0.0: return "hurt"
	if not motor.is_on_floor(): return "rise" if motor.velocity.y < -10.0 else "fall"
	if _landing_remaining>0.0 and absf(motor.normal_velocity.x)<50.0: return "land"
	if absf(motor.normal_velocity.x)>10.0: return "run"
	return "idle"

func animation_receipt() -> Dictionary:
	# Read-only real renderer state for captures; no test-only state injection.
	var frame: Dictionary = _frames_by_state[animation_state][frame_index] if _frames_by_state.has(animation_state) else {}
	return {"state":animation_state,"frame_index":frame_index,"facing":facing,
		"source_atlas":frame.get("atlas",""),"source_rect":frame.get("rect",[]),
		"source_pixel_sha256":frame.get("pixel_sha256",""),"state_age":_state_age,
		"body_height_wu":UnderworldActors.HUMANOID_HEIGHT,
		"muzzle_world":(motor.get_node("CourierVisual") as CourierVisual).visible_muzzle_position(),
		"motor_position":motor.position,"normal_velocity":motor.normal_velocity,
		"aim":controller.router.aim_direction,"router_epoch":controller.router.epoch,
		"hurt_remaining":_hurt_remaining,"flash_remaining":_damage_flash_remaining,"accepted_hurt_count":_accepted_hurt_count,
		"return_fade_remaining":_return_fade_remaining,"return_echo_count":return_echo_count,
		"damage_remaining":motor.damage_remaining,"damage_velocity":motor.damage_velocity,
		"weapon_anchor_state":(motor.get_node("CourierVisual") as CourierVisual).state,
		"weapon_anchor_recoil_remaining":_anchor_recoil_remaining,
		"dead":_dead,"generated_body_keyframes":int(_build.get("generated_keyframes",0))}

func _draw() -> void:
	if _build.is_empty() or not _frames_by_state.has(animation_state): return
	var frame: Dictionary = _frames_by_state[animation_state][frame_index]
	var coords: Array = frame.rect
	var rect := Rect2(coords[0],coords[1],coords[2],coords[3])
	var canvas: Array = _build.canvas
	var pivot: Array = _build.anchor
	var scale_factor := UnderworldActors.HUMANOID_HEIGHT / float(_build.standing_body_source_height)
	var target := Rect2(Vector2(-float(pivot[0]),-float(pivot[1]))*scale_factor+Vector2(0,18),Vector2(canvas[0],canvas[1])*scale_factor)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1.0))
	draw_texture_rect_region(RUN_SHEET if frame.atlas=="run_sheet.png" else STATES_SHEET,target,rect)
	draw_set_transform(Vector2.ZERO)
	if _dead: return
	# Bounded generated-body hit burst. World-anchored origin is relocated only by
	# the accepted segment_returned event, never stretched across the teleport.
	if _hurt_remaining > 0:
		var age := feedback.hurt_seconds-_hurt_remaining
		var origin := to_local(_hurt_origin)
		for i: int in 8:
			var direction := Vector2.from_angle(i*TAU/8+.2)
			var point := origin+direction*(5+age*65)
			draw_line(point,point+direction*3,Color("ead8a3",1-age/feedback.hurt_seconds),2,false)
	var anchor := motor.get_node("CourierVisual") as CourierVisual
	var muzzle := to_local(anchor.visible_muzzle_position())
	var aim := controller.router.aim_direction.normalized()
	if aim.is_zero_approx(): aim=anchor.aim_direction
	var hand := Vector2(facing*4,-1)
	draw_line(hand,muzzle,Color("101816"),4.0,false)
	draw_line(hand+aim*8-Vector2(0,2),muzzle-Vector2(0,2),Color("9b7740"),2.0,false)
	if _flash>0: draw_rect(Rect2(muzzle+aim*4-Vector2(2,2),Vector2(6,6)),Color("ead8a3"))

	# Formal regions deliberately hide PlayerFeedback's legacy particle canvas.
	# Keep the accepted grapple/guide on this actual visible body, with the
	# same world-space hand used by its weapon arm. No traversal state writes.
	PlayerFeedback.draw_grapple(self, controller, to_global(hand))

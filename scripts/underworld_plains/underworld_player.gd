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
var _frames_by_state: Dictionary = {}

func _ready() -> void:
	super._ready()
	_build = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH))
	for frame: Dictionary in _build.frames:
		var state: String = frame.state
		if not _frames_by_state.has(state): _frames_by_state[state] = []
		_frames_by_state[state].append(frame)
	controller.landed.connect(_accepted_landing)
	controller.segment_returned.connect(_segment_returned)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _accepted_landing() -> void:
	if not _dead: _landing_remaining = .16

func _segment_returned() -> void:
	_landing_remaining = 0.0
	_state_age = 0.0
	frame_index = 0

func _process(delta: float) -> void:
	super._process(delta)
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
	var anchor := motor.get_node("CourierVisual") as CourierVisual
	var muzzle := to_local(anchor.visible_muzzle_position())
	var aim := controller.router.aim_direction.normalized()
	if aim.is_zero_approx(): aim=anchor.aim_direction
	var hand := Vector2(facing*4,-1)
	draw_line(hand,muzzle,Color("101816"),4.0,false)
	draw_line(hand+aim*8-Vector2(0,2),muzzle-Vector2(0,2),Color("9b7740"),2.0,false)
	if _flash>0: draw_rect(Rect2(muzzle+aim*4-Vector2(2,2),Vector2(6,6)),Color("ead8a3"))

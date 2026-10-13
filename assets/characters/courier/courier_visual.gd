class_name CourierVisual
extends Node2D
## Cosmetic only. Feet origin and 104px nominal height remain stable.
## V3 source pivots scale into this space; SVG layers remain an explicit fallback.
## Physics and projectile muzzle remain consumer-owned.
const STATES: Array[StringName] = [&"idle", &"run", &"jump", &"fall", &"recoil", &"hurt", &"death", &"double_jump", &"wall_attach", &"wall_kick", &"hook_cast", &"hook_fly", &"hook_pull", &"hook_kick", &"hook_miss", &"hook_contact_kick", &"hook_retract", &"land", &"machine_recoil", &"jump_start"]
@export var use_plains_v3 := true
var _painted_states: Dictionary = {}
var _action_catalog: Dictionary = {}
var _transition: Sprite2D
var _transition_age := 1.0
var _transition_arm_position := Vector2.ZERO
var _shot_age := 1.0
var transition_seconds := 0.07
var weapon_tier := 1
var wall_surface_x := 0.0
var _transition_hand_local := Vector2.ZERO
var state: StringName = &"idle"
var elapsed: float = 0.0
var movement_speed := 0.0
var landing_pose := 0.0
var _lean := 0.0
var _stride_clock := 0.0
var facing: float = 1.0
var aim_direction: Vector2 = Vector2.RIGHT
@onready var body: Sprite2D = $Body
@onready var scarf: Sprite2D = $Scarf
@onready var left_leg: Sprite2D = $LeftLeg
@onready var right_leg: Sprite2D = $RightLeg
@onready var arm: Sprite2D = $WeaponArm

func _ready() -> void:
	if not use_plains_v3:
		return
	_action_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/actor_actions/courier_manifest.json"))
	_transition = Sprite2D.new()
	_transition.centered = false
	_transition.visible = false
	add_child(_transition)
	move_child(_transition,body.get_index())
	_painted_states = PlainsActorAssets.catalog("hero").get("states", {})
	if _painted_states.is_empty():
		return
	for layer: Sprite2D in [scarf, left_leg, right_leg]:
		layer.visible = false
	body.centered = false
	arm.centered = false
	var weapon: Dictionary = weapon_art()
	arm.texture = PlainsActorAssets.region_texture(str(weapon.texture), weapon.region)
	arm.offset = -Vector2(float(weapon.pivot[0]), float(weapon.pivot[1]))
	_apply_painted_frame()

func _apply_painted_frame() -> void:
	# Hurt is a tint/pose on the supplied recoil key, not an invented seventh animation.
	var extended: bool = _action_catalog.get("states",{}).has(str(state))
	var animation: Dictionary = _action_catalog.states[str(state)] if extended else _painted_states.get(str(state),_painted_states.idle)
	var frames: Array = animation.frames
	var index := int(elapsed * float(animation.fps))
	index = index % frames.size() if bool(animation.loop) else mini(index, frames.size() - 1)
	var frame: Dictionary = frames[index]
	var source_scale := float(animation.get("uniform_scale",_action_catalog.uniform_scale)) if extended else float(PlainsActorAssets.catalog("hero").uniform_scale)
	var pivot := Vector2(float(frame.pivot[0]), float(frame.pivot[1]))
	var shoulder := Vector2(float(frame.shoulder[0]), float(frame.shoulder[1]))
	body.texture = PlainsActorAssets.region_texture(str(animation.get("texture",_action_catalog.texture)) if extended else str(frame.texture),frame.region)
	body.offset = Vector2.ZERO
	body.position = -pivot * Vector2(facing, 1.0) * source_scale
	body.scale = Vector2(facing, 1.0) * source_scale
	var squash := Vector2(1.0 + landing_pose * .07, 1.0 - landing_pose * .07)
	var lean := 0.0 if state == &"wall_attach" else _lean - aim_direction.x * exp(-_shot_age * 20) * .12
	body.skew = 0
	body.scale = Vector2(facing,1) * source_scale * squash
	body.rotation = -facing*.30 if state == &"hook_kick" else 0.0
	body.skew = -lean
	body.position = -(body.transform.x * pivot.x + body.transform.y * pivot.y)
	if state == &"wall_attach" and frame.has("wall_contact"):
		var contact: Array = frame.wall_contact
		body.position.x = wall_surface_x - (body.transform.x * float(contact[0]) + body.transform.y * float(contact[1])).x
	arm.position = (shoulder - pivot) * Vector2(facing, 1.0) * source_scale
	arm.position -= aim_direction * exp(-_shot_age * 18.0) * 6.0
	if _transition != null and _transition.visible:
		arm.position = _transition_arm_position.lerp(arm.position,smoothstep(0,1,minf(1,_transition_age/transition_seconds)))
	# Exact weapon aim preserves pointer/muzzle alignment; body and recoil settle continuously.
	arm.rotation = aim_direction.angle()
	var weapon_data := weapon_art()
	arm.texture = PlainsActorAssets.region_texture(str(weapon_data.texture),weapon_data.region)
	arm.offset = -Vector2(float(weapon_data.pivot[0]),float(weapon_data.pivot[1]))
	var weapon_scale := float(weapon_data.runtime_scale)
	arm.scale = Vector2(weapon_scale, weapon_scale * (-1.0 if aim_direction.x < 0.0 else 1.0))
	arm.visible = state not in [&"wall_attach",&"wall_kick",&"hook_cast",&"hook_fly",&"hook_pull",&"hook_kick",&"hook_contact_kick",&"hook_miss",&"hook_retract",&"death"]
	body.modulate.a = smoothstep(0,1,minf(1,_transition_age/transition_seconds)) if _transition != null and _transition.visible else 1.0
	if _transition != null:
		_transition.modulate.a = 1-body.modulate.a
		if _transition_age >= transition_seconds: _transition.visible = false; body.modulate.a = 1
	modulate.a = maxf(0.0, 1.0 - maxf(elapsed - 0.5, 0.0) * 2.0) if state == &"death" else 1.0

func set_state(next_state: StringName) -> void:
	if next_state not in STATES:
		return
	if state != next_state:
		if _transition != null and body.texture != null:
			_transition_hand_local = to_local(grapple_hand_position())
			_transition_arm_position = arm.position
			_transition.texture = body.texture
			_transition.transform = body.transform
			_transition.offset = body.offset
			_transition.visible = true
			_transition_age = 0
		state = next_state
		elapsed = 0.0

func set_facing(direction: float) -> void:
	facing = -1.0 if direction < 0.0 else 1.0

func set_aim_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001:
		aim_direction = direction.normalized()

func muzzle_position(direction: Vector2) -> Vector2:
	set_aim_direction(direction)
	if not is_zero_approx(direction.x): set_facing(direction.x)
	if not _painted_states.is_empty(): _apply_painted_frame()
	# Independent weapon pivot, along its local barrel; never the abdomen.
	var weapon: Dictionary = weapon_art()
	var muzzle: Array = weapon.get("muzzle", [66,0])
	var pivot: Array = weapon.get("pivot", [0,0])
	return arm.to_global(Vector2(muzzle[0]-pivot[0],muzzle[1]-pivot[1]))

func _process(delta: float) -> void:
	if get_tree().paused: return
	_transition_age += delta
	_shot_age += delta
	elapsed += delta * (clampf(absf(movement_speed) / 260.0, 0.0, 1.5) if state == &"run" else 1.0)
	landing_pose = move_toward(landing_pose, 0, delta / .1)
	_lean = lerpf(_lean, clampf(movement_speed / 260.0, -1, 1) * -.055, 1 - exp(-delta / .08))
	if not _painted_states.is_empty():
		_apply_painted_frame()
		return
	var bob: float = sin(elapsed * 3.5) * 0.8
	var stride: float = 0.0
	var squash: Vector2 = Vector2.ONE
	var tilt: float = 0.0
	match state:
		&"run":
			stride = sin(elapsed * 16.0) * 0.65
			bob = -abs(sin(elapsed * 16.0)) * 3.0
		&"jump":
			stride = -0.48
			bob = -3.0
		&"fall":
			stride = 0.25
			squash = Vector2(0.96, 1.04)
		&"recoil":
			tilt = -exp(-elapsed * 16.0) * 0.17 * facing
			bob = -exp(-elapsed * 16.0) * 3.0
		&"hurt":
			tilt = -facing * 0.22 * exp(-elapsed * 8.0)
			bob = -2.0
			squash = Vector2(1.06, 0.94)
		&"death":
			tilt = minf(elapsed * 5.0, 1.45) * facing
			bob = minf(elapsed * 18.0, 18.0)
	body.position = Vector2(-48.0, -112.0 + bob)
	body.scale = Vector2(facing, 1.0) * squash
	# Mirrored uncentered layer preserves the x=0 body center.
	body.position.x = 48.0 if facing < 0.0 else -48.0
	body.offset = Vector2.ZERO
	body.rotation = tilt
	scarf.position = Vector2(-13.0 * facing, -65.0 + bob)
	scarf.scale.x = facing
	scarf.rotation = sin(elapsed * 7.0) * 0.08 + tilt
	left_leg.position = Vector2(-8.0 * facing, -35.0 + bob)
	right_leg.position = Vector2(9.0 * facing, -35.0 + bob)
	left_leg.rotation = stride * facing + tilt
	right_leg.rotation = -stride * facing + tilt
	arm.position = Vector2(4.0 * facing, -51.0 + bob)
	arm.rotation = aim_direction.angle()
	arm.scale.y = -1.0 if aim_direction.x < 0.0 else 1.0
	arm.position -= aim_direction * (exp(-elapsed * 18.0) * 6.0 if state == &"recoil" else 0.0)
	modulate.a = maxf(0.0, 1.0 - maxf(elapsed - 0.5, 0.0) * 2.0) if state == &"death" else 1.0

func shot_pose() -> void:
	_shot_age = 0
	if state == &"machine_recoil": elapsed = 0

func clear_transition() -> void:
	_transition_age = 1
	if _transition != null: _transition.visible = false
	body.modulate.a = 1

func weapon_art() -> Dictionary:
	return _action_catalog.machine_weapon if weapon_tier == 2 and _action_catalog.has("machine_weapon") else PlainsActorAssets.catalog("hero").get("weapon",{})

func grapple_hand_position() -> Vector2:
	if _action_catalog.get("states",{}).has(str(state)):
		var animation: Dictionary = _action_catalog.states[str(state)]
		var frames: Array = animation.frames
		var index := mini(int(elapsed*float(animation.fps)),frames.size()-1)
		var point: Array = frames[index].get("grapple_hand",frames[index].shoulder)
		var hand_local := to_local(body.to_global(Vector2(point[0],point[1])))
		if _transition != null and _transition.visible:
			hand_local = _transition_hand_local.lerp(hand_local,smoothstep(0,1,minf(1,_transition_age/transition_seconds)))
		return to_global(hand_local)
	return arm.global_position

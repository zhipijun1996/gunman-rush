class_name CourierVisual
extends Node2D
## Cosmetic only. Origin is feet; source artwork stands 104px high.
## Scale uniformly to target height / 104. Physics remains consumer-owned.
const STATES: Array[StringName] = [&"idle", &"run", &"jump", &"fall", &"recoil", &"hurt", &"death"]
var state: StringName = &"idle"
var elapsed: float = 0.0
var facing: float = 1.0
var aim_direction: Vector2 = Vector2.RIGHT
@onready var body: Sprite2D = $Body
@onready var scarf: Sprite2D = $Scarf
@onready var left_leg: Sprite2D = $LeftLeg
@onready var right_leg: Sprite2D = $RightLeg
@onready var arm: Sprite2D = $WeaponArm

func set_state(next_state: StringName) -> void:
	if next_state not in STATES:
		return
	if state != next_state:
		state = next_state
		elapsed = 0.0

func set_facing(direction: float) -> void:
	facing = -1.0 if direction < 0.0 else 1.0

func set_aim_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001:
		aim_direction = direction.normalized()

func _process(delta: float) -> void:
	elapsed += delta
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

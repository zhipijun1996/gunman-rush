extends CharacterBody2D
## A minimal scale reference that can walk and jump; independent of the main game.

@export var spawn_position := Vector2.ZERO
@export var fall_limit := 430.0
@export var world_width := 640.0
@export var move_speed := 160.0
@export var jump_speed := -420.0
@export var gravity := 1040.0

var scripted_direction := 0.0
var scripted_jump := false
var previous_jump := false

func _ready() -> void:
	reset_position()

func reset_position() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_sync_visual_grid()

func _physics_process(delta: float) -> void:
	var direction := scripted_direction
	if Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction += 1.0
	direction = clampf(direction, -1.0, 1.0)
	velocity.x = move_toward(velocity.x, direction * move_speed, 1400.0 * delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	var jump_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	if ((jump_pressed and not previous_jump) or scripted_jump) and is_on_floor():
		velocity.y = jump_speed
	previous_jump = jump_pressed
	scripted_jump = false
	move_and_slide()
	global_position.x = clampf(global_position.x, 10.0, world_width - 10.0)
	if absf(direction) > 0.01:
		$Visual.scale.x = 1.0 if direction > 0.0 else -1.0
	if global_position.y > fall_limit:
		reset_position()
	_sync_visual_grid()

func _sync_visual_grid() -> void:
	$Visual.position = global_position.round() - global_position

class_name EnemyActor
extends Node

signal defeated(actor: EnemyActor)
@export var definition: EnemyDefinition
@export var motor: EnemyMotor
@export var brain: EnemyPatrolAI
@export var damageable: Damageable
var health := HealthState.new()
var _spawn := Vector2.ZERO
var _collision_layer := 0
var _collision_mask := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if definition == null or not definition.is_valid() or motor == null or brain == null or damageable == null:
		push_error("Enemy requires a valid definition and local components")
		get_tree().quit(1)
		return
	_spawn = motor.global_position
	_collision_layer = motor.collision_layer
	_collision_mask = motor.collision_mask
	damageable.faction = definition.faction
	damageable.actor_id = motor.get_instance_id()
	damageable.died.connect(_on_death)
	reset(&"initial")

func _physics_process(delta: float) -> void:
	physics_tick(delta)

func physics_tick(delta: float) -> void:
	if health.terminal:
		return
	var intent := brain.sample_intent(motor.global_position)
	if motor.step(intent, delta):
		brain.on_blocked()

func reset(_policy: StringName = &"legacy_test") -> void:
	# Only new-stage or explicit historical graybox restart. Segment returns will
	# retain this actor's health and phase, not invoke reset on all world objects.
	if definition == null or not definition.is_valid():
		return
	motor.stop()
	motor.global_position = _spawn
	motor.collision_layer = _collision_layer
	motor.collision_mask = _collision_mask
	motor.configure(definition)
	brain.configure(definition, _spawn.x)
	health.configure(definition.health_definition)
	damageable.bind_health(health)
	set_physics_process(not health.terminal)

func _on_death() -> void:
	motor.stop()
	motor.collision_layer = 0
	motor.collision_mask = 0
	set_physics_process(false)
	defeated.emit(self)

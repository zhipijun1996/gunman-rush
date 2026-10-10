class_name ModuleSawHazard
extends Node2D

var definition: ModuleSawDefinition
var module: PlatformingModule
var controller: PlayerController
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var enabled := true
var runtime_source_id: StringName
var _previous_saw := Vector2.ZERO
var _previous_actor := Vector2.ZERO
var _actor_epoch := -1
var _touching := false
var _exposure := 0
var _pulse := 0
var _next_pulse := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 900
	runtime_source_id = StringName("%s@%d" % [definition.source_id, module.get_instance_id()])
	position = definition.at_time(module.clock)
	_previous_saw = global_position
	queue_redraw()

func setup_damage(actor: PlayerController, damage_policy: FrameDamagePolicy, life: DemoLifetime) -> void:
	controller = actor
	policy = damage_policy
	lifetime = life
	_actor_epoch = -1

func _physics_process(_delta: float) -> void:
	position = definition.at_time(module.clock)
	rotation = TAU * (module.clock / definition.period + definition.initial_phase)
	if policy == null or lifetime == null or not lifetime.active or not is_instance_valid(controller) or not controller.active:
		_previous_saw = global_position
		return
	var actor_position := controller.motor.global_position
	if _actor_epoch != lifetime.actor_epoch:
		# Segment teleport is not a traversed path through the hazard.
		_previous_actor = actor_position
		_previous_saw = global_position
		_touching = false
		_actor_epoch = lifetime.actor_epoch
	var collision := controller.motor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D if collision != null else null
	var touching := enabled and rectangle != null and SawHazard.swept_contact(_previous_actor - _previous_saw, actor_position - global_position, rectangle.size / 2.0, definition.radius)
	_previous_actor = actor_position
	_previous_saw = global_position
	if not touching:
		_touching = false
		return
	if not _touching:
		_exposure += 1
		_pulse = 0
		_next_pulse = policy.clock
	_touching = true
	if policy.clock < _next_pulse:
		return
	_next_pulse = policy.clock + definition.contact_interval
	_pulse += 1
	var request := DamageRequest.new()
	request.token = lifetime.token()
	request.actor_epoch = lifetime.actor_epoch
	request.health_epoch = controller.actor_resources.health.epoch
	request.target_id = &"player"
	request.source_id = runtime_source_id
	request.event_id = StringName("%s:%d:%d:%d" % [runtime_source_id, lifetime.actor_epoch, _exposure, _pulse])
	request.kind = DamageRequest.Kind.ENVIRONMENT
	request.amount = definition.damage
	request.physics_tick = Engine.get_physics_frames()
	policy.submit(request)

func _draw() -> void:
	PlainsTerrainSkin.draw_saw(self, definition.radius)

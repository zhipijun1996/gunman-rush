class_name DemoContactEmitter
extends Node2D

# A local contact source with stable exposure IDs and game-clock cadence.
var policy: FrameDamagePolicy
var controller: PlayerController
var source_id: StringName = &"contact"
var kind := DamageRequest.Kind.MONSTER
var amount := 1.0
var half_size := Vector2(14, 16)
var interval := 0.7
var enabled := true
# Optional owner-authoritative world collision rect, used by real Boss bodies.
var contact_rect_provider: Callable
# Explicit connected-region legacy pit-plane semantic, not physical thorns.
var fall_plane := false
var _was_touching := false
var _exposure := 0
var _pulse := 0
var _next_pulse := 0.0
var _last_actor_epoch := -1
var _previous_relative := Vector2.ZERO
var _physical_contact_frame := -1
var _physical_contact_epoch := -1
var _physical_contact_session := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 900
	# Opt-in moving bodies report an actual KinematicCollision. Their safe
	# margin can stop just outside the geometric sweep; do not enlarge hitboxes.
	if get_parent().has_signal("physical_contact"):
		get_parent().connect("physical_contact",notify_physical_contact)

func notify_physical_contact(collider: Node) -> void:
	if not is_instance_valid(controller) or collider != controller.motor or policy == null or policy.lifetime == null: return
	_physical_contact_frame = Engine.get_physics_frames()
	_physical_contact_epoch = policy.lifetime.actor_epoch
	_physical_contact_session = controller.session_id

func _physics_process(_delta: float) -> void:
	if policy == null or policy.lifetime == null or not policy.lifetime.active or not is_instance_valid(controller) or not controller.active:
		return
	var life := policy.lifetime
	var source_center := global_position
	var source_half_size := half_size
	if contact_rect_provider.is_valid():
		var source_bounds: Rect2 = contact_rect_provider.call()
		if not source_bounds.position.is_finite() or not source_bounds.size.is_finite() or source_bounds.size.x <= 0 or source_bounds.size.y <= 0: return
		source_center = source_bounds.get_center()
		source_half_size = source_bounds.size * .5
	var relative := controller.motor.global_position - source_center
	if _last_actor_epoch != life.actor_epoch:
		_previous_relative = relative
		_was_touching = false
		_last_actor_epoch = life.actor_epoch
	var collision := controller.motor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var actor_half_size := (collision.shape as RectangleShape2D).size * .5 if collision != null and collision.shape is RectangleShape2D else Vector2(12,18)
	var size := source_half_size + actor_half_size
	var protected := kind == DamageRequest.Kind.MONSTER and controller.traversal != null and controller.traversal.protects_contact(get_parent())
	var physical_contact := (_physical_contact_frame == Engine.get_physics_frames()
		and _physical_contact_epoch == life.actor_epoch and _physical_contact_session == controller.session_id)
	var touching := enabled and not protected and (physical_contact or segment_intersects_bounds(_previous_relative, relative, Rect2(-size, size * 2.0)))
	if touching and fall_plane and DamageBoundary.has_landing_below(controller.motor): touching = false
	_previous_relative = relative
	if not touching:
		_was_touching = false
		return
	if not _was_touching:
		_exposure += 1
		_pulse = 0
		_next_pulse = policy.clock
	_was_touching = true
	if policy.clock < _next_pulse:
		return
	_next_pulse = policy.clock + maxf(interval, 0.01)
	_pulse += 1
	var request := DamageRequest.new()
	request.token = life.token()
	request.actor_epoch = life.actor_epoch
	request.health_epoch = controller.actor_resources.health.epoch
	request.target_id = &"player"
	request.source_id = source_id
	request.event_id = StringName("%s:%d:%d:%d" % [source_id, life.actor_epoch, _exposure, _pulse])
	request.kind = kind
	request.amount = amount
	request.physics_tick = Engine.get_physics_frames()
	request.hit_direction = relative.normalized()
	policy.submit(request)

static func segment_intersects_bounds(start: Vector2, finish: Vector2, bounds: Rect2) -> bool:
	if bounds.has_point(start) or bounds.has_point(finish):
		return true
	var corners: Array[Vector2] = [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
	for index: int in 4:
		if Geometry2D.segment_intersects_segment(start, finish, corners[index], corners[(index + 1) % 4]) != null:
			return true
	return false

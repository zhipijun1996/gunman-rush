class_name ShotLatch
extends Node2D
## Local, one-way shot switch. Actual projectile collision owns hit delivery.
signal opened
const BELL_ART := preload("res://assets/plains_v3/windchime_switch.png")
var link_id := "A"
var link_color := Color("e8bd65")
var _clock := 0.0
var controller: PlayerController
var lifetime: DemoLifetime
var health := HealthState.new()
var receiver: Damageable
var bell_body: StaticBody2D
var gate_body: StaticBody2D
var gate_shape: CollisionShape2D
var bell_position := Vector2.ZERO
var gate_rect := Rect2()
var is_open := false
var open_count := 0
var _pending: Dictionary = {}
var _seen: Dictionary = {}
var _eligible_shots: Dictionary = {}
var _cancelled := false
var _request_epoch := 0

func setup(player: PlayerController, scope: DemoLifetime, bell: Vector2, gate: Rect2) -> void:
	controller = player
	lifetime = scope
	bell_position = bell
	gate_rect = gate
	process_physics_priority = 1150
	var definition := HealthDefinition.new()
	definition.resource_id = &"practice_shot_latch"
	definition.max_health = 1.0
	definition.initial_current = 1.0
	health.configure(definition)
	bell_body = StaticBody2D.new()
	bell_body.position = bell
	bell_body.collision_layer = 8
	bell_body.collision_mask = 0
	var bell_shape := CollisionShape2D.new()
	var bell_rectangle := RectangleShape2D.new()
	bell_rectangle.size = Vector2(28, 34)
	bell_shape.shape = bell_rectangle
	bell_body.add_child(bell_shape)
	receiver = Damageable.new()
	receiver.name = "Damageable"
	receiver.faction = &"mechanism"
	receiver.actor_id = bell_body.get_instance_id()
	bell_body.add_child(receiver)
	add_child(bell_body)
	receiver.bind_health(health)
	receiver.damage_sink = _receive_projectile
	gate_body = StaticBody2D.new()
	gate_body.position = gate.get_center()
	gate_body.collision_layer = 1
	gate_shape = CollisionShape2D.new()
	var gate_rectangle := RectangleShape2D.new()
	gate_rectangle.size = gate.size
	gate_shape.shape = gate_rectangle
	gate_body.add_child(gate_shape)
	add_child(gate_body)
	controller.shoot_ability.shot_fired.connect(_register_shot)
	queue_redraw()

func _register_shot(_direction: Vector2, shot_id: int) -> void:
	if not _cancelled and not is_open and lifetime.active and controller.active:
		_eligible_shots["%s:%s" % [controller.session_id, shot_id]] = {"token": lifetime.token(), "expires": _clock + controller.motor.tuning.projectile_lifetime + 1.0 / 60.0}

func _receive_projectile(context: Dictionary) -> bool:
	var key := "%s:%s" % [context.get("session_id", -1), context.get("shot_id", -1)]
	var eligibility: Dictionary = _eligible_shots.get(key, {})
	var token: DemoToken = eligibility.get("token")
	var id := str(context.get("event_id", ""))
	if _cancelled or is_open or not _pending.is_empty() or not lifetime.accepts(token) or id.is_empty() or _seen.has(id):
		return false
	if not controller.active or controller.actor_resources.health.terminal or context.get("source_faction", &"") != &"player" or context.get("source_actor_id", -1) != controller.motor.get_instance_id() or context.get("session_id", -1) != controller.session_id:
		return false
	if context.get("target_actor_id", -1) != receiver.actor_id or context.get("target_epoch", -1) != health.epoch:
		return false
	_pending = {"id": id, "token": token, "session": controller.session_id, "health_epoch": health.epoch, "request_epoch": _request_epoch}
	_seen[id] = true
	return true

func _physics_process(delta: float) -> void:
	_clock += delta
	for key: String in _eligible_shots.keys():
		if _eligible_shots[key].expires < _clock:
			_eligible_shots.erase(key)
	if _pending.is_empty():
		return
	var request := _pending
	_pending = {}
	_commit_open.call_deferred(request)

func _commit_open(request: Dictionary) -> void:
	if request.is_empty() or request.get("request_epoch", -1) != _request_epoch or _cancelled or is_open or not is_inside_tree() or not lifetime.accepts(request.token) or not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal or controller.session_id != request.session or health.epoch != request.health_epoch:
		return
	var result := health.apply_damage(ActorResourceRequest.new(StringName(request.id), health.epoch, 1.0, health.get_instance_id()))
	if not result.accepted():
		return
	is_open = true
	_eligible_shots.clear()
	_seen.clear()
	open_count += 1
	gate_body.collision_layer = 0
	gate_shape.disabled = true
	bell_body.collision_layer = 0
	opened.emit()
	queue_redraw()

func cancel_pending() -> void:
	_request_epoch += 1
	_seen.clear()
	_pending = {}
	_eligible_shots.clear()

func cancel() -> void:
	_cancelled = true
	cancel_pending()

func _draw() -> void:
	# The closed gate has matching solid collision, never a misleading platform.
	var gold := link_color if not is_open else Color("89d5ac")
	draw_line(bell_position + Vector2(0, -62), bell_position + Vector2(0, -17), Color("8b6744"), 3)
	draw_rect(Rect2(bell_position - Vector2(34, 64), Vector2(68, 8)), Color("765b41"))
	draw_texture_rect_region(BELL_ART, Rect2(bell_position + Vector2(-14, -26), Vector2(28, 49.4)), Rect2(200, 8, 746, 1316))
	draw_rect(Rect2(bell_position - Vector2(14, 17), Vector2(28, 34)), gold, false, 2)
	var wire_y := 370.0
	draw_polyline(PackedVector2Array([bell_position + Vector2(0,-65), Vector2(bell_position.x,wire_y), Vector2(gate_rect.get_center().x,wire_y), Vector2(gate_rect.get_center().x,gate_rect.position.y)]), Color(gold,0.5), 2)
	if not is_open:
		draw_rect(gate_rect, Color("66543b"))
		for y: float in range(int(gate_rect.position.y + 8), int(gate_rect.end.y), 24):
			draw_line(Vector2(gate_rect.position.x, y), Vector2(gate_rect.end.x, y + 8), gold, 3)
	else:
		draw_line(gate_rect.position, gate_rect.position + Vector2(gate_rect.size.x, 0), gold, 4)
	draw_string(ThemeDB.fallback_font, bell_position + Vector2(-37, -78), ("OPEN " if is_open else "SHOOT ") + link_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)

	draw_string(ThemeDB.fallback_font, Vector2(gate_rect.position.x - 4, gate_rect.position.y - 12), link_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, gold)

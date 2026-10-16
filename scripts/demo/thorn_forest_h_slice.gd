extends Node2D
## Development-only canopy technical slice. Never registered as a formal region.
const SNAPSHOT := preload("res://tools/level_capability_snapshot.gd")
const ROOT_RECT := Rect2(-200, 600, 1050, 90)
const BRANCH_RECT := Rect2(20, 405, 190, 24)
const ANCHOR_POINT := Vector2(380, 470)
const SPAWN := Vector2(100, 582)

class TraceObserver extends Node:
	var sample: Node2D
	func _physics_process(delta: float) -> void:
		sample.observe_tick(delta)

var player: PlayerMotor
var controller: PlayerController
var anchor: GrappleAnchor
var include_anchor := true
var grant_hook := true
var frame := 0
var finished := false
var branch_landed := false
var returned := false
var phase := "outbound"
var stable_branch := 0
var stable_return := 0
var before_steps := 0
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var requests: Array[Dictionary] = []
var initial_snapshot: Dictionary
var body_size := Vector2.ZERO

func _ready() -> void:
	process_physics_priority = -100
	_surface("RootLanding", ROOT_RECT)
	_surface("CanopyBranch", BRANCH_RECT)
	if include_anchor:
		anchor = GrappleAnchor.new()
		anchor.name = "BellVineAnchor"
		anchor.position = ANCHOR_POINT
		add_child(anchor)
	player = preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	player.position = SPAWN # Initial development spawn only; never reset during trace.
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	body_size = (player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size
	controller.enable_shot_energy()
	if grant_hook:
		controller.traversal.grant(&"grapple") # Existing Studio API, development only.
	controller.traversal.action_changed.connect(func(value: StringName) -> void:
		events.append({"tick": frame, "kind": String(value), "position": SNAPSHOT.pair(player.position)}))
	controller.landed.connect(func() -> void:
		events.append({"tick": frame, "kind": "landed", "position": SNAPSHOT.pair(player.position), "supports": supports()}))
	controller.shoot_ability.shot_fired.connect(func(_aim: Vector2, _serial: int) -> void:
		events.append({"tick": frame, "kind": "shot_fired"}))
	initial_snapshot = capture_capability_snapshot()
	var observer := TraceObserver.new()
	observer.sample = self
	observer.process_physics_priority = 100
	add_child(observer)
	var camera := Camera2D.new()
	camera.position = Vector2(280, 410)
	add_child(camera)
	camera.make_current()
	queue_redraw()

func capture_capability_snapshot() -> Dictionary:
	# Read actual states and their Definition; never repeat gameplay defaults.
	var value := SNAPSHOT.capture(controller, null, "development_forest_H_only_not_formal_grant")
	var definition := controller.actor_resources.health_definition
	value["health"] = {"current": controller.actor_resources.health.current,
		"capacity": controller.actor_resources.health.capacity,
		"definition_capacity": definition.max_health, "definition_initial": definition.initial_current,
		"definition_path": definition.resource_path, "definition_sha256": FileAccess.get_sha256(definition.resource_path)}
	return value

func _surface(label: String, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = label
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)

func _physics_process(_delta: float) -> void:
	if finished:
		return
	frame += 1
	before_steps = player.motion_steps
	var axis := 0.0
	if frame == 12:
		var direction := (ANCHOR_POINT - (player.position + Vector2(0, -6))).normalized()
		var queued := controller.router.request_action(&"grapple", direction)
		requests.append({"tick": frame, "kind": "grapple", "queued": queued, "direction": SNAPSHOT.pair(direction)})
	if phase == "outbound":
		if controller.traversal.state == &"hook_kick" or (player.position.y < 405 and not player.is_on_floor()):
			axis = -1.0 if player.position.x > 145 else 0.0
	else:
		if "CanopyBranch" in supports() or (player.position.y < 440 and player.position.x < 240):
			axis = 1.0
		elif player.is_on_floor():
			axis = -1.0 if player.position.x > 104 else 0.0
	controller.router.set_move_axis(axis)

func supports() -> Array[String]:
	var names: Array[String] = []
	for i: int in player.get_slide_collision_count():
		var contact := player.get_slide_collision(i)
		if contact.get_normal().dot(Vector2.UP) > 0.7:
			var body := contact.get_collider() as Node
			if body != null:
				names.append(String(body.name))
	return names

func observe_tick(_delta: float) -> void:
	if finished:
		return
	var actual_supports := supports()
	var body_rect := Rect2(player.position - body_size / 2, body_size)
	var full_branch := (player.is_on_floor() and "CanopyBranch" in actual_supports
		and body_rect.position.x >= BRANCH_RECT.position.x and body_rect.end.x <= BRANCH_RECT.end.x)
	stable_branch = stable_branch + 1 if full_branch else 0
	if phase == "outbound" and stable_branch >= 12:
		branch_landed = true
		phase = "return"
	var safe_return := branch_landed and player.is_on_floor() and "RootLanding" in actual_supports and player.position.x >= 70 and player.position.x <= 115
	stable_return = stable_return + 1 if safe_return else 0
	returned = stable_return >= 12
	frames.append({"tick": frame, "position": SNAPSHOT.pair(player.position), "velocity": SNAPSHOT.pair(player.velocity),
		"grounded": player.is_on_floor(), "supports": actual_supports, "full_branch_support": full_branch,
		"traversal": String(controller.traversal.state), "hook_direction": SNAPSHOT.pair(controller.traversal.hook_direction),
		"motion_steps": player.motion_steps,
		"motor_steps_this_tick": player.motion_steps - before_steps, "axis": controller.router.axis,
		"energy": controller.actor_resources.stamina.current, "health": controller.actor_resources.health.current,
		"air_shots": controller.action_resources.shot_charges, "hook_used": controller.traversal.hook_used})
	if returned or frame >= 480:
		finished = true
		controller.router.set_move_axis(0)

func _draw() -> void:
	# Honest technical silhouettes, not a forest art/animation acceptance sample.
	draw_rect(Rect2(-400, 0, 1500, 900), Color("142b26"))
	draw_rect(Rect2(385, 230, 55, 370), Color("31483a"))
	draw_circle(Vector2(400, 220), 95, Color("28443a"))
	draw_line(Vector2(50, 420), Vector2(405, 365), Color("524b37"), 28)
	draw_rect(ROOT_RECT, Color("526441"))
	draw_rect(BRANCH_RECT, Color("8c9864"))
	draw_line(BRANCH_RECT.position, Vector2(BRANCH_RECT.end.x, BRANCH_RECT.position.y), Color("e2e7ad"), 3)
	draw_string(ThemeDB.fallback_font, Vector2(10, 230), "FOREST H TECHNICAL PROTOTYPE - NOT FORMAL REGION", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e4e5c6"))

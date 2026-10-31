extends "res://game/world/levels/providers/thorn_forest_h_slice.gd"
## Current default H-only technical route. No formal region or ability grant.
var recoil_requested := false

func layout() -> Dictionary:
	return {"root": Rect2(-120, 600, 650, 70), "branch": Rect2(125, 510, 155, 24),
		"anchor": Vector2(280, 460), "spawn": Vector2(100, 582)}

func _ready() -> void:
	super._ready()
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, _serial: int):
		events.append({"tick": frame, "kind": "accepted_recoil_shot", "direction": SNAPSHOT.pair(direction),
			"energy": controller.actor_resources.stamina.current}))

func capture_capability_snapshot() -> Dictionary:
	var value := super.capture_capability_snapshot()
	var definition: TraversalDefinition = controller.traversal.definition
	value["traversal_definition"] = {"resource_path": definition.resource_path,
		"sha256": FileAccess.get_sha256(definition.resource_path), "scope": "current_default_H_only_technical_route",
		"hook_range": definition.hook_range, "hook_kick": SNAPSHOT.pair(definition.hook_kick),
		"hook_launch_seconds": definition.hook_launch_seconds, "contact_settlement_phase": "post_motor"}
	return value

func _physics_process(_delta: float) -> void:
	if finished: return
	frame += 1
	before_steps = player.motion_steps
	if frame == 2:
		var queued := controller.router.request_action(&"jump")
		requests.append({"tick": frame, "kind": "jump", "queued": queued})
	if frame == 18:
		var direction: Vector2 = (layout().anchor - (player.position + Vector2(0, -6))).normalized()
		var queued := controller.router.request_action(&"grapple", direction)
		requests.append({"tick": frame, "kind": "grapple", "queued": queued, "direction": SNAPSHOT.pair(direction)})
	var axis := 0.0
	if not branch_landed:
		# H contact and its configured burst do all outbound displacement.
		axis = 0.0
	else:
		if not recoil_requested:
			recoil_requested = true
			var queued := controller.router.request_action(&"shoot_release", Vector2.DOWN)
			requests.append({"tick": frame, "kind": "shoot_release", "queued": queued, "direction": [0, 1]})
		axis = clampf((100.0 - player.position.x) / 5.5, -1, 1)
	controller.router.set_move_axis(axis)

func _draw() -> void:
	draw_rect(Rect2(-200, 250, 850, 470), Color("142b26"))
	draw_rect(layout().root, Color("526441"))
	draw_rect(layout().branch, Color("8c9864"))
	draw_string(ThemeDB.fallback_font, Vector2(-60, 370), "CURRENT H + RECOIL TECHNICAL ROUTE / NOT FOREST ART", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e4e5c6"))

extends SceneTree
## v3 review: two 13-second explicit fixtures with real accepted projectile hits.
## Variant/expect_remains affect reporting only, never simulation or feedback.
const CASE_FRAMES := 780
const TOTAL_FRAMES := CASE_FRAMES * 2
const DEFINITIONS := ["res://resources/enemies/plains_charger.tres", "res://resources/enemies/plains_diver.tres"]
const INSTALLER := preload("res://scripts/underworld_plains/underworld_actor_installer.gd")
var frame := 0
var trace_path := ""
var variant := "after"
var seed_label := "enemy-feedback-01-remains"
var expect_remains := false
var world: Node2D
var fixture: Node2D
var controller: PlayerController
var enemy: EnemyMotor
var actor: EnemyActor
var policy: FrameDamagePolicy
var audio: GameAudio
var heading: Label
var detail: Label
var rows: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var failures: Array[String] = []
var busy := false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="): trace_path = argument.trim_prefix("--trace=")
		if argument.begins_with("--variant="): variant = argument.trim_prefix("--variant=")
		if argument.begins_with("--seed="): seed_label = argument.trim_prefix("--seed=")
		if argument == "--expect-remains": expect_remains = true
	start.call_deferred()

func label_at(text_value: String, point: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	return label

func start() -> void:
	root.size = Vector2i(1280, 720)
	world = Node2D.new()
	root.add_child(world)
	audio = GameAudio.new()
	world.add_child(audio)
	var camera := Camera2D.new()
	camera.position = Vector2(575, 440)
	camera.zoom = Vector2(2.5, 2.5)
	world.add_child(camera)
	var overlay := CanvasLayer.new()
	world.add_child(overlay)
	heading = label_at("", Vector2(54, 46), 30)
	overlay.add_child(heading)
	detail = label_at("", Vector2(54, 96), 20)
	overlay.add_child(detail)
	overlay.add_child(label_at("ENEMY-FEEDBACK-01 v3 | " + variant.to_upper() + " | real projectile HP -> death -> long hold", Vector2(54, 636), 20))
	overlay.add_child(label_at("Explicit fixture. Original AI / definitions / physics / HP / weapon. Normal-speed Godot movie; not a campaign route.", Vector2(54, 670), 16))
	await make_case(0)
	process_frame.connect(drive)

func solid(center: Vector2, size: Vector2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var pixels := Polygon2D.new()
	pixels.polygon = PackedVector2Array([-size * .5, Vector2(size.x * .5, -size.y * .5), size * .5, Vector2(-size.x * .5, size.y * .5)])
	pixels.color = color
	body.add_child(pixels)
	fixture.add_child(body)

func make_case(index: int) -> void:
	fixture = Node2D.new()
	world.add_child(fixture)
	# The floor spans the authored patrol/dive envelope and the corpse landing.
	# Geometry exists before spawn; no actor/corpse position is changed afterward.
	solid(Vector2(600, 520), Vector2(800, 40), Color("53634e"))
	solid(Vector2(345, 430), Vector2(20, 140), Color("364942"))
	var player: PlayerMotor = preload("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(480, 482)
	fixture.add_child(player)
	controller = player.get_node("Controller") as PlayerController
	player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	controller.router.activate_device(&"gamepad")
	controller.air_focus_ability.enabled = false
	enemy = preload("res://scenes/enemies/patrol_drone.tscn").instantiate()
	enemy.position = Vector2(640, 430 if index == 1 else 484)
	actor = enemy.get_node("Actor") as EnemyActor
	actor.definition = load(DEFINITIONS[index]) as EnemyDefinition
	fixture.add_child(enemy)
	var installation := INSTALLER.install(fixture)
	if installation.enemies != 1 or enemy.get_node_or_null("Presentation") == null:
		push_error("Formal installer did not produce a presentation in case %s" % index)
		quit(1)
		return
	policy = FrameDamagePolicy.new()
	policy.lifetime = DemoLifetime.new()
	fixture.add_child(policy)
	if not policy.bind_damageable(&"remains_capture_enemy", actor.damageable, actor.health): failures.append("damage binding failed")
	actor.bind_encounter(controller, policy, policy.lifetime, &"remains_capture_enemy", [])
	var id := index
	cases.append({"case": index, "definition": String(actor.definition.stable_id), "chain": "UnderworldEnemy via installer", "events": [], "inputs": [], "shots": [], "deaths": 0})
	actor.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
			cases[id].events.append({"frame": frame, "event_id": String(result.event_id), "amount": result.amount_applied, "HP": result.snapshot.current, "epoch": result.snapshot.epoch, "terminal": result.snapshot.terminal}))
	actor.defeated.connect(func(_defeated: EnemyActor) -> void: cases[id].deaths += 1)
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, shot_id: int) -> void:
		cases[id].shots.append({"frame": frame, "shot_id": shot_id, "direction": [direction.x, direction.y]}))
	heading.text = "%s / 2   UNDERWORLD INSTALLER   -   %s" % [index + 1, "AERIAL DIVER" if index == 1 else "GROUND CHARGER"]
	await process_frame

func optional_property(node: Object, names: Array[StringName]) -> Variant:
	if node == null: return null
	for property: Dictionary in node.get_property_list():
		if StringName(property.name) in names: return node.get(property.name)
	return null

func remains_receipts() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var candidates: Array[Node] = []
	# Installer removal queues the old sibling for deletion; Godot can rename
	# its replacement automatically. Observe the actual owner's public reference,
	# not a display-name convention. Baseline has no such property.
	var presentation := enemy.get_node("Presentation")
	var owned: Variant = optional_property(presentation, [&"feedback_remains"])
	if owned is Node2D:
		candidates.append(owned as Node2D)
	else:
		for node: Node in fixture.find_children("*", "", true, false):
			var lower_name := String(node.name).to_lower()
			if "remains" in lower_name or "corpse" in lower_name: candidates.append(node)
	for node: Node in candidates:
		if not node is Node2D: continue
		var body := node as Node2D
		var effective_alpha := body.self_modulate.a
		var ancestor: Node = body
		while ancestor != null:
			if ancestor is CanvasItem: effective_alpha *= (ancestor as CanvasItem).modulate.a
			ancestor = ancestor.get_parent()
		var settled: Variant = optional_property(body, [&"settled", &"_settled"])
		output.append({"path": String(fixture.get_path_to(body)), "visible": body.visible, "visible_in_tree": body.is_visible_in_tree(), "effective_alpha": effective_alpha,
			"position": [body.global_position.x, body.global_position.y], "rotation": body.global_rotation, "scale": [body.global_scale.x, body.global_scale.y],
			"settled": settled if settled is bool else null, "settled_source": "component property" if settled is bool else "not exposed; see stable-transform observation"})
	return output

func drive() -> void:
	if busy: return
	frame += 1
	var index := mini(1, (frame - 1) / CASE_FRAMES)
	var local_frame := (frame - 1) % CASE_FRAMES + 1
	if local_frame == 70: paused = true
	if local_frame == 85: paused = false
	var direction := (enemy.global_position - controller.motor.global_position).normalized()
	controller.router.set_aim(&"gamepad", direction, false)
	if local_frame in [50, 110, 170, 230] and not actor.health.terminal:
		var submitted := controller.router.request_action(&"shoot_release", direction)
		cases[index].inputs.append({"frame": frame, "local_frame": local_frame, "type": "shoot_release", "direction": [direction.x, direction.y], "router_submitted": submitted})
	var remains := remains_receipts()
	var death_frame := int(cases[index].events.back().frame) if actor.health.terminal and not cases[index].events.is_empty() else -1
	detail.text = "HP %s / %s   |   %s" % [actor.health.current, actor.health.capacity, "PAUSED: accepted pose held" if paused else "death + %.1fs: observing landing and long hold" % (float(frame-death_frame)/60) if death_frame >= 0 else "original movement; real nonlethal / lethal shots"]
	var presentation := enemy.get_node("Presentation") as Node2D
	rows.append({"frame": frame, "case": index, "local_frame": local_frame, "paused": paused,
		"player_position": [controller.motor.position.x, controller.motor.position.y], "player_velocity": [controller.motor.velocity.x, controller.motor.velocity.y],
		"enemy_position": [enemy.position.x, enemy.position.y], "enemy_velocity": [enemy.velocity.x, enemy.velocity.y], "HP": actor.health.current,
		"state": String(actor.attack_behavior.state) if actor.attack_behavior != null else "patrol", "remains": remains,
		"presentation_visible": presentation.visible, "presentation_alpha": presentation.modulate.a})
	if local_frame == CASE_FRAMES:
		busy = true
		end_case.call_deferred(index)

func end_case(index: int) -> void:
	paused = false
	var result: Dictionary = cases[index]
	if not actor.health.terminal or result.events.size() != 3 or result.deaths != 1:
		failures.append("case %s requires 3 real projectile HP commits and one death, got %s / %s / terminal=%s" % [index, result.events.size(), result.deaths, actor.health.terminal])
	var expected_health := [2.0, 1.0, 0.0]
	for event_index: int in mini(3, result.events.size()):
		if result.events[event_index].HP != expected_health[event_index]: failures.append("case %s unexpected HP sequence" % index)
	var case_rows := rows.filter(func(row: Dictionary) -> bool: return row.case == index)
	var tail := case_rows.slice(maxi(0, case_rows.size()-210))
	var stable_visible := tail.size() == 210
	var anchor: Dictionary = {}
	for row: Dictionary in tail:
		var bodies: Array = row.remains
		if bodies.is_empty(): stable_visible = false; continue
		var body: Dictionary = bodies[0]
		if anchor.is_empty(): anchor = body
		if not body.visible_in_tree or body.effective_alpha <= .05 or body.position != anchor.position or body.rotation != anchor.rotation or body.scale != anchor.scale:
			stable_visible = false
		if body.settled is bool and body.settled != true: stable_visible = false
	cases[index].stable_visible_tail_frames = 210 if stable_visible else 0
	cases[index].tail_observation = "3.5s stable visible world transform, component settled when exposed" if stable_visible else "No stable visible remains tail: baseline may intentionally have none"
	if expect_remains and not stable_visible: failures.append("case %s lacks >3s visible, settled, stationary remains" % index)
	cases[index].terminal = actor.health.terminal
	cases[index].final_health = actor.health.current
	controller.shoot_ability.clear_projectiles()
	fixture.queue_free()
	await process_frame
	await process_frame
	if index == 1:
		await finish()
	else:
		await make_case(index + 1)
		busy = false

func finish() -> void:
	process_frame.disconnect(drive)
	var audio_counts := audio.played.duplicate()
	var released: bool = await audio.shutdown()
	if not released: failures.append("audio backend did not release")
	var file := FileAccess.open(trace_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write enemy remains trace")
		quit(1)
		return
	file.store_string(JSON.stringify({"task": "ENEMY-FEEDBACK-01", "version": "v3-remains-review", "variant": variant, "seed": seed_label,
		"scope": "two explicit Underworld spawn fixtures; actual Router/Shoot/projectile/policy/HP; long settled-remains observation; no campaign/device claim",
		"expect_remains": expect_remains, "frames": rows, "cases": cases, "audio_counts": audio_counts, "failures": failures, "audio_released": released}))
	file.close()
	world.free()
	await process_frame
	await process_frame
	if not failures.is_empty():
		for failure: String in failures: printerr("FAIL: ", failure)
		quit(1)
		return
	print("ENEMY REMAINS CAPTURE: 1560 frames; two cases; 6 projectile HP commits; 2 deaths")
	quit()

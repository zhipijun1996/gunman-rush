extends SceneTree
## Four five-second development fixtures. No injected HP, damage or feedback.
## Same driver runs against baseline and candidate sources; variant is a label.
const CASE_FRAMES := 300
const TOTAL_FRAMES := CASE_FRAMES * 4
const DEFINITIONS := ["res://resources/enemies/plains_charger.tres", "res://resources/enemies/plains_diver.tres"]
const INSTALLER := preload("res://scripts/underworld_plains/underworld_actor_installer.gd")
var frame := 0
var trace_path := ""
var variant := "after"
var seed_label := "enemy-feedback-01"
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
	camera.position = Vector2(600, 420)
	camera.zoom = Vector2(2, 2)
	world.add_child(camera)
	var overlay := CanvasLayer.new()
	world.add_child(overlay)
	heading = label_at("", Vector2(54, 46), 30)
	overlay.add_child(heading)
	detail = label_at("", Vector2(54, 96), 20)
	overlay.add_child(detail)
	overlay.add_child(label_at("ENEMY-FEEDBACK-01 | " + variant.to_upper() + " | real Router -> projectile -> accepted HP", Vector2(54, 636), 20))
	overlay.add_child(label_at("Explicit spawn fixture; original AI, definitions, collision, damage and audio. Not a campaign route.", Vector2(54, 670), 17))
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
	enemy.position = Vector2(640, 430 if index % 2 == 1 else 484)
	actor = enemy.get_node("Actor") as EnemyActor
	actor.definition = load(DEFINITIONS[index % 2]) as EnemyDefinition
	fixture.add_child(enemy)
	if index >= 2:
		var installation := INSTALLER.install(fixture)
		if installation.enemies != 1: failures.append("formal installer failed in case %s" % index)
	policy = FrameDamagePolicy.new()
	policy.lifetime = DemoLifetime.new()
	fixture.add_child(policy)
	if not policy.bind_damageable(&"capture_enemy", actor.damageable, actor.health): failures.append("damage binding failed")
	actor.bind_encounter(controller, policy, policy.lifetime, &"capture_enemy", [])
	var id := index
	cases.append({"case": index, "definition": String(actor.definition.stable_id), "chain": "UnderworldEnemy via installer" if index >= 2 else "EnemyPresentation", "events": [], "shots": [], "deaths": 0})
	actor.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
			cases[id].events.append({"frame": frame, "event_id": String(result.event_id), "amount": result.amount_applied, "HP": result.snapshot.current, "epoch": result.snapshot.epoch, "terminal": result.snapshot.terminal}))
	actor.defeated.connect(func(_defeated: EnemyActor) -> void: cases[id].deaths += 1)
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, shot_id: int) -> void:
		cases[id].shots.append({"frame": frame, "shot_id": shot_id, "direction": [direction.x, direction.y]}))
	heading.text = "%s / 4   %s   -   %s" % [index + 1, "UNDERWORLD INSTALLER" if index >= 2 else "ENEMY PRESENTATION", "AERIAL DIVER" if index % 2 == 1 else "GROUND CHARGER"]
	await process_frame

func drive() -> void:
	if busy: return
	frame += 1
	var index := mini(3, (frame - 1) / CASE_FRAMES)
	var local_frame := (frame - 1) % CASE_FRAMES + 1
	if local_frame == 70: paused = true
	if local_frame == 85: paused = false
	var direction := (enemy.global_position - controller.motor.global_position).normalized()
	controller.router.set_aim(&"gamepad", direction, false)
	if local_frame in [50, 110, 170, 230] and not actor.health.terminal:
		controller.router.request_action(&"shoot_release", direction)
	detail.text = "HP %s / %s   |   %s   |   accepted hits %s   |   %s" % [actor.health.current, actor.health.capacity, actor.attack_behavior.state if actor.attack_behavior != null else &"patrol", cases[index].events.size(), "PAUSED: same accepted pose" if paused else "original movement + recoil"]
	var presentation := enemy.get_node("Presentation") as Node2D
	var sample: Variant = null
	for property: Dictionary in presentation.get_property_list():
		if property.name == "feedback_sample": sample = presentation.get("feedback_sample")
	rows.append({"frame": frame, "case": index, "local_frame": local_frame, "paused": paused,
		"player_position": [controller.motor.position.x, controller.motor.position.y], "player_velocity": [controller.motor.velocity.x, controller.motor.velocity.y],
		"enemy_position": [enemy.position.x, enemy.position.y], "enemy_velocity": [enemy.velocity.x, enemy.velocity.y], "HP": actor.health.current,
		"state": String(actor.attack_behavior.state) if actor.attack_behavior != null else "patrol",
		"feedback": {"hurt": sample.hurt_remaining, "death_active": sample.death_active, "death_elapsed": sample.death_elapsed, "hits": sample.accepted_hit_count, "deaths": sample.accepted_death_count} if sample != null else {},
		"presentation_visible": presentation.visible, "presentation_alpha": presentation.modulate.a})
	if local_frame == CASE_FRAMES:
		busy = true
		end_case.call_deferred(index)

func end_case(index: int) -> void:
	paused = false
	var result: Dictionary = cases[index]
	if not actor.health.terminal or result.events.size() != 3 or result.deaths != 1:
		failures.append("case %s requires 3 actual projectile HP commits and one death, got %s / %s / terminal=%s" % [index, result.events.size(), result.deaths, actor.health.terminal])
	var expected_health := [2.0, 1.0, 0.0]
	for event_index: int in mini(3, result.events.size()):
		if result.events[event_index].HP != expected_health[event_index]: failures.append("case %s unexpected HP sequence" % index)
	cases[index].terminal = actor.health.terminal
	cases[index].final_health = actor.health.current
	controller.shoot_ability.clear_projectiles()
	fixture.queue_free()
	await process_frame
	await process_frame
	if index == 3:
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
		push_error("Cannot write enemy feedback trace")
		quit(1)
		return
	file.store_string(JSON.stringify({"task": "ENEMY-FEEDBACK-01", "variant": variant, "seed": seed_label,
		"scope": "four explicit spawn fixtures; original actors, actual Router/Shoot/projectile/policy/HP; no campaign or device claim",
		"frames": rows, "cases": cases, "audio_counts": audio_counts, "failures": failures, "audio_released": released}))
	file.close()
	world.free()
	await process_frame
	await process_frame
	if not failures.is_empty():
		for failure: String in failures: printerr("FAIL: ", failure)
		quit(1)
		return
	print("ENEMY FEEDBACK CAPTURE: 1200 frames; four cases; 12 projectile HP commits; 4 deaths")
	quit()

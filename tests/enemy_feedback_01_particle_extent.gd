extends "res://tests/enemy_feedback_01_tests.gd"
## Identical real-GPU observation driver for ENEMY-FEEDBACK-01 v3 and v4.
## Each species/age starts an equivalent fresh supported arena, shoots through
## the real Router, then advances ordinary ticks. Pause only freezes observation;
## the pair changes particles.visible, never feedback, HP, AI or burst age.
const EXTENT_FRAMES: Array[int] = [2, 6]
var extent_rows: Array[Dictionary] = []
var extent_output := "res://build/enemy_feedback_01/particle-extent"
var extent_label := "unlabeled"

func read_extent_arguments() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index: int in arguments.size():
		var argument := arguments[index]
		if argument.begins_with("--extent-output="):
			extent_output = argument.trim_prefix("--extent-output=")
		elif argument == "--extent-output" and index + 1 < arguments.size():
			extent_output = arguments[index + 1]
		elif argument.begins_with("--extent-label="):
			extent_label = argument.trim_prefix("--extent-label=")
		elif argument == "--extent-label" and index + 1 < arguments.size():
			extent_label = arguments[index + 1]

func extent_pair(path: String, after_frames: int) -> void:
	await setup(path, true)
	check(await shoot_until_health_changes("extent_real_router_projectile"), "extent fixture receives a genuine accepted projectile")
	var target := art as UnderworldEnemy
	var particles := target.feedback_particles
	check(actor.health.current == actor.health.capacity - 1 and target.feedback_sample.accepted_hit_count == 1 and particles.emitted_bursts == 1, "extent follows exactly one accepted nonlethal hit and one burst")
	var accepted_tick := Engine.get_physics_frames()
	await ticks(after_frames, "extent_ordinary_ticks_after_accepted_hit")
	var observed_tick := Engine.get_physics_frames()
	paused = true
	check(not particles._bursts.is_empty(), "real accepted burst is live at requested observation frame")
	if particles._bursts.is_empty():
		paused = false
		await cleanup()
		return
	var frozen := JSON.stringify(particles._bursts)
	var age := float(particles._bursts.back().age)
	var contact: Vector2 = particles._bursts.back().point
	var canvas := particles.get_canvas_transform()
	var center := canvas * contact
	var hp := actor.health.current
	var count := particles.emitted_bursts
	var serial := target.feedback_sample.impact_serial
	var prefix := String(actor.definition.stable_id) + "-frame-%02d" % after_frames
	particles.visible = false
	await RenderingServer.frame_post_draw
	var without := root.get_texture().get_image()
	without.save_png(extent_output.path_join(prefix + "-off.png"))
	particles.visible = true
	await RenderingServer.frame_post_draw
	var with_particles := root.get_texture().get_image()
	with_particles.save_png(extent_output.path_join(prefix + "-on.png"))
	var region := Rect2i(Vector2i((center - Vector2(96, 96)).floor()), Vector2i(192, 192)).intersection(Rect2i(Vector2i.ZERO, without.get_size()))
	var minimum := region.end
	var maximum := region.position - Vector2i.ONE
	var changed := 0
	var maximum_radius := 0.0
	var touches_region_border := false
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if without.get_pixel(x, y) == with_particles.get_pixel(x, y): continue
			changed += 1
			minimum = Vector2i(mini(minimum.x, x), mini(minimum.y, y))
			maximum = Vector2i(maxi(maximum.x, x), maxi(maximum.y, y))
			maximum_radius = maxf(maximum_radius, (canvas.affine_inverse() * Vector2(x+.5, y+.5)).distance_to(contact))
			if x == region.position.x or y == region.position.y or x == region.end.x - 1 or y == region.end.y - 1:
				touches_region_border = true
	var difference_bounds := Rect2i(minimum, maximum - minimum + Vector2i.ONE) if changed > 0 else Rect2i()
	check(changed > 0, "actual visibility-only GPU difference contains accepted particle pixels")
	check(not touches_region_border, "measured particle envelope is not clipped by observation region")
	check(JSON.stringify(particles._bursts) == frozen and particles.emitted_bursts == count and target.feedback_sample.impact_serial == serial and actor.health.current == hp, "both rendered frames retain identical actual burst age, accepted receipt and HP")
	extent_rows.append({"species": String(actor.definition.stable_id), "definition": path, "requested_frames_after_accepted": after_frames, "accepted_physics_tick": accepted_tick, "observation_physics_tick": observed_tick, "paused_render_end_physics_tick": Engine.get_physics_frames(), "actual_burst_age_seconds_both_frames": age, "changed_pixels": changed, "difference_bbox_screen": difference_bounds, "maximum_radius_world": maximum_radius, "contact_world": contact, "canvas_transform": canvas, "region": region, "clipped": touches_region_border, "HP": hp, "impact_serial": serial, "emitted_bursts": count, "off_png": prefix + "-off.png", "on_png": prefix + "-on.png"})
	paused = false
	await cleanup()

func run() -> void:
	read_extent_arguments()
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color("26362f"))
	DirAccess.make_dir_recursive_absolute(extent_output)
	for path: String in SOURCES:
		for after_frames: int in EXTENT_FRAMES:
			await extent_pair(path, after_frames)
	var hashes: Dictionary = {}
	for path: String in ["res://tests/enemy_feedback_01_particle_extent.gd", "res://tests/enemy_feedback_01_tests.gd", "res://scripts/enemies/enemy_feedback_01_particles.gd", "res://scripts/underworld_plains/underworld_enemy.gd"]:
		hashes[path] = FileAccess.get_sha256(path)
	var output := {"task": "ENEMY-FEEDBACK-01", "label": extent_label, "checks": checks, "failures": failures, "viewport": [1280, 720], "fixed_fps_expected": 60, "fixture": "same base supported arena and original species Definition; fresh equivalent fixture for each observation age; no gameplay RNG draw or seed override", "driver_source_sha256": hashes["res://tests/enemy_feedback_01_particle_extent.gd"], "source_sha256": hashes, "measurements": extent_rows, "scope": "real Router projectile then 2/6 ordinary ticks; same-burst-age visibility-only GPU difference; pair with identical driver/fixture/actual ages across v3/v4 before claiming envelope gain; not quality or device approval"}
	var file := FileAccess.open(extent_output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_PARTICLE_EXTENT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

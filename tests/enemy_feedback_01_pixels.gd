extends "res://tests/enemy_feedback_01_tests.gd"
## Actual GPU body pixels following a real accepted Router projectile.
## Source-mask samples move with the actual body; no direct flash/VFX calls.
var pixels: Array[Dictionary] = []
var ablations: Array[Dictionary] = []
var living_facts: Dictionary = {}
const PIXEL_OUTPUT := "res://build/enemy_feedback_01/v4-pixels/"

func sample_sprite_rgba(image: Image, texture: Texture2D, bounds: Rect2, transform: Transform2D) -> Dictionary:
	var source_image := texture.get_image()
	var sum := Vector3.ZERO
	var saturation := 0.0
	var count := 0
	for y: int in source_image.get_height():
		for x: int in source_image.get_width():
			if source_image.get_pixel(x, y).a < .98: continue
			var uv := Vector2((x+.5)/source_image.get_width(), (y+.5)/source_image.get_height())
			var point := (transform * (bounds.position + bounds.size*uv)).floor()
			if not Rect2(Vector2.ZERO, image.get_size()).has_point(point): continue
			var color := image.get_pixel(int(point.x), int(point.y))
			sum += Vector3(color.r, color.g, color.b)
			saturation += color.s
			count += 1
	var mean := sum / maxi(1, count)
	return {"samples": count, "mean_rgb": [mean.x, mean.y, mean.z], "mean_luma": mean.dot(Vector3(.2126, .7152, .0722)), "mean_saturation": saturation/maxi(1, count), "screen_rotation_radians": transform.get_rotation(), "bounds": transform*bounds}

func actual_palette_ablation(name: String) -> void:
	var body: EnemyFeedback01Body = (art as UnderworldEnemy).feedback_body
	var material_value := float(body.flash_material.get_shader_parameter("readable_material"))
	var prior_pause := paused
	var prior_transparency := root.transparent_bg
	var health_before := actor.health.current
	paused = true
	# A transparent actual viewport exposes rendered alpha, which an opaque
	# background would hide. Only a task-local material uniform is ablated.
	root.transparent_bg = true
	body.flash_material.set_shader_parameter("readable_material", 0.0)
	await RenderingServer.frame_post_draw
	var original := root.get_texture().get_image()
	original.save_png(PIXEL_OUTPUT + name + "-palette-original-material.png")
	var original_stats := sample_sprite_rgba(original, body.source, body.destination, body.get_global_transform_with_canvas())
	body.flash_material.set_shader_parameter("readable_material", material_value)
	await RenderingServer.frame_post_draw
	var palette := root.get_texture().get_image()
	palette.save_png(PIXEL_OUTPUT + name + "-palette-readable-material.png")
	var palette_stats := sample_sprite_rgba(palette, body.source, body.destination, body.get_global_transform_with_canvas())
	var region := Rect2i(body.get_global_transform_with_canvas()*body.destination).grow(2).intersection(Rect2i(Vector2i.ZERO, original.get_size()))
	var alpha_changed := 0
	var rgb_changed := 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var a := original.get_pixel(x, y)
			var b := palette.get_pixel(x, y)
			if a.a != b.a: alpha_changed += 1
			if Vector3(a.r, a.g, a.b) != Vector3(b.r, b.g, b.b): rgb_changed += 1
	check(alpha_changed == 0, "actual original/readable palette ablation preserves every rendered silhouette alpha pixel")
	check(rgb_changed > 0 and float(palette_stats.mean_luma) > float(original_stats.mean_luma), "actual opt-in readable palette changes RGB and lifts opaque body mean luminance")
	check(actor.health.current == health_before and (art as UnderworldEnemy).feedback_sample.impact_serial == 0, "material rendering ablation never generates accepted gameplay or feedback events")
	living_facts[name] = palette_stats.duplicate(true)
	ablations.append({"kind": "actual_body_palette_uniform_ablation", "species": name, "paused": true, "readable_material": material_value, "original": original_stats, "readable": palette_stats, "alpha_changed_pixels": alpha_changed, "rgb_changed_pixels": rgb_changed, "luma_delta": float(palette_stats.mean_luma)-float(original_stats.mean_luma), "scope": "same actual body/pose/source alpha; local readable_material uniform only; aesthetic acceptance remains unverified"})
	root.transparent_bg = prior_transparency
	paused = prior_pause

func actual_particle_ablation(name: String) -> void:
	var target := art as UnderworldEnemy
	var particles := target.feedback_particles
	check(not particles._bursts.is_empty(), "render ablation has a genuine accepted projectile burst to observe")
	if particles._bursts.is_empty(): return
	var prior_pause := paused
	var prior_visible := particles.visible
	paused = true
	var frozen := JSON.stringify(particles._bursts)
	var flash := target.feedback_sample.impact_remaining
	var serial := target.feedback_sample.impact_serial
	var count := particles.emitted_bursts
	var contact: Vector2 = particles._bursts.back().point
	var age := float(particles._bursts.back().age)
	var canvas := particles.get_canvas_transform()
	var center := canvas*contact
	particles.visible = false
	await RenderingServer.frame_post_draw
	var without := root.get_texture().get_image()
	without.save_png(PIXEL_OUTPUT + name + "-accepted-particles-off.png")
	particles.visible = true
	await RenderingServer.frame_post_draw
	var with_particles := root.get_texture().get_image()
	with_particles.save_png(PIXEL_OUTPUT + name + "-accepted-particles-on.png")
	var region := Rect2i(Vector2i((center-Vector2(96,96)).floor()), Vector2i(192,192)).intersection(Rect2i(Vector2i.ZERO, without.get_size()))
	var minimum := region.end
	var maximum := region.position-Vector2i.ONE
	var changed := 0
	var radius := 0.0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if without.get_pixel(x,y) == with_particles.get_pixel(x,y): continue
			changed += 1
			minimum = Vector2i(mini(minimum.x,x), mini(minimum.y,y))
			maximum = Vector2i(maxi(maximum.x,x), maxi(maximum.y,y))
			radius = maxf(radius, (canvas.affine_inverse()*Vector2(x+.5,y+.5)).distance_to(contact))
	var difference_bounds := Rect2i(minimum, maximum-minimum+Vector2i.ONE) if changed > 0 else Rect2i()
	check(changed > 0, "actual accepted pixel particles contribute visible pixels when only their render visibility changes")
	check(JSON.stringify(particles._bursts) == frozen and target.feedback_sample.impact_remaining == flash, "particle render pair observes exactly one frozen burst age and unchanged body flash")
	check(particles.emitted_bursts == count and target.feedback_sample.impact_serial == serial and actor.health.current == actor.health.capacity-1, "particle visibility ablation creates no new accepted hit or emitted burst")
	ablations.append({"kind": "actual_accepted_particle_visibility_ablation", "species": name, "age_seconds_both_frames": age, "serial": serial, "emitted_bursts": count, "changed_pixels": changed, "difference_bbox_screen": difference_bounds, "maximum_radius_world": radius, "contact_world": contact, "region": region, "scope": "same actual accepted burst age, HP, pose and flash; visibility-only render ablation; no claim of v3/v4 size gain without matched v3 baseline"})
	particles.visible = prior_visible
	paused = prior_pause


func capture_body(label: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var body: EnemyFeedback01Body = (art as UnderworldEnemy).feedback_body
	var source_image := body.source.get_image()
	var light := 0.0
	var bright := 0
	var count := 0
	for y: int in source_image.get_height():
		for x: int in source_image.get_width():
			if source_image.get_pixel(x, y).a < .98: continue
			var uv := Vector2((x+.5)/source_image.get_width(), (y+.5)/source_image.get_height())
			var local := body.destination.position + body.destination.size * uv
			var p := (body.get_global_transform_with_canvas() * local).floor()
			if not Rect2(Vector2.ZERO, image.get_size()).has_point(p): continue
			var color := image.get_pixel(int(p.x), int(p.y))
			var luma := color.r*.2126 + color.g*.7152 + color.b*.0722
			light += luma
			if color.r > .8 and color.g > .75 and color.b > .5: bright += 1
			count += 1
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01/v4-pixels")
	image.save_png("res://build/enemy_feedback_01/v4-pixels/" + label + ".png")
	var row := {"phase": label, "samples": count, "mean_luma": light/maxi(1,count), "cream_fraction": float(bright)/maxi(1,count), "flash": body.flash_material.get_shader_parameter("hit_flash"), "HP": actor.health.current, "body_bounds": body.get_global_transform_with_canvas()*body.destination}
	pixels.append(row)
	return row

func capture_remains(label: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var remains: EnemyFeedback01Remains = (art as UnderworldEnemy).feedback_remains
	var center := remains.get_global_transform_with_canvas() * Vector2.ZERO
	var crop := Rect2i(Vector2i((center - Vector2(64, 64)).floor()), Vector2i(128, 128)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var body_pixels := 0
	var bottom_pixel := -1
	var background := Color("26362f")
	for y: int in range(crop.position.y, crop.end.y):
		for x: int in range(crop.position.x, crop.end.x):
			var color := image.get_pixel(x, y)
			if absf(color.r - background.r) + absf(color.g - background.g) + absf(color.b - background.b) > .06:
				body_pixels += 1
				bottom_pixel = maxi(bottom_pixel, y)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_region(crop).get_data())
	var digest := context.finish().hex_encode()
	image.save_png("res://build/enemy_feedback_01/v4-pixels/" + label + ".png")
	var terrain := PhysicsRayQueryParameters2D.create(remains.global_position, remains.global_position + Vector2(0, 2048), 1)
	var hit := remains.get_world_2d().direct_space_state.intersect_ray(terrain)
	var floor_y := (remains.get_canvas_transform() * (hit.position as Vector2)).y if not hit.is_empty() else INF
	var mirror := Transform2D(0.0, Vector2(float(remains.get("_face")), 1), 0.0, Vector2.ZERO)
	var corpse_stats := sample_sprite_rgba(image, remains.source, remains.bounds, remains.get_global_transform_with_canvas()*mirror)
	var species := String(actor.definition.stable_id)
	var live: Dictionary = living_facts.get(species, {})
	var material_facts := {"species": species, "living": live, "corpse": corpse_stats, "rest_rotation_radians": remains.global_rotation, "lifeless_uniform": remains.flash_material.get_shader_parameter("lifeless"), "readable_material_uniform": remains.flash_material.get_shader_parameter("readable_material"), "scope": "actual rendered RGB/saturation/direction facts; visual distinction requires independent/user assessment"}
	if not live.is_empty():
		material_facts.luma_delta_corpse_minus_living = float(corpse_stats.mean_luma)-float(live.mean_luma)
		material_facts.saturation_delta_corpse_minus_living = float(corpse_stats.mean_saturation)-float(live.mean_saturation)
	var row := {"phase": label, "material_facts": material_facts, "remains": remains_snapshot(remains), "visible_pixels": body_pixels, "bottom_pixel": bottom_pixel, "floor_screen_y": floor_y, "body_floor_gap_pixels": floor_y - float(bottom_pixel+1), "crop": crop, "crop_rgba_sha256": digest, "HP": actor.health.current, "inherited_body_visible": art.is_visible_in_tree()}
	pixels.append(row)
	return row

func actual_lethal_remains_pixels(path: String) -> void:
	await setup(path, true)
	var name := String(actor.definition.stable_id)
	for _hit: int in 3:
		check(await shoot_until_health_changes("pixel_actual_lethal_remains"), "persistent corpse GPU case receives real accepted projectile")
	check(actor.health.terminal and (art as UnderworldEnemy).feedback_remains.accepted_starts == 1, "GPU corpse follows one genuine three-projectile accepted death")
	await ticks(130, "pixel_corpse_persists_over_two_seconds")
	var remains: EnemyFeedback01Remains = (art as UnderworldEnemy).feedback_remains
	var corpse := await capture_remains(name + "-actual-persistent-corpse")
	check(not art.is_visible_in_tree() and remains.active and remains.settled and remains.is_visible_in_tree(), "actual corpse is independently visible beyond inherited body fade")
	check(int(corpse.visible_pixels) > 20, "actual GPU viewport still draws corpse pixels after more than two seconds")
	check(absf(float(corpse.body_floor_gap_pixels)) <= 3, "actual rendered corpse silhouette touches the real floor, not a rotated transparent AABB corner")
	paused = true
	for _frame: int in 4:
		await process_frame
	var frozen := await capture_remains(name + "-actual-persistent-corpse-paused")
	check(frozen.crop_rgba_sha256 == corpse.crop_rgba_sha256 and frozen.remains == corpse.remains, "settled paused corpse retains identical actual rendered pixels and visual transform")
	paused = false
	await cleanup()

func run() -> void:
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color("26362f"))
	for path: String in SOURCES:
		await setup(path, true)
		var name := String(actor.definition.stable_id)
		var before := await capture_body(name + "-before")
		await actual_palette_ablation(name)
		check((art as UnderworldEnemy).feedback_body.z_index == 0 and (art as UnderworldEnemy).feedback_body.show_behind_parent, "body retains the actor world draw layer while its own HP and telegraphs stay above")
		check(await shoot_until_health_changes("pixel_real_projectile"), "GPU sample receives actual accepted projectile")
		await process_frame
		var impact := await capture_body(name + "-impact")
		check(int(impact.samples) > 100, "actual opaque sprite has sufficient body pixels")
		check(float(impact.cream_fraction) > .70 and float(impact.mean_luma) > float(before.mean_luma) + .3, "actual dark body pixels become a readable cream hit silhouette")
		check(float(impact.flash) > .5 and actor.health.current == actor.health.capacity-1, "GPU hit flash follows committed HP rather than a visual trigger")
		await actual_particle_ablation(name)
		await ticks(30, "pixel_recovery")
		var recovered := await capture_body(name + "-recovered")
		check(float(recovered.flash) == 0 and float(recovered.mean_luma) < float(impact.mean_luma) - .3, "body returns to original material after bounded flash")
		check((art as UnderworldEnemy).feedback_particles.emitted_bursts == 1, "GPU sample has one accepted-hit burst")
		check(await shoot_until_health_changes("pixel_second_real_projectile"), "second real accepted projectile supplies live flash before pause restore")
		await process_frame
		paused = true
		check(actor.restore_instance_health(0), "formal restore API accepts dead snapshot during paused hurt")
		await process_frame
		var corpse := await capture_body(name + "-paused-restored")
		check(not (art as UnderworldEnemy).feedback_body.visible and float(corpse.flash) == 0 and (art as UnderworldEnemy).feedback_particles.active_bursts() == 0, "paused restore immediately clears body flash visibility and cached bursts before resume")
		check(float(corpse.cream_fraction) < .10, "actual paused viewport no longer contains the old cream body silhouette")
		check(not (art as UnderworldEnemy).feedback_sample.death_active and (art as UnderworldEnemy).feedback_sample.accepted_death_count == 0, "restored corpse never starts a new accepted death")
		var remains: EnemyFeedback01Remains = (art as UnderworldEnemy).feedback_remains
		check(remains.active and remains.restored and remains.settled and remains.accepted_starts == 0 and remains.is_visible_in_tree(), "paused restored corpse reconstructs static visible remains without accepted death replay")
		paused = false
		await cleanup()
		await actual_lethal_remains_pixels(path)
	var file := FileAccess.open("res://build/enemy_feedback_01/v4-pixels/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"feedback_revision": "readable_material_impact_v4", "checks": checks, "failures": failures, "pixels": pixels, "render_ablations": ablations, "scope": "actual GPU sprite samples under real accepted projectiles, explicit arena; no art redesign/animation-frame or device acceptance"}, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_PIXELS checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

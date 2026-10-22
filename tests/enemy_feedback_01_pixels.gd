extends "res://tests/enemy_feedback_01_tests.gd"
## Actual GPU body pixels following a real accepted Router projectile.
## Source-mask samples move with the actual body; no direct flash/VFX calls.
var pixels: Array[Dictionary] = []

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
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01/v3-pixels")
	image.save_png("res://build/enemy_feedback_01/v3-pixels/" + label + ".png")
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
	image.save_png("res://build/enemy_feedback_01/v3-pixels/" + label + ".png")
	var terrain := PhysicsRayQueryParameters2D.create(remains.global_position, remains.global_position + Vector2(0, 2048), 1)
	var hit := remains.get_world_2d().direct_space_state.intersect_ray(terrain)
	var floor_y := (remains.get_canvas_transform() * (hit.position as Vector2)).y if not hit.is_empty() else INF
	var row := {"phase": label, "remains": remains_snapshot(remains), "visible_pixels": body_pixels, "bottom_pixel": bottom_pixel, "floor_screen_y": floor_y, "body_floor_gap_pixels": floor_y - float(bottom_pixel+1), "crop": crop, "crop_rgba_sha256": digest, "HP": actor.health.current, "inherited_body_visible": art.is_visible_in_tree()}
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
		check((art as UnderworldEnemy).feedback_body.z_index == 0 and (art as UnderworldEnemy).feedback_body.show_behind_parent, "body retains the actor world draw layer while its own HP and telegraphs stay above")
		check(await shoot_until_health_changes("pixel_real_projectile"), "GPU sample receives actual accepted projectile")
		await process_frame
		var impact := await capture_body(name + "-impact")
		check(int(impact.samples) > 100, "actual opaque sprite has sufficient body pixels")
		check(float(impact.cream_fraction) > .70 and float(impact.mean_luma) > float(before.mean_luma) + .3, "actual dark body pixels become a readable cream hit silhouette")
		check(float(impact.flash) > .5 and actor.health.current == actor.health.capacity-1, "GPU hit flash follows committed HP rather than a visual trigger")
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
	var file := FileAccess.open("res://build/enemy_feedback_01/v3-pixels/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"feedback_revision": "persistent_remains_v3", "checks": checks, "failures": failures, "pixels": pixels, "scope": "actual GPU sprite samples under real accepted projectiles, explicit arena; no art redesign/animation-frame or device acceptance"}, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_PIXELS checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

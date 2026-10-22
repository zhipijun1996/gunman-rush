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
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01/v2-pixels")
	image.save_png("res://build/enemy_feedback_01/v2-pixels/" + label + ".png")
	var row := {"phase": label, "samples": count, "mean_luma": light/maxi(1,count), "cream_fraction": float(bright)/maxi(1,count), "flash": body.flash_material.get_shader_parameter("hit_flash"), "HP": actor.health.current, "body_bounds": body.get_global_transform_with_canvas()*body.destination}
	pixels.append(row)
	return row

func run() -> void:
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color("26362f"))
	for path: String in SOURCES:
		await setup(path, true)
		var name := String(actor.definition.stable_id)
		var before := await capture_body(name + "-before")
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
		await cleanup()
	var file := FileAccess.open("res://build/enemy_feedback_01/v2-pixels/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "pixels": pixels, "scope": "actual GPU sprite samples under real accepted projectiles, explicit arena; no art redesign/animation-frame or device acceptance"}, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_PIXELS checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

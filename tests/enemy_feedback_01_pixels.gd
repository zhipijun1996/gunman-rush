extends "res://tests/enemy_feedback_01_tests.gd"
## Actual GPU body pixels following a real accepted Router projectile.
## Source-mask samples move with the actual body; no direct flash/VFX calls.
var pixels: Array[Dictionary] = []
var ablations: Array[Dictionary] = []
var living_facts: Dictionary = {}
const PIXEL_OUTPUT := "res://build/enemy_feedback_01/v5-pixels/"

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
	DirAccess.make_dir_recursive_absolute("res://build/enemy_feedback_01/v5-pixels")
	image.save_png("res://build/enemy_feedback_01/v5-pixels/" + label + ".png")
	var row := {"phase": label, "samples": count, "mean_luma": light/maxi(1,count), "cream_fraction": float(bright)/maxi(1,count), "flash": body.flash_material.get_shader_parameter("hit_flash"), "HP": actor.health.current, "body_bounds": body.get_global_transform_with_canvas()*body.destination}
	pixels.append(row)
	return row

func capture_remains(label: String) -> Dictionary:
	var effect: EnemyFeedback01Remains = (art as UnderworldEnemy).feedback_remains
	var prior_layer := effect.visibility_layer
	var prior_mask := root.canvas_cull_mask
	var death_layer := 1 << 19
	# Capture the actual task death leaf in its own render channel. Existing
	# projectile contact FX can legitimately remain frozen while paused; their
	# pixels do not belong to this leaf's epoch-cancellation contract.
	var ancestors: Array[Dictionary] = []
	var ancestor := effect.get_parent()
	while ancestor is CanvasItem:
		var item := ancestor as CanvasItem
		ancestors.append({"item":item,"layer":item.visibility_layer})
		# The explicit test world is a drawing-free Node2D; preserve the full
		# ancestor visibility chain without admitting any unrelated child layer.
		item.visibility_layer |= death_layer
		ancestor = ancestor.get_parent()
	effect.visibility_layer = death_layer
	root.canvas_cull_mask = death_layer
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	# Restore normal rendering immediately after actual viewport readback.
	effect.visibility_layer = prior_layer
	root.canvas_cull_mask = prior_mask
	for entry: Dictionary in ancestors:
		(entry.item as CanvasItem).visibility_layer = int(entry.layer)
	var center := effect.get_global_transform_with_canvas()*Vector2.ZERO
	var crop := Rect2i(Vector2i((center-Vector2(96,96)).floor()), Vector2i(192,192)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	var visible_pixels := 0
	var background := Color("26362f")
	for y: int in range(crop.position.y,crop.end.y):
		for x: int in range(crop.position.x,crop.end.x):
			var color := image.get_pixel(x,y)
			if absf(color.r-background.r)+absf(color.g-background.g)+absf(color.b-background.b) > .06:
				visible_pixels += 1
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_region(crop).get_data())
	var digest := context.finish().hex_encode()
	image.save_png(PIXEL_OUTPUT+label+".png")
	var row := {"phase":label,"effect":remains_snapshot(effect),"visible_pixels":visible_pixels,"crop":crop,"crop_rgba_sha256":digest,"HP":actor.health.current,"inherited_body_visible":art.is_visible_in_tree(),"capture_visibility_layer":death_layer,"restored_effect_visibility_layer":prior_layer,"restored_viewport_cull_mask":prior_mask,"scope":"actual viewport pixels isolated to the task death leaf render channel; other projectile/contact FX remain untouched; v5 replaces rejected persistent corpse contract"}
	pixels.append(row)
	return row

func actual_lethal_remains_pixels(path: String, cancel_active: bool = false) -> void:
	await setup(path,true)
	var name := String(actor.definition.stable_id)+("-epoch-cancel" if cancel_active else "-natural-expiry")
	for _hit: int in 3:
		check(await shoot_until_health_changes("pixel_actual_death_explosion"), "death explosion GPU case receives real accepted projectile")
	var effect: EnemyFeedback01Remains = (art as UnderworldEnemy).feedback_remains
	check(actor.health.terminal and effect.active and effect.accepted_starts == 1, "GPU explosion follows one genuine three-projectile accepted death")
	paused = true
	var early := await capture_remains(name+"-early")
	check(int(early.visible_pixels) > 20 and effect.active and effect.visible, "actual early accepted death explosion draws visible GPU pixels")
	for _frame: int in 4: await process_frame
	var frozen := await capture_remains(name+"-early-paused")
	check(frozen.crop_rgba_sha256 == early.crop_rgba_sha256 and frozen.effect == early.effect, "paused accepted death explosion preserves identical actual pixels and state")
	if cancel_active:
		check(actor.restore_instance_health(0), "official epoch initialization can cancel an active accepted explosion while paused")
		await process_frame
		var cancelled := await capture_remains(name+"-cleared-by-epoch")
		check(not effect.active and not effect.visible and effect.restored and int(cancelled.visible_pixels) == 0, "epoch initialization immediately clears active explosion pixels without restoring a corpse")
		check((art as UnderworldEnemy).feedback_particles.active_bursts() == 0 and (art as UnderworldEnemy).feedback_sample.flash_strength() == 0, "active death epoch cancellation clears old contact particles and flash")
	paused = false
	if not cancel_active:
		await ticks(8,"pixel_real_death_fragment_expansion")
		var expansion := await capture_remains(name+"-fragment-expansion")
		check(effect.active and effect.phase != &"flash" and int(expansion.visible_pixels) > 0, "actual death burst retains visible fragment pixels after its initial flash")
	await ticks(90,"pixel_explosion_absent_after_one_second")
	var ended := await capture_remains(name+"-ended")
	check(not effect.active and not effect.visible and effect.settled and int(ended.visible_pixels) == 0, "actual GPU death area is blank after more than one second with no persistent corpse")
	if not cancel_active:
		check(effect.phase == &"spent" and effect.accepted_starts == 1, "ordinary accepted explosion spends once without epoch cancellation")
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
		check(not remains.active and not remains.visible and remains.restored and remains.settled and remains.accepted_starts == 0, "paused saved-dead snapshot stays absent without explosion replay or a persistent corpse")
		paused = false
		await cleanup()
		await actual_lethal_remains_pixels(path)
		await actual_lethal_remains_pixels(path,true)
	var file := FileAccess.open("res://build/enemy_feedback_01/v5-pixels/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"feedback_revision": "accepted_explosion_v5", "checks": checks, "failures": failures, "pixels": pixels, "render_ablations": ablations, "scope": "actual GPU sprite samples under real accepted projectiles, explicit arena; no art redesign/animation-frame or device acceptance"}, "\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_PIXELS checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

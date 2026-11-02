extends SceneTree
# Actual module and formal stage consumers. Camera repositioning below is ONLY
# visual inspection, never evidence of player traversal or device performance.
var checks := 0
var failures := 0
var capture := "--capture" in OS.get_cmdline_user_args()
var folder := "res://build/verification/wood-platforms"
var inventory: Array[Dictionary] = []
class LegacyStrip extends Node2D:
	var surfaces: Array[Rect2] = []
	func _draw() -> void:
		for rect: Rect2 in surfaces: PlainsCohesionArt.draw_surface(self, rect, true)
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func frames(count: int) -> void:
	for i: int in count: await process_frame
func shot(name_value: String) -> void:
	if not capture: return
	await frames(4)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder + "/" + name_value + ".png") == OK, "actual GPU capture saved")
func check_module(module: PlatformingModule, context: String) -> void:
	var found: Dictionary = {}
	for node: Node in module.get_children():
		if node.has_meta("platform_index"):
			var index := int(node.get_meta("platform_index"))
			var rect: Rect2 = module.definition.platforms[index]
			check(not found.has(index), "one draw per surface")
			found[index] = true
			check(node is ColorRect and node.material is ShaderMaterial, "actual draw owns material")
			check(node.material.shader == PlainsWoodPlatformArt.MATERIAL, "actual consumer uses terminal-aware renderer")
			check(node.size.x == rect.size.x and node.position.x == rect.position.x, "actual draw matches physical horizontal outline")
			var scale_value := float(node.material.get_shader_parameter("art_scale"))
			check(scale_value * 290 <= rect.size.x, "short-cap transitions cannot overlap")
			var body: StaticBody2D = module.get_node("Platform%s" % index)
			var collider: CollisionShape2D = body.get_node("CollisionShape2D")
			check(collider.one_way_collision and collider.shape.size == rect.size, "one-way collision unchanged")
			inventory.append({"consumer": context, "module": str(module.definition.module_id), "index": index, "width": rect.size.x, "height": rect.size.y, "renderer": node.material.shader.resource_path})
	check(found.size() == module.definition.one_way_platform_indices.size(), "every formal one-way instance has observed renderer")
func check_pixel_module(module: PlatformingModule, context: String) -> void:
	var found: Dictionary = {}
	check(module.pixel_mechanism_art, "current formal consumer selects pixel family")
	for node: Node in module.get_children():
		if not node.has_meta("platform_index"): continue
		var index := int(node.get_meta("platform_index"))
		var rect: Rect2 = module.definition.platforms[index]
		check(not found.has(index), "current pixel draw is unique")
		found[index] = true
		check(node is PlainsWoodPlatformArt.PixelOneWayPaint, "current actual one-way uses pixel renderer")
		if not node is PlainsWoodPlatformArt.PixelOneWayPaint: continue
		check(node.bounds == rect and node.position == Vector2.ZERO, "current pixel outline matches complete physical rectangle")
		var body: StaticBody2D = module.get_node("Platform%s" % index)
		var collider: CollisionShape2D = body.get_node("CollisionShape2D")
		check(collider.one_way_collision and collider.shape.size == rect.size and body.position == rect.get_center(), "current pixel draw keeps actual physical body")
		inventory.append({"consumer":context,"module":str(module.definition.module_id),"index":index,"width":rect.size.x,"height":rect.size.y,"renderer":"PixelOneWayPaint/current-pixel"})
	check(found.size() == module.definition.one_way_platform_indices.size(), "every current formal one-way owns an observed pixel draw")

func check_legacy_geometry(source: PlatformingModule, context: String) -> void:
	# Historical shader regression keeps every original check on the production
	# renderer using the exact current module's platform geometry. This isolated
	# rendering fixture is not a claim that the formal game still uses old art.
	var module := PlatformingModule.new()
	module.definition = source.definition.duplicate(true)
	module.definition.danger_bounds.clear()
	module.definition.surface_thorns.clear()
	module.definition.saws.clear()
	module.definition.ferries.clear()
	module.pixel_mechanism_art = false
	module.authoring_debug = false
	module.terrain_candidate_preview = true
	module.position = Vector2(1000000, 1000000)
	root.add_child(module)
	check_module(module, context)
	module.free()

func check_current_module(module: PlatformingModule, context: String, formal_default := false, legacy_replay := false) -> void:
	var found: Dictionary = {}
	var stage: Node = module
	while stage != null and not stage is PlainsRegionStage: stage = stage.get_parent()
	if formal_default:
		check(module.pixel_mechanism_art, "formal default retains pixel mechanism selection")
		check(stage is PlainsRegionStage and UnderworldActors.enabled(module), "formal default has actual Underworld stage context")
		if stage is PlainsRegionStage:
			check(stage.terrain_art.art is UnderworldTerrain, "formal default stage owns actual Underworld terrain")
	for node: Node in module.get_children():
		if not node.has_meta("platform_index"): continue
		var index := int(node.get_meta("platform_index"))
		check(index >= 0 and index < module.definition.platforms.size(), "draw references actual platform index")
		if index < 0 or index >= module.definition.platforms.size(): continue
		var rect: Rect2 = module.definition.platforms[index]
		check(index in module.definition.one_way_platform_indices, "draw belongs to authored one-way surface")
		check(not found.has(index), "one draw per surface")
		found[index] = true
		var renderer := "unknown"
		if module.pixel_mechanism_art and not legacy_replay:
			check(node is PlainsWoodPlatformArt.PixelOneWayPaint, "actual default draw is PixelOneWayPaint")
			if node is PlainsWoodPlatformArt.PixelOneWayPaint:
				renderer = "PixelOneWayPaint/UnderworldTerrain" if UnderworldActors.enabled(node) else "PixelOneWayPaint/PixelFormalTerrain"
				check(node.bounds == rect, "pixel draw bounds match complete authored physical rectangle")
				check(node.transform == Transform2D.IDENTITY, "pixel draw remains in module coordinates without transform drift")
				if formal_default: check(UnderworldActors.enabled(node), "actual default paint resolves Underworld draw branch")
		else:
			# Explicit historical material fixture, including replay over each
			# real formal module. Never relabel this as the default renderer.
			check(node is ColorRect and node.material is ShaderMaterial, "actual legacy draw owns material")
			if node is ColorRect and node.material is ShaderMaterial:
				check(node.material.shader == PlainsWoodPlatformArt.MATERIAL, "actual consumer uses terminal-aware renderer")
				check(node.size.x == rect.size.x and node.position.x == rect.position.x, "actual draw matches physical horizontal outline")
				var scale_value := float(node.material.get_shader_parameter("art_scale"))
				check(scale_value * 290 <= rect.size.x, "short-cap transitions cannot overlap")
				renderer = node.material.shader.resource_path if node.material.shader != null else "missing-shader"
		check(node.find_children("*", "CollisionObject2D", true, false).is_empty() and node.find_children("*", "CollisionShape2D", true, false).is_empty(), "paint never owns physical collision descendants")
		var body := module.get_node_or_null("Platform%s" % index) as StaticBody2D
		check(body != null, "original physical platform body remains")
		if body == null: continue
		var collider := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		check(collider != null and collider.shape is RectangleShape2D, "original one-way rectangle shape remains")
		if collider != null and collider.shape is RectangleShape2D:
			check(collider.one_way_collision and collider.shape.size == rect.size, "one-way collision unchanged")
			check(body.position == rect.get_center() and collider.position == Vector2.ZERO, "physical body/shape matches authored outline and pixel bounds")
			check(body.is_in_group("one_way_platform") and body.collision_layer == 1, "original one-way platform semantic group/layer preserved")
		inventory.append({"consumer": context, "module": str(module.definition.module_id), "index": index, "width": rect.size.x, "height": rect.size.y, "renderer": renderer, "physical_bounds": str(rect), "legacy_visual_replay": legacy_replay})
	check(found.size() == module.definition.one_way_platform_indices.size(), "every formal one-way instance has observed renderer")

func replay_legacy_visuals(module: PlatformingModule, context: String) -> void:
	# Test-owned visual replacement only, after default captures. Keep every
	# actual formal body, shape, module selection flag and authored definition.
	var original_pixel_flag := module.pixel_mechanism_art
	var physical: Dictionary = {}
	for index: int in module.definition.one_way_platform_indices:
		var body := module.get_node("Platform%s" % index) as StaticBody2D
		var collider := body.get_node("CollisionShape2D") as CollisionShape2D
		physical[index] = [body.get_instance_id(), collider.get_instance_id(), collider.shape.get_instance_id()]
	for node: Node in module.get_children():
		if node.has_meta("platform_index"):
			module.remove_child(node)
			node.free()
	for index: int in module.definition.one_way_platform_indices:
		var paint := PlainsWoodPlatformArt.build(module.definition.platforms[index], false)
		paint.set_meta("platform_index", index)
		module.add_child(paint)
		var body := module.get_node("Platform%s" % index) as StaticBody2D
		var collider := body.get_node("CollisionShape2D") as CollisionShape2D
		check(physical[index] == [body.get_instance_id(), collider.get_instance_id(), collider.shape.get_instance_id()], "legacy replay preserves actual formal body/shape identity")
	check(module.pixel_mechanism_art == original_pixel_flag, "legacy replay never changes production renderer selection flag")
	check_current_module(module, context, false, true)
	check_module(module, context + "/original-legacy-checks")

func run() -> void:
	var legacy := "--legacy-strip" in OS.get_cmdline_user_args()
	if legacy: folder += "-rejected"
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(3)
	check(app.start_plains("terrain-production"), "normal formal stage starts")
	await frames(6)
	var stage := app.stage as PlainsRegionStage
	var target: PlatformingModule
	var largest := 0.0
	for module: PlatformingModule in stage.assembler.modules:
		check_current_module(module, "formal-map-1", true)
		check_pixel_module(module, "formal-map-1")
		check_legacy_geometry(module, "historical-shader/current-map-1-geometry")
		for index: int in module.definition.one_way_platform_indices:
			if module.definition.platforms[index].size.x > largest:
				target = module
				largest = module.definition.platforms[index].size.x
	check(largest > 300, "formal seed includes long one-way surfaces")
	if capture and target != null:
		var camera := root.get_camera_2d()
		camera.set_process(false)
		camera.set_physics_process(false)
		var index: int = target.definition.one_way_platform_indices[0]
		var surface: Rect2 = target.definition.platforms[index]
		camera.position = target.to_global(surface.get_center()) + Vector2(0, 110)
		camera.zoom = Vector2.ONE * minf(1.0, 1050.0 / largest)
		camera.reset_smoothing()
		paused = true
		await shot("formal-one-way")
		for candidate: PlatformingModule in stage.assembler.modules:
			if candidate.definition.module_id == &"region_stairs":
				camera.position = candidate.to_global(candidate.definition.world_bounds.get_center())
				camera.zoom = Vector2.ONE
				camera.reset_smoothing()
				await shot("formal-stacked")
				break
		paused = false
	for candidate: PlatformingModule in stage.assembler.modules:
		replay_legacy_visuals(candidate, "formal-map-1-legacy-replay")
	check(await load("res://tests/plains_campaign_fixture.gd").second_map(app, self), "second formal map lifecycle fixture")
	for candidate: PlatformingModule in app.stage.assembler.modules:
		check_current_module(candidate, "formal-map-2", true)
		check_pixel_module(candidate, "formal-map-2")
		check_legacy_geometry(candidate, "historical-shader/current-map-2-geometry")
	if capture:
		for candidate: PlatformingModule in app.stage.assembler.modules:
			if candidate.definition.one_way_platform_indices.is_empty(): continue
			var camera := root.get_camera_2d()
			camera.set_process(false)
			camera.set_physics_process(false)
			var surface: Rect2 = candidate.definition.platforms[candidate.definition.one_way_platform_indices[0]]
			camera.position = candidate.to_global(surface.get_center()) + Vector2(0, 110)
			camera.reset_smoothing()
			paused = true
			await shot("formal-map-2")
			paused = false
			break
	for candidate: PlatformingModule in app.stage.assembler.modules:
		replay_legacy_visuals(candidate, "formal-map-2-legacy-replay")
	app.abandon_run()
	await frames(3)
	app.free()
	await frames(3)
	# Same production PlatformingModule, systematic length and translation sweep.
	var original: PlatformingModule = load("res://game/world/generation/scenes/modules/safe_hub.tscn").instantiate()
	var definition: PlatformingModuleDefinition = original.definition
	original.free()
	if definition == null:
		# Reuse an actual registered definition instead of inventing motor/port rules.
		printerr("Fixture base missing")
		quit(1)
		return
	var module := PlatformingModule.new()
	module.definition = definition.duplicate(true)
	module.definition.danger_bounds.clear()
	module.definition.surface_thorns.clear()
	module.definition.saws.clear()
	module.definition.ferries.clear()
	module.definition.platforms.clear()
	module.definition.one_way_platform_indices.clear()
	# Keep valid authored support for the original ports/anchors (not drawn).
	module.definition.platforms = definition.platforms.duplicate()
	var widths: Array[float] = [8, 24, 60, 96, 192, 383.5, 1000]
	for i: int in widths.size():
		module.definition.one_way_platform_indices.append(module.definition.platforms.size())
		module.definition.platforms.append(Rect2(100, 80+i*70, widths[i], 24))
	for y: float in [650, 690]:
		module.definition.one_way_platform_indices.append(module.definition.platforms.size())
		module.definition.platforms.append(Rect2(100, y, 680, 24))
	module.pixel_mechanism_art = false # Explicit legacy material sweep; original GPU contract stays intact.
	module.authoring_debug = false
	module.terrain_candidate_preview = true
	root.add_child(module)
	for i: int in widths.size():
		var label := Label.new()
		label.text = str(widths[i])
		label.position = Vector2(20, 70+i*70)
		module.add_child(label)
	var title := Label.new()
	title.text = "PRODUCTION MODULE / variable widths + stacked one-way surfaces / rendering probe"
	title.position = Vector2(20, 20)
	module.add_child(title)
	check_module(module, "production-module-width-sweep/original-legacy-checks")
	if "--missing-legacy-material" in OS.get_cmdline_user_args():
		# Isolated malformed-renderer guard: it must count a failure, not abort.
		for node: Node in module.get_children():
			if node.has_meta("platform_index"):
				node.material = null
				break
	check_current_module(module, "production-module-width-sweep")
	if legacy:
		# Isolated negative control: the former real draw function must fail the
		# SAME pixel contract. No production flag or runtime code is mutated.
		for node: Node in module.get_children():
			if node.has_meta("platform_index"): node.hide()
		var old := LegacyStrip.new()
		for index: int in module.definition.one_way_platform_indices:
			old.surfaces.append(module.definition.platforms[index])
		module.add_child(old)
	root.transparent_bg = true
	await shot("width-sweep")
	var baseline: Image
	if capture:
		baseline = root.get_texture().get_image()
		for row: int in range(2, widths.size()):
			var continuous := true
			for x: int in range(106, 100+floori(widths[row])-6):
				var opaque := false
				for y: int in range(82+row*70, 96+row*70):
					if baseline.get_pixel(x,y).a > 0.6: opaque = true
				if not opaque: continuous = false
			check(continuous, "actual painted body has no internal transparent breaks at width=" + str(widths[row]))
		# End identity must survive length changes, not just translation. Integer
		# widths avoid comparing different subpixel coverage at fractional edges.
		for row: int in [4, 6]:
			var stable := true
			for dx: int in range(1, 18):
				for dy: int in range(-7, 23):
					for side: int in [0, 1]:
						var xa := 100+dx if side == 0 else 196-dx
						var xb := 100+dx if side == 0 else 100+int(widths[row])-dx
						var a := baseline.get_pixel(xa, 290+dy)
						var b := baseline.get_pixel(xb, 80+row*70+dy)
						for channel: int in 4:
							if absf(a[channel]-b[channel]) > 1.001/255.0: stable = false
			check(stable, "actual left AND right terminal stay intact when length changes")
	module.position.x += 37
	await shot("translated")
	if capture:
		var translated := root.get_texture().get_image()
		var same := true
		var changed_channels := 0
		for y: int in range(65, 550):
			for x: int in range(100, 1100):
				var a := baseline.get_pixel(x,y)
				var b := translated.get_pixel(x+37,y)
				for channel: int in 4:
					if a[channel] != b[channel]: changed_channels += 1
					# GPU interpolation may round a channel by one 8-bit level.
					if absf(a[channel] - b[channel]) > 1.001 / 255.0: same = false
		print("GPU translation: ", changed_channels, " changed channels; bound=1/255 per channel")
		check(same, "actual GPU art follows the body without world-phase clipping")
	var default_pixel := PlatformingModule.new()
	default_pixel.definition = module.definition.duplicate(true)
	default_pixel.authoring_debug = false
	default_pixel.terrain_candidate_preview = true
	module.free()
	root.add_child(default_pixel)
	check(default_pixel.pixel_mechanism_art and not UnderworldActors.enabled(default_pixel), "isolated default fixture exercises real PixelFormal fallback")
	if "--unknown-default-renderer" in OS.get_cmdline_user_args():
		# Unknown CanvasItem is rejected even with otherwise correct metadata.
		for node: Node in default_pixel.get_children():
			if node.has_meta("platform_index"):
				var index := int(node.get_meta("platform_index"))
				default_pixel.remove_child(node)
				node.free()
				var wrong := Node2D.new()
				wrong.set_meta("platform_index", index)
				default_pixel.add_child(wrong)
				break
	check_current_module(default_pixel, "default-pixel-module-width-sweep")
	default_pixel.free()
	var file := FileAccess.open(folder + "/inventory.json", FileAccess.WRITE)
	var consumers: Array[Dictionary] = []
	for context: String in ["formal-map-1", "formal-map-2", "formal-map-1-legacy-replay", "formal-map-2-legacy-replay", "production-module-width-sweep", "default-pixel-module-width-sweep", "historical-shader/current-map-1-geometry", "historical-shader/current-map-2-geometry", "production-module-width-sweep/original-legacy-checks", "formal-map-1-legacy-replay/original-legacy-checks", "formal-map-2-legacy-replay/original-legacy-checks"]:
		consumers.append({"id": context, "path": "PlatformingModule -> PlainsWoodPlatformArt -> actual renderer (see instances)", "instances": inventory.filter(func(i: Dictionary) -> bool: return i.consumer == context).size()})
	file.store_string(JSON.stringify({"consumers": consumers, "instances": inventory, "capture": capture, "legacy_negative": legacy, "checks": checks, "failures": failures, "scope": "one-way rendering and collision ownership; no traversal or device claim"}, "  "))
	file.close()
	print("WOOD PLATFORMS: %s assertions, %s failures" % [checks, failures])
	quit(1 if failures else 0)

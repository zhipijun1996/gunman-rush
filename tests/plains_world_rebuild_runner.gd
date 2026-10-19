extends SceneTree
## Complete-world source and real installed consumer; not artistic admission.
const WORLD := preload("res://scripts/generation/plains_world_rebuild.gd")
const STAGE := preload("res://scripts/demo/plains_world_rebuild_stage.gd")
const PRIOR_DEFAULT := "98a71fc9d52471dfbc8ec6b25dfb09d1a1326d158cd9dbc71367966ef0ec2a51"
var assertions := 0
var failures: Array[String] = []
var output_path := ""
var variant_id := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		print("WORLD REBUILD FAILURE: ", label)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
		elif arg.begins_with("--variant="): variant_id = int(arg.trim_prefix("--variant="))
	if output_path.is_empty(): quit(2); return
	run.call_deferred()

func packed(values: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for value: Array in values: points.append(Vector2(float(value[0]), float(value[1])))
	return points

func verify_negative(source: Dictionary) -> void:
	var invalid: Dictionary = source.duplicate(true)
	invalid.version = "unknown"
	check(not WORLD.validate(invalid).is_empty(), "Unknown source version rejected")
	invalid = source.duplicate(true)
	invalid.bodies.pop_back()
	check(not WORLD.validate(invalid).is_empty(), "Missing common foundation rejected")
	invalid = source.duplicate(true)
	invalid.bodies[1].id = invalid.bodies[0].id
	check(not WORLD.validate(invalid).is_empty(), "Duplicate entity identity rejected")
	invalid = source.duplicate(true)
	invalid.bodies[0].polygon = [[0, 0], [1, 0], [2, 0], [3, 0]]
	check(not WORLD.validate(invalid).is_empty(), "Degenerate terrain rejected")
	invalid = source.duplicate(true)
	invalid.bodies[0].painting_source = "independent_thin_top_strip"
	check(not WORLD.validate(invalid).is_empty(), "Painting detached from solid complete body rejected")
	invalid = source.duplicate(true)
	invalid.bodies[0].top_surfaces[0] = {"from": [200, 0], "to": [100, 0], "role": "main_route"}
	check(not WORLD.validate(invalid).is_empty(), "Backwards standing surface rejected")
	invalid = source.duplicate(true)
	invalid.bodies[0].top_surfaces[0] = {"from": [100, 0], "to": [200, 0], "role": "main_route"}
	check(not WORLD.validate(invalid).is_empty(), "Floating standing claim outside solid rejected")
	invalid = source.duplicate(true)
	for point: Array in invalid.bodies[2].polygon: point[1] += 1000
	check(not WORLD.validate(invalid).is_empty(), "Disconnected creek root rejected")
	invalid = source.duplicate(true)
	invalid.bodies[1].top_surfaces[0]["from"][0] += 1000
	check(not WORLD.validate(invalid).is_empty(), "Unregistered main-route jump span rejected")
	invalid = source.duplicate(true)
	invalid.bodies[0].paint_frame.uniform_scale *= 1.1
	check(not WORLD.validate(invalid).is_empty(), "Changed source-frame scale without rederiving collision is refused")
	invalid = source.duplicate(true)
	invalid.bodies[0].paint_frame.source_path = "res://assets/visual_development/plains_world_rebuild/environment_source.png"
	check(not WORLD.validate(invalid).is_empty(), "Different real image cannot masquerade as registered complete terrain source")
	invalid = source.duplicate(true)
	invalid.bodies[0].paint_frame.source_size[0] += 1
	check(not WORLD.validate(invalid).is_empty(), "False original source dimensions refused")
	invalid = source.duplicate(true)
	invalid.bodies[0].paint_frame.mirror_x = not bool(invalid.bodies[0].paint_frame.mirror_x)
	check(not WORLD.validate(invalid).is_empty(), "Mirror change without source-derived physical reconstruction refused")
	invalid = source.duplicate(true)
	invalid.bodies[0].polygon[0][0] += 2
	check(not WORLD.validate(invalid).is_empty(), "Collision point detached from source painting frame refused")
	invalid = source.duplicate(true)
	invalid.bodies[0].source_polygon[0][0] += 2
	check(not WORLD.validate(invalid).is_empty(), "Counterfeit source contour detached from actual registered painting refused")
	check(WORLD.generate("world-rebuild-01", -1).has("error"), "Negative structure variant refused")
	check(WORLD.generate("world-rebuild-01", 2).has("error"), "Unregistered second-plus structure refused")

func source_pixel_to_world(sprite: Sprite2D, pixel: Vector2) -> Vector2:
	var local := pixel
	var size := sprite.texture.get_size()
	if sprite.flip_h: local.x = size.x-local.x
	if sprite.flip_v: local.y = size.y-local.y
	if sprite.centered: local -= size*.5
	local += sprite.offset
	return sprite.to_global(local)

func world_to_source_pixel(sprite: Sprite2D, world: Vector2) -> Vector2:
	var local := sprite.to_local(world)-sprite.offset
	var size := sprite.texture.get_size()
	if sprite.centered: local += size*.5
	if sprite.flip_h: local.x=size.x-local.x
	if sprite.flip_v: local.y=size.y-local.y
	return local

func verify_stage(plan: Dictionary, tuning: PlayerTuning) -> Dictionary:
	var stage := STAGE.new() as PlainsWorldRebuildStage
	stage.configure_world(plan, tuning)
	root.add_child(stage)
	await physics_frame
	await process_frame
	var actual := stage.get_world_rebuild_snapshot()
	check(actual.ready, "Actual new stage assembles")
	if not actual.ready:
		# Preserve the primary source/assembly refusal as failed evidence without
		# dereferencing missing dependent consumers or masking the real cause.
		stage.queue_free()
		await process_frame
		await process_frame
		return actual

	check(actual.legacy_modules == 0, "No old rectangle/module implementation instantiated")
	check(actual.actual_collisions.size() == plan.bodies.size(), "Every complete source body installs one actual collider")
	for index: int in range(stage.body_colliders.size()):
		var collider: CollisionPolygon2D = stage.body_colliders[index]
		var source: Dictionary = plan.bodies[index]
		check(collider.polygon == packed(source.polygon), "Actual collision points exactly equal complete body source: " + str(source.id))
		check(str(collider.get_meta("world_body_id")) == str(source.id), "Actual collider binds source identity")
		check(not collider.disabled and not collider.one_way_collision and collider.build_mode == CollisionPolygon2D.BUILD_SOLIDS, "Solid body remains enabled, complete and two-sided")
		check((collider.get_parent() as StaticBody2D).collision_layer == 1, "Solid world uses actual terrain collision layer")
		var shape_count := (collider.get_parent() as StaticBody2D).get_shape_owners().size()
		check(shape_count > 0, "Polygon creates actual physics shape owner")
		for surface: Dictionary in source.top_surfaces:
			var middle := (Vector2(float(surface.from[0]),float(surface.from[1]))+Vector2(float(surface.to[0]),float(surface.to[1])))*.5
			var query := PhysicsRayQueryParameters2D.create(middle-Vector2(0,30),middle+Vector2(0,30),1)
			var hit := stage.get_world_2d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider == collider.get_parent(), "Actual physics ray finds declared complete-body standing surface")

	var actual_player := preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	actual_player.position = Vector2(float(plan.spawn[0]),float(plan.spawn[1]))
	root.add_child(actual_player)
	await physics_frame
	var actual_controller := actual_player.get_node("Controller") as PlayerController
	var respawn := SegmentRespawn.new()
	respawn.configure(actual_controller,DemoLifetime.new())
	check(respawn.is_safe(Vector2(float(plan.spawn[0]),float(plan.spawn[1]))), "Actual unchanged full-player safe-entry contract accepts source-derived spawn")
	var actual_actor_z := actual_player.z_index
	actual_player.queue_free()
	await process_frame
	check(actual.actual_enemies == plan.enemy_spawns.size(), "Existing enemy contract really instantiated")
	check(not actual.painting.is_empty(), "Actual painting consumer supplies measured evidence")
	actual["installed_paint_diagnostics"] = []
	var composer: Node2D = stage.world_composer
	for source: Dictionary in plan.bodies:
		var instance := composer.get_node_or_null(str(source.id).validate_node_name()+"CompletePainting") as Sprite2D
		check(instance != null, "Actual complete painted body installs source Sprite: "+str(source.id))
		if instance == null: continue
		var frame: Dictionary = source.paint_frame
		var receipt: Dictionary = {}
		for row: Dictionary in actual.painting.bodies:
			if str(row.id) == str(source.id): receipt = row; break
		check(not receipt.is_empty() and receipt.world_polygon == source.polygon, "Measured painter binds same complete polygon as actual collider")
		check(instance.texture != null and instance.texture.resource_path == str(frame.source_path), "Actual Sprite uses registered frame source")
		check(FileAccess.get_sha256(str(frame.source_path)) == str(receipt.source_sha256), "Actual painting bytes match receipt")
		check(instance.texture.get_size() == Vector2(float(frame.source_size[0]),float(frame.source_size[1])), "Actual original image dimensions equal registered source frame")
		check(not instance.region_enabled and instance.hframes==1 and instance.vframes==1, "Whole painted construction rendered without slicing or hidden atlas deformation")
		check(absf(absf(instance.scale.x)-float(frame.uniform_scale))<.00001 and absf(absf(instance.scale.y)-float(frame.uniform_scale))<.00001, "Actual Sprite has one equal-axis source-to-world scale")
		check(instance.material == null, "Source painting remains direct Sprite without UV remapping or opacity-forcing material")
		check(instance.z_index<actual_actor_z, "Whole terrain source stays behind actual dynamic actor layer")
		check(int(receipt.get("actual_z_index",999))==instance.z_index, "Measured terrain depth equals actual installed Sprite depth")

		var transformed: Array = []
		for value: Array in source.source_polygon:
			var at := source_pixel_to_world(instance,Vector2(float(value[0]),float(value[1])))
			transformed.append([at.x,at.y])
		if bool(frame.mirror_x): transformed.reverse()
		check(packed(transformed).size()==packed(source.polygon).size(), "Source outline and installed collider retain all construction vertices")
		var max_mismatch := 0.0
		for index: int in mini(transformed.size(),source.polygon.size()):
			max_mismatch=maxf(max_mismatch,Vector2(float(transformed[index][0]),float(transformed[index][1])).distance_to(Vector2(float(source.polygon[index][0]),float(source.polygon[index][1]))))
		check(max_mismatch<.001, "Actual Sprite source polygon maps point-for-point to real collider with declared mirror and origin")
		var image := instance.texture.get_image()
		check(image != null and not image.is_empty(), "Original source pixels load for physical contact-material verification")
		var material_samples: Array = []
		for surface: Dictionary in source.top_surfaces:
			var middle := (Vector2(float(surface.from[0]),float(surface.from[1]))+Vector2(float(surface.to[0]),float(surface.to[1])))*.5
			var found_solid_pixel := false
			var pixels: Array = []
			for depth: float in [2.0,6.0,10.0]:
				var pixel := world_to_source_pixel(instance,middle+Vector2(0,depth))
				var inside := pixel.x>=0 and pixel.y>=0 and pixel.x<image.get_width() and pixel.y<image.get_height()
				var opacity := image.get_pixel(int(pixel.x),int(pixel.y)).a if inside else 0.0
				pixels.append([pixel.x,pixel.y,opacity])
				if opacity>.95: found_solid_pixel=true
			check(found_solid_pixel,"Actual standing contact has real opaque source material immediately below, not transparent Sprite bounds")
			material_samples.append(pixels)
		actual.installed_paint_diagnostics.append({"id":source.id,"max_source_collider_mismatch":max_mismatch,"contact_material_samples":material_samples,"source":frame.source_path,"uniform_scale":frame.uniform_scale})

	check(not actual.production_pool, "Experiment not added to formal pool")
	stage.queue_free()
	await process_frame
	await process_frame
	return actual

func verify_layout_reuse(plan: Dictionary, actual: Dictionary) -> void:
	# Exact four-image fingerprints from admitted first-sample main02 receipt,
	# 97703a8f. This scoped reuse experiment does not freeze future art globally.
	var first_sources: Dictionary = {
		"res://assets/visual_development/plains_world_rebuild/creek_bed_v3.png":"e6fc061529c850c200a847bf59c63798a870087c9d2744c06ed50da4205b9842",
		"res://assets/visual_development/plains_world_rebuild/environment_source.png":"782e81756e8b11d5557838818973c89f94e41393e599581608c56230a7aa97e6",
		"res://assets/visual_development/plains_world_rebuild/terrain_cliff_v2.png":"8b0e39bb1cb05f91501e6c3d121498b25d82c0f17725108853daae73d2056b5d",
		"res://assets/visual_development/plains_world_rebuild/terrain_east_v3.png":"703dfdbbadecc40965bb7d7cffa9477df1e4b7e23331a01a1c678e161425b131"
	}
	var consumed: Dictionary = {}
	for row: Dictionary in actual.painting.bodies: consumed[str(row.source)]=str(row.source_sha256)
	for row: Dictionary in actual.painting.layers:
		if row.has("source"): consumed[str(row.source)]=str(row.source_sha256)
	check(consumed==first_sources,"Second layout really consumes exactly the same four first-sample image bytes")
	for path: String in first_sources:
		check(FileAccess.get_sha256(path)==str(first_sources[path]),"Second structure has not silently painted a per-layout replacement image")
	var first: Dictionary = WORLD.generate("world-rebuild-01",0)
	check(first.validation_errors.is_empty(),"First registered layout remains legal after migration extension")
	var original: Array = first.routes[0].points
	var migrated: Array = plan.routes[0].points
	var first_profile: Array = []
	var migrated_profile: Array = []
	for p: Array in original:first_profile.append([float(p[0])-float(original[0][0]),float(p[1])-float(original[0][1])])
	for p: Array in migrated:migrated_profile.append([float(p[0])-float(migrated[0][0]),float(p[1])-float(migrated[0][1])])
	check(first_profile!=migrated_profile,"Actual second main route changes relative geometry rather than translating the first")
	var first_height := float(first.bodies[1].top_surfaces[0].from[1])-float(first.bodies[0].top_surfaces[-1].to[1])
	var second_height := float(plan.bodies[1].top_surfaces[0].from[1])-float(plan.bodies[0].top_surfaces[-1].to[1])
	check(absf(first_height-second_height)>=float(plan.player_source.body_size[1])*2,"Second structure changes relative rim height by at least two actual player heights")
	actual["reuse_comparison"]={"first_source_commit":"97703a8ff4ca9a86c7fb92ff2d182d0595ffce96","same_painting_sources":consumed,"first_relative_route":first_profile,"second_relative_route":migrated_profile,"first_relative_rim_height":first_height,"second_relative_rim_height":second_height,"scope":"Two explicit construction layouts; not random region or all-Seed quality"}

func run() -> void:
	var tuning := PlayerTuning.load_default()
	var generator := PlainsRegionGenerator.new()
	generator.root_bell_mode = "v3"
	var old := generator.generate(PlainsRegionCampaign.seed_for("joint-recoil-01", 1), tuning, false, "", "intro")
	check(old.get("ok", false) and old.manifest.manifest_hash == PRIOR_DEFAULT, "Original default Manifest exact baseline remains unchanged")
	var plan: Dictionary = WORLD.generate("world-rebuild-01", variant_id)
	check(not plan.has("error") and plan.validation_errors.is_empty(), "First world structure passes actual grammar")
	check(plan == WORLD.generate("world-rebuild-01", variant_id), "Same Seed replays complete world source")
	var replay: Dictionary = JSON.parse_string(JSON.stringify(plan))
	check(WORLD.validate(replay).is_empty(), "Ordinary JSON replay preserves accepted complete bodies: "+str(WORLD.validate(replay)))
	check(RandomStageGenerator.new()._canonical(plan) == RandomStageGenerator.new()._canonical(replay), "Ordinary JSON retains complete plan semantics")
	check(not plan.formal_pool and plan.variant == variant_id, "Explicit selected prototype remains outside formal pool")
	check(plan.bodies.size() == 3 and plan.interfaces.size() == 4, "Two complete ridges and common foundation own explicit extension/root interfaces")
	for body: Dictionary in plan.bodies:
		check(body.collision_source == "polygon" and body.painting_source == "paint_frame", "Physics polygon and direct painting frame share the registered source")
		check(not Geometry2D.triangulate_polygon(packed(body.polygon)).is_empty(), "Complete irregular body triangulates")
		check(body.polygon.size() > 4 or body.id == "creek_foundation", "Ridges carry shaped complete volume rather than slab plus alpha skirt")
	verify_negative(plan)
	var actual: Dictionary = await verify_stage(plan, tuning)
	if variant_id==1: verify_layout_reuse(plan,actual)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null: check(false, "Native evidence can be preserved")
	else:
		file.store_string(JSON.stringify({"assertions": assertions, "failures": failures, "source_plan": plan, "actual": actual}) + "\n")
		file.close()
	print("PLAINS WORLD REBUILD: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

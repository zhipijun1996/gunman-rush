extends SceneTree
## Complete-world source and real installed consumer; not artistic admission.
const WORLD := preload("res://scripts/generation/plains_world_rebuild.gd")
const STAGE := preload("res://scripts/demo/plains_world_rebuild_stage.gd")
const PRIOR_DEFAULT := "98a71fc9d52471dfbc8ec6b25dfb09d1a1326d158cd9dbc71367966ef0ec2a51"
var assertions := 0
var failures: Array[String] = []
var output_path := ""

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		print("WORLD REBUILD FAILURE: ", label)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
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
	check(WORLD.generate("world-rebuild-01", -1).has("error"), "Negative structure variant refused")
	check(WORLD.generate("world-rebuild-01", 2).has("error"), "Unregistered second-plus structure refused")

func verify_stage(plan: Dictionary, tuning: PlayerTuning) -> Dictionary:
	var stage := STAGE.new() as PlainsWorldRebuildStage
	stage.configure_world(plan, tuning)
	root.add_child(stage)
	await physics_frame
	await process_frame
	var actual := stage.get_world_rebuild_snapshot()
	check(actual.ready, "Actual new stage assembles")
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

	check(actual.actual_enemies == plan.enemy_spawns.size(), "Existing enemy contract really instantiated")
	check(not actual.painting.is_empty(), "Actual painting consumer supplies measured evidence")
	var composer: Node2D = stage.world_composer
	for source: Dictionary in plan.bodies:
		var instance: MeshInstance2D = composer.get_node(str(source.id).validate_node_name()+"CompletePainting") as MeshInstance2D
		check(instance != null and instance.mesh != null, "Actual painted mesh exists for complete source body")
		if instance == null or instance.mesh == null: continue
		var receipt: Dictionary = {}
		for row: Dictionary in actual.painting.bodies:
			if str(row.id) == str(source.id): receipt = row; break
		check(not receipt.is_empty() and receipt.world_polygon == source.polygon, "Measured painter binds same complete polygon as actual collider")
		check(instance.texture != null and instance.texture.resource_path == str(receipt.source), "Actual mesh uses measured real image resource")
		check(FileAccess.get_sha256(str(receipt.source)) == str(receipt.source_sha256), "Actual painting bytes match receipt")
		check(FileAccess.get_sha256(str(receipt.mapping_source)) == str(receipt.mapping_sha256), "Actual source-coordinate mapping bytes match receipt")
		check(instance.material is ShaderMaterial, "Complete-body consumer really installs its declared opaque material")
		var surface_arrays: Array = instance.mesh.surface_get_arrays(0)
		var vertices: PackedVector2Array = surface_arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = surface_arrays[Mesh.ARRAY_TEX_UV]
		check(vertices.size() == int(receipt.mesh_vertices) and vertices.size()%3 == 0 and uvs.size() == vertices.size(), "Actual installed mesh triangle/UV counts match measured painter")
		var body_polygon := packed(source.polygon)
		var actual_area := 0.0
		var expected_area := 0.0
		for index: int in body_polygon.size():
			expected_area += body_polygon[index].cross(body_polygon[(index+1)%body_polygon.size()])*.5
		for index: int in range(0,vertices.size(),3):
			actual_area += absf((vertices[index+1]-vertices[index]).cross(vertices[index+2]-vertices[index]))*.5
			var middle := (vertices[index]+vertices[index+1]+vertices[index+2])/3.0
			check(Geometry2D.is_point_in_polygon(middle,body_polygon), "Installed painted triangle lies inside actual shared solid")
		check(absf(actual_area-absf(expected_area)) < .1, "Installed painting covers complete solid area without missing shoulders or root volume")
		var all_uvs_valid := true
		for uv: Vector2 in uvs:
			if not uv.is_finite() or uv.x<0 or uv.x>1 or uv.y<0 or uv.y>1: all_uvs_valid = false
		check(all_uvs_valid, "Actual source UVs stay finite and inside real material image")
		var density := float(receipt.get("source_pixels_per_world_unit",0))
		check(density>0 and not receipt.get("body_width_normalized",true) and not receipt.get("body_depth_normalized",true), "Consumer declares fixed world painting scale rather than whole-body normalization")
		if str(source.kind) == "creek_bedrock":
			var center := (float(plan.bodies[0].top_surfaces[-1].to[0])+float(plan.bodies[1].top_surfaces[0].from[0]))*.5
			var rim_top := float(plan.bodies[0].top_surfaces[-1].to[1])
			var fixed_density_matches := true
			for index: int in vertices.size():
				var expected_uv := Vector2((800+(vertices[index].x-center)*density)/1536.0,(190+(vertices[index].y-rim_top)*density)/1024.0)
				if uvs[index].distance_to(expected_uv)>.00001: fixed_density_matches = false
			check(fixed_density_matches, "Actual foundation mesh consumes same fixed source-pixel/world density on both axes")
		else:
			var sample_x := float(source.top_surfaces[-1].to[0])-160 if str(source.id)=="west_meadow_ridge" else float(source.top_surfaces[0].from[0])+160
			var sample_y := float(source.top_surfaces[-1].to[1])+80 if str(source.id)=="west_meadow_ridge" else float(source.top_surfaces[0].from[1])+80
			var sample := Vector2(sample_x,sample_y)
			var first_uv: Vector2 = composer.call("_source_uv",source,sample,-240.0,3000.0,1200.0)
			var changed_bounds_uv: Vector2 = composer.call("_source_uv",source,sample,-1240.0,9000.0,4200.0)
			check(first_uv == changed_bounds_uv, "Changing overall width/depth arguments cannot rescale local painted bank material")

	check(not actual.production_pool, "Experiment not added to formal pool")
	stage.queue_free()
	await process_frame
	await process_frame
	return actual

func run() -> void:
	var tuning := PlayerTuning.load_default()
	var generator := PlainsRegionGenerator.new()
	generator.root_bell_mode = "v3"
	var old := generator.generate(PlainsRegionCampaign.seed_for("joint-recoil-01", 1), tuning, false, "", "intro")
	check(old.get("ok", false) and old.manifest.manifest_hash == PRIOR_DEFAULT, "Original default Manifest exact baseline remains unchanged")
	var plan: Dictionary = WORLD.generate("world-rebuild-01", 0)
	check(not plan.has("error") and plan.validation_errors.is_empty(), "First world structure passes actual grammar")
	check(plan == WORLD.generate("world-rebuild-01", 0), "Same Seed replays complete world source")
	var replay: Dictionary = JSON.parse_string(JSON.stringify(plan))
	check(WORLD.validate(replay).is_empty(), "Ordinary JSON replay preserves accepted complete bodies")
	check(RandomStageGenerator.new()._canonical(plan) == RandomStageGenerator.new()._canonical(replay), "Ordinary JSON retains complete plan semantics")
	check(not plan.formal_pool and plan.variant == 0, "First candidate isolated and second layout not expanded")
	check(plan.bodies.size() == 3 and plan.interfaces.size() == 4, "Two complete ridges and common foundation own explicit extension/root interfaces")
	for body: Dictionary in plan.bodies:
		check(body.collision_source == "polygon" and body.painting_source == "polygon", "Physics and painting both consume complete same source")
		check(not Geometry2D.triangulate_polygon(packed(body.polygon)).is_empty(), "Complete irregular body triangulates")
		check(body.polygon.size() > 4 or body.kind == "creek_bedrock", "Ridges carry shaped complete volume rather than slab plus alpha skirt")
	verify_negative(plan)
	var actual: Dictionary = await verify_stage(plan, tuning)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null: check(false, "Native evidence can be preserved")
	else:
		file.store_string(JSON.stringify({"assertions": assertions, "failures": failures, "source_plan": plan, "actual": actual}) + "\n")
		file.close()
	print("PLAINS WORLD REBUILD: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

extends SceneTree
## Technical fixtures are not live-route, enemy-state or visual acceptance.
var assertions := 0
var failures := 0
var app: DemoApp
var observations: Array[Dictionary] = []
var output := ""
var deliberate_floating := false
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg == "--deliberate-floating-prop=20": deliberate_floating = true
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func frames(count: int) -> void:
	for unused: int in count: await physics_frame
func values_rect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])
func has_physics(node: Node) -> bool:
	if node is CollisionObject2D or node is CollisionShape2D or node is CollisionPolygon2D: return true
	for child: Node in node.get_children():
		if has_physics(child): return true
	return false
func valid_item(item: Dictionary, supports: Array[Rect2], blocked: Array[Rect2]) -> bool:
	var support := values_rect(item.support)
	var bounds := values_rect(item.display_bounds)
	if not support in supports or absf(bounds.end.y - support.position.y) > 0.01: return false
	if bounds.position.x < support.position.x or bounds.end.x > support.end.x: return false
	if str(item.asset_id) not in ["ruin_arch", "stones"]: return false
	return not blocked.any(func(r: Rect2): return r.intersects(bounds.grow(8)))
func run() -> void:
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("level-design-v2-baseline"), "real formal DemoApp starts")
	await frames(8)
	var stage := app.stage as PlainsRegionStage
	check(stage != null and stage.assembly_ok, "formal PlainsRegionStage assembly")
	if stage == null:
		finish()
		return
	# Freeze this fixture after actual setup. Natural AI/routes are tested separately.
	paused = true
	var scenery: PlainsRegionScenery
	for child: Node in stage.get_children():
		if child is PlainsRegionScenery: scenery = child
	check(scenery != null, "actual formal scenery consumer installed")
	if scenery == null:
		finish()
		return
	var geometry_before := JSON.stringify(stage.generated.manifest)
	var rng_before := app.director.manifest.canonical_json()
	var plan := scenery.presentation_manifest
	check(plan.items.size() == 2, "golden must contain both real identities, all omitted cannot pass")
	check(not has_physics(scenery), "actual landmark subtree has no collision/physics")
	var silhouettes: Array[String] = []
	var actual_sprites: Array[Dictionary] = []
	for item: Dictionary in plan.items:
		silhouettes.append(str(item.asset_id))
		check(valid_item(item, scenery.supports, scenery.protected_regions), "full graphic width grounded and clear: " + str(item.area_id))
		var child := scenery.get_node("Landmark_" + str(item.area_id)) as Sprite2D
		check(child != null and child.texture is AtlasTexture and child.get_meta("landmark") == item, "actual texture and plan binding: " + str(item.area_id))
		if deliberate_floating and actual_sprites.is_empty(): child.position.y -= 20
		var actual_bounds := Rect2(child.global_position, child.texture.get_size() * child.global_scale)
		var actual_foot := Vector2(actual_bounds.get_center().x, actual_bounds.end.y)
		check(actual_bounds.is_equal_approx(values_rect(item.display_bounds)), "actual sprite position/scale match displayed metadata: " + str(item.area_id))
		check(actual_foot.is_equal_approx(Vector2(item.foot[0], item.foot[1])), "actual sprite bottom matches support foot: " + str(item.area_id))
		actual_sprites.append({"area_id": item.area_id, "display_bounds": PlainsRegionScenery.rect_values(actual_bounds), "foot": [actual_foot.x, actual_foot.y]})
		var ray := PhysicsRayQueryParameters2D.create(actual_foot - Vector2(0, 1), actual_foot + Vector2(0, 3), 1)
		var hit := stage.get_world_2d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider is StaticBody2D, "real collision exists immediately below foot: " + str(item.area_id))
		var invalid := item.duplicate(true)
		invalid.display_bounds[1] -= 20
		check(not valid_item(invalid, scenery.supports, scenery.protected_regions), "deliberate floating consumer rejected")
		invalid = item.duplicate(true)
		invalid.support = [item.foot[0] - 100, item.foot[1], 200, 32]
		check(not valid_item(invalid, scenery.supports, scenery.protected_regions), "invented / one-way-only support rejected")
		var obstructed: Array[Rect2] = [values_rect(item.display_bounds)]
		check(not valid_item(item, scenery.supports, obstructed), "deliberate protected target overlap rejected")
	check("ruin_arch" in silhouettes and "stones" in silhouettes, "arch and low stones remain semantically distinct")
	var a: Dictionary = plan.items.filter(func(item: Dictionary): return item.area_id == "area_0_1")[0] if plan.items.any(func(item: Dictionary): return item.area_id == "area_0_1") else {}
	var b: Dictionary = plan.items.filter(func(item: Dictionary): return item.area_id == "area_1_0")[0] if plan.items.any(func(item: Dictionary): return item.area_id == "area_1_0") else {}
	check(not a.is_empty() and a.asset_id == "ruin_arch", "golden A clock court is arch")
	check(not b.is_empty() and b.asset_id == "stones", "golden B creek return is low stones")
	if not a.is_empty(): check(a.support == [200.0, 18.0, 280.0, 40.0], "A uses existing adjacent well solid")
	if not b.is_empty(): check(b.support == [1600.0, -682.0, 640.0, 32.0], "B uses thin existing solid, not junction one-way")
	var empty_supports: Array[Rect2] = []
	var no_support := PlainsRegionScenery.plan(stage.generated.manifest, empty_supports, scenery.protected_regions)
	check(no_support.items.is_empty() and not no_support.omitted.is_empty(), "deliberate unsupported scene omits explicitly")
	var all_blocked: Array[Rect2] = [stage.bounds]
	check(PlainsRegionScenery.plan(stage.generated.manifest, scenery.supports, all_blocked).items.is_empty(), "deliberate all-clearance failure cannot create props")
	var unsupported: Dictionary = stage.generated.manifest.duplicate(true)
	for area: Dictionary in unsupported.areas: area.landmark = "windchime"
	check(PlainsRegionScenery.plan(unsupported, scenery.supports, scenery.protected_regions).items.is_empty(), "unsupported identity never folds into fake interactive bells or repeated arch")
	var again := PlainsRegionScenery.plan(stage.generated.manifest, scenery.supports, scenery.protected_regions)
	check(again == plan, "presentation repeat deterministic")
	check(JSON.stringify(stage.generated.manifest) == geometry_before, "complete manifest geometry/interactables unchanged")
	check(app.director.manifest.canonical_json() == rng_before, "run manifest and RNG positions unchanged by planning")
	observations.append({"seed": "level-design-v2-baseline", "map": 1, "fixture": "actual DemoApp setup paused for technical assertions, not live enemy acceptance", "plan": plan, "actual_sprites": actual_sprites, "assertions": assertions, "failures": failures})
	finish()
func finish() -> void:
	if output.is_empty() or FileAccess.file_exists(output):
		printerr("Unique --output is required; prior evidence must not be overwritten")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		failures += 1
	else:
		file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "scope": "technical golden and deliberately rejected fixtures; live routes/visual/device separate", "observations": observations, "assertions": assertions, "failures": failures}) + "\n")
		file.close()
	if is_instance_valid(app): app.free()
	if deliberate_floating and failures == 3: print("PLAINS AUTONOMY NEGATIVE: actual sprite floating rejected by bounds, foot and collider")
	print("PLAINS AUTONOMY GOLDEN: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Calls the actual candidate generator/validator. No capture, art or traversal claim.
const Plan = preload("res://game/world/generation/plains_place_plan.gd")
const SEEDS := ["places-contract-01", "places-contract-02", "places-contract-03", "places-contract-04", "places-contract-05", "places-contract-06", "places-contract-07", "places-contract-08", "places-contract-09", "places-contract-10", "places-contract-11", "places-contract-12"]
var assertions := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		print("PLACE CONTRACT FAILURE: " + message)

func local_terrain(plan: Dictionary) -> Array:
	var result: Array = []
	for instance: Dictionary in plan.place_instances:
		var polygons: Array = []
		var delta := Vector2(instance.translation[0], instance.translation[1])
		for solid: Dictionary in plan.solid_polygons:
			if solid.place_id != instance.id: continue
			var points: Array = []
			for raw: Array in solid.points:
				points.append([float(raw[0]) - delta.x, float(raw[1]) - delta.y])
			polygons.append(points)
		result.append(polygons)
	return result

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var tuning := PlayerTuning.load_default()
	var actual: Array = []
	var orders: Dictionary = {}
	var geometries: Dictionary = {}
	var first: Dictionary = {}
	for seed_value: String in SEEDS:
		var result: Dictionary = Plan.generate(seed_value, tuning)
		check(result.get("ok", false), seed_value + ": actual generation succeeds: " + str(result.get("error", "")))
		if not result.get("ok", false): continue
		var manifest: Dictionary = result.manifest
		var plan: Dictionary = result.environment_plan
		if first.is_empty(): first = manifest.duplicate(true)
		check(result.attempts >= 1 and result.attempts <= Plan.ATTEMPTS, seed_value + ": bounded attempts")
		check(Plan.generate(seed_value, tuning).get("manifest", {}) == manifest, seed_value + ": exact deterministic replay")
		check(Plan.validate_recorded(manifest, tuning), seed_value + ": recorded consumer accepts actual generation")
		check(plan.generation.fallback_id == "", seed_value + ": no unverified fallback")
		check(plan.connections.size() == 2, seed_value + ": two actual connecting edges")
		var profile_consistent := true
		for body: Dictionary in plan.terrain_instances:
			var solid: Dictionary = {}
			for candidate: Dictionary in plan.solid_polygons:
				if candidate.id == body.solid_id: solid = candidate
			if solid.is_empty():
				profile_consistent = false
				continue
			for i: int in body.source_profile_px.size():
				var source := Vector2(body.source_profile_px[i][0], body.source_profile_px[i][1])
				var source_anchor := Vector2(body.source_anchor_px[0], body.source_anchor_px[1])
				var world_anchor := Vector2(body.world_anchor[0], body.world_anchor[1])
				var collision := Vector2(solid.points[i][0], solid.points[i][1])
				profile_consistent = profile_consistent and collision.distance_to(world_anchor + (source - source_anchor) * float(body.uniform_scale)) < 0.01
		check(profile_consistent, seed_value + ": source painting transform and actual standing collision coincide")
		check(plan.get("joint_synthesis", {}).get("same_source_contract", false), seed_value + ": actual plan declares shared synthesis source")
		var focus_matches := true
		var layers_match := true
		for place: Dictionary in plan.places:
			for focal: Dictionary in place.focal_anchors:
				if not focal.has("attachment_id"): continue
				var found := false
				for attachment: Dictionary in plan.attachments:
					if attachment.id != str(place.id) + "/" + str(focal.attachment_id): continue
					found = true
					focus_matches = focus_matches and Vector2(focal.position[0], focal.position[1]).distance_to(Vector2(attachment.position[0], attachment.position[1])) < 0.01
				focus_matches = focus_matches and found
			for anchor: Dictionary in place.layer_anchors:
				var found := false
				for layer: Dictionary in plan.layer_instances:
					if str(layer.id) + "/anchor" != str(anchor.id): continue
					found = true
					var camera := Vector2(place.composition.camera_center[0], place.composition.camera_center[1])
					var reference := Vector2(layer.camera_reference[0], layer.camera_reference[1])
					var displayed_layer_anchor := Vector2(layer.world_anchor[0], layer.world_anchor[1]) + (camera - reference) * (1.0 - float(layer.depth_factor))
					layers_match = layers_match and displayed_layer_anchor.distance_to(Vector2(anchor.position[0], anchor.position[1])) < 0.01
				layers_match = layers_match and found
		check(focus_matches, seed_value + ": focal intent follows actual attachment root, not stale independent coordinates")
		check(layers_match, seed_value + ": shared parallax resolves to source-relative scene anchor at intended camera")
		orders[JSON.stringify(plan.prototype_order)] = true
		# Compare actual resolved points/translations, not names or manifest hashes.
		var shape := {"solids": plan.solid_polygons, "instances": plan.place_instances.map(func(item: Dictionary) -> Variant: return item.translation), "connections": plan.connections}
		geometries[JSON.stringify(shape, "", true)] = true
		actual.append({"seed":seed_value,"prototype_order":plan.prototype_order,"place_instances":plan.place_instances,"connections":plan.connections,"attempts":result.attempts,"rejections":result.rejections,"local_terrain":local_terrain(plan)})
	check(orders.size() > 1, "preregistered seeds resolve different actual orders")
	check(geometries.size() > 1, "preregistered seeds resolve different actual geometry")
	if not first.is_empty():
		var tampered := first.duplicate(true)
		tampered.environment_plan.solid_polygons[0].points[0][0] += 7.0
		# Rehashing must not legitimize altered geometry: replay is authoritative.
		tampered.manifest_hash = PlainsEnvironmentPlan._hash(tampered)
		check(not Plan.validate_recorded(tampered, tuning), "rehash does not admit altered geometry")
		tampered = first.duplicate(true)
		tampered.manifest_hash = "unrecorded"
		check(not Plan.validate_recorded(tampered, tuning), "altered manifest hash rejected")
		tampered = first.duplicate(true)
		tampered.environment_plan.place_instances[0].source_measurement_sha256 = "0".repeat(64)
		tampered.manifest_hash = PlainsEnvironmentPlan._hash(tampered)
		check(not Plan.validate_recorded(tampered, tuning), "rehash does not admit altered source measurement")
		# Change the visual transform independently, not merely a manifest label.
		var shifted_body: Dictionary = first.environment_plan.terrain_instances[0].duplicate(true)
		shifted_body.world_anchor[1] += 8.0
		check(not Plan._body_errors(shifted_body, first.environment_plan.solid_polygons).is_empty(), "visual anchor drift from actual standing collision rejected")
		var shifted_solids: Array = first.environment_plan.solid_polygons.duplicate(true)
		for solid: Dictionary in shifted_solids:
			if solid.id == shifted_body.solid_id:
				solid.points[1][1] += 12.0
		check(not Plan._body_errors(first.environment_plan.terrain_instances[0], shifted_solids).is_empty(), "single landing contour drift from actual painted source rejected")
	for mutation: String in ["missing-body-art", "invalid-scale", "break-port", "overlap-places", "source-sha-mismatch", "composition-blocked"]:
		var rejected: Dictionary = Plan.generate(SEEDS[0], tuning, "seeded", mutation)
		check(not rejected.get("ok", false), mutation + ": actual consumer rejects")
		check(rejected.get("attempts", -1) == Plan.ATTEMPTS, mutation + ": actual bounded retries exhausted")
		check(rejected.get("rejections", []).size() == Plan.ATTEMPTS, mutation + ": every rejection preserved")
		for rejection: Dictionary in rejected.get("rejections", []):
			check(not str(rejection.get("reason", "")).is_empty(), mutation + ": explicit refusal reason")
	# Exercise the same catalog preflight used by generate, without altering disk.
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(Plan.CONTRACT_PATH))
	check(catalog is Dictionary, "actual catalog readable")
	if catalog is Dictionary:
		check(Plan._catalog_errors(catalog).is_empty(), "actual catalog preflight accepted")
		for fault: String in ["unmeasured", "span", "scale", "source"]:
			var damaged: Dictionary = catalog.duplicate(true)
			var prototype: Dictionary = damaged.prototypes.wind_meadow
			match fault:
				"unmeasured": prototype.erase("joint_synthesis")
				"span": damaged.connection_recipes[0].gap_world = 999.0
				"scale": prototype.joint_synthesis.variants[0].scales.meadow_bank = 2.0
				"source": damaged.source_families.whole_bank.texture = "res://not-a-measured-place.png"
			check(not Plan._catalog_errors(damaged).is_empty(), fault + ": actual preflight refuses invalid catalog")
	var report := {"scope":"Actual generation/replay/refusal only; no Motor, art or formal admission", "preregistered_seeds":SEEDS,"actual":actual,"different_orders":orders.size(),"different_geometries":geometries.size(),"assertions":assertions,"failures":failures}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
			if file == null:
				check(false, "cannot write actual report")
			else:
				file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PLAINS PLACES CONTRACT: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

extends SceneTree
## Calls the actual candidate generator/validator. No capture, art or traversal claim.
const Plan = preload("res://scripts/generation/plains_place_plan.gd")
const SEEDS := ["places-contract-01", "places-contract-02", "places-contract-03", "places-contract-04", "places-contract-05", "places-contract-06", "places-contract-07", "places-contract-08", "places-contract-09", "places-contract-10", "places-contract-11", "places-contract-12"]
var assertions := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		print("PLACE CONTRACT FAILURE: " + message)

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
		orders[JSON.stringify(plan.prototype_order)] = true
		# Compare actual resolved points/translations, not names or manifest hashes.
		var shape := {"solids": plan.solid_polygons, "instances": plan.place_instances.map(func(item: Dictionary) -> Variant: return item.translation), "connections": plan.connections}
		geometries[JSON.stringify(shape, "", true)] = true
		actual.append({"seed":seed_value,"prototype_order":plan.prototype_order,"place_instances":plan.place_instances,"connections":plan.connections,"attempts":result.attempts,"rejections":result.rejections})
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
	for mutation: String in ["missing-body-art", "invalid-scale", "break-port", "overlap-places", "source-sha-mismatch"]:
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
				"unmeasured": prototype.erase("measurement")
				"span": damaged.connection_recipes[0].gap_world = 999.0
				"scale": prototype.measurement.terrain_instances[0].uniform_scale = 2.0
				"source": prototype.measurement.terrain_instances[0].texture = "res://not-a-measured-place.png"
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

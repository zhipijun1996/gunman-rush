extends SceneTree
## Actual complete formal generator + art compiler; not Motor or art admission.
const Plan = preload("res://scripts/generation/plains_region_art_plan.gd")
const ROOT_SEEDS := ["regional-art-01","regional-art-02","regional-art-03","regional-art-04","regional-art-05","regional-art-06"]
var assertions := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures.append(label);print("REGIONAL CONTRACT FAILURE: ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var baseline_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-script="): baseline_path = arg.trim_prefix("--baseline-script=")
	var baseline_script: Script = load(baseline_path) as Script if not baseline_path.is_empty() else null
	var tuning := PlayerTuning.load_default()
	var rows: Array = []
	var first: Dictionary = {}
	for root_seed: String in ROOT_SEEDS:
		var seed_value := PlainsRegionCampaign.seed_for(root_seed,1)
		var result := Plan.generate(seed_value,tuning)
		check(result.get("ok",false),root_seed+": full formal generation+art compile")
		if not result.get("ok",false): continue
		var manifest: Dictionary = result.manifest
		var plan: Dictionary = result.regional_art_plan
		if first.is_empty(): first = result.duplicate(true)
		check(not manifest.sample and manifest.layout_id=="connected_region" and manifest.areas.size()>=15,root_seed+": actual full map, not places chain")
		check(PlainsRegionGenerator.new().validate(manifest,tuning),root_seed+": original physics/topology validator")
		check(Plan.validate_recorded(plan,manifest),root_seed+": exact authoritative art replay")
		check(Plan.generate(seed_value,tuning)==result,root_seed+": exact seeded determinism")
		check(plan.generation.attempt>=0 and plan.generation.attempt<Plan.ATTEMPTS and plan.generation.fallback_id=="",root_seed+": bounded candidates, no unverified fallback")
		check(not plan.production_pool and plan.layout_source=="formal_full_region",root_seed+": explicitly isolated full formal consumer")
		var original := PlainsRegionGenerator.new()
		original.root_bell_mode = "v3"
		original.regional_art_profile = "continuous_plains_v1"
		var raw := original._candidate(seed_value,false,"",int(plan.generation.attempt),"intro")
		check(raw==manifest,root_seed+": art-profile formal geometry/content/resources consumed exactly")
		var columns: Array = manifest.topology.column_positions
		var layout_valid: bool = manifest.regional_art_profile=="continuous_plains_v1"
		for i: int in range(1,columns.size()): layout_valid = layout_valid and float(columns[i])-float(columns[i-1])>=1400.0
		for edge: Dictionary in manifest.connections:
			if edge.kind=="horizontal": layout_valid = layout_valid and float(edge.art_clearance.quiet_arrival_width)==180.0
		check(layout_valid,root_seed+": art clearance participates before actual world embedding")
		var voids_preserved := true
		for support: Array in manifest.ground_supports:
			var body := Rect2(support[0],support[1],support[2],support[3])
			for space: Dictionary in manifest.art_layout.get("protected_airspaces",[]):
				var r: Array = space.rect
				voids_preserved = voids_preserved and not body.intersects(Rect2(r[0],r[1],r[2],r[3]))
		check(voids_preserved,root_seed+": no new mass intersects original gap/shaft fall columns")
		check(manifest.art_layout.get("landmass_method","")=="world_base_mass_minus_actual_lower_route_voids_v2",root_seed+": fullmass method actually consumed")
		var known_solid_ids: Array = []
		for solid: Dictionary in plan.solids: known_solid_ids.append(str(solid.id))
		check(known_solid_ids.size()==plan.solids.size(),root_seed+": actual source solid corpus")
		check(not plan.terrain_edges.is_empty() and not plan.surfaces.is_empty(),root_seed+": actual exposed union boundaries and surfaces")
		var belts_valid: bool = plan.layer_belts.size()>=3
		for belt: Dictionary in plan.layer_belts:
			belts_valid = belts_valid and not belt.reset_per_place and belt.world_polyline.size()>=3
		check(belts_valid,root_seed+": continuous world-space scene belts")
		rows.append({"root_seed":root_seed,"seed":seed_value,"manifest":manifest,"plan":plan})
	if not first.is_empty():
		var plan: Dictionary = first.regional_art_plan
		for mutation: String in ["geometry","layer","landmark","topology"]:
			var damaged: Dictionary = plan.duplicate(true)
			match mutation:
				"geometry": damaged.solids[0].rect[2] += 17.0
				"layer": damaged.layer_belts[0].reset_per_place = true
				"landmark": damaged.landmarks[0].position[0] += 50.0
				"topology": damaged.topology.connections.remove_at(0)
			damaged.plan_hash = Plan.plan_hash(damaged)
			check(not Plan.validate_recorded(damaged,first.manifest),"Rehashed "+mutation+" drift rejected")
		var sample: Dictionary = first.manifest.duplicate(true)
		sample.sample = true
		check(not Plan.compile(sample).ok,"Small sample cannot masquerade full region")
		var oversized: Dictionary = first.manifest.duplicate(true)
		oversized.world_bounds[2] = Plan.MAX_WORLD_WIDTH + 1.0
		check(not Plan.compile(oversized).ok,"Art projection budget rejects unexpressible extent")
	var legacy := PlainsRegionGenerator.new()
	legacy.root_bell_mode = "v3"
	var legacy_manifest := legacy._candidate(PlainsRegionCampaign.seed_for(ROOT_SEEDS[0],1),false,"",0,"intro")
	check(not legacy_manifest.has("regional_art_profile") and not legacy_manifest.has("art_layout"),"Default formal candidate does not inherit opt-in art profile")
	check(not Plan.compile(legacy_manifest).ok,"Post-hoc wrapping an unconstrained legacy map is rejected")
	legacy.regional_art_profile = "unknown_profile"
	check(not legacy.generate(ROOT_SEEDS[0],tuning).get("ok",false),"Unknown art profile refused")
	if baseline_script!=null:
		for root_seed: String in ROOT_SEEDS:
			var baseline: RefCounted = baseline_script.new()
			baseline.set("root_bell_mode","v3")
			var expected: Dictionary = baseline.call("_candidate",PlainsRegionCampaign.seed_for(root_seed,1),false,"",0,"intro")
			var current := PlainsRegionGenerator.new()
			current.root_bell_mode = "v3"
			check(current._candidate(PlainsRegionCampaign.seed_for(root_seed,1),false,"",0,"intro")==expected,root_seed+": default-profile full Manifest equals actual PR85 baseline")
	elif not baseline_path.is_empty(): check(false,"Cannot load actual PR85 baseline script")
	var union: Array = Plan._exposed_edges([{"id":"a","source_node":"a","rect":[0.0,0.0,100.0,80.0]},{"id":"b","source_node":"b","rect":[100.0,0.0,100.0,80.0]}])
	check(not union.any(func(e:Dictionary)->bool:return e.face in ["left","right"] and float(e.a[0])==100.0),"Touching solids eliminate internal vertical join")
	var report := {"scope":"Actual formal generation/replay/rejection/union, not gameplay or art acceptance","root_seeds":ROOT_SEEDS,"actual":rows,"assertions":assertions,"failures":failures}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			var file := FileAccess.open(arg.trim_prefix("--output="),FileAccess.WRITE)
			if file == null: check(false,"Cannot archive actual native corpus")
			else: file.store_string(JSON.stringify(report)+"\n")
	print("PLAINS REGIONAL ART CONTRACT: %d assertions, %d failures" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)

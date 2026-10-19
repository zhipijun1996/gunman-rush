extends SceneTree
## Actual producers/registry. These assertions do not claim Motor traversal.
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var output := "res://build/forest_revision03/contracts/report.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok: printerr("INTERWOVEN CONTRACT FAIL: " + label)
func edge(m: Dictionary, id: String) -> Dictionary:
	for row: Dictionary in m.connections:
		if row.id == id: return row
	return {}
func run() -> void:
	var tuning := PlayerTuning.load_default()
	var registry := ThornForestRegionGenerator.new()
	var modes: Dictionary = {}
	for index: int in 10:
		for map_index: int in [1,2]:
			var seed_value := ThornForestRegionGenerator.seed_for("forest-depth-hollow-%02d" % index,map_index)
			var capability := {"grapple":true,"abilities":["grapple"],"forest_layout_version":"forest-interwoven-canopy-v13"}
			var result := registry.generate(seed_value,tuning,map_index,capability)
			check(result.get("ok",false),"actual v13 producer / " + seed_value)
			if not result.get("ok",false): continue
			var m: Dictionary = result.manifest
			check(registry.validate(m,tuning) and ForestSceneLanguage.validate(m),"strict full manifest and every scene identity / " + seed_value)
			var old := ThornForestRegionV2.new().generate(seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"]})
			var pinned := registry.generate(seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"],"forest_layout_version":"forest-woven-trunk-v12"})
			check(RandomStageGenerator.new()._same_data(old,pinned),"old complete v12 producer remains pinned / " + seed_value)
			var expected_enemies: Array = old.manifest.enemies.duplicate(true)
			for enemy: Dictionary in expected_enemies:
				if str(enemy.id) == "hollow_route__inner_thread":
					enemy.position = [500.0,806.0]
					enemy.line_start = [470.0,802.0]
					enemy.line_end = [520.0,802.0]
					enemy.authored_body_sweep = [487.0,792.0,26.0,28.0]
			check(m.enemies == expected_enemies and m.rewards == old.manifest.rewards and m.enemy_drops == old.manifest.enemy_drops,"exact single guard occupancy relocation; every other enemy/stat/reward/drop unchanged / " + seed_value)
			check(m.enemies.size() == old.manifest.enemies.size(),"no enemy removed for the deep landing / " + seed_value)
			var destinations: Dictionary = {}
			for row: Dictionary in m.connections:
				if row.a in ["arrival","interwoven_inner"]:
					if not destinations.has(row.a): destinations[row.a] = {}
					destinations[row.a][row.b] = true
			check(destinations.get("arrival",{}).size() >= 2 and destinations.get("interwoven_inner",{}).size() >= 2,"two actual junctions with different destinations, not parallel labels / " + seed_value)
			check(not m.routes.fast.has("root_spiral_flight") and not m.routes.growth.has("root_spiral_flight") and edge(m,"root_spiral_flight").optional_skill_shortcut,"first four-action shaft is optional on ordinary routes / " + seed_value)
			check(m.routes.high_return.has("root_spiral_rest_flight"),"historical uninterrupted skill route remains available / " + seed_value)
			check(not edge(m,"crown_inner_return").is_empty() and not edge(m,"inner_bay_return").is_empty(),"explicit alternate return edges / " + seed_value)
			var mode: String = m.choices.interwoven_first_branch
			modes[mode] = true
			check(m.routes.fast.has("inner_thorn_HR") if mode == "inner" else m.routes.fast.has("upper_root_RH"),"seed changes consumed branch choice / " + seed_value)
			check(m.routes.growth.has("upper_root_RH") if mode == "inner" else m.routes.growth.has("inner_thorn_HR"),"alternate exploration strategy uses the other physical route / " + seed_value)
			var malformed: Dictionary = m.duplicate(true)
			malformed.hook_anchors[-1].position[0] += 50.0
			malformed.manifest_hash = ThornForestRegionV2V13._hash(malformed)
			check(not registry.validate(malformed,tuning),"coordinated rehashed anchor edit refused / " + seed_value)
			malformed = m.duplicate(true)
			edge(malformed,"inner_hollow_HH").action_program.remove_at(0)
			malformed.manifest_hash = ThornForestRegionV2V13._hash(malformed)
			check(not registry.validate(malformed,tuning),"coordinated rehashed missing action refused / " + seed_value)
			cases.append({"seed":seed_value,"map_index":map_index,"manifest_hash":m.manifest_hash,"branch":mode,"routes":m.routes.duplicate(true)})
	check(cases.size() == 20 and modes.size() == 2,"original ten roots and two maps include both branch choices")
	check(not registry.generate("invalid",tuning,1,{"grapple":true,"abilities":["grapple","double_jump"],"forest_layout_version":"forest-interwoven-canopy-v13"}).get("ok",false),"second movement ability cannot silently enter H-only forest")
	var failures := checks.filter(func(row: Dictionary) -> bool:return not row.passed).size()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"real20producer_contracts_not_Motor_or_fun","checks":checks,"cases":cases,"failures":failures})); file.close()
	print("FOREST INTERWOVEN CONTRACT: %s checks / %s failures" % [checks.size(),failures])
	quit(0 if failures == 0 else 1)

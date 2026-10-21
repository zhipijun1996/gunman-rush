extends SceneTree
## Producer and immutable replay evidence only; no claim of Motor feasibility.
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var output := "res://build/region_bible_v2/forest-world-contract/report.json"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok: printerr("FOREST BIBLE WORLD FAIL: "+label)
func run() -> void:
	var tuning := PlayerTuning.load_default()
	var registry := ThornForestRegionGenerator.new()
	var variants: Dictionary = {}
	var definitions: Dictionary = {}
	for index: int in 10:
		for map_index: int in [1,2]:
			var seed_value := registry.seed_for("forest-depth-hollow-%02d" % index,map_index)
			var result := registry.generate(seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"],"forest_layout_version":"forest-bible-world-v15"})
			check(result.get("ok",false),"actual v15 producer / "+seed_value)
			if not result.get("ok",false): continue
			var m: Dictionary = result.manifest
			var previous := ThornForestRegionV2V14.new().generate(seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"]})
			check(registry.validate(m,tuning) and ForestBibleV2Layout.validate(m),"complete strict reproducible world / "+seed_value)
			var old: Dictionary = previous.manifest
			for category: String in ["platforms","hook_anchors","enemies","rewards","geometry_instances"]:
				var retained := true
				for original: Dictionary in old[category]:
					var found := false
					for current: Dictionary in m[category]:
						if current.id == original.id: found = current == original; break
					retained = retained and found
				check(retained,"every inherited "+category+" remains exact / "+seed_value)
			var all_drops := true
			for enemy: Dictionary in m.enemies:
				var settled: Variant = m.enemy_drops.get(str(enemy.id))
				var legacy_no_drop: bool = settled is Dictionary and settled == {"kind":"none","amount":0} and str(enemy.id) != "bible_double_window_weaver"
				all_drops = all_drops and settled is Dictionary and not settled.is_empty() and (legacy_no_drop or (settled.get("enemy_id") == str(enemy.id) and settled.get("stream_namespace") == "enemy_drops"))
			check(all_drops,"every formal enemy has its own settled consumption row / "+seed_value)
			var old_drops_exact: bool = m.enemy_drops.size() == old.enemy_drops.size()+1
			for old_id: String in old.enemy_drops:
				old_drops_exact = old_drops_exact and m.enemy_drops.get(old_id) == old.enemy_drops[old_id]
			check(old_drops_exact,"every inherited drop unchanged; exactly one new enemy key / "+seed_value)
			var dropper := EnemyDropService.new()
			var configured := dropper.configure(str(m.seed),"thorn_forest/map_%s" % map_index)
			var independently_settled := dropper.settle(&"bible_double_window_weaver")
			check(configured and not independently_settled.is_empty() and m.enemy_drops.get("bible_double_window_weaver") == independently_settled,"new drop independently recomputed using per-enemy stream / "+seed_value)
			for route_name: String in ["fast","growth","high_return","change_mind","borer"]:
				check(m.routes[route_name] == old.routes[route_name],"old route program "+route_name+" unchanged / "+seed_value)
			var mode: String = m.choices.bible_root_connection
			variants[mode] = true
			var exit_edge := ThornForestRegionV2V10._edge_by_id(m,"bible_root_mouth_exit")
			check(exit_edge.b == ("R" if mode == "outer_root_east_mouth" else "D"),"actual receiver relation, independent of recommendation / "+seed_value)
			check(not ForestExpeditionLayout._platform_by_id(m,"bible_outer_step2").is_empty() if mode == "outer_root_east_mouth" else not ForestExpeditionLayout._platform_by_id(m,"bible_inner_step2").is_empty(),"exclusive physical mouth geometry / "+seed_value)
			check(ForestExpeditionLayout._platform_by_id(m,"bible_inner_step2").is_empty() if mode == "outer_root_east_mouth" else ForestExpeditionLayout._platform_by_id(m,"bible_outer_step2").is_empty(),"other mouth not merely a recommendation / "+seed_value)
			for row: Dictionary in m.forest_discoveries: definitions[row.definition_id] = true
			for mutation: String in ["reward","return_support","strand","gate","action","enemy_drop"]:
				var bad := m.duplicate(true)
				match mutation:
					"reward": bad.rewards.pop_back()
					"return_support": bad.platforms.pop_back()
					"strand": bad.enemies[-1].web_strands[0].end[0] += 80.0
					"gate": bad.forest_shortcuts[0].rect[3] = 0.0
					"action": ThornForestRegionV2V10._edge_by_id(bad,"bible_backbranch_flight").action_program.pop_back()
					"enemy_drop": bad.enemy_drops.erase("bible_double_window_weaver")
				bad.manifest_hash = ThornForestRegionV2V15._hash(bad)
				check(not registry.validate(bad,tuning),"rehashed "+mutation+" mutation rejected / "+seed_value)
			cases.append({"seed":seed_value,"map_index":map_index,"manifest_hash":m.manifest_hash,"variant":mode,"actual_receiver":exit_edge.b,"new_routes":m.routes.bible_backbranch_journey})
	check(cases.size() == 20 and variants.size() == 2,"ten roots/two maps cover both actual connections")
	check(definitions.size() == 6,"all six named discoveries have formal world rows")
	check(not registry.generate("invalid",tuning,1,{"grapple":true,"abilities":["grapple","double_jump"],"forest_layout_version":"forest-bible-world-v15"}).get("ok",false),"new world preserves H-only capability gate")
	var failures := checks.filter(func(row: Dictionary) -> bool: return not row.passed).size()
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"actual20_Bible_world_producers_not_Motor_or_art","checks":checks,"cases":cases,"failures":failures})); file.close()
	print("FOREST BIBLE WORLD CONTRACT: %s checks / %s failures" % [checks.size(),failures])
	quit(0 if failures == 0 else 1)

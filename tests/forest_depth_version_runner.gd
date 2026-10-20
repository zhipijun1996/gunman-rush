extends SceneTree
## Runtime version contracts only; not v2 route or Boss admission.
const LEGACY := preload("res://scripts/generation/thorn_forest_region_v1.gd")
# Independently selected v2 playtest-default contract; not production admission.
const EXPECTED_PUBLIC_DEFAULT := ThornForestRegionGenerator.DEPTH_VERSION
# Deliberate independent expectation; updated only after the candidate golden.
const EXPECTED_PUBLIC_LAYOUT := "forest-fruit-routes-v14"
var assertions := 0
var failures := 0
var cases: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var exit_weak_refs: Dictionary = {}
var exit_observations: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	checks.append({"label":label,"passed":ok})
	if not ok:
		failures += 1
		printerr("FOREST VERSION FAIL: "+label)
func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame
func run() -> void:
	var registry := ThornForestRegionGenerator.new()
	var old := LEGACY.new()
	var equality := RandomStageGenerator.new()
	var tuning := PlayerTuning.load_default()
	check(ThornForestRegionGenerator.VERSION == EXPECTED_PUBLIC_DEFAULT,"public default matches the independently selected version expectation")
	for root_seed: String in ["version-contract-00","version-contract-01","version-contract-02","version-contract-03"]:
		for map_index: int in [1,2]:
			var seed_value := LEGACY.seed_for(root_seed,map_index)
			var capabilities := {"grapple":true,"abilities":["grapple"]}
			var direct: Dictionary = old.generate(seed_value,tuning,map_index,capabilities)
			var explicit_legacy_capabilities: Dictionary=capabilities.duplicate(true)
			explicit_legacy_capabilities.forest_content_version=LEGACY.VERSION
			var delegated: Dictionary = registry.generate(seed_value,tuning,map_index,explicit_legacy_capabilities)
			var pinned: Dictionary = registry.generate_version(LEGACY.VERSION,seed_value,tuning,map_index,capabilities)
			check(direct.ok and delegated.ok and pinned.ok,"v1 generation succeeds "+seed_value)
			check(equality._same_data(direct,delegated) and equality._same_data(direct,pinned),"complete generated outputs exactly equal "+seed_value)
			check(registry.validate(direct.manifest,tuning) and old.validate(delegated.manifest,tuning),"both validators accept complete legacy output "+seed_value)
			# Public no-version API is a separate contract from immutable v1 replay.
			var public_default: Dictionary=registry.generate(seed_value,tuning,map_index,capabilities)
			var expected_default: Dictionary=registry.generate_version(EXPECTED_PUBLIC_DEFAULT,seed_value,tuning,map_index,capabilities)
			check(public_default.ok and expected_default.ok and public_default.manifest.version==EXPECTED_PUBLIC_DEFAULT and equality._same_data(public_default,expected_default),"unversioned API exactly uses expected public default "+seed_value)
			check(registry.validate(public_default.manifest,tuning),"public default complete manifest validates "+seed_value)
			var broken: Dictionary = direct.manifest.duplicate(true)
			broken.version = "unsupported-forest-version"
			check(not registry.validate(broken,tuning) and not old.validate(broken,tuning),"both validators refuse edited legacy version "+seed_value)
			cases.append({"id":"delegate","seed":seed_value,"map":map_index,"equal_complete_output":equality._same_data(direct,delegated) and equality._same_data(direct,pinned),"manifest":direct.manifest,"stage_generator_version":delegated.stage_generator_version,"enemy_version":delegated.encounter_plan.version})
	for unsupported: String in ["unknown", "thorn-forest-region-v999", ""]:
		var refused: Dictionary = registry.generate_version(unsupported,"version-invalid",tuning,1,{"grapple":true})
		check(not refused.ok and not refused.has("manifest"),"unsupported explicit version refuses without fallback: "+unsupported)
	var malformed: Dictionary = registry.generate("version-invalid",tuning,1,{"grapple":true,"forest_content_version":{"version":LEGACY.VERSION}})
	check(not malformed.ok,"malformed capability version does not become the default")
	var queen: Dictionary = registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,"version-queen-unimplemented",tuning,2,{"grapple":true,"abilities":["grapple"],"forest_layout_version":ThornForestRegionGenerator.DEPTH_LAYOUT_V9})
	check(queen.ok and queen.manifest.version==ThornForestRegionGenerator.DEPTH_VERSION and queen.manifest.map_index==2 and queen.production_pool==false and registry.validate(queen.manifest,tuning),"v2 map2 exposes exact technically valid experimental candidate without production/commercial admission")
	var queen_contract: Dictionary=queen.get("manifest",{}).get("boss_contract",{})
	check(queen_contract.get("version")=="forest-queen-weave-golden-v2" and queen_contract.get("boss_contract")=="queen-weave-region-experimental" and queen_contract.get("admission")=="experimental_whole_boss_pending" and queen_contract.get("entry_mapping",{}).get("new_high_bridge")==false,"v2 map2 retains exact pending whole-Boss admission and existing-floor connector")
	cases.append({"id":"v2_map2_experimental","ok":queen.ok,"returned_version":queen.get("manifest",{}).get("version",""),"production_pool":queen.get("production_pool"),"boss_contract":queen_contract.duplicate(true)})
	check_recorded_layouts(registry,tuning)
	check_canopy_contract(registry,tuning)
	check_expedition_contract(registry,tuning)
	check_vertical_contract(registry,tuning)
	check_recorded_expedition(registry,tuning)
	check_interwoven_contract(registry,tuning)
	check_fruit_contract(registry,tuning)
	for map_index: int in [1,2]:
		await app_case(map_index)
	# A bounded lifecycle hypothesis: the long async run() previously quit while
	# these local RefCounteds were still on its suspended coroutine stack.
	# Observe them weakly, release only runner-owned locals, then return before quit.
	exit_weak_refs={"registry":weakref(registry),"legacy":weakref(old),"equality":weakref(equality),"tuning":weakref(tuning),"tuning_script":weakref(tuning.get_script())}
	for label: String in exit_weak_refs:
		exit_observations[label]={"before_release_alive":is_instance_valid((exit_weak_refs[label] as WeakRef).get_ref())}
	registry=null
	old=null
	equality=null
	tuning=null
	deferred_finish.call_deferred()
func deferred_finish() -> void:
	# This callback runs only after run() has returned. No sleeps or retries.
	for label: String in exit_weak_refs:
		var alive := is_instance_valid((exit_weak_refs[label] as WeakRef).get_ref())
		exit_observations[label]["after_run_return_alive"]=alive
		if label!="tuning_script": check(not alive,"owned local released after run returns: "+label)
	var output := "res://build/forest_depth/versions/native/capture.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"capture_schema":6,"scope":"runtime version compatibility only; v2 gameplay not covered","assertions":assertions,"failures":failures,"engine":Engine.get_version_info(),"cases":cases,"checks":checks,"exit_lifecycle":exit_observations},"\t"))
	file.close()
	file=null
	print("FOREST DEPTH VERSIONS: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
func app_case(map_index: int) -> void:
	# Dynamic actual Node consumer avoids compiling App's typed graph into this
	# generator runner. All original checks/cases are forwarded by the helper.
	var helper: Node=load("res://tests/forest_depth_version_app_case.gd").new()
	helper.reporter=weakref(self)
	helper.legacy_version=LEGACY.VERSION
	root.add_child(helper)
	await helper.run(map_index)
	helper.free()

func check_recorded_layouts(registry: ThornForestRegionGenerator,tuning: PlayerTuning) -> void:
	# Expected outputs are extracted from actual old Motor captures, not generated
	# by either implementation under comparison. Their original hashes stay fixed.
	var fixtures := [
		{"file":"v7_root00_map2.json","sha256":"7c61e9c844c36d021630ae6614d5521b602fb49d8c43c17bcfe6e66e5b2499fd","layout":ThornForestRegionGenerator.DEPTH_LAYOUT_V7,"north":true},
		{"file":"v9_root00_map2_before_north.json","sha256":"843c85d5be23f04a340e0f8d604af48be7fa42c8c079b462112e33316bfecca6","layout":ThornForestRegionGenerator.DEPTH_LAYOUT_V9,"north":false}]
	for fixture: Dictionary in fixtures:
		var path: String="res://tests/fixtures/forest_recorded_layouts/"+fixture.file
		check(FileAccess.get_sha256(path)==fixture.sha256,"recorded original fixture bytes retained: "+fixture.file)
		var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var rebuilt := registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,original.seed,tuning,int(original.map_index),{"grapple":true,"abilities":["grapple"],"forest_layout_version":fixture.layout,"forest_v9_north_return":fixture.north})
		check(rebuilt.ok and RandomStageGenerator.new()._same_data(original,rebuilt.get("manifest",{})),"entire recorded layout rebuilt without rewriting hash: "+fixture.file)
		check(registry.validate(original,tuning),"strict validation accepts actual old layout: "+fixture.file)
		check(ThornForestRegionGenerator.boss_definition_path(original.version,2,original)=="res://resources/bosses/thorn_queen_v2.tres","recorded layout retains original Boss: "+fixture.file)
		var edited := original.duplicate(true)
		edited.boss_content={"contract":"forest-queen-canopy-v3","scene":"res://scenes/bosses/thorn_queen_canopy.tscn","resource":"res://resources/bosses/thorn_queen_canopy.tres"}
		edited.manifest_hash=ThornForestRegionGenerator._hash(edited)
		check(not registry.validate(edited,tuning) and ThornForestRegionGenerator.boss_scene_path(original.version,2,edited).is_empty(),"rehashing cannot promote recorded map into a different Boss: "+fixture.file)
		cases.append({"id":"recorded_depth_layout","fixture":fixture.file,"fixture_sha256":FileAccess.get_sha256(path),"original":original,"rebuilt":rebuilt.get("manifest",{}),"boss_resource":ThornForestRegionGenerator.boss_definition_path(original.version,2,original)})

func check_canopy_contract(registry: ThornForestRegionGenerator,tuning: PlayerTuning) -> void:
	var generated := registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,"version-canopy-current",tuning,2,{"grapple":true,"abilities":["grapple"],"forest_layout_version":ThornForestRegionGenerator.DEPTH_LAYOUT_CANOPY})
	check(generated.ok,"explicit canopy layout generates a complete candidate")
	if not generated.ok: return
	var m: Dictionary=generated.manifest
	var geometry: Dictionary=m.boss_geometry
	check(registry.validate(m,tuning) and m.layout_version==ThornForestRegionGenerator.DEPTH_LAYOUT_CANOPY and not m.production_pool,"canopy candidate validates without production admission")
	check(ThornForestRegionGenerator.boss_scene_path(m.version,2,m)=="res://scenes/bosses/thorn_queen_canopy.tscn" and ThornForestRegionGenerator.boss_definition_path(m.version,2,m)=="res://resources/bosses/thorn_queen_canopy.tres","current manifest explicitly resolves the new whitelisted Boss pair")
	var config := load("res://resources/bosses/thorn_queen_canopy.tres") as ThornQueenCanopyDefinition
	var prep := Vector2(m.boss_approach_origin[0],m.boss_approach_origin[1])
	var origin := prep-Vector2(config.canopy_arena.position.x-config.entry_gap,config.canopy_spawn.y)
	check(RandomStageGenerator.new()._same_data(geometry,config.build_geometry(origin,true)),"Factory consumes the single actual canopy geometry source")
	var support := Rect2(origin+config.canopy_platforms[1].position,config.canopy_platforms[1].size)
	var at := Vector2(geometry.safe_return[0],geometry.safe_return[1])
	check(absf(at.y+18-support.position.y)<.001 and at.x-12>=support.position.x and at.x+12<=support.end.x,"safe return lies on full-body S support")
	var reward := Vector2(geometry.reward_position[0],geometry.reward_position[1])
	check(absf(reward.y+18-(origin.y+600))<.001 and reward.x-12>origin.x+500 and reward.x+12<origin.x+650,"reward uses the actual free low bay rather than arena-center solid rib")
	for field: String in ["scene","resource","contract"]:
		var edited := m.duplicate(true)
		edited.boss_content[field]="unrecognized"
		edited.manifest_hash=ThornForestRegionGenerator._hash(edited)
		check(not registry.validate(edited,tuning) and ThornForestRegionGenerator.boss_scene_path(m.version,2,edited).is_empty(),"unknown Boss content is rejected after coherent rehash: "+field)
	var missing := m.duplicate(true)
	missing.erase("boss_content");missing.manifest_hash=ThornForestRegionGenerator._hash(missing)
	check(not registry.validate(missing,tuning) and ThornForestRegionGenerator.boss_definition_path(m.version,2,missing).is_empty(),"new layout without explicit Boss content cannot silently fall back")
	cases.append({"id":"canopy_content_contract","manifest":m,"geometry_from_resource":config.build_geometry(origin,true),"boss_scene":ThornForestRegionGenerator.boss_scene_path(m.version,2,m),"boss_resource":ThornForestRegionGenerator.boss_definition_path(m.version,2,m)})

func check_expedition_contract(registry: ThornForestRegionGenerator,tuning: PlayerTuning) -> void:
	# Independent expected identity: never derive the expected layout from producer.
	var expected_layout := "forest-expedition-airborne-v11"
	var equality := RandomStageGenerator.new()
	for map_index: int in [1,2]:
		var seed_value := "version-expedition-map-%s" % map_index
		var capabilities := {"grapple":true,"abilities":["grapple"]}
		var explicit_capabilities := capabilities.duplicate(true)
		explicit_capabilities.forest_layout_version=expected_layout
		var explicit := registry.generate_version("thorn-forest-region-v2",seed_value,tuning,map_index,explicit_capabilities)
		var current: Dictionary=load("res://scripts/generation/thorn_forest_region_v2_v11.gd").new().generate(seed_value,tuning,map_index,capabilities)
		check(explicit.get("ok",false) and current.get("ok",false),"explicit and default expedition generation succeeds map%s" % map_index)
		if not explicit.get("ok",false) or not current.get("ok",false): continue
		var m: Dictionary=explicit.manifest
		var expected_scene := "res://scenes/bosses/rootbell_guardian_v2.tscn" if map_index==1 else "res://scenes/bosses/thorn_queen_canopy.tscn"
		var expected_resource := "res://resources/bosses/rootbell_guardian_v2.tres" if map_index==1 else "res://resources/bosses/thorn_queen_canopy.tres"
		check(m.version=="thorn-forest-region-v2" and m.layout_version==expected_layout and m.seed==seed_value and m.map_index==map_index and not m.production_pool,"explicit exact expedition identity and pending admission map%s" % map_index)
		check(equality._same_data(explicit,current) and current.manifest.layout_version==expected_layout,"explicit historical v11 equals frozen complete output map%s" % map_index)
		check(registry.validate(m,tuning) and registry.validate(current.manifest,tuning) and m.manifest_hash==ThornForestRegionGenerator._hash(m),"expedition complete output roundtrip/hash validates map%s" % map_index)
		var actual_scene := ThornForestRegionGenerator.boss_scene_path(m.version,map_index,m)
		var actual_resource := ThornForestRegionGenerator.boss_definition_path(m.version,map_index,m)
		check(actual_scene==expected_scene and actual_resource==expected_resource,"exact expedition map Boss scene/resource map%s" % map_index)
		var negatives: Array[Dictionary]=[]
		for layout: String in ["forest-expedition-airborne-v999","shared-tree-canopy-hunt-v10"]:
			var edited:=m.duplicate(true)
			edited.layout_version=layout;edited.manifest_hash=ThornForestRegionGenerator._hash(edited)
			var rejected:=not registry.validate(edited,tuning)
			check(rejected,"rehashing cannot relabel expedition as future or old geometry map%s/%s" % [map_index,layout])
			negatives.append({"kind":"relabeled/"+layout,"rejected":rejected})
		var future:=registry.generate_version("thorn-forest-region-v2",seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"],"forest_layout_version":"forest-expedition-airborne-v999"})
		var future_rejected: bool=not future.get("ok",false) and not future.has("manifest")
		check(future_rejected,"unknown expedition layout refuses without fallback map%s" % map_index)
		negatives.append({"kind":"future_generation","rejected":future_rejected})
		var corrupt:=m.duplicate(true)
		corrupt.manifest_hash="unrecognized"
		var hash_rejected:=not registry.validate(corrupt,tuning)
		check(hash_rejected,"corrupt expedition hash refuses map%s" % map_index)
		negatives.append({"kind":"corrupt_hash","rejected":hash_rejected})
		if map_index==2:
			for field: String in ["scene","resource","contract"]:
				var edited:=m.duplicate(true)
				edited.boss_content[field]="unrecognized";edited.manifest_hash=ThornForestRegionGenerator._hash(edited)
				var rejected:=not registry.validate(edited,tuning) and ThornForestRegionGenerator.boss_scene_path(m.version,map_index,edited).is_empty()
				check(rejected,"expedition rejects coherent wrong Boss mapping: "+field)
				negatives.append({"kind":"boss/"+field,"rejected":rejected})
			var missing:=m.duplicate(true)
			missing.erase("boss_content");missing.manifest_hash=ThornForestRegionGenerator._hash(missing)
			var rejected:=not registry.validate(missing,tuning) and ThornForestRegionGenerator.boss_definition_path(m.version,map_index,missing).is_empty()
			check(rejected,"expedition without explicit Canopy mapping cannot fall back")
			negatives.append({"kind":"missing_boss","rejected":rejected})
		cases.append({"id":"expedition_content_contract","map":map_index,"manifest":m,"default_manifest":current.manifest,"complete_output_equal":equality._same_data(explicit,current),"boss_scene":actual_scene,"boss_resource":actual_resource,"negative_cases":negatives})

func check_vertical_contract(registry: ThornForestRegionGenerator,tuning: PlayerTuning) -> void:
	# Semantic and version contracts only: actual movement is a separate proof.
	var expected_layout := "forest-woven-trunk-v12"
	var expected_phrases := ["root_spiral_flight","lower_fork_flight","thorn_mouth_flight","middle_fork_flight","broken_arch_flight","upper_spiral_flight","canopy_fork_flight"]
	var equality := RandomStageGenerator.new()
	for map_index: int in [1,2]:
		var seed_value := "version-woven-map-%s" % map_index
		var explicit := registry.generate_version("thorn-forest-region-v2",seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"],"forest_layout_version":expected_layout})
		var current: Dictionary=load("res://scripts/generation/thorn_forest_region_v2.gd").new().generate(seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"]})
		check(explicit.get("ok",false) and current.get("ok",false),"explicit pinned v12 and frozen woven producer generation succeeds map%s" % map_index)
		if not explicit.get("ok",false) or not current.get("ok",false):continue
		var m: Dictionary=explicit.manifest
		check(m.version=="thorn-forest-region-v2" and m.layout_version==expected_layout and m.map_index==map_index and m.seed==seed_value and not m.production_pool,"exact independent woven candidate identity map%s" % map_index)
		check(equality._same_data(explicit,current),"pinned historical v12 equals complete frozen producer output map%s" % map_index)
		check(m.player_tuning_hash==FileAccess.get_sha256("res://config/player_tuning.json"),"v12 carries actual current tuning fingerprint map%s" % map_index)
		check(registry.validate(m,tuning) and m.manifest_hash==ThornForestRegionGenerator._hash(m),"complete v12 validates and hashes map%s" % map_index)
		var actual_phrases: Array=[]
		for edge: Dictionary in m.connections:
			if edge.kind=="airborne_chain" and edge.id in expected_phrases:
				actual_phrases.append(edge.id)
				check(edge.continuous_airborne==true and edge.optional_lower_alternative==false and edge.action_program.size()>=2 and edge.id in m.routes.fast,"primary compound flight is real declared route edge: "+edge.id)
		check(actual_phrases==expected_phrases,"exact seven distinct primary flight edges map%s" % map_index)
		var hang_ids: Array=[]
		for anchor: Dictionary in m.hook_anchors:
			if anchor.get("hang_enabled",false):hang_ids.append(anchor.id)
		check(hang_ids==["root_spiral__rest_ring","thorn_mouth__rest_ring","thorn_retry_low_ring","thorn_retry_high_ring","thorn_retry_exit_ring","upper_spiral__rest_ring"],"six exact hanging declarations preserve three rest choices and three recovery stages map%s" % map_index)
		var rest_ids: Array=[];var recovery_ids: Array=[]
		for anchor: Dictionary in m.hook_anchors:
			if not anchor.get("hang_enabled",false):continue
			if anchor.get("scene_kind")=="hanging_growth_ring":rest_ids.append(anchor.id)
			if anchor.get("scene_kind")=="hanging_root_ring" and anchor.get("tether_host_support_id")=="thorn_mouth__entry" and anchor.get("recovery_role")=="deep_catch_return_to_thorn_mouth":recovery_ids.append(anchor.id)
		check(rest_ids==["root_spiral__rest_ring","thorn_mouth__rest_ring","upper_spiral__rest_ring"],"original three observation-ring declarations retained map%s" % map_index)
		check(recovery_ids==["thorn_retry_low_ring","thorn_retry_high_ring","thorn_retry_exit_ring"],"three recovery stages have exact real one-way bough host map%s" % map_index)
		var rest_edges: Array=m.connections.filter(func(e: Dictionary) -> bool:return e.id=="root_spiral_rest_flight")
		var rest_valid:=rest_edges.size()==1
		if rest_valid:
			var e: Dictionary=rest_edges[0]
			rest_valid=e.kind=="hanging_chain" and e.a=="root_spiral_mouth" and e.b=="root_spiral_crown" and e.rest_anchor_id=="root_spiral__rest_ring" and e.hang_observation_frames==18 and equality._same_data(e.action_program,load("res://scripts/generation/forest_vertical_chain_geometry.gd").build().rest_program)
		check(rest_valid,"actual hanging alternative consumes the single real factory rest program map%s" % map_index)
		check("root_spiral_rest_flight" not in m.routes.fast and "root_spiral_flight" in m.routes.fast and "root_spiral_rest_flight" in m.routes.growth and "root_spiral_rest_flight" in m.routes.high_return and "root_spiral_flight" not in m.routes.growth and "root_spiral_flight" not in m.routes.high_return,"declared early rest choice changes growth/high route and rejoins same crown map%s" % map_index)
		var final_edge: Dictionary=m.connections.filter(func(e: Dictionary) -> bool:return e.id=="canopy_fork_flight")[0]
		check(m.vertical_contract.primary_rise==1528.0 and float(m.spawn[1])-float(final_edge.landing[1])==1528.0,"declared primary rise matches actual first and final banks map%s" % map_index)
		var host: Dictionary=m.platforms.filter(func(p: Dictionary) -> bool:return p.id=="thorn_mouth__entry")[0]
		check(host.one_way==true and m.expedition_recovery.support=="thorn_mouth__recovery" and m.expedition_recovery.mouth=="thorn_mouth_mouth","deep recovery retains legitimate one-way host and SAME challenge mouth map%s" % map_index)
		var boss_scene := "res://scenes/bosses/rootbell_guardian_v2.tscn" if map_index==1 else "res://scenes/bosses/thorn_queen_canopy.tscn"
		var boss_resource := "res://resources/bosses/rootbell_guardian_v2.tres" if map_index==1 else "res://resources/bosses/thorn_queen_canopy.tres"
		check(ThornForestRegionGenerator.boss_scene_path(m.version,map_index,m)==boss_scene and ThornForestRegionGenerator.boss_definition_path(m.version,map_index,m)==boss_resource,"exact v12 Boss pair map%s" % map_index)
		var negatives: Array=[]
		for layout: String in ["forest-woven-trunk-v999","forest-expedition-airborne-v11"]:
			var edited:=m.duplicate(true);edited.layout_version=layout;edited.manifest_hash=ThornForestRegionGenerator._hash(edited)
			var rejected:=not registry.validate(edited,tuning)
			check(rejected,"coherent v12 relabel rejected: "+layout)
			negatives.append({"kind":"relabeled/"+layout,"rejected":rejected})
		for mutation: String in ["missing_hang","missing_flight","historical_tuning","missing_rest_choice","wrong_recovery_mouth"]:
			var edited:=m.duplicate(true)
			if mutation=="missing_rest_choice":edited.connections=edited.connections.filter(func(e: Dictionary) -> bool:return e.id!="root_spiral_rest_flight")
			elif mutation=="wrong_recovery_mouth":edited.expedition_recovery.mouth="canopy_fork_mouth"
			elif mutation=="historical_tuning":edited.player_tuning_hash="e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058"
			elif mutation=="missing_hang":
				for anchor: Dictionary in edited.hook_anchors:anchor.erase("hang_enabled")
			else:
				edited.connections=edited.connections.filter(func(e: Dictionary) -> bool:return e.id!="root_spiral_flight")
			edited.manifest_hash=ThornForestRegionGenerator._hash(edited)
			var rejected:=not registry.validate(edited,tuning)
			check(rejected,"coherent v12 semantic mutation rejected: "+mutation)
			negatives.append({"kind":mutation,"rejected":rejected})
		cases.append({"id":"vertical_content_contract","map":map_index,"manifest":m,"default_manifest":current.manifest,"complete_output_equal":equality._same_data(explicit,current),"primary_flights":actual_phrases,"hang_ids":hang_ids,"boss_scene":boss_scene,"boss_resource":boss_resource,"negative_cases":negatives})

func check_recorded_expedition(registry: ThornForestRegionGenerator,tuning: PlayerTuning) -> void:
	# Entire real final v11 manifests extracted from original source-bound corpus.
	var fixtures := {1:"ddd26758ae3d968927a16bfaa94c89366e00a443120b6441fc2a285df615a2ff",2:"85e7ef09f8fbc59a4f0f5f70d2286200bb9e86bb55db6fcc029a08847949cf72"}
	for index: int in [1,2]:
		var path := "res://tests/fixtures/forest_recorded_layouts/v11_corpus_map%s.json" % index
		check(FileAccess.get_sha256(path)==fixtures[index],"original final v11 fixture bytes retained map%s" % index)
		var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var rebuilt := registry.generate_version("thorn-forest-region-v2",original.seed,tuning,index,{"grapple":true,"abilities":["grapple"],"forest_layout_version":"forest-expedition-airborne-v11"})
		check(rebuilt.get("ok",false) and RandomStageGenerator.new()._same_data(original,rebuilt.get("manifest",{})),"entire final v11 fixture and exact old hash rebuilt map%s" % index)
		check(registry.validate(original,tuning),"actual final v11 original validates map%s" % index)
		var edited:=original.duplicate(true);edited.player_tuning_hash=FileAccess.get_sha256("res://config/player_tuning.json");edited.manifest_hash=ThornForestRegionGenerator._hash(edited)
		var rejected:=not registry.validate(edited,tuning)
		check(rejected,"rehashing cannot change historical generation fingerprint map%s" % index)
		cases.append({"id":"recorded_expedition_layout","map":index,"fixture_sha256":FileAccess.get_sha256(path),"original":original,"rebuilt":rebuilt.get("manifest",{}),"current_tuning_mutation_rejected":rejected})

func check_interwoven_contract(registry: ThornForestRegionGenerator,tuning: PlayerTuning) -> void:
	# V13 is an immutable recorded layout even after a later default is selected.
	var expected_layout := "forest-interwoven-canopy-v13"
	var expected_edges := ["root_bay_approach","root_bay_lesson_flight","inner_hollow_HH","upper_root_RH","upper_root_crown_H","inner_thorn_HR","crown_inner_return","inner_bay_return"]
	var expected_supports := ["interwoven_root_bridge","interwoven_lesson_bough","interwoven_inner_bough","interwoven_upper_launch"]
	var equality := RandomStageGenerator.new()
	for map_index: int in [1,2]:
		var seed_value := "version-interwoven-map-%s" % map_index
		var capabilities := {"grapple":true,"abilities":["grapple"]}
		var pinned := capabilities.duplicate(true)
		pinned.forest_layout_version=expected_layout
		var explicit := registry.generate_version("thorn-forest-region-v2",seed_value,tuning,map_index,pinned)
		var frozen: Dictionary=load("res://scripts/generation/thorn_forest_region_v2_v13.gd").new().generate(seed_value,tuning,map_index,capabilities)
		var current := registry.generate(seed_value,tuning,map_index,pinned)
		check(explicit.get("ok",false) and frozen.get("ok",false) and current.get("ok",false),"v13 explicit, frozen and pinned registry generation succeeds map%s" % map_index)
		if not explicit.get("ok",false) or not frozen.get("ok",false) or not current.get("ok",false):continue
		var m: Dictionary=explicit.manifest
		check(m.version=="thorn-forest-region-v2" and m.layout_version==expected_layout and m.seed==seed_value and m.map_index==map_index and m.requires==["grapple"] and not m.production_pool,"independently expected v13 identity, H-only and pending admission map%s" % map_index)
		check(equality._same_data(explicit,frozen),"explicit v13 equals entire dedicated producer output map%s" % map_index)
		check(equality._same_data(explicit,current) and current.manifest.layout_version==expected_layout,"actual pinned registry equals entire explicit v13 output map%s" % map_index)
		check(registry.validate(m,tuning) and registry.validate(current.manifest,tuning) and m.manifest_hash==ThornForestRegionGenerator._hash(m),"v13 complete strict validation and hash map%s" % map_index)
		check(m.player_tuning_hash==FileAccess.get_sha256("res://config/player_tuning.json"),"v13 uses actual current tuning fingerprint map%s" % map_index)
		var actual_edges: Array=[]
		for edge: Dictionary in m.connections:
			if edge.id in expected_edges:actual_edges.append(edge.id)
		check(actual_edges==expected_edges,"v13 exact added real approach, branch and return edges map%s" % map_index)
		var actual_supports: Array=[]
		for support: Dictionary in m.platforms:
			if support.id in expected_supports:
				actual_supports.append(support.id)
				check(support.one_way==true and support.rect[2]>=100.0,"v13 actual broad grounded bough: "+support.id)
		check(actual_supports==expected_supports,"v13 exact added grounded supports map%s" % map_index)
		check(m.entry_contract.selected=="root_bay" and m.entry_contract.optional_skill_route=="root_spiral","short grounded entry and optional original skill line map%s" % map_index)
		check(m.interwoven_contract.held_hang_resets_focus==false,"v13 explicitly preserves no hanging focus refill map%s" % map_index)
		check(m.interwoven_contract.splits.slice(0,2)==["arrival","interwoven_inner"] and m.interwoven_contract.rejoins.slice(0,2)==["root_spiral_crown","thorn_mouth_mouth"],"v13 explicit early split and distinct rejoins map%s" % map_index)
		check(m.interwoven_contract.splits==["arrival","interwoven_inner","broken_arch_crown"] and m.interwoven_contract.rejoins==["root_spiral_crown","thorn_mouth_mouth","interwoven_root_landing","M"],"v13 exact expanded split and rejoin identity map%s" % map_index)
		var landing_nodes: Array=m.areas.filter(func(row: Dictionary) -> bool:return row.id=="interwoven_root_landing")
		check(landing_nodes.size()==1 and landing_nodes[0].position==[400.0,802.0] and landing_nodes[0].role=="junction","v13 actual root landing junction map%s" % map_index)
		var deep_edges: Array=m.connections.filter(func(row: Dictionary) -> bool:return row.id=="interwoven_deep_ascent")
		check(deep_edges.size()==1 and deep_edges[0].a=="interwoven_deep_basin" and deep_edges[0].b=="interwoven_root_landing" and deep_edges[0].landing==[400.0,802.0] and deep_edges[0].landing_support_id=="hollow__inner_root","v13 ascent reaches actual lip instead of relabeling D map%s" % map_index)
		var root_walk: Array=m.connections.filter(func(row: Dictionary) -> bool:return row.id=="interwoven_root_to_D")
		check(root_walk.size()==1 and root_walk[0].a=="interwoven_root_landing" and root_walk[0].b=="D" and root_walk[0].kind=="walk" and root_walk[0].path==[[400.0,802.0],[720.0,802.0]],"v13 actual root lip walk to old D map%s" % map_index)
		var root_support: Array=m.platforms.filter(func(row: Dictionary) -> bool:return row.id=="hollow__inner_root")
		check(root_support.size()==1 and root_support[0].rect==[290.0,820.0,500.0,40.0] and not root_support[0].one_way,"v13 root walk shares exact real continuous solid support map%s" % map_index)
		var camp_walk: Array=m.connections.filter(func(row: Dictionary) -> bool:return row.id=="interwoven_root_to_camp")
		var camp_at_lip: bool=m.merchant_position==[360.0,802.0]
		check((camp_at_lip and camp_walk.size()==1 and camp_walk[0].a=="interwoven_root_landing" and camp_walk[0].b=="camp" and camp_walk[0].kind=="walk" and camp_walk[0].path==[[400.0,802.0],[360.0,802.0]]) or (not camp_at_lip and camp_walk.is_empty()),"v13 conditional camp edge uses actual merchant360 source map%s" % map_index)
		var west_reward: bool=m.choices.west_reward
		check(m.choices.interwoven_midroute==("upper_west_reward_existing_order" if west_reward else "deep_root_camp_first") and m.choices.interwoven_midroute_basis=="actual_existing_west_reward; no additional random draw","v13 exact seed-west order policy map%s" % map_index)
		check((west_reward and "interwoven_deep_ascent" not in m.routes.growth and "interwoven_deep_descent" not in m.routes.growth) or (not west_reward and "interwoven_deep_ascent" in m.routes.growth and "interwoven_deep_descent" in m.routes.growth and m.routes.growth.find("interwoven_deep_descent")+1==m.routes.growth.find("interwoven_deep_ascent") and m.routes.growth.find("broken_arch_flight")<m.routes.growth.find("interwoven_deep_descent")),"v13 actual growth respects conditional west-order and deep adjacency map%s" % map_index)
		check(m.choices.interwoven_first_branch in ["inner","upper"] and m.streams.interwoven=="forest_interwoven","v13 finite branch and isolated random stream map%s" % map_index)
		var inner := ["root_bay_approach","root_bay_lesson_flight","inner_hollow_HH","inner_thorn_HR"]
		var upper := ["root_bay_approach","root_bay_lesson_flight","inner_hollow_HH","upper_root_RH","upper_root_crown_H"]
		var fast_prefix: Array=inner if m.choices.interwoven_first_branch=="inner" else upper
		var growth_prefix: Array=upper if m.choices.interwoven_first_branch=="inner" else inner
		check(m.routes.fast.slice(0,fast_prefix.size())==fast_prefix and m.routes.growth.slice(0,growth_prefix.size())==growth_prefix,"v13 actual fast/growth consume different early branch prefixes map%s" % map_index)
		check("root_spiral_rest_flight" in m.routes.high_return and "root_bay_approach" not in m.routes.high_return,"v13 optional original long skill strategy retained map%s" % map_index)
		var boss_scene := "res://scenes/bosses/rootbell_guardian_v2.tscn" if map_index==1 else "res://scenes/bosses/thorn_queen_canopy.tscn"
		var boss_resource := "res://resources/bosses/rootbell_guardian_v2.tres" if map_index==1 else "res://resources/bosses/thorn_queen_canopy.tres"
		check(ThornForestRegionGenerator.boss_scene_path(m.version,map_index,m)==boss_scene and ThornForestRegionGenerator.boss_definition_path(m.version,map_index,m)==boss_resource,"v13 exact unchanged Boss pair map%s" % map_index)
		var negatives: Array=[]
		for mutation: String in ["relabel_v12","relabel_future","missing_support","missing_branch","wrong_route","wrong_return","hang_refill","historical_tuning"]:
			var edited := m.duplicate(true)
			if mutation=="relabel_v12":edited.layout_version="forest-woven-trunk-v12"
			elif mutation=="relabel_future":edited.layout_version="forest-interwoven-canopy-v999"
			elif mutation=="missing_support":edited.platforms=edited.platforms.filter(func(row: Dictionary) -> bool:return row.id!="interwoven_inner_bough")
			elif mutation=="missing_branch":edited.connections=edited.connections.filter(func(row: Dictionary) -> bool:return row.id!="inner_thorn_HR")
			elif mutation=="wrong_route":edited.routes.fast=["inner_bay_return"]
			elif mutation=="wrong_return":
				for edge: Dictionary in edited.connections:
					if edge.id=="inner_bay_return":edge.b="gate_ready"
			elif mutation=="hang_refill":edited.interwoven_contract.held_hang_resets_focus=true
			else:edited.player_tuning_hash="e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058"
			edited.manifest_hash=ThornForestRegionGenerator._hash(edited)
			var rejected := not registry.validate(edited,tuning)
			check(rejected,"v13 coherent semantic mutation rejected: "+mutation)
			negatives.append({"kind":mutation,"rejected":rejected})
		for forbidden: String in ["double_jump","wall_climb","weapon_evolution_1","weapon_evolution_2"]:
			var illegal := pinned.duplicate(true);illegal[forbidden]=true
			var denied := registry.generate_version("thorn-forest-region-v2",seed_value,tuning,map_index,illegal)
			var rejected: bool=not denied.get("ok",false) and not denied.has("manifest")
			check(rejected,"v13 rejects ungranted S2 capability: "+forbidden)
			negatives.append({"kind":"capability/"+forbidden,"rejected":rejected})
		cases.append({"id":"interwoven_content_contract","map":map_index,"manifest":m,"default_manifest":current.manifest,"frozen_manifest":frozen.manifest,"complete_output_equal":equality._same_data(explicit,current) and equality._same_data(explicit,frozen),"added_edges":actual_edges,"added_supports":actual_supports,"boss_scene":boss_scene,"boss_resource":boss_resource,"negative_cases":negatives})

func check_fruit_contract(registry: ThornForestRegionGenerator,tuning: PlayerTuning) -> void:
	var equality := RandomStageGenerator.new()
	for map_index: int in [1,2]:
		var seed_value := "version-fruit-map-%s" % map_index
		var capabilities := {"grapple":true,"abilities":["grapple"]}
		var pinned := capabilities.duplicate(true)
		pinned.forest_layout_version = "forest-fruit-routes-v14"
		var explicit := registry.generate_version("thorn-forest-region-v2",seed_value,tuning,map_index,pinned)
		var dedicated: Dictionary = load("res://scripts/generation/thorn_forest_region_v2_v14.gd").new().generate(seed_value,tuning,map_index,capabilities)
		var current := registry.generate(seed_value,tuning,map_index,capabilities)
		check(explicit.get("ok",false) and dedicated.get("ok",false) and current.get("ok",false),"registered candidate and public layout generate map%s" % map_index)
		if not explicit.get("ok",false) or not dedicated.get("ok",false) or not current.get("ok",false):continue
		var m: Dictionary = explicit.manifest
		check(m.layout_version=="forest-fruit-routes-v14" and equality._same_data(explicit,dedicated),"explicit v14 equals complete dedicated output map%s" % map_index)
		check(registry.validate(m,tuning) and m.manifest_hash==ThornForestRegionGenerator._hash(m),"strict registered v14 and hash validate map%s" % map_index)
		var expected_pin := capabilities.duplicate(true)
		expected_pin.forest_layout_version = EXPECTED_PUBLIC_LAYOUT
		var expected := registry.generate_version("thorn-forest-region-v2",seed_value,tuning,map_index,expected_pin)
		check(current.manifest.layout_version==EXPECTED_PUBLIC_LAYOUT and equality._same_data(current,expected),"independently selected public layout equals whole explicit output map%s" % map_index)
		var previous: Dictionary = load("res://scripts/generation/thorn_forest_region_v2_v13.gd").new().generate(seed_value,tuning,map_index,capabilities)
		for field: String in ["platforms","dangers","connections","geometry_instances","enemies","rewards","enemy_drops","streams","stream_positions","routes","choices"]:
			check(equality._same_data(m[field],previous.manifest[field]),"v14 preserves old actual "+field+" map%s"%map_index)
		var boss_scene := "res://scenes/bosses/rootbell_guardian_v2.tscn" if map_index==1 else "res://scenes/bosses/thorn_queen_canopy.tscn"
		check(ThornForestRegionGenerator.boss_scene_path(m.version,map_index,m)==boss_scene,"v14 resolves unchanged exact Boss whitelist map%s" % map_index)
		var edited := m.duplicate(true)
		edited.hook_anchors[0].position[0] += 1.0
		edited.manifest_hash = ThornForestRegionGenerator._hash(edited)
		check(not registry.validate(edited,tuning),"v14 refuses coherently rehashed target movement map%s" % map_index)
		edited = m.duplicate(true)
		edited.fruit_routes_contract.max_local_stem = 1000.0
		edited.manifest_hash = ThornForestRegionGenerator._hash(edited)
		check(not registry.validate(edited,tuning),"v14 refuses coherently rehashed long-stem policy map%s" % map_index)
		if map_index==2:
			edited=m.duplicate(true);edited.erase("boss_content");edited.manifest_hash=ThornForestRegionGenerator._hash(edited)
			check(not registry.validate(edited,tuning) and ThornForestRegionGenerator.boss_scene_path(m.version,map_index,edited).is_empty(),"v14 missing Queen whitelist content cannot fall back")
		cases.append({"id":"fruit_candidate_and_public_layout","map":map_index,"candidate_manifest":m,"default_manifest":current.manifest,"expected_public_layout":EXPECTED_PUBLIC_LAYOUT,"dedicated_complete_equal":equality._same_data(explicit,dedicated)})

extends SceneTree
## One actual04 addon generation, full template-resolved gears data; no route/neighbor certification.
const PROFILE = preload("res://game/world/generation/mapgen/runtime_map_generation_profile.gd")
const SELECTION = preload("res://game/world/generation/mapgen/runtime_map_generated_selection.gd")
const DATA = preload("res://addons/mapgen/data_json.gd")
const M35_HOST = preload("res://experiments/generation/runtime_map_m35_slice.gd")
var checks := 0
var failures := 0
var source := RuntimeMapGenerationJob.new()
var lifetime := DemoLifetime.new()
var ticket: RefCounted
var request := LevelRequest.new()
var result: Dictionary
var provenance: Dictionary
var bindings: Dictionary
var ids: Array[String] = []
var content_ref := ""
var spawn: Vector2

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("M35 PROVIDER: "+label)

func admit(data: Dictionary) -> LevelBuildResult:
	return RuntimeMapV2Provider.load_generated_level(request,data,ids,spawn,bindings,provenance)

func rejected(data: Dictionary, label: String) -> void:
	var built := admit(data)
	check(not built.accepted() and built.plan==null and not built.error.is_empty(),"reject without Plan: "+label)

func run() -> void:
	var profile: Dictionary = PROFILE.read_profile(M35_HOST.INPUT_PROFILE)
	var host := RuntimeMapFrozenSource.read_binding_file(M35_HOST.BINDINGS_PATH,M35_HOST.BINDINGS_SHA256)
	check(profile.ok and host.ok,"actual shared algorithm profile and SHA-verified gears selection recipe decode")
	if not profile.ok or not host.ok:
		finish()
		return
	var lock: Dictionary = profile.lock
	bindings = host.bindings
	check(bindings.get("version")=="runtime-v4-gears-r1" and bindings.get("selected_instances")==[] and bindings.get("spawns")=={},"gears recipe contains no historical instance IDs or global spawn")
	if bindings.get("selected_instances")!=[] or bindings.get("spawns")!={}:
		finish()
		return
	var locked := true
	for path: String in lock.addon_files: locked = locked and FileAccess.get_sha256("res://"+path)==lock.addon_files[path]
	for item: Dictionary in [lock.gears_conformance.request,lock.gears_conformance.config]: locked = locked and FileAccess.get_sha256(item.path)==item.sha256
	check(locked,"actual installed addon and original upstream 930007 input bytes match shared lock")
	if not locked:
		finish()
		return
	var algorithm: Dictionary = profile.request
	var config: Dictionary = profile.config
	check(algorithm.seed is int and algorithm.seed==930007,"actual integer 930007 mechanism request, not default930001 relabelled")
	if not algorithm.seed is int or algorithm.seed!=930007:
		finish()
		return
	request.root_seed = str(algorithm.seed)
	request.tuning = PlayerTuning.load_default()
	request.capabilities = {"profile":"explicit_upstream_mechanism_not_a_player_grant","collision_half_extents":algorithm.player.clearance_half_extents_pixels.duplicate()}
	ticket = source.begin(root,lifetime,request,algorithm,config,bindings,ids)
	check(ticket!=null,"source-owned generation ticket accepted")
	if ticket==null:
		finish()
		return
	while source.phase(ticket) in ["preload","generate","validate"]:
		source.tick(ticket,lifetime)
		await process_frame
	check(source.phase(ticket)=="ready","actual addon result converted by existing source/Provider: "+source.error(ticket))
	if source.phase(ticket)!="ready":
		finish()
		return
	result = source.actual_result(ticket,lifetime)
	provenance = source.provenance(ticket,lifetime)
	var half_extents: Array = algorithm.player.clearance_half_extents_pixels
	var selection: Dictionary = SELECTION.resolve(result,bindings,Vector2(float(half_extents[0]),float(half_extents[1])))
	check(selection.ok and selection.get("ids",[]).size()==1,"shared resolver selects one actual gears template/version/role: "+str(selection.get("error","")))
	if not selection.ok or selection.ids.size()!=1:
		finish()
		return
	ids.assign(selection.ids)
	bindings = selection.bindings
	spawn = selection.spawn
	var selected: Dictionary = {}
	for instance: Dictionary in result.map.instances:
		if instance.id==ids[0]: selected = instance
	check(not selected.is_empty(),"resolved gears instance exists in actual generated map")
	if selected.is_empty():
		finish()
		return
	content_ref = selected.content_ref
	var before := DATA.canonical(result)
	var built := source.take_plan(ticket,lifetime)
	check(built!=null and built.accepted(),"single actual generated Plan is available")
	if built==null or not built.accepted():
		finish()
		return
	check(built.plan.modules.size()==1 and built.plan.modules[0].instance_id==ids[0] and built.plan.connections.is_empty(),"single actual selected gears instance does not fabricate neighbors or seams")
	var placement: LevelModulePlacement = built.plan.modules[0]
	var definition: PlatformingModuleDefinition = placement.definition
	var content: Dictionary = result.content_store[content_ref]
	var original_origin := Vector2(float(selected.origin_blocks[0]),float(selected.origin_blocks[1]))*128.0
	check(placement.position==original_origin and definition.world_bounds==Rect2(0,0,1024,768),"actual materialized local coordinates receive exactly one instance translation")
	var first_platform: Array = content.platforms[0]
	var platform_spawn := original_origin+Vector2(float(first_platform[0])+float(first_platform[2])*0.5,float(first_platform[1])-float(half_extents[1]))
	check(spawn==platform_spawn and built.plan.spawn==spawn,"resolved spawn is the actual existing platform center at player body height")
	check(selected.module_id=="game-plains-ferry-gears" and selected.content_version=="sha256:18e0578b0631239884f0ff9bb598b04867396bcbe3988c036b512ebe32e092b3" and selected.role=="traversal","actual04 mechanism selection retains exact template/version/role")
	check(content.stable_id=="game-plains-ferry-gears" and content.hazards==[[44,658,912,40]],"actual original module and full hazard band preserved")
	check(definition.platforms.size()==4 and definition.one_way_platform_indices==[2] and definition.danger_bounds==[Rect2(44,658,912,40)],"all four original platforms, one-way index and hazard become existing native definitions")
	check(definition.saws.size()==1 and definition.ferries.size()==2 and definition.surface_thorns.is_empty(),"exact original mechanism counts; no extra mechanism family")
	check(definition.is_valid() and definition.supports(request.tuning),"original native definition validators remain authoritative")
	var saw: ModuleSawDefinition = definition.saws[0]
	check(saw.source_id==&"relay_gear" and saw.origin==Vector2(512,368) and saw.travel==Vector2(0,240),"original saw identity/geometry")
	check(saw.radius==20 and saw.period==4.8 and saw.initial_phase==0 and saw.damage==1 and saw.contact_interval==0.7,"all five original saw numeric fields preserved")
	check(saw.envelope()==Rect2(492,108,40,520) and saw.at_time(1.2).is_equal_approx(Vector2(512,608)) and saw.at_time(3.6).is_equal_approx(Vector2(512,128)),"existing native saw period and envelope retain original meaning")
	for index: int in 2:
		var raw: Dictionary = content.moving_platforms[index]
		var ferry: ModuleMovingPlatformDefinition = definition.ferries[index]
		check(not raw.has("trajectory_kind") and not ferry is RuntimeMapEllipseDefinition,"original absent trajectory field selects native linear definition")
		check(str(ferry.platform_id)==raw.platform_id and ferry.start==Vector2(raw.start[0],raw.start[1]) and ferry.finish==Vector2(raw.finish[0],raw.finish[1]) and ferry.size==Vector2(raw.size[0],raw.size[1]),"linear identity/start/finish/size fully preserved: "+str(index))
		check(ferry.travel_duration==raw.travel_duration and ferry.dwell_duration==raw.dwell_duration and ferry.initial_phase==raw.initial_phase and ferry.period()==9,"all three original linear timing fields preserved: "+str(index))
		check(ferry.at_time(0)==ferry.start and ferry.at_time(1.5)==ferry.start and ferry.at_time(4.5)==ferry.finish and ferry.at_time(6)==ferry.finish and ferry.at_time(9)==ferry.start,"native linear dwell/travel boundary order: "+str(index))
	var state := PlainsRegionState.new()
	state.bind_map(built.plan.map_hash)
	var saved := state.snapshot()
	for mode: String in ["hazard","saw","linear"]:
		var changed: Dictionary = result.duplicate(true)
		var next_content: Dictionary = changed.content_store[content_ref]
		match mode:
			"hazard": next_content.hazards[0][0] += 1
			"saw": next_content.saws[0].contact_interval = 0.8
			"linear": next_content.moving_platforms[0].travel_duration = 3.5
		var fresh := admit(changed)
		check(fresh.accepted() and fresh.plan.map_hash!=built.plan.map_hash,"valid changed actual content gets new identity: "+mode)
		if fresh.accepted(): check(not PlainsRegionState.new().restore(saved,fresh.plan.map_hash),"old state refuses changed mechanism content: "+mode)
	for field: String in ["source_id","origin","travel","radius","period","initial_phase","damage","contact_interval"]:
		var bad: Dictionary = result.duplicate(true)
		bad.content_store[content_ref].saws[0].erase(field)
		rejected(bad,"missing saw "+field+" cannot fall back to Resource default")
	for field: String in ["platform_id","start","finish","size","travel_duration","dwell_duration","initial_phase"]:
		var bad: Dictionary = result.duplicate(true)
		bad.content_store[content_ref].moving_platforms[0].erase(field)
		rejected(bad,"missing linear "+field+" cannot fall back to Resource default")
	for mode: String in ["missing_hazards","missing_saws","hazard_extra","hazard_zero","hazard_outside","hazard_nan","saw_extra","saw_duplicate","saw_period","saw_phase","saw_radius","saw_outside","saw_damage","saw_interval","linear_extra","linear_explicit_kind","linear_duplicate","cross_id","linear_phase","linear_zero_travel","linear_zero_dwell","linear_same_endpoints","linear_outside","linear_nan","hooks","thorns","enemies","reward_sites","latches"]:
		var bad: Dictionary = result.duplicate(true)
		var raw: Dictionary = bad.content_store[content_ref]
		match mode:
			"missing_hazards": raw.erase("hazards")
			"missing_saws": raw.erase("saws")
			"hazard_extra": raw.hazards[0].append(1)
			"hazard_zero": raw.hazards[0][2] = 0
			"hazard_outside": raw.hazards[0][0] = -1
			"hazard_nan": raw.hazards[0][0] = NAN
			"saw_extra": raw.saws[0]["unknown"] = 1
			"saw_duplicate": raw.saws.append(raw.saws[0].duplicate(true))
			"saw_period": raw.saws[0].period = 0
			"saw_phase": raw.saws[0].initial_phase = 1
			"saw_radius": raw.saws[0].radius = -1
			"saw_outside": raw.saws[0].origin = [-100,368]
			"saw_damage": raw.saws[0].damage = 0
			"saw_interval": raw.saws[0].contact_interval = 0
			"linear_extra": raw.moving_platforms[0]["unknown"] = 1
			"linear_explicit_kind": raw.moving_platforms[0].trajectory_kind = "linear"
			"linear_duplicate": raw.moving_platforms[1].platform_id = raw.moving_platforms[0].platform_id
			"cross_id": raw.moving_platforms[0].platform_id = raw.saws[0].source_id
			"linear_phase": raw.moving_platforms[0].initial_phase = 1
			"linear_zero_travel": raw.moving_platforms[0].travel_duration = 0
			"linear_zero_dwell": raw.moving_platforms[0].dwell_duration = 0
			"linear_same_endpoints": raw.moving_platforms[0].finish = raw.moving_platforms[0].start.duplicate()
			"linear_outside": raw.moving_platforms[0].start = [-100,590]
			"linear_nan": raw.moving_platforms[0].initial_phase = NAN
			_: raw[mode].append({"unsupported":true})
		rejected(bad,mode)
	check(DATA.canonical(result)==before,"all original generated data remains intact after admission and negative probes")
	check(source.phase(ticket)=="assemble","Plan taken for validation only; no Stage commit or route completion claimed")
	finish()

func finish() -> void:
	source.close()
	lifetime.end()
	print("RUNTIME_MAP_M35_PROVIDER checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

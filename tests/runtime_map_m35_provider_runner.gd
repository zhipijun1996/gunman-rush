extends SceneTree
## One actual addon generation, full M35 data; no route/neighbor certification.
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
var ids: Array[String] = ["M35"]
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
	var lock: Variant = JSON.parse_string(FileAccess.get_file_as_string(RuntimeMapGenerationJob.LOCK_PATH))
	var host := RuntimeMapFrozenSource.read_binding_file(M35_HOST.BINDINGS_PATH,M35_HOST.BINDINGS_SHA256)
	check(lock is Dictionary and host.ok,"actual shared algorithm lock and SHA-verified M35 host bindings decode")
	if not lock is Dictionary or not host.ok:
		finish()
		return
	bindings = host.bindings
	if not (bindings.get("version")=="m35-loading-r1" and bindings.get("selected_instances")==["M35"] and (LevelContentValidation.point(bindings.get("spawns",{}).get("seam")) and Vector2(float(bindings.spawns.seam[0]),float(bindings.spawns.seam[1]))==Vector2(1626,1742))):
		var seam: Variant = bindings.get("spawns",{}).get("seam")
		var scalar_types: Array[String] = []
		if seam is Array:
			for value: Variant in seam: scalar_types.append(type_string(typeof(value)))
		print("M35_BINDING_DIAGNOSTIC ",JSON.stringify({"version":bindings.get("version"),"selected_instances":bindings.get("selected_instances"),"seam":seam,"seam_type":type_string(typeof(seam)),"scalar_types":scalar_types,"point_valid":LevelContentValidation.point(seam),"array_equal":seam==[1626,1742],"vector_equal":Vector2(float(seam[0]),float(seam[1]))==Vector2(1626,1742) if LevelContentValidation.point(seam) else false}))
	check(bindings.get("version")=="m35-loading-r1" and bindings.get("selected_instances")==["M35"] and (LevelContentValidation.point(bindings.get("spawns",{}).get("seam")) and Vector2(float(bindings.spawns.seam[0]),float(bindings.spawns.seam[1]))==Vector2(1626,1742)),"independent M35 binding selects one original module and existing platform center")
	if bindings.get("selected_instances")!=["M35"] or not LevelContentValidation.point(bindings.get("spawns",{}).get("seam")):
		finish()
		return
	spawn = Vector2(bindings.spawns.seam[0],bindings.spawns.seam[1])
	var locked := true
	for path: String in lock.addon_files: locked = locked and FileAccess.get_sha256("res://"+path)==lock.addon_files[path]
	for item: Dictionary in [lock.conformance.request,lock.conformance.config]: locked = locked and FileAccess.get_sha256(item.path)==item.sha256
	check(locked,"actual installed addon and algorithm input bytes match original lock")
	if not locked:
		finish()
		return
	var algorithm: Dictionary = DATA.parse(FileAccess.get_file_as_string(lock.conformance.request.path))
	var config: Dictionary = DATA.parse(FileAccess.get_file_as_string(lock.conformance.config.path))
	check(algorithm.ok and config.ok and algorithm.value.seed==930001,"actual integer 930001 conformance request")
	if not algorithm.ok or not config.ok:
		finish()
		return
	request.root_seed = str(algorithm.value.seed)
	request.tuning = PlayerTuning.load_default()
	ticket = source.begin(root,lifetime,request,algorithm.value,config.value,bindings,ids)
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
	var before := DATA.canonical(result)
	var built := source.take_plan(ticket,lifetime)
	check(built!=null and built.accepted(),"single actual generated Plan is available")
	if built==null or not built.accepted():
		finish()
		return
	check(built.plan.modules.size()==1 and built.plan.modules[0].instance_id=="M35" and built.plan.connections.is_empty(),"single selected M35 does not fabricate neighbors or seams")
	var placement: LevelModulePlacement = built.plan.modules[0]
	var definition: PlatformingModuleDefinition = placement.definition
	var content: Dictionary = result.content_store["content/M35.json"]
	check(placement.position==Vector2(1536,1152) and definition.world_bounds==Rect2(0,0,1024,768),"materialized local coordinates receive exactly one instance translation")
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
		var next_content: Dictionary = changed.content_store["content/M35.json"]
		match mode:
			"hazard": next_content.hazards[0][0] += 1
			"saw": next_content.saws[0].contact_interval = 0.8
			"linear": next_content.moving_platforms[0].travel_duration = 3.5
		var fresh := admit(changed)
		check(fresh.accepted() and fresh.plan.map_hash!=built.plan.map_hash,"valid changed actual content gets new identity: "+mode)
		if fresh.accepted(): check(not PlainsRegionState.new().restore(saved,fresh.plan.map_hash),"old state refuses changed mechanism content: "+mode)
	for field: String in ["source_id","origin","travel","radius","period","initial_phase","damage","contact_interval"]:
		var bad: Dictionary = result.duplicate(true)
		bad.content_store["content/M35.json"].saws[0].erase(field)
		rejected(bad,"missing saw "+field+" cannot fall back to Resource default")
	for field: String in ["platform_id","start","finish","size","travel_duration","dwell_duration","initial_phase"]:
		var bad: Dictionary = result.duplicate(true)
		bad.content_store["content/M35.json"].moving_platforms[0].erase(field)
		rejected(bad,"missing linear "+field+" cannot fall back to Resource default")
	for mode: String in ["missing_hazards","missing_saws","hazard_extra","hazard_zero","hazard_outside","hazard_nan","saw_extra","saw_duplicate","saw_period","saw_phase","saw_radius","saw_outside","saw_damage","saw_interval","linear_extra","linear_explicit_kind","linear_duplicate","cross_id","linear_phase","linear_zero_travel","linear_zero_dwell","linear_same_endpoints","linear_outside","linear_nan","hooks","thorns","enemies","reward_sites","latches"]:
		var bad: Dictionary = result.duplicate(true)
		var raw: Dictionary = bad.content_store["content/M35.json"]
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

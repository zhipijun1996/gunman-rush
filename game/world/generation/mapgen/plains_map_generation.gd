class_name PlainsMapGeneration
extends RefCounted
## One run's generation source and committed maps. No gameplay services.
const VERSION := "plains-mapgen-v3"
const CONFIG := "res://config/plains_mapgen.json"
const REQUEST = preload("res://game/world/generation/mapgen/runtime_map_generation_request.gd")
var generation := RuntimeMapGenerationJob.new()
var ticket: RefCounted
var progress := ""
var _maps: Dictionary = {}
var _pending: LevelBuildResult
var _pending_index := 0
var _started_usec := 0
var _ready_usec := 0
var _attempt_metrics: Array[Dictionary]=[]

# Keep the seed namespace stable across host profiles for comparable samples.
static func seed_for(root_seed: String, map_index: int) -> int:
	return (root_seed+"/plains/map_%s/mapgen-v1" % map_index).sha256_text().substr(0,13).hex_to_int()

var phase := "idle"
var error := ""
var _result: LevelBuildResult
var _owner: WeakRef
var _lifetime: DemoLifetime
var _original: LevelRequest
var _request: LevelRequest
var _data: Dictionary
var _config: Dictionary
var _recipe: Dictionary
var _rules: Dictionary
var _attempt := 0
var _early_reservation := false
var _failures: Array[String]=[]

func begin_map(owner: Node, lifetime: DemoLifetime, original: LevelRequest, controller: PlayerController) -> void:
	_result=null;error="";phase="loading";_attempt=0;_failures.clear()
	_started_usec=Time.get_ticks_usec();_ready_usec=0;_attempt_metrics.clear()
	_original=original;_owner=weakref(owner);_lifetime=lifetime;_early_reservation=false
	if _maps.has(original.map_index):
		var cached: LevelBuildResult=_maps[original.map_index]
		if original.expected_hash.is_empty() or original.expected_hash==cached.plan.map_hash:
			_result=cached;phase="ready";return
		_fail("Committed map identity changed");return
	var profile := RuntimeMapGenerationProfile.read_profile()
	var decoded: Dictionary=preload("res://addons/mapgen/data_json.gd").parse(FileAccess.get_file_as_string(CONFIG))
	var rules_value: Variant=decoded.get("value")
	if not profile.get("ok",false) or not rules_value is Dictionary:
		_fail("Formal map-gen inputs unavailable");return
	_rules=rules_value
	if _rules.get("version")!=VERSION or _rules.get("sdk")!="0.4.1" or _rules.get("module_package")!="1.1.0" or original.map_index not in [1,2]:
		_fail("Unsupported formal map-gen profile");return
	if not _rules.get("module_ids") is Array or _rules.module_ids.is_empty():
		_fail("Formal module pool is empty");return
	var seed := seed_for(original.root_seed,original.map_index)
	var actual := REQUEST.from_controller(controller,controller.motor,seed,profile.request,true)
	if not actual.ok: _fail(actual.error);return
	_data=actual.request
	_data.module_filter={"regions":["平原"],"include_ids":_rules.module_ids.duplicate(),"exclude_ids":[]}
	_data.air_loop.enabled=true
	_config=profile.config.duplicate(true)
	_config.shape=_rules.shape.duplicate(true)
	_config.scoring.merge(_rules.scoring,true)
	_config.search.merge(_rules.search,true)
	_config.search.reserve_from_growth_count=int(_rules.reserve_from_growth_count)
	var goals: Dictionary=_rules.maps[original.map_index-1]
	for key: String in ["growth_target","reward_target","main_paths_required"]: _config.goals[key]=goals[key]
	_request=LevelRequest.new()
	_request.region_id=original.region_id;_request.map_index=original.map_index
	_request.tuning=original.tuning;_request.expected_hash=original.expected_hash
	_request.capabilities=original.capabilities.duplicate(true)
	_request.capabilities.collision_half_extents=actual.snapshot.collision.half_extents_pixels.duplicate()
	_request.capabilities.abilities=_data.player.abilities.duplicate()
	_request.capabilities.maximum_jumps=actual.snapshot.abilities.maximum_jumps
	_request.capabilities.maximum_air_shots=actual.snapshot.tuning.max_air_shots
	_request.capabilities["movement_projection"]="formal_plains_nominal_recoil_or_reverse_blink_v1"
	_recipe={
		"schema":"gunman-rush/runtime-map-bindings/v1", "version":VERSION,
		"selected_instances":[],
		"selection_recipe":{
			"schema":"gunman-rush/runtime-map-selection/v1", "kind":"whole_map",
			"root":{"module_id":"game-plains-windchime-lesson","content_version":"sha256:b2ee44df5422a7b4dd9be1358a075c46cefb00992de802607389f6f94ecfa433","role":"start"}
		},
		"spawn_rule":{"kind":"original_platform_top_center","instance":"root","platform_index":0},
		"spawns":{}, "host_profile_sha256":FileAccess.get_sha256(CONFIG), "filter_source_capacity":true
	}
	_start_attempt()

func _start_attempt() -> void:
	if _owner==null or not is_instance_valid(_owner.get_ref()) or not _lifetime.active:
		_fail("Map generation cancelled");return
	var seed := seed_for(_original.root_seed if _attempt==0 else _original.root_seed+"/attempt_%s" % _attempt,_original.map_index)
	_data.seed=seed;_request.root_seed=str(seed)
	_config.search.reserve_from_growth_count=int(_rules.retry_reserve_from_growth_count if _early_reservation else _rules.reserve_from_growth_count)
	ticket=generation.begin(_owner.get_ref(),_lifetime,_request,_data,_config,_recipe,[],"formal",int(_rules.operation_budget),bool(_rules.background_solve))
	if ticket==null: _fail("Map generation request refused")

func advance_map(lifetime: DemoLifetime) -> void:
	if phase!="loading": return
	generation.tick(ticket,lifetime)
	progress=generation.phase(ticket)
	if progress=="ready":
		var built := generation.take_plan(ticket,lifetime)
		if built==null: _fail("Generated map became stale");return
		_ready_usec=Time.get_ticks_usec()
		var result := generation.actual_result(ticket,lifetime)
		var problem := _bind_gameplay(built,result,_original.root_seed,generation.resolved_bindings(ticket,lifetime))
		if not problem.is_empty():
			generation.fail_assembly(ticket,problem);_fail(problem);return
		_pending=built;_pending_index=_original.map_index;_result=built;phase="ready"
	elif progress in ["failed","cancelled","stale",""]:
		var problem := generation.error(ticket)
		_failures.append(problem)
		_attempt_metrics.append(generation.metrics(ticket))
		if not lifetime.active or generation.metrics(ticket).get("generation_status")=="PASS":
			_fail(problem);return
		print("MAPGEN SEARCH attempt=",_attempt," seed=",_data.seed," reserve_from=",_config.search.reserve_from_growth_count," error=",problem)
		# Retry reservation placement with identical goals, abilities and seed.
		if _early_reservation:
			_attempt+=1
			_early_reservation=false
		else:
			_early_reservation=true
		if _attempt>=int(_rules.max_attempts): _fail("地图生成未完成，请返回家园后重新出发。")
		else: _start_attempt()

func result() -> LevelBuildResult:
	return _result if phase=="ready" else _reject(error)

func _fail(message: String) -> void:
	error=message;phase="failed"

func commit(lifetime: DemoLifetime) -> bool:
	if _pending==null: return true # Already committed map reloaded.
	if not generation.commit(ticket,lifetime): return false
	print("MAPGEN_TIMING "+JSON.stringify(timing_summary()))
	_maps[_pending_index]=_pending
	_pending=null
	return true

func timing_summary() -> Dictionary:
	var attempts:=_attempt_metrics.duplicate()
	attempts.append(generation.metrics(ticket))
	var summary: Dictionary={"attempts":attempts.size(),"preload_ms":0.0,"solve_ms":0.0,"failed_solve_ms":0.0,"validate_ms":0.0,"bind_assemble_ms":float(Time.get_ticks_usec()-_ready_usec)/1000.0,"total_ms":float(Time.get_ticks_usec()-_started_usec)/1000.0}
	for metrics: Dictionary in attempts:
		summary.preload_ms+=float(metrics.get("preload_wall_ms",0))
		summary.solve_ms+=float(metrics.get("generation_wall_ms",0))
		summary.validate_ms+=float(metrics.get("validate_ms",0))
		if metrics.get("generation_status")!="PASS":summary.failed_solve_ms+=float(metrics.get("generation_wall_ms",0))
	var current: Dictionary=attempts[-1]
	summary["backend"]=current.get("backend","cooperative")
	summary["library_warmup_ms"]=current.get("verified_library_receipt",{}).get("warmup",{}).get("wall_ms",0)
	return summary

func close() -> void:
	generation.close();_maps.clear();_pending=null;phase="cancelled";error="Map generation cancelled"

static func _bind_gameplay(built: LevelBuildResult, result: Dictionary, root_seed: String, bindings: Dictionary) -> String:
	var plan := built.plan
	var areas: Array = []
	var nodes: Array = []
	var encounter_rows: Array = []
	var latch_rows: Array = []
	var boss_found := false
	for placement: LevelModulePlacement in plan.modules:
		var instance: Dictionary=placement.definition.get_meta("runtime_map_v2_instance")
		var content: Dictionary=placement.definition.get_meta("runtime_map_v2_content")
		var bank := placement.position+placement.definition.entry_port.position
		var role := "tutorial" if instance.role=="start" else "boss" if instance.role=="boss" else "challenge_reward" if instance.role=="target_reward" else "exploration"
		var label := "BELLSTRIDER" if instance.role=="boss" and plan.map_index==1 else "WINDKEEPER" if instance.role=="boss" else "CACHE" if instance.role=="target_reward" else "MEADOW"
		areas.append({"id":placement.instance_id,"role":role,"label":label,"position":[bank.x,bank.y],"identity":"clock_court" if role=="boss" else "meadow"})
		nodes.append({"id":placement.instance_id,"module_id":str(placement.template_id),"offset":[placement.position.x,placement.position.y],"mirrored":bool(instance.transform.mirror_x)})
		if instance.role=="start":
			var side := -1.0
			for port: Dictionary in instance.ports:
				if port.id in instance.connected_port_ids: side=-1.0 if port.face=="RIGHT" else 1.0
			var rules: Dictionary=preload("res://addons/mapgen/data_json.gd").parse(FileAccess.get_file_as_string(CONFIG)).value
			plan.merchant_position=plan.spawn+Vector2(side*float(rules.camp_offset_from_spawn),0)
		if instance.role=="boss":
			if boss_found: return "Multiple generated Boss modules"
			boss_found=true
			var floor_rect := Rect2()
			for index: int in content.platforms.size():
				if index in content.one_way_platform_indices: continue
				var rectangle := RuntimeMapShotLatchAdapter.rectangle(content.platforms[index])
				if rectangle.size.x>floor_rect.size.x: floor_rect=rectangle
			if floor_rect.size.x<800: return "Generated Boss floor cannot support the existing encounter"
			plan.boss_arena=Rect2(placement.position+Vector2(floor_rect.position.x,0),Vector2(floor_rect.size.x,floor_rect.position.y))
			plan.boss={"definition_id":&"bellstrider" if plan.map_index==1 else &"windkeeper_storm","position":Vector2(plan.boss_arena.get_center().x,plan.boss_arena.end.y-65)}
		for raw: Dictionary in RuntimeMapContentAdapter.mechanisms(content):
			var latch := raw.duplicate(true)
			latch["id"]=RuntimeMapShotLatchAdapter.state_key(placement.instance_id,str(raw.id))
			latch["node_index"]=plan.modules.find(placement)
			latch_rows.append(latch)
		if instance.role=="target_reward":
			for raw: Dictionary in content.reward_sites:
				plan.caches.append({"id":"plains/map_%s/%s/%s/item" % [plan.map_index,placement.instance_id,raw.id],"tier":"medium" if plan.map_index==1 else "high","position":placement.position+Vector2(raw.position[0],raw.position[1]),"source":"mapgen_reward_site","coins":0,"items":[],"reward_mode":"item_resource","resources":[{"kind":"coin","amount":int(raw.amount)},{"kind":"note","amount":CacheRewardPolicy.note_amount("medium" if plan.map_index==1 else "high")}]})
	for actor: Dictionary in plan.actors:
		var definition := EnemyFactory.definition_for_behavior(actor.behavior_id,actor.overrides)
		encounter_rows.append({"id":actor.id,"behavior_id":str(actor.behavior_id),"position":[actor.position.x,actor.position.y],"patrol_radius":definition.patrol_half_width,"aerial":definition.aerial,"initial_idle_cooldown":actor.get("initial_idle_cooldown",0)})
	if not boss_found or plan.caches.is_empty() or plan.actors.is_empty(): return "Generated map lacks Boss, item reward sites or enemies"
	var drops := EnemyDropService.new()
	if not drops.configure(root_seed,"plains_region"): return "Native enemy drop configuration invalid"
	var drop_rows := {}
	for actor: Dictionary in plan.actors:
		drop_rows[str(actor.id)]=drops.settle(StringName(actor.id),StringName(actor.behavior_id))
	var edges: Array=[]
	for edge: Dictionary in plan.connections:
		edges.append({"id":edge.id,"a":str(edge.a.instance_id),"b":str(edge.b.instance_id),"kind":"exploration","condition":"open"})
	# Persist immutable SDK data; execution timings/diagnostics are observations,
	# so a fresh run with identical inputs retains the same Manifest source.
	var recorded_result := {}
	for field: String in ["schema","status","request_fingerprint","map","content_store"]: recorded_result[field]=result[field]
	var recorded_identity: Dictionary=plan.get_meta("runtime_map_v2_identity").duplicate(true)
	recorded_identity.erase("result_receipt_digest") # Digest includes SDK execution observations.
	var view := {
		"version":VERSION, "seed":PlainsRegionCampaign.seed_for(root_seed,plan.map_index),
		"difficulty":"intro" if plan.map_index==1 else "advanced", "family":"mapgen",
		"fallback_id":"", "manifest_hash":plan.map_hash,
		"world_bounds":[plan.bounds.position.x,plan.bounds.position.y,plan.bounds.size.x,plan.bounds.size.y],
		"areas":areas, "nodes":nodes, "connections":edges,
		"merchant_position":[plan.merchant_position.x,plan.merchant_position.y],
		"rewards":_cache_view(plan), "enemies":encounter_rows, "enemy_drops":drop_rows,
		"shot_latch_plan":{"version":VERSION,"latches":latch_rows},
		"mapgen":{
			"source_json":JSON.stringify({"result":recorded_result,"bindings":bindings,"identity":recorded_identity},"",true,true),
			"host_profile_sha256":FileAccess.get_sha256(CONFIG)
		}
	}
	built.legacy_generated={
		"placement_points":plan.anchors.duplicate(), "manifest":view,
		"stage_generator_version":VERSION, "boss_arena":plan.boss_arena,
		"encounter_plan":{"version":VERSION,"enemies":encounter_rows}
	}
	return plan.validation_error()

static func _cache_view(plan: LevelPlan) -> Array:
	var records: Array=[]
	for cache: Dictionary in plan.caches:
		var row := cache.duplicate(true)
		row.position=[cache.position.x,cache.position.y]
		records.append(row)
	return records

static func recorded_level(view: Dictionary, tuning: PlayerTuning, root_seed: String, map_index: int) -> LevelBuildResult:
	if view.get("version")!=VERSION or not view.get("mapgen") is Dictionary or view.get("seed")!=PlainsRegionCampaign.seed_for(root_seed,map_index): return _reject("Recorded map-gen identity invalid")
	# Typed decode preserves SDK integer inputs across a Godot JSON roundtrip.
	if view.mapgen.get("host_profile_sha256")!=FileAccess.get_sha256(CONFIG) or not view.mapgen.get("source_json") is String: return _reject("Recorded host/source profile unavailable")
	var typed: Dictionary=preload("res://addons/mapgen/data_json.gd").parse(view.mapgen.source_json)
	if not typed.get("ok",false) or not typed.get("value") is Dictionary: return _reject("Invalid recorded source data")
	var source: Dictionary=typed.value
	if not source.get("result") is Dictionary or not source.get("bindings") is Dictionary or not source.get("identity") is Dictionary: return _reject("Recorded host/source profile unavailable")
	if not source.result.get("map") is Dictionary or not source.result.map.get("seed") is int or not source.result.map.get("instances") is Array: return _reject("Recorded source map invalid")
	var profile_hash := FileAccess.get_sha256(CONFIG)
	if not source.bindings.get("selection_recipe") is Dictionary or source.bindings.get("version")!=VERSION or source.bindings.get("host_profile_sha256")!=profile_hash or source.bindings.selection_recipe.get("kind")!="whole_map": return _reject("Recorded formal bindings differ")
	var rules: Dictionary=preload("res://addons/mapgen/data_json.gd").parse(FileAccess.get_file_as_string(CONFIG)).value
	var accepted_seed := false
	for attempt: int in int(rules.max_attempts):
		if source.result.map.seed==seed_for(root_seed if attempt==0 else root_seed+"/attempt_%s" % attempt,map_index): accepted_seed=true;break
	if not accepted_seed: return _reject("Recorded SDK seed differs from the run/map namespace")
	for instance: Variant in source.result.map.instances:
		if not instance is Dictionary or instance.get("module_id") not in rules.module_ids: return _reject("Recorded module is outside the formal pool")
	var identity: Dictionary=source.identity
	if not identity.get("host_load") is Dictionary or not identity.get("source_receipt") is Dictionary: return _reject("Missing recorded binding receipt")
	var load_data: Dictionary=identity.host_load
	if load_data.get("region_id")!="plains" or load_data.get("map_index")!=map_index or not load_data.get("capabilities") is Dictionary: return _reject("Recorded load scope differs")
	var request := LevelRequest.new()
	request.root_seed=str(int(source.result.map.seed));request.region_id=&"plains";request.map_index=map_index
	request.tuning=tuning;request.expected_hash=str(view.get("manifest_hash",""));request.capabilities=load_data.capabilities
	if request.expected_hash.is_empty() or not LevelContentValidation.point(load_data.get("spawn")) or not load_data.get("selected_instances") is Array: return _reject("Recorded map hash/spawn missing")
	var ids: Array[String]=[]
	for id: Variant in load_data.get("selected_instances",[]): ids.append(str(id))
	if ids.size()!=source.result.map.instances.size(): return _reject("Recorded source is not a complete map")
	var built := RuntimeMapV2Provider.load_generated_level(request,source.result,ids,Vector2(load_data.spawn[0],load_data.spawn[1]),source.bindings,identity.source_receipt,"formal")
	if not built.accepted(): return built
	var error := _bind_gameplay(built,source.result,root_seed,source.bindings)
	if not error.is_empty(): return _reject(error)
	if not RandomStageGenerator.new()._same_data(view,built.legacy_generated.manifest): return _reject("Recorded source view differs from actual map bindings")
	return built

static func _reject(error: String) -> LevelBuildResult:
	var result := LevelBuildResult.new();result.error=error;return result

extends SceneTree
## Real locked addon once to PASS; lifecycle probes use the public opaque API.
## No replacement solver, invented generated map, SceneTree assembly or timing SLA.
const SOURCE := preload("res://game/world/generation/mapgen/runtime_map_generation_job.gd")
const DATA := preload("res://addons/mapgen/data_json.gd")
const PROTOCOL := preload("res://addons/mapgen/protocol.gd")
const PROFILE := preload("res://game/world/generation/mapgen/runtime_map_generation_profile.gd")
const HOST := preload("res://experiments/generation/runtime_map_generated_slice.gd")
const GEARS_HOST := preload("res://experiments/generation/runtime_map_m35_slice.gd")
const VERIFIED_LIBRARY := preload("res://game/world/generation/mapgen/runtime_map_verified_library_cache.gd")
const SELECTION := preload("res://game/world/generation/mapgen/runtime_map_generated_selection.gd")
const IDS: Array[String] = []
const MAX_ADVANCE_CALLS := 10000 # Same bounded frame cohort as the existing entrance test;04 work units differ.
var checks := 0
var failures := 0
var request_data: Dictionary = {}
var config: Dictionary = {}
var bindings: Dictionary = {}
var lock: Dictionary = {}
var cold_preloads := 0
var warm_preloads := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("GENERATION JOB: "+label)

func host_request() -> LevelRequest:
	var request := LevelRequest.new()
	request.root_seed = str(request_data.seed)
	request.tuning = PlayerTuning.load_default()
	request.capabilities = {"profile":"explicit_upstream_conformance_not_a_player_grant","collision_half_extents":request_data.player.clearance_half_extents_pixels.duplicate()}
	return request

func start(source: SOURCE, owner: Object, lifetime: DemoLifetime, budget: int = 128) -> RefCounted:
	return source.begin(owner,lifetime,host_request(),request_data,config,bindings,IDS,"seam",budget)

func rejected(source: SOURCE, ticket: RefCounted, lifetime: DemoLifetime, label: String) -> void:
	check(not source.is_current(ticket,lifetime),label+": not current")
	check(not source.tick(ticket,lifetime),label+": cannot tick")
	check(source.take_plan(ticket,lifetime)==null,label+": cannot take plan")
	check(not source.commit(ticket,lifetime),label+": cannot commit")
	check(source.actual_result(ticket,lifetime).is_empty() and source.provenance(ticket,lifetime).is_empty(),label+": no result/provenance escape")
	check(source.output_summary(ticket,lifetime).is_empty() and source.request_abilities(ticket,lifetime).is_empty(),label+": no narrow result/input escape")

func preload_source(source: SOURCE, ticket: RefCounted, lifetime: DemoLifetime) -> bool:
	var started := Time.get_ticks_msec()
	var ticks := 0
	var accepted := true
	var frames_waited := 0
	var batch := 128 if int(source.metrics(ticket).operation_budget)==1 else 1
	while source.phase(ticket)=="preload" and frames_waited<10000 and Time.get_ticks_msec()-started<60000:
		# Pure-data setup only: batch tiny preload ticks for the one-unit
		# continuation probe; live entrance runners retain one tick per frame.
		for step: int in batch:
			if source.phase(ticket)!="preload": break
			accepted = source.tick(ticket,lifetime)
			ticks += 1
			if not accepted: break
		if not accepted: break
		await process_frame
		frames_waited += 1
	check(accepted and source.phase(ticket)=="generate","cooperative preload verifies actual archive before original generation: "+source.error(ticket))
	if not accepted or source.phase(ticket)!="generate": return false
	check(int(source.progress(ticket).get("operations",-1))==0 and int(source.metrics(ticket).advance_calls)==0,"cooperative preload does not consume generation work units")
	var preload_receipt := source.metrics(ticket)
	var hit: bool = preload_receipt.get("preload_cache_hit",false)
	if hit: warm_preloads += 1
	else: cold_preloads += 1
	# Cold verification retains its original exact-unit receipt assertion. Warm
	# jobs consume no ZIP work and must cite the already verified immutable DATA.
	check((int(preload_receipt.preload_calls)>0 if not hit else int(preload_receipt.preload_calls)==0) and preload_receipt.preload_tick_ms.size()==ticks,"each preload host tick has measured receipt with exact original units; verified cache hit performs zero ZIP units")
	var verified: Dictionary = preload_receipt.get("verified_library_receipt",{})
	check(verified.get("module_sha256")==lock.module_package.sha256 and verified.get("sdk_version")==lock.version and verified.get("checked_files",0)>0 and verified.get("source_json_read_only",false) and verified.get("source_files_read_only",false),"cold or warm admission cites fully verified immutable archive under exact SDK identity")
	check(not preload_receipt.has("preload_profile") if hit else preload_receipt.has("preload_profile"),"cache hit does not fabricate a new original SDK preload profile")
	return true

func suspended(source: SOURCE, ticket: RefCounted, lifetime: DemoLifetime) -> bool:
	if not await preload_source(source,ticket,lifetime): return false
	var accepted := source.tick(ticket,lifetime)
	var progress: Dictionary = source.progress(ticket)
	check(accepted and source.phase(ticket)=="generate" and not progress.get("done",true) and int(progress.get("operations",0))>0,"actual job has a suspended positive-operation continuation")
	return accepted and source.phase(ticket)=="generate" and not progress.get("done",true)

func run() -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/mapgen_candidate.json"))
	check(value is Dictionary,"actual candidate installation lock exists")
	if not value is Dictionary:
		finish()
		return
	lock = value
	var input_bytes_ok := true
	for input: Dictionary in [lock.conformance.request,lock.conformance.config]:
		input_bytes_ok = input_bytes_ok and FileAccess.get_sha256(input.path)==input.sha256
	check(input_bytes_ok,"actual conformance request/config bytes retain installation lock")
	if not input_bytes_ok:
		finish()
		return
	var inputs := PROFILE.read_profile(HOST.DEFAULT_INPUT_PROFILE)
	var host := RuntimeMapFrozenSource.read_binding_file(HOST.DEFAULT_BINDINGS_PATH,HOST.DEFAULT_BINDINGS_SHA256)
	check(inputs.ok and host.ok,"original typed profile inputs and exact new host recipe only; no frozen map/content read")
	if not inputs.ok or not host.ok:
		finish()
		return
	request_data = inputs.request
	config = inputs.config
	bindings = host.bindings
	check(request_data.seed is int and request_data.seed==930001,"fixture declares original upstream conformance; no float seed coercion or player grant")
	var nodes_before := get_node_count()
	value_snapshot_contract()
	context_rejections()
	await queued_owner_rejection()
	cache_key_and_partial_preload_contract()
	await cancellation_checkpoints()
	await warm_cache_isolation_contract()
	await disposal_contract()
	await budget_failure_contract()
	await replacement_then_success()
	check(cold_preloads==1 and warm_preloads>1,"one actual library verification serves distinct source instances; close/failure/replacement retain verified DATA")
	check(get_node_count()==nodes_before,"source/Provider lifecycle did not create any scene nodes")
	finish()

func tuning_values(tuning: PlayerTuning) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in tuning.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
		var key := str(property.name)
		var value: Variant = tuning.get(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

func value_snapshot_contract() -> void:
	var source := SOURCE.new()
	var request := host_request()
	# Deliberate effective tuning changes prove this is not reconstruction from
	# PlayerTuning.load_default or Resource's exported-property duplication.
	request.tuning.ground_speed += 13.0
	request.tuning.gravity += 17.0
	request.tuning.jump_speeds[0] += 23.0
	request.capabilities["nested"] = {"samples":[1,2]}
	var expected := tuning_values(request.tuning)
	# Isolated pure value-copy unit only; never inspect or mutate ticket state.
	var copied: LevelRequest = source._copy_request(request)
	check(copied!=request and copied.tuning!=request.tuning,"request and actual PlayerTuning snapshot have detached object identities")
	check(not expected.is_empty(),"snapshot counterexample includes actual script-variable values")
	for field: String in expected:
		check(copied.tuning.get(field)==expected[field],"all actual non-export tuning fields copied exactly: "+field)
	request.tuning.ground_speed += 29.0
	request.tuning.gravity += 31.0
	request.tuning.jump_speeds[0] += 37.0
	request.capabilities.nested.samples[0] = 99
	request.root_seed = "changed after snapshot"
	check(tuning_values(copied.tuning)==expected,"caller later scalar/array tuning mutations cannot change exact captured snapshot")
	check(copied.capabilities.nested.samples==[1,2] and copied.root_seed==str(request_data.seed),"caller later nested capability/request mutation cannot change captured values")
	copied.tuning.jump_speeds[0] += 41.0
	check(copied.tuning.jump_speeds!=request.tuning.jump_speeds,"snapshot tuning array mutations cannot change caller tuning")
	source.close()

func context_rejections() -> void:
	var owner := RefCounted.new()
	var source := SOURCE.new()
	var lifetime := DemoLifetime.new()
	var ticket := start(source,owner,lifetime)
	check(ticket != null and ticket.get_script()==null,"public ticket is a plain RefCounted handle, not internal scripted state")
	var names: Array[String] = []
	for property: Dictionary in ticket.get_property_list(): names.append(str(property.name))
	for field: String in ["actual","provenance","phase","token","lifetime","request","taken","committed"]:
		check(field not in names,"opaque handle exposes no internal field: "+field)
	ticket.set_meta("phase","ready")
	ticket.set_meta("actual",{"status":"PASS"})
	check(source.phase(ticket)=="preload" and source.actual_result(ticket,lifetime).is_empty(),"caller handle metadata cannot forge phase or actual result")
	check(source.take_plan(ticket,lifetime)==null and not source.commit(ticket,lifetime) and not source.fail_assembly(ticket,"not assembling"),"preload cannot be consumed, committed or marked as assembly")
	var impostor := RefCounted.new()
	rejected(source,impostor,lifetime,"unissued handle")
	check(source.is_current(ticket,lifetime) and source.phase(ticket)=="preload","foreign handle rejection leaves current ticket usable")
	var equal_epoch := DemoLifetime.new()
	check(lifetime.token().key()==equal_epoch.token().key() and lifetime!=equal_epoch,"distinct real DemoLifetime objects share numeric epochs in counterexample")
	rejected(source,ticket,equal_epoch,"same-epoch different actual lifetime")
	check(source.phase(ticket)=="cancelled","wrong actual lifetime cancels only its current old job")
	var fresh := start(source,owner,equal_epoch)
	check(source.is_current(fresh,equal_epoch),"same source accepts new ticket with replacement actual lifetime")
	check(not source.abort(ticket,"late old abort") and source.phase(fresh)=="preload","old handle cannot cancel replacement")
	equal_epoch.invalidate_actor()
	rejected(source,fresh,equal_epoch,"actual actor invalidation")
	source.close()

	var ended_source := SOURCE.new()
	var ended_lifetime := DemoLifetime.new()
	var ended := start(ended_source,owner,ended_lifetime)
	ended_lifetime.end()
	rejected(ended_source,ended,ended_lifetime,"actual run end")
	ended_source.close()

	var flow := DemoRunDirector.new()
	check(flow.start("generation-job-stage-boundary",RunProfile.development()).accepted(),"real run director starts stage invalidation counterexample")
	var stage_source := SOURCE.new()
	var stage_ticket := start(stage_source,owner,flow.lifetime)
	var stage_token := flow.lifetime.token()
	check(flow.complete_stage(stage_token) and not flow.offers.is_empty(),"real run owner supplies stage transition offer")
	if not flow.offers.is_empty():
		check(flow.select_exit(stage_token,flow.offers[0].exit_id,&"generation-job-next-stage").accepted(),"original run owner advances stage/actor epochs")
		rejected(stage_source,stage_ticket,flow.lifetime,"actual stage transition")
	stage_source.close()
	flow.end_failure(&"generation-job-test-cleanup")

	var weak_owner: RefCounted = RefCounted.new()
	var owner_reference: WeakRef = weakref(weak_owner)
	var freed_source := SOURCE.new()
	var freed_lifetime := DemoLifetime.new()
	var freed_ticket := start(freed_source,weak_owner,freed_lifetime)
	weak_owner = null
	check(owner_reference.get_ref()==null,"source retains only WeakRef to the actual owner")
	rejected(freed_source,freed_ticket,freed_lifetime,"freed owner")
	freed_source.close()

func queued_owner_rejection() -> void:
	var owner := Node.new()
	root.add_child(owner)
	var source := SOURCE.new()
	var lifetime := DemoLifetime.new()
	var ticket := start(source,owner,lifetime)
	owner.queue_free()
	check(is_instance_valid(owner) and owner.is_queued_for_deletion(),"owner counterexample is queued before actual free")
	rejected(source,ticket,lifetime,"owner queued for deletion")
	source.close()
	await process_frame

func cache_key_and_partial_preload_contract() -> void:
	# This standalone runner starts with no published cache; never inject a fake
	# archive or clear a ready global library to make a test pass.
	check(not VERIFIED_LIBRARY.has_verified(lock),"fresh process starts without an unverified ready library")
	var key := VERIFIED_LIBRARY.cache_key(lock)
	for field: String in ["version","implementation","algorithm","release_head","source_commit"]:
		var changed := lock.duplicate(true)
		changed[field] = "different-"+str(changed[field])
		check(VERIFIED_LIBRARY.cache_key(changed)!=key and not VERIFIED_LIBRARY.has_verified(changed),"verified library isolates actual SDK identity field "+field)
	for section: String in ["module_package","archive"]:
		var changed := lock.duplicate(true)
		changed[section].sha256 = "0".repeat(64)
		check(VERIFIED_LIBRARY.cache_key(changed)!=key and not VERIFIED_LIBRARY.has_verified(changed),"verified library isolates actual archive SHA "+section)
	var owner := RefCounted.new()
	var lifetime := DemoLifetime.new()
	var source := SOURCE.new()
	var ticket := start(source,owner,lifetime,1)
	check(source.tick(ticket,lifetime) and source.phase(ticket)=="preload" and int(source.metrics(ticket).preload_calls)==1,"partial real cooperative preload executes exactly one original unit")
	source.close()
	check(not VERIFIED_LIBRARY.has_verified(lock) and VERIFIED_LIBRARY.receipt(lock).is_empty(),"cancelled partial verification never publishes ready library data")
	rejected(source,ticket,lifetime,"closed partial library preload")

func warm_cache_isolation_contract() -> void:
	var owner := RefCounted.new()
	var life_a := DemoLifetime.new()
	var life_b := DemoLifetime.new()
	var first := SOURCE.new()
	var second := SOURCE.new()
	var a := start(first,owner,life_a,1)
	var b := start(second,owner,life_b,1)
	if await preload_source(first,a,life_a) and await preload_source(second,b,life_b):
		check(first.metrics(a).preload_cache_hit and second.metrics(b).preload_cache_hit,"separate source objects share only verified library admission")
		var metadata := VERIFIED_LIBRARY.receipt(lock)
		metadata.module_sha256 = "caller mutation"
		check(VERIFIED_LIBRARY.receipt(lock).module_sha256==lock.module_package.sha256 and not metadata.has("library"),"cache metadata is a copy and exposes no mutable SDK archive")
		check(first.tick(a,life_a) and int(first.progress(a).operations)==1 and int(second.progress(b).operations)==0,"advancing one cached job leaves the other original SDK continuation untouched")
		first.close()
		check(second.tick(b,life_b) and int(second.progress(b).operations)==1,"cancelling one cached job does not cancel another preparation continuation")
		check(VERIFIED_LIBRARY.has_verified(lock),"source exit retains the global verified library")
	first.close()
	second.close()

func cancellation_checkpoints() -> void:
	var owner := RefCounted.new()
	var lifetime := DemoLifetime.new()
	var token_before := lifetime.token().key()
	var early := SOURCE.new()
	var early_ticket := start(early,owner,lifetime)
	early.close()
	early.close()
	rejected(early,early_ticket,lifetime,"close during preload")
	check(early.begin(owner,lifetime,host_request(),request_data,config,bindings,IDS)==null,"closed source rejects begin")

	var created := SOURCE.new()
	var created_ticket := start(created,owner,lifetime)
	if await preload_source(created,created_ticket,lifetime):
		check(created.abort(created_ticket,"cancel before first advance"),"cancel actual created addon job before first advance")
		check(created.phase(created_ticket)=="cancelled" and created.progress(created_ticket).get("done",false) and int(created.metrics(created_ticket).operations)==0,"upstream cancellation completes created job with zero operations")
		rejected(created,created_ticket,lifetime,"cancelled before advance")
	created.close()

	var suspended_source := SOURCE.new()
	var suspended_ticket := start(suspended_source,owner,lifetime,1)
	if await suspended(suspended_source,suspended_ticket,lifetime):
		check(int(suspended_source.progress(suspended_ticket).operations)==1,"one original work unit16checkpoints, not one millisecond, reaches actual suspended checkpoint")
		suspended_source.close()
		check(suspended_source.phase(suspended_ticket)=="cancelled" and suspended_source.progress(suspended_ticket).get("done",false),"close unwinds actual suspended addon continuation")
		rejected(suspended_source,suspended_ticket,lifetime,"exit during suspended generation")
	suspended_source.close()
	check(lifetime.active and lifetime.token().key()==token_before,"source cancellation never ends or advances caller's lifetime")

func disposal_contract() -> void:
	var owner := RefCounted.new()
	var lifetime := DemoLifetime.new()
	var token_before := lifetime.token().key()
	var explicit_source: SOURCE = SOURCE.new()
	var explicit_ticket := start(explicit_source,owner,lifetime)
	var explicit_reference: WeakRef = weakref(explicit_source)
	explicit_source.close()
	explicit_source = null
	check(explicit_reference.get_ref()==null and explicit_ticket.get_script()==null,"explicitly closed source releases without PREDELETE self dispatch while opaque handle survives")
	var unclosed_source: SOURCE = SOURCE.new()
	var unclosed_ticket := start(unclosed_source,owner,lifetime,1)
	var unclosed_reference: WeakRef = weakref(unclosed_source)
	if await suspended(unclosed_source,unclosed_ticket,lifetime):
		# The fallback must unwind the real suspended continuation directly.
		# The original wrapper's strict engine-error/leak gate observes disposal.
		var references_before_release := unclosed_source.get_reference_count()
		unclosed_source = null
		var released_before_frame := unclosed_reference.get_ref()==null
		#04 preload/suspended helpers await frames; allow their completed coroutine
		#call-stack temporaries to clear before checking actual ownership release.
		await process_frame
		var released_after_frame := unclosed_reference.get_ref()==null
		print("RUNTIME_MAP_GENERATION_JOB_DISPOSAL ",JSON.stringify({"references_before_release":references_before_release,"released_before_frame":released_before_frame,"released_after_frame":released_after_frame,"scope":"one frame for completed async helper stack temporaries; no production destructor change"}))
		check(released_after_frame and unclosed_ticket.get_script()==null,"PREDELETE fallback releases unclosed suspended work after completed async helper stack cleanup")
	else:
		unclosed_source.close()
		unclosed_source = null
	check(lifetime.active and lifetime.token().key()==token_before,"either disposal path leaves caller lifetime authority unchanged")

func budget_failure_contract() -> void:
	# Explicit guard counterexample only. Keep the actual normal profile/seed,
	# locked resource bytes and existing positive contract completely unchanged.
	var normal_config := DATA.canonical(config)
	var normal_request := DATA.canonical(request_data)
	var normal_bindings := DATA.canonical(bindings)
	var constrained: Dictionary = config.duplicate(true)
	constrained.search.candidate_expansion_budget = 1
	var owner := RefCounted.new()
	var lifetime := DemoLifetime.new()
	var token_before := lifetime.token().key()
	var source := SOURCE.new()
	var ticket := source.begin(owner,lifetime,host_request(),request_data,constrained,bindings,IDS)
	check(ticket!=null and source.phase(ticket)=="preload","real budget guard begins with accepted typed SDK inputs and a private config copy")
	if ticket==null:
		source.close()
		return
	if not await preload_source(source,ticket,lifetime):
		source.close()
		return
	var calls := 0
	while source.phase(ticket)=="generate" and calls<MAX_ADVANCE_CALLS:
		var advanced := source.tick(ticket,lifetime)
		calls += 1
		if not advanced: break
		await process_frame
	check(source.phase(ticket)=="validate","original SDK budget exhaustion reaches the separate validate phase")
	if source.phase(ticket)!="validate":
		source.close()
		return
	# Read the original result while it is still an unconsumed validation
	# candidate, before the failed host envelope deliberately closes result access.
	var actual: Dictionary = source.actual_result(ticket,lifetime)
	check(actual.get("status")=="BUDGET_EXHAUSTED" and actual.get("schema")=="mapgen/generation-result/v1","actual original SDK reports its budget status and result schema")
	check(source.output_summary(ticket,lifetime).is_empty(),"real SDK budget failure with null map/store has no output summary before host validation")
	var diagnostics: Dictionary = actual.get("diagnostics",{})
	var sdk_error: Dictionary = diagnostics.get("error",{})
	check(sdk_error.get("message")=="candidate_expansion_budget" and not str(sdk_error.get("phase","")).is_empty(),"actual SDK error identifies candidate_expansion_budget and its genuine phase")
	check(not source.tick(ticket,lifetime) and source.phase(ticket)=="failed","validate rejects actual non-PASS SDK result without offering a plan")
	var message := source.error(ticket)
	check("BUDGET_EXHAUSTED" in message and "mapgen/generation-result/v1" in message and "candidate_expansion_budget" in message,"host failure exposes original SDK status/schema/message instead of generic not-PASS")
	var decoded := JSON.new()
	var code := decoded.parse(message.trim_prefix("generation result rejected: "))
	var forwarded: Variant = decoded.data
	check(code==OK and forwarded is Dictionary and forwarded.get("status")==actual.get("status") and forwarded.get("schema")==actual.get("schema") and forwarded.get("error")==sdk_error,"forwarded structured diagnostics preserve exact real SDK error fields")
	var receipt: Dictionary = source.metrics(ticket)
	check(receipt.get("generation_status")==actual.get("status") and int(receipt.advance_calls)>0 and receipt.get("generation_profile") is Dictionary,"real failure metrics retain actual SDK status and performed generation work/profile")
	check(float(receipt.soft_tick_ms)==SOURCE.SOFT_TICK_MS,"soft timing receipt comes from the single production constant, not a duplicated4ms value")
	rejected(source,ticket,lifetime,"real SDK candidate-budget exhaustion")
	check(source.resolved_bindings(ticket,lifetime).is_empty(),"failed budget result exposes no resolved binding or Provider admission")
	check(DATA.canonical(config)==normal_config and DATA.canonical(request_data)==normal_request and DATA.canonical(bindings)==normal_bindings,"budget guard leaves normal algorithm config, seed and actual host recipe untouched")
	check(lifetime.active and lifetime.token().key()==token_before,"budget failure does not become a second run/lifetime authority")
	print("RUNTIME_MAP_GENERATION_JOB_BUDGET_FAILURE ",JSON.stringify({"status":actual.get("status"),"schema":actual.get("schema"),"sdk_error":sdk_error,"forwarded_error":message,"generation_status":receipt.get("generation_status"),"soft_tick_ms":receipt.soft_tick_ms,"candidate_expansion_budget":constrained.search.candidate_expansion_budget,"seed":request_data.seed,"scope":"real SDK guard counterexample only; normal profile unchanged"}))
	source.close()

func replacement_then_success() -> void:
	var owner := RefCounted.new()
	var lifetime := DemoLifetime.new()
	var source := SOURCE.new()
	var old_ticket := start(source,owner,lifetime)
	var old_serial := source.request_serial(old_ticket)
	if not await suspended(source,old_ticket,lifetime):
		source.close()
		return
	var caller_request: Dictionary = request_data.duplicate(true)
	var caller_config: Dictionary = config.duplicate(true)
	var caller_bindings: Dictionary = bindings.duplicate(true)
	var selected: Array[String] = IDS.duplicate()
	var request := host_request()
	var expected: String = PROTOCOL.fingerprint(caller_request,caller_config,lock.module_package.sha256)
	var ticket := source.begin(owner,lifetime,request,caller_request,caller_config,caller_bindings,selected)
	check(source.request_serial(ticket)==old_serial+1,"replacement allocates a strictly newer serial after cancelling old real job")
	rejected(source,old_ticket,lifetime,"superseded suspended request")
	check(not source.abort(old_ticket,"late cancellation") and not source.fail_assembly(old_ticket,"late assembly failure") and source.phase(ticket)=="preload","stale cancel/failure cannot modify newest ticket")
	# Mutate caller-owned values after begin. The real generation must retain its
	# captured original integer request, config, host bindings and LevelRequest.
	caller_request.seed = 7
	caller_config.goals.growth_target = 1
	caller_bindings.spawn_rule.platform_index = 99
	selected.clear()
	request.root_seed = "caller-mutated"
	request.expected_hash = "a".repeat(64)
	request.capabilities.profile = "caller-mutated"
	request.tuning.ground_speed = 0.0
	request.tuning.max_jumps = 0
	request.tuning.jump_speeds.clear()
	if not await preload_source(source,ticket,lifetime):
		source.close()
		return
	var calls := 0
	var configured_cap := int(source.metrics(ticket).configured_work_unit_cap)
	var previous_operations := 0
	while source.phase(ticket)=="generate" and calls<MAX_ADVANCE_CALLS:
		var advanced := source.tick(ticket,lifetime)
		calls += 1
		var operations := int(source.progress(ticket).get("operations",0))
		check(advanced and operations>previous_operations and operations-previous_operations<=configured_cap,"real host tick respects its configured original work-unit cap, each16checkpoints")
		previous_operations = operations
		if not advanced: break
		await process_frame
	check(source.phase(ticket)=="validate","completed original addon result awaits a separate validate tick: "+source.error(ticket))
	if source.phase(ticket)!="validate":
		source.close()
		return
	check(source.take_plan(ticket,lifetime)==null and not source.commit(ticket,lifetime),"completed generation cannot skip Provider validation")
	check(source.tick(ticket,lifetime) and source.phase(ticket)=="ready","real generated result passes original Provider: "+source.error(ticket))
	if source.phase(ticket)!="ready":
		source.close()
		return
	var actual: Dictionary = source.actual_result(ticket,lifetime)
	var origin: Dictionary = source.provenance(ticket,lifetime)
	check(actual.status=="PASS" and actual.request_fingerprint==expected and actual.map.generator.request_fingerprint==expected,"wrapper preserves original result/map fingerprint of captured inputs")
	check(actual.map.map_id=="map-"+expected.substr(0,24),"original generated map_id remains unchanged")
	var summary := source.output_summary(ticket,lifetime)
	check(summary=={"status":actual.status,"seed":actual.map.seed,"request_fingerprint":actual.request_fingerprint,"instances":actual.map.instances.size(),"connections":actual.map.connections.size(),"content_entries":actual.content_store.size()},"narrow output summary exactly matches original result without copying full map/store")
	summary.status = "caller mutation"
	var abilities := source.request_abilities(ticket,lifetime)
	abilities.clear()
	check(source.output_summary(ticket,lifetime).status=="PASS" and source.request_abilities(ticket,lifetime)==request_data.player.abilities,"narrow summary and abilities never expose mutable source data")
	check(origin.kind=="generated_memory" and origin.request.seed==930001 and origin.config.goals.growth_target==32,"provenance binds actual captured algorithm values")
	check(origin.algorithm_package.zip_sha256==lock.archive.sha256 and origin.algorithm_package.release_head==lock.release_head and origin.algorithm_package.source_commit==lock.source_commit and origin.module_archive.sha256==lock.module_package.sha256,"provenance uses actual installed release and opened module archive")
	check(not origin.has("files") and not origin.has("bindings_file") and not origin.has("map_bytes_sha256"),"memory job makes no fabricated file byte attestations")
	actual.map.generator.request_fingerprint = "tampered"
	actual.map.map_id = "tampered"
	origin.kind = "frozen_files"
	origin.request.seed = 8
	check(source.actual_result(ticket,lifetime).map.generator.request_fingerprint==expected and source.provenance(ticket,lifetime).request.seed==930001,"actual_result/provenance nested copies cannot mutate internal job state")
	var receipt: Dictionary = source.metrics(ticket)
	var history: Array[Dictionary] = source.progress_history(ticket)
	check(int(receipt.operations)==int(ceil(float(receipt.microsteps)/16.0)) and int(receipt.advance_calls)==int(receipt.operations) and int(receipt.advance_ticks)==calls,"actual04 checkpoint count maps exactly to original16-checkpoint units and measured host ticks")
	check(history.size()==calls+1 and history[0].operations==0 and history.back().done,"initial plus each host-tick progress sample is retained; exact SDK phase profile covers internal unit transitions")
	check(receipt.preload_ms>0.0 and receipt.validate_ms>=0.0 and receipt.advance_tick_ms.size()==calls and receipt.advance_max_ms>=0.0,"preload, each actual advance/max and Provider validation have separate receipts without16ms claim")
	check(receipt.generation_execution_ms>=receipt.advance_unit_total_ms and receipt.generation_wall_ms>=receipt.generation_execution_ms and receipt.between_tick_gap_ms>0.0,"execution intervals and between-tick caller/frame gaps are separated from generation wall time")
	check(receipt.sdk_result_snapshot_execution_ms>=0.0 and receipt.fingerprint_execution_ms>=0.0 and receipt.selection_execution_ms>=0.0 and receipt.provider_execution_ms>=0.0 and receipt.sdk_profile_capture_execution_ms>=0.0 and receipt.generation_progress_sample_execution_ms>=0.0,"actual host snapshot/fingerprint/selection/Provider/profile/progress costs have separate receipts")
	check(receipt.preload_cache_hit and int(receipt.preload_calls)==0 and receipt.provider_profile is Dictionary,"successful real generation uses warm verified source and retains original Provider diagnostic profile")
	history[0].operations = -1
	receipt.advance_tick_ms.clear()
	var progress_copy: Dictionary = source.progress(ticket)
	progress_copy.operations = -1
	check(source.progress_history(ticket)[0].operations==0 and source.metrics(ticket).advance_tick_ms.size()==calls and int(source.progress(ticket).microsteps)==int(receipt.microsteps),"progress/history/timing getters deep-copy nested mutable data")
	var built := source.take_plan(ticket,lifetime)
	check(built != null and built.accepted() and source.phase(ticket)=="assemble","ready plan is offered once for caller-owned assembly")
	if built == null or not built.accepted():
		source.close()
		return
	var resolved := SELECTION.resolve(source.actual_result(ticket,lifetime),bindings,Vector2(request_data.player.clearance_half_extents_pixels[0],request_data.player.clearance_half_extents_pixels[1]))
	check(resolved.ok and built.plan.seed==str(request_data.seed) and built.plan.spawn==resolved.spawn and built.plan.modules.size()==resolved.ids.size() and built.legacy_generated.is_empty(),"captured actual recipe resolves template/version/topology and original-platform spawn without pinned IDs or legacy compatibility")
	check(built.plan.get_meta("runtime_map_v2_identity").host_load.capabilities.profile=="explicit_upstream_conformance_not_a_player_grant","caller capability mutation cannot relabel admitted plan")
	check(source.take_plan(ticket,lifetime)==null,"duplicate plan consumption is refused")
	check(source.commit(ticket,lifetime) and source.phase(ticket)=="committed","newest real validated plan commits exactly once")
	check(not source.commit(ticket,lifetime) and not source.fail_assembly(ticket,"late failure") and not source.abort(ticket,"late abort"),"duplicate commit/late failure/abort cannot alter committed state")
	await cross_profile_warm_success(source,ticket,lifetime,built)
	var timings: Dictionary = source.metrics(ticket)
	print("RUNTIME_MAP_GENERATION_JOB_METRICS ",JSON.stringify({"operations":timings.operations,"advance_calls":timings.advance_calls,"preload_ms":timings.preload_ms,"advance_max_ms":timings.advance_max_ms,"validate_ms":timings.validate_ms,"request_fingerprint":expected,"scope":"source_envelope_and_pure_plan_only"}))
	source.close()
	rejected(source,ticket,lifetime,"closed committed source")
	check(lifetime.active,"closing committed source does not end RunSession authority")

func cross_profile_warm_success(previous: SOURCE, previous_ticket: RefCounted, previous_lifetime: DemoLifetime, previous_built: LevelBuildResult) -> void:
	# Same-process regression against the measured 0.4.1 original 930007 result.
	# The original 0.4.0 baseline remains an explicit rejected identity. This is a
	# test oracle, never a runtime selection/config/geometry authority. Host-load
	# identity is intentionally not the real controller's 6f1...: this pure data
	# runner declares the existing Provider fixture's explicit capability profile.
	const GOLDEN_040_GEARS_MAP_CONTENT := "c652943fe8e5e50c2b21242cc09530228a12d1a7fbfb08975977da5a4e835d97"
	const GOLDEN_GEARS_MAP_CONTENT := "273410cebf375c38f52783ea8edc281003ed6b2dfb19b40bd85d1a9542bd5eee"
	var previous_result := DATA.canonical(previous.actual_result(previous_ticket,previous_lifetime))
	var previous_provenance := DATA.canonical(previous.provenance(previous_ticket,previous_lifetime))
	var previous_identity: Dictionary = previous_built.plan.get_meta("runtime_map_v2_identity").duplicate(true)
	var inputs := PROFILE.read_profile(GEARS_HOST.INPUT_PROFILE)
	var host := RuntimeMapFrozenSource.read_binding_file(GEARS_HOST.BINDINGS_PATH,GEARS_HOST.BINDINGS_SHA256)
	check(inputs.ok and host.ok,"warm cross-profile test reads original locked gears profile and exact recipe, no frozen map/store")
	if not inputs.ok or not host.ok: return
	var algorithm: Dictionary = inputs.request
	check(algorithm.seed is int and algorithm.seed==930007,"warm cross-profile generation uses independent original integer930007 request")
	var request := LevelRequest.new()
	request.root_seed = str(algorithm.seed)
	request.tuning = PlayerTuning.load_default()
	request.capabilities = {"profile":"explicit_upstream_mechanism_not_a_player_grant","collision_half_extents":algorithm.player.clearance_half_extents_pixels.duplicate()}
	var owner := RefCounted.new()
	var lifetime := DemoLifetime.new()
	var source := SOURCE.new()
	var ticket := source.begin(owner,lifetime,request,algorithm,inputs.config,host.bindings,IDS)
	if not await preload_source(source,ticket,lifetime):
		source.close()
		return
	check(source.metrics(ticket).preload_cache_hit and int(source.metrics(ticket).preload_calls)==0,"independent actual930007 source reuses default930001 verified library with zero ZIP work")
	var calls := 0
	while source.phase(ticket)=="generate" and calls<MAX_ADVANCE_CALLS:
		var accepted := source.tick(ticket,lifetime)
		calls += 1
		if not accepted: break
		await process_frame
	check(source.phase(ticket)=="validate","warm actual930007 completes original SDK generation before host validation: "+source.error(ticket))
	if source.phase(ticket)!="validate":
		source.close()
		return
	check(source.tick(ticket,lifetime) and source.phase(ticket)=="ready","warm actual930007 passes original resolver and Provider: "+source.error(ticket))
	if source.phase(ticket)!="ready":
		source.close()
		return
	var actual := source.actual_result(ticket,lifetime)
	var origin := source.provenance(ticket,lifetime)
	var expected: String = PROTOCOL.fingerprint(algorithm,inputs.config,inputs.lock.module_package.sha256)
	check(actual.status=="PASS" and actual.request_fingerprint==expected and actual.map.generator.request_fingerprint==expected and actual.map.seed==930007,"warm930007 actual PASS preserves its own original request/map fingerprint and seed")
	check(origin.request==algorithm and origin.config==inputs.config and origin.request.seed!=request_data.seed,"warm cache shares no previous request/config or RNG state")
	var resolved := source.resolved_bindings(ticket,lifetime)
	var selected: Array[String] = []
	for id: Variant in resolved.selected_instances: selected.append(str(id))
	var spawn_data: Array = resolved.spawns.seam
	var spawn := Vector2(float(spawn_data[0]),float(spawn_data[1]))
	var built := source.take_plan(ticket,lifetime)
	check(built!=null and built.accepted() and built.plan.seed==request.root_seed and built.plan.modules.size()==1,"warm930007 offers its own selected native Plan and consistent LevelRequest seed")
	if built==null or not built.accepted() or built.plan.modules.size()!=1:
		source.close()
		return
	var identity: Dictionary = built.plan.get_meta("runtime_map_v2_identity")
	check(identity.map_content_identity==GOLDEN_GEARS_MAP_CONTENT,"warm cached930007 complete map/store identity equals original accepted real generation golden")
	check(identity.map_content_identity!=GOLDEN_040_GEARS_MAP_CONTENT,"explicit 0.4.1 package upgrade cannot reuse original 0.4.0 map content identity")
	check(identity.host_load.selected_instances==selected and identity.host_load.spawn==[spawn.x,spawn.y] and identity.host_load.capabilities==request.capabilities and identity.host_load_identity!=previous_identity.host_load_identity,"actual warm host-load identity binds this request's resolved scope/spawn/capabilities independently")
	var definition: PlatformingModuleDefinition = built.plan.modules[0].definition
	var instance: Dictionary = definition.get_meta("runtime_map_v2_instance")
	var content: Dictionary = actual.content_store[instance.content_ref]
	check(instance.module_id=="game-plains-ferry-gears" and instance.role=="traversal" and definition.get_meta("runtime_map_v2_content")==content and definition.danger_bounds.size()==content.hazards.size() and definition.saws.size()==1 and definition.ferries.size()==2,"warm resolver/Provider preserves complete actual gears content, hazards, saw and both ferries")
	var repeated := RuntimeMapV2Provider.load_generated_level(request,actual,selected,spawn,resolved,origin)
	check(repeated.accepted() and repeated.plan.get_meta("runtime_map_v2_identity")==identity,"same actual warm inputs reproduce exact content and host identities through the original Provider")
	check(source.commit(ticket,lifetime) and not source.commit(ticket,lifetime),"independent warm930007 Plan commits exactly once")
	source.close()
	check(previous.is_current(previous_ticket,previous_lifetime) and previous.phase(previous_ticket)=="committed","creating, generating, committing and closing warm930007 never cancels prior live930001 job")
	check(DATA.canonical(previous.actual_result(previous_ticket,previous_lifetime))==previous_result and DATA.canonical(previous.provenance(previous_ticket,previous_lifetime))==previous_provenance and previous_built.plan.get_meta("runtime_map_v2_identity")==previous_identity,"full cross-profile cached generation leaves prior live930001 result/provenance/Plan identities unchanged")
	print("RUNTIME_MAP_GENERATION_JOB_WARM_GEARS ",JSON.stringify({"seed":algorithm.seed,"status":actual.status,"request_fingerprint":expected,"map_content_identity":identity.map_content_identity,"host_load_identity":identity.host_load_identity,"preload_calls":source.metrics(ticket).preload_calls,"preload_cache_hit":source.metrics(ticket).preload_cache_hit,"scope":"real930001 then930007 same-process shared immutable library; independent original SDK jobs"}))

func finish() -> void:
	print("RUNTIME_MAP_GENERATION_JOB checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

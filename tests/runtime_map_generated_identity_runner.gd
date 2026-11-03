extends SceneTree
## Actual addon output admission; no fabricated layout or solver substitute.
const PRELOAD_JOB = preload("res://addons/mapgen/preload_job.gd")
const PROFILE = preload("res://experiments/generation/runtime_map_generation_profile.gd")
const SELECTION = preload("res://experiments/generation/runtime_map_generated_selection.gd")
const HOST = preload("res://experiments/generation/runtime_map_generated_slice.gd")
const DATA = preload("res://addons/mapgen/data_json.gd")
const JOB = preload("res://addons/mapgen/generation_job.gd")
const PROTOCOL = preload("res://addons/mapgen/protocol.gd")
var checks := 0
var failures := 0
var result: Dictionary
var provenance: Dictionary
var bindings: Dictionary
var request: LevelRequest
var ids: Array[String] = []
var spawn: Vector2
var ellipse_ref := ""

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("GENERATED IDENTITY: "+label)

func admit(data: Dictionary, source: Dictionary, host_bindings: Dictionary) -> LevelBuildResult:
	return RuntimeMapV2Provider.load_generated_level(request,data,ids,spawn,host_bindings,source)

func run() -> void:
	var profile: Dictionary = PROFILE.read_profile(HOST.DEFAULT_INPUT_PROFILE)
	check(profile.ok,"actual installation lock and shared default input profile decoded")
	if not profile.ok:
		finish()
		return
	var lock: Dictionary = profile.lock
	var locked := true
	for path: String in lock.addon_files:
		locked = locked and FileAccess.get_sha256("res://"+path)==lock.addon_files[path]
	for input: Dictionary in [lock.conformance.request,lock.conformance.config]:
		locked = locked and FileAccess.get_sha256(input.path)==input.sha256
	check(locked,"actual installed addon and algorithm input bytes match shared host lock")
	if not locked:
		finish()
		return
	var loader = PRELOAD_JOB.create(lock.module_package.path,lock.module_package.sha256)
	while not loader.is_done():
		var loading: Dictionary = loader.advance(128)
		if not loading.ok:
			check(false,"actual cooperative preload advance accepted")
			loader.cancel()
			finish()
			return
		await process_frame
	var loaded: Dictionary = loader.result()
	check(loaded.get("status")=="PASS","original cooperative preloader verifies actual locked archive and member bytes")
	if loaded.get("status")!="PASS":
		finish()
		return
	var algorithm_request: Dictionary = profile.request
	var config: Dictionary = profile.config
	check(algorithm_request.seed is int and algorithm_request.seed==930001,"shared profile preserves original integer 930001 input")
	var job = JOB.create(algorithm_request,loaded.library,config)
	while not job.is_done():
		var advanced: Dictionary = job.advance(128)
		if not advanced.ok:
			check(false,"actual job advance accepted")
			job.cancel()
			finish()
			return
		await process_frame
	result = job.result()
	check(result.get("status")=="PASS","real addon generation completed PASS")
	if result.get("status")!="PASS":
		finish()
		return
	provenance = {"kind":"generated_memory","expected_request_fingerprint":PROTOCOL.fingerprint(algorithm_request,config,loaded.library.sha256),"implementation":PROTOCOL.IMPLEMENTATION,"algorithm":PROTOCOL.ALGORITHM,"algorithm_package":{"version":lock.version,"zip_sha256":lock.archive.sha256,"release_head":lock.release_head,"source_commit":lock.source_commit},"module_archive":{"path":lock.module_package.path,"sha256":loaded.library.sha256,"version":loaded.library.version},"request":algorithm_request,"config":config}
	var host := RuntimeMapFrozenSource.read_binding_file(HOST.DEFAULT_BINDINGS_PATH,HOST.DEFAULT_BINDINGS_SHA256)
	check(host.ok,"current host selection recipe retains actual byte check")
	if not host.ok:
		finish()
		return
	var half_extents: Array = algorithm_request.player.clearance_half_extents_pixels
	var selection: Dictionary = SELECTION.resolve(result,host.bindings,Vector2(float(half_extents[0]),float(half_extents[1])))
	check(selection.ok,"shared host resolver selects unique actual templates/versions/roles and connections: "+str(selection.get("error","")))
	if not selection.ok:
		finish()
		return
	ids.assign(selection.ids)
	bindings = selection.bindings
	spawn = selection.spawn
	for instance: Dictionary in result.map.instances:
		if instance.id in ids and instance.module_id=="idea-spec02-s11-001": ellipse_ref = instance.content_ref
	check(not ellipse_ref.is_empty(),"resolved actual ellipse content ref, not a historical M-number")
	if ellipse_ref.is_empty():
		finish()
		return
	request = LevelRequest.new()
	request.root_seed = str(algorithm_request.seed)
	request.tuning = PlayerTuning.load_default()
	selection_guards(host.bindings,Vector2(float(half_extents[0]),float(half_extents[1])),selection)
	var before := DATA.canonical(result)
	var built := admit(result,provenance,bindings)
	check(built.accepted(),"actual generated selected content admitted: "+built.error)
	if not built.accepted():
		for observed: Dictionary in [{"name":"result","value":result},{"name":"provenance","value":provenance}]:
			var non_json := first_non_json(observed.value,observed.name)
			if not non_json.is_empty(): print("GENERATED_IDENTITY_NON_JSON ",JSON.stringify(non_json))
		finish()
		return
	check(DATA.canonical(result)==before,"Provider never mutates upstream map_id/fingerprint/data")
	check(built.legacy_generated.is_empty(),"no legacy generated compatibility view")
	var instances: Dictionary = {}
	for instance: Dictionary in result.map.instances: instances[instance.id] = instance
	for placement: LevelModulePlacement in built.plan.modules:
		var original_instance: Dictionary = instances[placement.instance_id]
		var original_content: Dictionary = result.content_store[original_instance.content_ref]
		var admitted_instance: Dictionary = placement.definition.get_meta("runtime_map_v2_instance")
		var admitted_content: Dictionary = placement.definition.get_meta("runtime_map_v2_content")
		check(string_keys_only(admitted_instance) and string_keys_only(admitted_content),"memory conversion passes String-only copied keys to original converter: "+placement.instance_id)
		var difference := first_data_difference(admitted_instance,original_instance,placement.instance_id+".instance")
		if difference.is_empty(): difference = first_data_difference(admitted_content,original_content,placement.instance_id+".content")
		if not difference.is_empty(): print("GENERATED_IDENTITY_VALUE_DIFFERENCE ",JSON.stringify(difference))
		check(difference.is_empty(),"key copying preserves exact typed/scalar data: "+placement.instance_id)

	var identity: Dictionary = built.plan.get_meta("runtime_map_v2_identity")
	check(result.map.generator.implementation=="mapgen/gdscript-candidate-0.4.0" and result.map.generator.algorithm=="stable-v3-reward-space" and provenance.algorithm_package.version=="0.4.0","actual installed04 job identity, not a relabelled03 result")
	var historical: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mapgen_godot_04/host03_identity.json"))
	check(historical is Dictionary and historical.get("kind")=="captured_0.3_host_identity_not_historical_save_bytes","actual archived03 identity receipt is available with explicit scope")
	if historical is Dictionary and historical.get("identity") is Dictionary:
		var prior: Dictionary = historical.identity
		check(prior.map_content.implementation=="mapgen/gdscript-candidate-0.3.0" and prior.map_content.algorithm=="stable-v2" and prior.source_receipt.algorithm_package.version=="0.3.0","archived identity retains original03 implementation/algorithm/package")
		check(prior.generation_input_fingerprint!=identity.generation_input_fingerprint and prior.host_load_identity!=built.plan.map_hash,"actual04 input/load identities differ from captured03 record")
		var historical_state := PlainsRegionState.new()
		check(historical_state.bind_map(str(prior.host_load_identity)),"test state uses the actual archived03 host identity")
		var historical_saved := historical_state.snapshot()
		check(PlainsRegionState.new().restore(historical_saved,str(prior.host_load_identity)),"old03 identity still restores its own unchanged run-local schema")
		check(not PlainsRegionState.new().restore(historical_saved,built.plan.map_hash),"current04 rejects actual03 identity without changing save schema")

	# Reconstruct the exact original v1 host fields, not the current host hash.
	# Same actual generated payload/bindings; only the host adapter version differs.
	var old_ids: Array[String] = ids.duplicate()
	old_ids.sort()
	var old_host := {"schema":"gunman-rush/runtime-map-load/v1","adapter_version":"runtime-map-generated/1","source_kind":"generated_memory","map_content_identity":identity.map_content_identity,"selected_instances":old_ids,"bindings_schema":bindings.schema,"bindings_version":bindings.version,"bindings_data_sha256":JSON.stringify(bindings,"",true,true).sha256_text(),"active_binding":"seam","spawn":[spawn.x,spawn.y],"region_id":str(request.region_id),"map_index":request.map_index,"capabilities":request.capabilities.duplicate(true)}
	var old_host_hash := JSON.stringify(old_host,"",true,true).sha256_text()
	check(identity.host_load.adapter_version=="runtime-map-generated/2" and old_host_hash!=built.plan.map_hash,"corrected host adapter has a new identity for the same payload/bindings")
	var old_state := PlainsRegionState.new()
	check(old_state.bind_map(old_host_hash),"real run-local state binds independently reconstructed v1 host identity")
	var old_saved := old_state.snapshot()
	check(PlainsRegionState.new().restore(old_saved,old_host_hash),"original v1 identity still describes its own unchanged save schema")
	check(not PlainsRegionState.new().restore(old_saved,built.plan.map_hash),"corrected v2 host refuses old v1 run-local state for identical payload/bindings")

	check(identity.source_kind=="generated_memory" and identity.generation_input_fingerprint==result.request_fingerprint,"distinct memory source preserves actual upstream fingerprint")
	check(identity.map_content.map_data_sha256==JSON.stringify(result.map,"",true,true).sha256_text() and identity.map_content.content_store_data_sha256==JSON.stringify(result.content_store,"",true,true).sha256_text(),"identity still digests original actual result dictionaries")
	check(not identity.map_content.has("map_bytes_sha256") and not identity.map_content.has("verified_bytes_sha256") and not identity.source_receipt.has("files"),"no generated data masquerades as file bytes")
	var changed_timing: Dictionary = result.duplicate(true)
	changed_timing.metrics.generation_seconds = float(changed_timing.metrics.get("generation_seconds",0.0))+1.0
	var timed := admit(changed_timing,provenance,bindings)
	check(timed.accepted() and timed.plan.map_hash==built.plan.map_hash,"elapsed generation time does not change restore identity")
	if timed.accepted():
		check(timed.plan.get_meta("runtime_map_v2_identity").result_receipt_digest!=identity.result_receipt_digest,"raw result receipt retains actual timing difference")
	var state := PlainsRegionState.new()
	state.bind_map(built.plan.map_hash)
	var saved := state.snapshot()
	check(PlainsRegionState.new().restore(saved,built.plan.map_hash),"same actual04 identity restores current run-local state")
	var altered_bindings: Dictionary = bindings.duplicate(true)
	altered_bindings.version += "/next"
	var rebound := admit(result,provenance,altered_bindings)
	check(rebound.accepted() and rebound.plan.map_hash!=built.plan.map_hash,"host binding version changes memory load identity")
	if rebound.accepted(): check(not PlainsRegionState.new().restore(saved,rebound.plan.map_hash),"previous state rejects changed memory host identity")
	var changed: Dictionary = result.duplicate(true)
	changed.content_store[ellipse_ref].moving_platforms[0].ellipse_period = 10.0
	changed.content_store[ellipse_ref].moving_platforms[0].travel_duration = 10.0
	var new_content := admit(changed,provenance,bindings)
	check(new_content.accepted() and new_content.plan.map_hash!=built.plan.map_hash,"valid actual payload change cannot retain restore identity")
	for mode: String in ["kind","fake_files","missing_map","failed","fingerprint","implementation","algorithm","module","request","missing_content","unsupported_content","nontext_key","object_value","nonfinite_value","stringname_value"]:
		var bad: Dictionary = result.duplicate(true)
		var source: Dictionary = provenance.duplicate(true)
		match mode:
			"kind": source.kind = "frozen_files"
			"fake_files": source.files = {"map.json":"a".repeat(64)}
			"missing_map": bad.map = null
			"failed": bad.status = "CANCELLED"
			"fingerprint": bad.map.generator.request_fingerprint = "a".repeat(64)
			"implementation": bad.map.generator.implementation = "other"
			"algorithm": source.algorithm = "other"
			"module": source.module_archive.sha256 = "a".repeat(64)
			"request": source.request.seed += 1
			"missing_content": bad.content_store.erase(ellipse_ref)
			"unsupported_content": bad.content_store[ellipse_ref].enemies.append({"unsupported":true})
			"nontext_key": bad.map.validation[123] = "not a text key"
			"object_value": bad.map.validation["invalid_value"] = RefCounted.new()
			"nonfinite_value": bad.map.validation["invalid_value"] = NAN
			"stringname_value": bad.map.validation["invalid_value"] = &"not_an_observed_value_contract"
		var rejected := admit(bad,source,bindings)
		check(not rejected.accepted() and rejected.plan==null and not rejected.error.is_empty(),"reject without Plan: "+mode)
		if mode in ["nontext_key","object_value","nonfinite_value","stringname_value"]:
			check(rejected.error=="generated_memory: expected finite JSON data only","reject actual nondata type before conversion: "+mode)
	var same_text: Dictionary = {"validation":1}
	same_text[StringName("validation")] = 2
	if same_text.size()==1:
		check(same_text["validation"]==2,"engine Dictionary treats String and StringName same-text keys as one identity")
	else:
		var ambiguous: Dictionary = result.duplicate(true)
		ambiguous.map.validation = same_text
		check(not admit(ambiguous,provenance,bindings).accepted(),"distinct same-text keys are explicitly rejected before copy")
	request.expected_hash = built.plan.map_hash
	check(not admit(changed,provenance,bindings).accepted(),"expected04 identity refuses altered content")
	check(not admit(result,provenance,altered_bindings).accepted(),"expected04 identity refuses altered bindings")
	var altered_source: Dictionary = provenance.duplicate(true)
	altered_source.algorithm_package.source_commit = "a".repeat(40)
	check(not admit(result,altered_source,bindings).accepted(),"expected04 identity refuses changed algorithm source provenance")
	request.expected_hash = ""
	for wrong_version: String in ["0.3.0","0.3.1","0.4.1"]:
		altered_source = provenance.duplicate(true)
		altered_source.algorithm_package.version = wrong_version
		var version_rejected := admit(result,altered_source,bindings)
		check(not version_rejected.accepted() and version_rejected.error=="provenance.algorithm_package: invalid release identity","wrong package version cannot label actual04 result: "+wrong_version)
	request.expected_hash = "a".repeat(64)
	check(not admit(result,provenance,bindings).accepted(),"expected hash remains enforced for memory source")
	finish()

func selection_guards(recipe: Dictionary, body_half: Vector2, selected: Dictionary) -> void:
	# Deliberately corrupted copies are guard probes, never generated-output receipts.
	var original := DATA.canonical(result)
	var root_id: String = selected.bindings.selection_resolution.root_instance_id
	var edge: Dictionary = selected.bindings.selection_resolution.internal_connections[0]
	for mode: String in ["root_role","root_version","missing_connection","duplicate_connection","unmaterialized","recipe_kind","negative_index","fractional_index","nonfinite_index","string_index","missing_platform"]:
		var bad: Dictionary = result.duplicate(true)
		var bad_recipe: Dictionary = recipe.duplicate(true)
		match mode:
			"root_role", "root_version", "unmaterialized":
				for instance: Dictionary in bad.map.instances:
					if instance.id!=root_id: continue
					if mode=="root_role": instance.role = "not_the_authored_role"
					elif mode=="root_version": instance.content_version = "sha256:"+"a".repeat(64)
					else: instance.transform.content_is_materialized = false
			"missing_connection": bad.map.connections.erase(edge)
			"duplicate_connection": bad.map.connections.append(edge.duplicate(true))
			"recipe_kind": bad_recipe.selection_recipe.kind = "unsupported_kind"
			"negative_index": bad_recipe.spawn_rule.platform_index = -1
			"fractional_index": bad_recipe.spawn_rule.platform_index = 0.5
			"nonfinite_index": bad_recipe.spawn_rule.platform_index = INF
			"string_index": bad_recipe.spawn_rule.platform_index = "0"
			"missing_platform": bad_recipe.spawn_rule.platform_index = 10000
		var denied: Dictionary = SELECTION.resolve(bad,bad_recipe,body_half)
		check(not denied.ok and not str(denied.get("error","")).is_empty() and not denied.has("bindings"),"actual selection guard rejects independent tamper: "+mode)
	for invalid_half: Vector2 in [Vector2.ZERO,Vector2(-1,body_half.y),Vector2(body_half.x,INF)]:
		var denied: Dictionary = SELECTION.resolve(result,recipe,invalid_half)
		check(not denied.ok and not str(denied.get("error","")).is_empty(),"actual selection rejects invalid body clearance: "+str(invalid_half))
	check(DATA.canonical(result)==original,"selection guard probes leave actual generated result untouched")
	var rejected_source := RuntimeMapGenerationJob.new()
	var rejected_lifetime := DemoLifetime.new()
	var old_pinned: Array[String] = ["M16","M18","M21"]
	var denied_ticket := rejected_source.begin(root,rejected_lifetime,request,provenance.request,provenance.config,recipe,old_pinned)
	check(denied_ticket!=null and rejected_source.phase(denied_ticket)=="failed" and rejected_source.error(denied_ticket)=="04 selection must resolve actual output; do not pass pinned instance IDs" and rejected_source.take_plan(denied_ticket,rejected_lifetime)==null,"historical pinned IDs cannot bypass actual04 host selection")
	rejected_source.close()
	rejected_lifetime.end()

func finish() -> void:
	print("RUNTIME_MAP_GENERATED_IDENTITY checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func first_non_json(value: Variant, path: String) -> Dictionary:
	if value == null or value is bool or value is String or value is int: return {}
	if value is float:
		return {} if is_finite(value) else {"path":path,"type":type_string(typeof(value)),"reason":"nonfinite number","value":str(value)}
	if value is Array:
		for index: int in value.size():
			var found := first_non_json(value[index],path+"["+str(index)+"]")
			if not found.is_empty(): return found
		return {}
	if value is Dictionary:
		for key: Variant in value:
			if not (key is String or key is StringName): return {"path":path,"key":str(key),"key_type":type_string(typeof(key)),"reason":"nontext Dictionary key"}
			var found := first_non_json(value[key],path+"."+str(key))
			if not found.is_empty(): return found
		return {}
	return {"path":path,"type":type_string(typeof(value)),"reason":"unsupported data value"}

func string_keys_only(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not string_keys_only(value[key]): return false
	elif value is Array:
		for item: Variant in value:
			if not string_keys_only(item): return false
	return true

func first_data_difference(left: Variant, right: Variant, path: String) -> Dictionary:
	if typeof(left)!=typeof(right):
		return {"path":path,"reason":"value type changed","left_type":type_string(typeof(left)),"right_type":type_string(typeof(right))}
	if left is Dictionary:
		if left.size()!=right.size(): return {"path":path,"reason":"dictionary size changed"}
		var right_keys: Dictionary = {}
		for key: Variant in right:
			if not (key is String or key is StringName) or right_keys.has(str(key)): return {"path":path,"reason":"invalid or duplicate right text key"}
			right_keys[str(key)] = key
		var seen: Dictionary = {}
		for key: Variant in left:
			if not (key is String or key is StringName) or seen.has(str(key)): return {"path":path,"reason":"invalid or duplicate left text key"}
			var text := str(key)
			seen[text] = true
			if not right_keys.has(text): return {"path":path+"."+text,"reason":"missing text key"}
			var difference := first_data_difference(left[key],right[right_keys[text]],path+"."+text)
			if not difference.is_empty(): return difference
	elif left is Array:
		if left.size()!=right.size(): return {"path":path,"reason":"array length changed"}
		for index: int in left.size():
			var difference := first_data_difference(left[index],right[index],path+"["+str(index)+"]")
			if not difference.is_empty(): return difference
	elif left!=right:
		return {"path":path,"reason":"scalar value changed","type":type_string(typeof(left)),"left":str(left),"right":str(right)}
	return {}

extends SceneTree
## Actual addon output admission; no fabricated layout or solver substitute.
const ARCHIVE = preload("res://addons/mapgen/module_archive.gd")
const DATA = preload("res://addons/mapgen/data_json.gd")
const JOB = preload("res://addons/mapgen/generation_job.gd")
const PROTOCOL = preload("res://addons/mapgen/protocol.gd")
var checks := 0
var failures := 0
var result: Dictionary
var provenance: Dictionary
var bindings: Dictionary
var request: LevelRequest
var ids: Array[String] = ["M16","M18","M21"]
var spawn := Vector2(-448,846)

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("GENERATED IDENTITY: "+label)

func admit(data: Dictionary, source: Dictionary, host_bindings: Dictionary) -> LevelBuildResult:
	return RuntimeMapV2Provider.load_generated_level(request,data,ids,spawn,host_bindings,source)

func run() -> void:
	var lock: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/mapgen_candidate.json"))
	check(lock is Dictionary,"actual installation lock decoded")
	if not lock is Dictionary:
		finish()
		return
	var locked := true
	for path: String in lock.addon_files:
		locked = locked and FileAccess.get_sha256("res://"+path)==lock.addon_files[path]
	for input: Dictionary in [lock.conformance.request,lock.conformance.config]:
		locked = locked and FileAccess.get_sha256(input.path)==input.sha256
	check(locked,"actual installed addon and algorithm input bytes match shared host lock")
	if not locked:
		finish()
		return
	var loaded: Dictionary = ARCHIVE.open_zip(lock.module_package.path,lock.module_package.sha256)
	check(loaded.ok,"original addon verifies actual locked archive and member bytes")
	if not loaded.ok:
		finish()
		return
	var algorithm_request: Dictionary = DATA.parse(FileAccess.get_file_as_string(lock.conformance.request.path))
	var config: Dictionary = DATA.parse(FileAccess.get_file_as_string(lock.conformance.config.path))
	check(algorithm_request.ok and config.ok,"original DataJSON preserves actual algorithm input types")
	if not algorithm_request.ok or not config.ok:
		finish()
		return
	var job = JOB.create(algorithm_request.value,loaded.library,config.value)
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
	provenance = {"kind":"generated_memory","expected_request_fingerprint":PROTOCOL.fingerprint(algorithm_request.value,config.value,loaded.library.sha256),"implementation":PROTOCOL.IMPLEMENTATION,"algorithm":PROTOCOL.ALGORITHM,"algorithm_package":{"version":lock.version,"zip_sha256":lock.archive.sha256,"release_head":lock.release_head,"source_commit":lock.source_commit},"module_archive":{"path":lock.module_package.path,"sha256":loaded.library.sha256,"version":loaded.library.version},"request":algorithm_request.value,"config":config.value}
	var frozen := RuntimeMapFrozenSource.read_inputs()
	check(frozen.ok,"existing host bindings retain actual frozen-byte check")
	if not frozen.ok:
		finish()
		return
	bindings = frozen.bindings.duplicate(true)
	request = LevelRequest.new()
	request.root_seed = str(algorithm_request.value.seed)
	request.tuning = PlayerTuning.load_default()
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
	var altered_bindings: Dictionary = bindings.duplicate(true)
	altered_bindings.version += "/next"
	var rebound := admit(result,provenance,altered_bindings)
	check(rebound.accepted() and rebound.plan.map_hash!=built.plan.map_hash,"host binding version changes memory load identity")
	if rebound.accepted(): check(not PlainsRegionState.new().restore(saved,rebound.plan.map_hash),"previous state rejects changed memory host identity")
	var changed: Dictionary = result.duplicate(true)
	changed.content_store["content/M16.json"].moving_platforms[0].ellipse_period = 10.0
	changed.content_store["content/M16.json"].moving_platforms[0].travel_duration = 10.0
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
			"missing_content": bad.content_store.erase("content/M16.json")
			"unsupported_content": bad.content_store["content/M16.json"].enemies.append({"unsupported":true})
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
	request.expected_hash = "a".repeat(64)
	check(not admit(result,provenance,bindings).accepted(),"expected hash remains enforced for memory source")
	finish()

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

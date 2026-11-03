class_name RuntimeMapGenerationJob
extends RefCounted
## Source-owned cooperative envelope. The entrance owns SceneTree and RunSession.
## Every accepting operation receives the entrance's actual current lifetime.
const JOB := preload("res://addons/mapgen/generation_job.gd")
const PRELOAD_JOB := preload("res://addons/mapgen/preload_job.gd")
const VERIFIED_LIBRARY := preload("res://experiments/generation/runtime_map_verified_library_cache.gd")
const WORK_GATE := preload("res://addons/mapgen/work_gate.gd")
const SELECTION := preload("res://experiments/generation/runtime_map_generated_selection.gd")
# Original SDK Web host uses an 8ms yielding target. The first actual main-game
# Web run with 4ms rejected the result after ~92.5s of generation; its package,
# input/config and 90s search limit stay unchanged. This is no hard frame limit.
const SOFT_TICK_MS := 8.0
const PROTOCOL := preload("res://addons/mapgen/protocol.gd")
const LOCK_PATH := "res://config/mapgen_candidate.json"

class Ticket extends RefCounted:
	# The caller owns only this handle; state is never stored on that object.
	var handle := RefCounted.new()
	var serial := 0
	var owner: WeakRef
	var lifetime: DemoLifetime
	var token: DemoToken
	var phase := "preload"
	var error := ""
	var request: LevelRequest
	var request_data: Dictionary = {}
	var config: Dictionary = {}
	var bindings: Dictionary = {}
	var ids: Array[String] = []
	var binding_id := "seam"
	var operation_budget := 128
	var lock: Dictionary = {}
	var preloader: Variant
	var preload_started_usec := 0
	var resolved: Dictionary = {}
	var generation_started_usec := 0
	var last_tick_finished_usec := 0
	var last_tick_phase := ""
	var job: Variant
	var actual: Dictionary = {}
	var provenance: Dictionary = {}
	var progress: Dictionary = {}
	var progress_history: Array[Dictionary] = []
	var metrics: Dictionary = {"tick_ms":[],"tick_phases":[],"tick_max_ms":0.0,"preload_ms":0.0,"preload_tick_ms":[],"preload_advance_total_ms":0.0,"preload_advance_max_ms":0.0,"preload_calls":0,"preload_progress":[],"preload_unit_overruns":[],"advance_unit_total_ms":0.0,"advance_tick_ms":[],"advance_max_ms":0.0,"advance_tick_max_ms":0.0,"advance_calls":0,"advance_ticks":0,"advance_unit_overruns":[],"validate_ms":0.0,"operations":0,"microsteps":0,"quantum_checkpoints":16,"budget_kind":"work-unit cap per host tick; original advance1 is16 checkpoints; soft time target only","sampling":"initial + each host tick + terminal/cancel; exact unit count/max/total and SDK phase profiles retained"}
	var built: LevelBuildResult
	var taken := false
	var committed := false

var _serial := 0
var _current: Ticket
var _closed := false
var _ticking := false

func begin(owner: Object, lifetime: DemoLifetime, level_request: LevelRequest, request_data: Dictionary, config: Dictionary, bindings: Dictionary, ids: Array[String], binding_id: String = "seam", operation_budget: int = 128) -> RefCounted:
	if _closed or _ticking: return null
	if _current != null: _cancel(_current,"replaced by a newer generation request")
	_serial += 1
	var ticket := Ticket.new()
	ticket.serial = _serial
	ticket.lifetime = lifetime
	ticket.token = lifetime.token() if lifetime != null else null
	if is_instance_valid(owner): ticket.owner = weakref(owner)
	ticket.request = _copy_request(level_request)
	ticket.request_data = request_data.duplicate(true)
	ticket.config = config.duplicate(true)
	ticket.bindings = bindings.duplicate(true)
	ticket.ids.assign(ids)
	ticket.binding_id = binding_id
	ticket.operation_budget = operation_budget
	ticket.metrics["operation_budget"] = operation_budget
	ticket.metrics["soft_tick_ms"] = SOFT_TICK_MS
	ticket.metrics["configured_work_unit_cap"] = operation_budget
	ticket.metrics["timing_basis"] = "main-thread monotonic execution elapsed; gaps include yielding and caller work; not OS CPU or a hard frame guarantee"
	ticket.metrics["preload_cache_hit"] = false
	_current = ticket
	if not _accepts(ticket,lifetime):
		_fail(ticket,"generation owner/lifetime is not active")
	elif ticket.request == null or ticket.request.tuning == null:
		_fail(ticket,"request: missing LevelRequest/tuning")
	elif not ids.is_empty():
		_fail(ticket,"04 selection must resolve actual output; do not pass pinned instance IDs")
	elif not bindings.get("selection_recipe") is Dictionary:
		_fail(ticket,"04 generation requires a versioned selection recipe")
	elif operation_budget < 1 or operation_budget > 4096:
		_fail(ticket,"advance operation budget must be 1..4096")
	else:
		var problem: String = PROTOCOL.validate(ticket.request_data,ticket.config)
		if not problem.is_empty(): _fail(ticket,problem)
	return ticket.handle

func tick(value: RefCounted, current_lifetime: DemoLifetime) -> bool:
	var ticket := _ticket(value)
	if _ticking or ticket == null: return false
	if not _guard(ticket,current_lifetime): return false
	if ticket.phase not in ["preload","generate","validate"]: return false
	_ticking = true
	var phase_before := ticket.phase
	var tick_started := Time.get_ticks_usec()
	if ticket.last_tick_finished_usec>0:
		var gap := float(tick_started-ticket.last_tick_finished_usec)/1000.0
		_add_ms(ticket,"between_tick_gap_ms",gap)
		_add_ms(ticket,ticket.last_tick_phase+"_gap_ms",gap)
		ticket.metrics["between_tick_intervals"] = int(ticket.metrics.get("between_tick_intervals",0))+1
	match ticket.phase:
		"preload": _preload(ticket)
		"generate": _advance(ticket)
		"validate": _validate(ticket)
	var duration := _elapsed_ms(tick_started)
	_add_ms(ticket,"host_tick_execution_ms",duration)
	ticket.last_tick_finished_usec = Time.get_ticks_usec()
	ticket.last_tick_phase = phase_before
	ticket.metrics.tick_ms.append(duration)
	ticket.metrics.tick_phases.append(phase_before)
	ticket.metrics.tick_max_ms = maxf(float(ticket.metrics.tick_max_ms),duration)
	if phase_before=="preload":
		ticket.metrics.preload_ms = float(ticket.metrics.preload_ms)+duration
		ticket.metrics.preload_tick_ms.append(duration)
		if ticket.phase=="generate": ticket.metrics["preload_wall_ms"] = _elapsed_ms(ticket.preload_started_usec)
	elif phase_before=="generate":
		_add_ms(ticket,"generation_execution_ms",duration)
		ticket.metrics.advance_tick_ms.append(duration)
		ticket.metrics.advance_ticks = int(ticket.metrics.advance_ticks)+1
		ticket.metrics.advance_tick_max_ms = maxf(float(ticket.metrics.advance_tick_max_ms),duration)
	_ticking = false
	return _guard(ticket,current_lifetime) and ticket.phase not in ["failed","cancelled"]

func take_plan(value: RefCounted, current_lifetime: DemoLifetime) -> LevelBuildResult:
	var ticket := _ticket(value)
	if ticket == null or not _guard(ticket,current_lifetime): return null
	if ticket.phase != "ready" or ticket.taken or ticket.built == null: return null
	if not ticket.built.accepted(): return null
	var built: LevelBuildResult = ticket.built
	ticket.taken = true
	ticket.built = null
	ticket.phase = "assemble"
	if not _guard(ticket,current_lifetime): return null
	return built

func commit(value: RefCounted, current_lifetime: DemoLifetime) -> bool:
	var ticket := _ticket(value)
	if ticket == null or not _guard(ticket,current_lifetime): return false
	if ticket.phase != "assemble" or not ticket.taken or ticket.committed: return false
	ticket.committed = true
	ticket.phase = "committed"
	return _accepts(ticket,current_lifetime)

func abort(value: RefCounted, reason: String) -> bool:
	var ticket := _ticket(value)
	if ticket == null or ticket.phase in ["cancelled","failed","committed"]: return false
	_cancel(ticket,reason if not reason.is_empty() else "generation cancelled")
	return true

func fail_assembly(value: RefCounted, message: String) -> bool:
	var ticket := _ticket(value)
	if ticket == null or _closed or ticket.phase != "assemble" or ticket.committed: return false
	_fail(ticket,message if not message.is_empty() else "assembly failed")
	return true

func close() -> void:
	if _closed: return
	_closed = true
	if _current != null: _cancel(_current,"generation source closed")

func is_closed() -> bool:
	return _closed

func is_current(value: RefCounted, current_lifetime: DemoLifetime) -> bool:
	return _accepts(_ticket(value),current_lifetime)

func _accepts(ticket: Ticket, current_lifetime: DemoLifetime) -> bool:
	if _closed or ticket == null or ticket != _current or ticket.serial != _serial or current_lifetime == null: return false
	if ticket.phase in ["failed","cancelled"]: return false
	if ticket.lifetime != current_lifetime or ticket.token == null: return false
	if not current_lifetime.accepts(ticket.token) or ticket.owner == null: return false
	var owner: Object = ticket.owner.get_ref()
	return is_instance_valid(owner) and not owner.is_queued_for_deletion()

# Diagnostics never offer a plan or advance a ticket. Mutable data is copied.
func phase(value: RefCounted) -> String:
	var ticket := _ticket(value)
	return ticket.phase if ticket != null else "stale"

func error(value: RefCounted) -> String:
	var ticket := _ticket(value)
	return ticket.error if ticket != null else "stale generation ticket"

func metrics(value: RefCounted) -> Dictionary:
	var ticket := _ticket(value)
	return ticket.metrics.duplicate(true) if ticket != null else {}

func progress(value: RefCounted) -> Dictionary:
	var ticket := _ticket(value)
	return ticket.progress.duplicate(true) if ticket != null else {}

func progress_history(value: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ticket := _ticket(value)
	if ticket != null: result.assign(ticket.progress_history.duplicate(true))
	return result

func actual_result(value: RefCounted, current_lifetime: DemoLifetime) -> Dictionary:
	var ticket := _ticket(value)
	if ticket == null or not _accepts(ticket,current_lifetime) or ticket.phase == "cancelled": return {}
	var started := Time.get_ticks_usec()
	var result := ticket.actual.duplicate(true)
	_add_ms(ticket,"actual_result_copy_execution_ms",_elapsed_ms(started))
	ticket.metrics["actual_result_copy_calls"] = int(ticket.metrics.get("actual_result_copy_calls",0))+1
	return result

func output_summary(value: RefCounted, current_lifetime: DemoLifetime) -> Dictionary:
	var ticket := _ticket(value)
	if not _accepts(ticket,current_lifetime) or ticket.actual.is_empty(): return {}
	# A genuine SDK failure has map/content_store=null before host validation.
	if not ticket.actual.get("map") is Dictionary or not ticket.actual.get("content_store") is Dictionary: return {}
	var started := Time.get_ticks_usec()
	var actual := ticket.actual
	var map: Dictionary = actual.get("map",{})
	var result := {"status":actual.get("status","MISSING"),"seed":map.get("seed"),"request_fingerprint":actual.get("request_fingerprint"),"instances":map.get("instances",[]).size(),"connections":map.get("connections",[]).size(),"content_entries":actual.get("content_store",{}).size()}
	_add_ms(ticket,"output_summary_execution_ms",_elapsed_ms(started))
	return result

func request_abilities(value: RefCounted, current_lifetime: DemoLifetime) -> Array:
	var ticket := _ticket(value)
	if not _accepts(ticket,current_lifetime): return []
	return ticket.request_data.get("player",{}).get("abilities",[]).duplicate(true)

func provenance(value: RefCounted, current_lifetime: DemoLifetime) -> Dictionary:
	var ticket := _ticket(value)
	if ticket == null or not _accepts(ticket,current_lifetime) or ticket.phase == "cancelled": return {}
	return ticket.provenance.duplicate(true)

func resolved_bindings(value: RefCounted, current_lifetime: DemoLifetime) -> Dictionary:
	var ticket := _ticket(value)
	if not _accepts(ticket,current_lifetime) or ticket.resolved.is_empty(): return {}
	return ticket.bindings.duplicate(true)


func request_serial(value: RefCounted) -> int:
	var ticket := _ticket(value)
	return ticket.serial if ticket != null else 0

func _ticket(value: RefCounted) -> Ticket:
	if value == null or _current == null or value != _current.handle: return null
	return _current if _current.serial == _serial else null

func _guard(ticket: Ticket, current_lifetime: DemoLifetime) -> bool:
	if _accepts(ticket,current_lifetime): return true
	# A stale caller cannot cancel the replacement, even with equal epoch numbers.
	if ticket == _current and ticket.serial == _serial: _cancel(ticket,"generation owner/lifetime/token is stale")
	return false

func _preload(ticket: Ticket) -> void:
	var started := Time.get_ticks_usec()
	if ticket.preloader == null:
		ticket.preload_started_usec = started
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCK_PATH))
		if not value is Dictionary:
			_fail(ticket,"missing/invalid installed mapgen candidate lock")
			return
		ticket.lock = value
		var problem := _lock_error(ticket.lock)
		if not problem.is_empty():
			_fail(ticket,problem)
			return
		var lookup_started := Time.get_ticks_usec()
		var hit := VERIFIED_LIBRARY.has_verified(ticket.lock)
		ticket.metrics["cache_lookup_execution_ms"] = _elapsed_ms(lookup_started)
		ticket.metrics["preload_cache_hit"] = hit
		if hit:
			_start_generation(ticket)
			return
		ticket.preloader = PRELOAD_JOB.create(str(ticket.lock.module_package.path),str(ticket.lock.module_package.sha256))
	var calls := 0
	while calls<ticket.operation_budget and not ticket.preloader.is_done():
		if not _accepts(ticket,ticket.lifetime):
			_cancel(ticket,"preload context invalidated")
			return
		var step_started := Time.get_ticks_usec()
		var advanced: Dictionary = ticket.preloader.advance(1)
		var duration := _elapsed_ms(step_started)
		ticket.metrics.preload_advance_total_ms = float(ticket.metrics.preload_advance_total_ms)+duration
		if duration>SOFT_TICK_MS: ticket.metrics.preload_unit_overruns.append({"ms":duration,"phase_after":ticket.preloader.phase_name()})
		ticket.metrics.preload_advance_max_ms = maxf(float(ticket.metrics.preload_advance_max_ms),duration)
		ticket.metrics.preload_calls = int(ticket.metrics.preload_calls)+1
		calls += 1
		if not advanced.get("ok",false):
			_fail(ticket,str(advanced.get("error","cooperative preload failed")))
			return
		if _elapsed_ms(started)>=SOFT_TICK_MS: break
	var sample_started := Time.get_ticks_usec()
	ticket.progress = ticket.preloader.progress()
	ticket.metrics.preload_progress.append(ticket.progress)
	_add_ms(ticket,"preload_progress_sample_execution_ms",_elapsed_ms(sample_started))
	if not ticket.preloader.is_done(): return
	var opened: Dictionary = ticket.preloader.result()
	if opened.get("status")!="PASS":
		_fail(ticket,str(opened.get("error","module preload did not PASS")))
		return
	var profile_started := Time.get_ticks_usec()
	ticket.metrics["preload_profile"] = ticket.preloader.profile()
	_add_ms(ticket,"sdk_profile_capture_execution_ms",_elapsed_ms(profile_started))
	var publish_started := Time.get_ticks_usec()
	if not VERIFIED_LIBRARY.publish(ticket.lock,ticket.preloader):
		_fail(ticket,"module preload did not PASS with installed archive identity")
		return
	ticket.metrics["verified_library_publish_execution_ms"] = _elapsed_ms(publish_started)
	_start_generation(ticket)

func _start_generation(ticket: Ticket) -> void:
	ticket.metrics["verified_library_receipt"] = VERIFIED_LIBRARY.receipt(ticket.lock)
	ticket.metrics["preload_wall_ms"] = _elapsed_ms(ticket.preload_started_usec)
	var lock: Dictionary = ticket.lock
	var fingerprint_started := Time.get_ticks_usec()
	var expected: String = PROTOCOL.fingerprint(ticket.request_data,ticket.config,str(lock.module_package.sha256))
	_add_ms(ticket,"fingerprint_execution_ms",_elapsed_ms(fingerprint_started))
	ticket.provenance = {"kind":"generated_memory","expected_request_fingerprint":expected,"implementation":PROTOCOL.IMPLEMENTATION,"algorithm":PROTOCOL.ALGORITHM,"algorithm_package":{"version":lock.version,"zip_sha256":lock.archive.sha256,"release_head":lock.release_head,"source_commit":lock.source_commit},"module_archive":{"path":lock.module_package.path,"sha256":lock.module_package.sha256,"version":lock.module_package.version},"request":ticket.request_data.duplicate(true),"config":ticket.config.duplicate(true)}
	ticket.preloader = null
	ticket.generation_started_usec = Time.get_ticks_usec()
	var create_started := Time.get_ticks_usec()
	ticket.job = VERIFIED_LIBRARY.create_job(lock,ticket.request_data,ticket.config)
	ticket.metrics["sdk_job_create_execution_ms"] = _elapsed_ms(create_started)
	if ticket.job == null:
		_fail(ticket,"verified module library unavailable")
		return
	ticket.progress = ticket.job.progress()
	ticket.progress_history.append(ticket.progress)
	ticket.phase = "generate"

func _advance(ticket: Ticket) -> void:
	var started := Time.get_ticks_usec()
	var calls := 0
	while calls<ticket.operation_budget and not ticket.job.is_done():
		if not _accepts(ticket,ticket.lifetime):
			_cancel(ticket,"generation context invalidated")
			return
		var step_started := Time.get_ticks_usec()
		var advanced: Dictionary = ticket.job.advance(1)
		var duration := _elapsed_ms(step_started)
		ticket.metrics.advance_unit_total_ms = float(ticket.metrics.advance_unit_total_ms)+duration
		if duration>SOFT_TICK_MS: ticket.metrics.advance_unit_overruns.append({"ms":duration,"phase_after":ticket.job.phase_name()})
		ticket.metrics.advance_calls = int(ticket.metrics.advance_calls)+1
		ticket.metrics.advance_max_ms = maxf(float(ticket.metrics.advance_max_ms),duration)
		calls += 1
		if not advanced.get("ok",false):
			_fail(ticket,str(advanced.get("error","generation advance failed")))
			return
		if _elapsed_ms(started)>=SOFT_TICK_MS: break
	var sample_started := Time.get_ticks_usec()
	ticket.progress = ticket.job.progress()
	ticket.progress_history.append(ticket.progress)
	_add_ms(ticket,"generation_progress_sample_execution_ms",_elapsed_ms(sample_started))
	ticket.metrics.operations = int(ticket.progress.get("operations",0))
	ticket.metrics.microsteps = int(ticket.progress.get("microsteps",0))
	if ticket.job.is_done():
		var profile_started := Time.get_ticks_usec()
		ticket.metrics["generation_profile"] = ticket.job.profile()
		_add_ms(ticket,"sdk_profile_capture_execution_ms",_elapsed_ms(profile_started))
		var snapshot_started := Time.get_ticks_usec()
		ticket.actual = ticket.job.result() # Original SDK already returns a deep snapshot.
		ticket.metrics["sdk_result_snapshot_execution_ms"] = _elapsed_ms(snapshot_started)
		ticket.metrics["generation_wall_ms"] = _elapsed_ms(ticket.generation_started_usec)
		ticket.phase = "validate"

func _validate(ticket: Ticket) -> void:
	var started := Time.get_ticks_usec()
	var fingerprint_started := Time.get_ticks_usec()
	var expected: String = PROTOCOL.fingerprint(ticket.request_data,ticket.config,str(ticket.lock.module_package.sha256))
	_add_ms(ticket,"fingerprint_execution_ms",_elapsed_ms(fingerprint_started))
	var actual: Dictionary = ticket.actual
	ticket.metrics["generation_status"] = actual.get("status","MISSING")
	if actual.get("status") != "PASS" or actual.get("schema") != "mapgen/generation-result/v1":
		ticket.metrics.validate_ms = _elapsed_ms(started)
		var failure := {"status":actual.get("status","MISSING"),"schema":actual.get("schema","MISSING")}
		if actual.get("diagnostics") is Dictionary and actual.diagnostics.get("error") is Dictionary:
			failure["error"] = actual.diagnostics.error.duplicate(true)
		_fail(ticket,"generation result rejected: "+JSON.stringify(failure))
		return
	if expected != ticket.provenance.get("expected_request_fingerprint") or actual.get("request_fingerprint") != expected:
		ticket.metrics.validate_ms = _elapsed_ms(started)
		_fail(ticket,"generation result differs from actual Protocol request fingerprint")
		return
	if not actual.get("map") is Dictionary or not actual.map.get("generator") is Dictionary or actual.map.generator.get("request_fingerprint") != expected:
		ticket.metrics.validate_ms = _elapsed_ms(started)
		_fail(ticket,"generation map differs from original Protocol request fingerprint")
		return
	var half: Variant = ticket.request.capabilities.get("collision_half_extents")
	if not LevelContentValidation.point(half):
		ticket.metrics.validate_ms = _elapsed_ms(started)
		_fail(ticket,"missing actual host collision_half_extents snapshot")
		return
	var selection_started := Time.get_ticks_usec()
	ticket.resolved = SELECTION.resolve(actual,ticket.bindings,Vector2(float(half[0]),float(half[1])),ticket.binding_id)
	ticket.metrics["selection_execution_ms"] = _elapsed_ms(selection_started)
	if not ticket.resolved.ok:
		ticket.metrics.validate_ms = _elapsed_ms(started)
		_fail(ticket,str(ticket.resolved.error))
		return
	ticket.ids.assign(ticket.resolved.ids)
	ticket.bindings = ticket.resolved.bindings
	var spawn: Vector2 = ticket.resolved.spawn
	# Audited Provider copies map/store and output metadata before writing. No
	# redundant full snapshot here; public diagnostic getters still deep-copy.
	var provider_started := Time.get_ticks_usec()
	ticket.built = RuntimeMapV2Provider.load_generated_level(ticket.request,actual,ticket.ids,spawn,ticket.bindings,ticket.provenance,ticket.binding_id)
	ticket.metrics["provider_execution_ms"] = _elapsed_ms(provider_started)
	if ticket.built != null and ticket.built.accepted():
		ticket.metrics["provider_profile"] = ticket.built.plan.get_meta("runtime_map_v2_profile",{}).duplicate(true)
	ticket.metrics.validate_ms = _elapsed_ms(started)
	if ticket.built == null or not ticket.built.accepted():
		_fail(ticket,ticket.built.error if ticket.built != null else "generated provider returned no LevelBuildResult")
		return
	ticket.phase = "ready"

func _lock_error(lock: Dictionary) -> String:
	if lock.get("version") != "0.4.0" or lock.get("implementation") != PROTOCOL.IMPLEMENTATION or lock.get("algorithm") != PROTOCOL.ALGORITHM:
		return "installed candidate implementation/algorithm/version mismatch"
	if not lock.get("archive") is Dictionary or not _hex(lock.archive.get("sha256"),64) or not _hex(lock.get("release_head"),40) or not _hex(lock.get("source_commit"),40):
		return "invalid installed algorithm release identity"
	if not lock.get("module_package") is Dictionary or lock.module_package.get("version") != "1.1.0" or lock.module_package.get("sha256") != PROTOCOL.PACKAGE_SHA or not lock.module_package.get("path") is String:
		return "invalid locked module package identity/path"
	# Installer/bundle checks own addon source bytes; exported scripts may be remapped.
	return ""

func _hex(value: Variant, length: int) -> bool:
	return value is String and value.length() == length and value == value.to_lower() and value.is_valid_hex_number(false)

func _copy_request(source: LevelRequest) -> LevelRequest:
	if source == null: return null
	var result := LevelRequest.new()
	result.root_seed = source.root_seed
	result.region_id = source.region_id
	result.map_index = source.map_index
	if source.tuning != null:
		# PlayerTuning's live fields are non-export script variables. Resource
		# duplicate does not capture them; copy the actual values, not defaults.
		result.tuning = PlayerTuning.new()
		for property: Dictionary in source.tuning.get_property_list():
			if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
			var key := str(property.name)
			var value: Variant = source.tuning.get(key)
			result.tuning.set(key,value.duplicate(true) if value is Array or value is Dictionary else value)
	result.expected_hash = source.expected_hash
	result.root_bell_mode = source.root_bell_mode
	result.capabilities = source.capabilities.duplicate(true)
	return result

func _add_ms(ticket: Ticket, name: String, duration: float) -> void:
	ticket.metrics[name] = float(ticket.metrics.get(name,0.0))+duration

func _elapsed_ms(started: int) -> float:
	return float(Time.get_ticks_usec()-started)/1000.0

func _capture_terminal_wall(ticket: Ticket) -> void:
	if ticket.preload_started_usec>0 and not ticket.metrics.has("preload_wall_ms"):
		ticket.metrics["preload_wall_ms"] = _elapsed_ms(ticket.preload_started_usec)
	if ticket.generation_started_usec>0 and not ticket.metrics.has("generation_wall_ms"):
		ticket.metrics["generation_wall_ms"] = _elapsed_ms(ticket.generation_started_usec)

func _capture_missing_profiles(ticket: Ticket) -> void:
	var started := Time.get_ticks_usec()
	if ticket.preloader != null and not ticket.metrics.has("preload_profile"):
		ticket.metrics["preload_profile"] = ticket.preloader.profile()
		ticket.metrics["preload_terminal_status"] = str(ticket.preloader.result().get("status","PENDING"))
	if ticket.job != null and not ticket.metrics.has("generation_profile"):
		ticket.metrics["generation_profile"] = ticket.job.profile()
		ticket.metrics["generation_terminal_status"] = str(ticket.job.result().get("status","PENDING"))
	ticket.metrics["cancel_profile_ms"] = float(ticket.metrics.get("cancel_profile_ms",0.0))+_elapsed_ms(started)

func _cancel(ticket: Ticket, reason: String) -> void:
	var started := Time.get_ticks_usec()
	if ticket.preloader != null:
		ticket.preloader.cancel()
		ticket.progress = ticket.preloader.progress().duplicate(true)
		ticket.metrics.preload_progress.append(ticket.progress.duplicate(true))
	if ticket.job != null:
		ticket.job.cancel()
		ticket.progress = ticket.job.progress().duplicate(true)
		ticket.progress_history.append(ticket.progress.duplicate(true))
		ticket.metrics.operations = int(ticket.progress.get("operations",0))
	_capture_missing_profiles(ticket)
	_capture_terminal_wall(ticket)
	ticket.preloader = null
	if ticket.phase not in ["failed","committed"]:
		ticket.error = reason
		ticket.phase = "cancelled"
	ticket.built = null
	ticket.job = null
	ticket.metrics["cancel_ms"] = float(ticket.metrics.get("cancel_ms",0.0))+_elapsed_ms(started)

func _fail(ticket: Ticket, message: String) -> void:
	var started := Time.get_ticks_usec()
	if ticket.preloader != null:
		ticket.preloader.cancel()
		ticket.progress = ticket.preloader.progress().duplicate(true)
	if ticket.job != null:
		ticket.job.cancel()
		ticket.progress = ticket.job.progress().duplicate(true)
		ticket.progress_history.append(ticket.progress.duplicate(true))
		ticket.metrics.operations = int(ticket.progress.get("operations",0))
	_capture_missing_profiles(ticket)
	_capture_terminal_wall(ticket)
	ticket.preloader = null
	ticket.error = message
	ticket.phase = "failed"
	ticket.built = null
	ticket.job = null
	ticket.metrics["cancel_ms"] = float(ticket.metrics.get("cancel_ms",0.0))+_elapsed_ms(started)

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	# Explicit close remains the entrance's responsibility. During PREDELETE
	# self method dispatch is no longer valid: only unwind the owned pure job.
	_closed = true
	if _current != null:
		if _current.preloader != null: _current.preloader.cancel()
		_current.preloader = null
		if _current.job != null: _current.job.cancel()
		_current.job = null
		_current.built = null
		_current = null

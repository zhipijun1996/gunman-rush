class_name RuntimeMapGenerationJob
extends RefCounted
## Source-owned cooperative envelope. The entrance owns SceneTree and RunSession.
## Every accepting operation receives the entrance's actual current lifetime.
const JOB := preload("res://addons/mapgen/generation_job.gd")
const ARCHIVE := preload("res://addons/mapgen/module_archive.gd")
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
	var library: Variant
	var job: Variant
	var actual: Dictionary = {}
	var provenance: Dictionary = {}
	var progress: Dictionary = {}
	var progress_history: Array[Dictionary] = []
	var metrics: Dictionary = {"preload_ms":0.0,"advance_ms":[],"advance_max_ms":0.0,"advance_calls":0,"validate_ms":0.0,"operations":0}
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
	_current = ticket
	if not _accepts(ticket,lifetime):
		_fail(ticket,"generation owner/lifetime is not active")
	elif ticket.request == null or ticket.request.tuning == null:
		_fail(ticket,"request: missing LevelRequest/tuning")
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
	match ticket.phase:
		"preload": _preload(ticket)
		"generate": _advance(ticket)
		"validate": _validate(ticket)
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
	return ticket.actual.duplicate(true)

func provenance(value: RefCounted, current_lifetime: DemoLifetime) -> Dictionary:
	var ticket := _ticket(value)
	if ticket == null or not _accepts(ticket,current_lifetime) or ticket.phase == "cancelled": return {}
	return ticket.provenance.duplicate(true)

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
	var lock_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCK_PATH))
	if not lock_value is Dictionary:
		ticket.metrics.preload_ms = _elapsed_ms(started)
		_fail(ticket,"missing/invalid installed mapgen candidate lock")
		return
	var lock: Dictionary = lock_value
	var problem := _lock_error(lock)
	if not problem.is_empty():
		ticket.metrics.preload_ms = _elapsed_ms(started)
		_fail(ticket,problem)
		return
	var modules: Dictionary = lock.module_package
	var opened: Dictionary = ARCHIVE.open_zip(str(modules.path),str(modules.sha256))
	ticket.metrics.preload_ms = _elapsed_ms(started)
	if not opened.get("ok",false):
		_fail(ticket,str(opened.get("error","module archive preload failed")))
		return
	ticket.library = opened.library
	if ticket.library.sha256 != modules.sha256 or ticket.library.version != modules.version:
		_fail(ticket,"module archive identity differs from installed lock")
		return
	ticket.provenance = {"kind":"generated_memory","expected_request_fingerprint":PROTOCOL.fingerprint(ticket.request_data,ticket.config,str(ticket.library.sha256)),"implementation":PROTOCOL.IMPLEMENTATION,"algorithm":PROTOCOL.ALGORITHM,"algorithm_package":{"version":lock.version,"zip_sha256":lock.archive.sha256,"release_head":lock.release_head,"source_commit":lock.source_commit},"module_archive":{"path":modules.path,"sha256":ticket.library.sha256,"version":ticket.library.version},"request":ticket.request_data.duplicate(true),"config":ticket.config.duplicate(true)}
	# No bindings_file byte attestation: this API receives values, not a read file.
	ticket.job = JOB.create(ticket.request_data,ticket.library,ticket.config)
	ticket.progress = ticket.job.progress().duplicate(true)
	ticket.progress_history.append(ticket.progress.duplicate(true))
	ticket.metrics.preload_ms = _elapsed_ms(started)
	ticket.phase = "generate"

func _advance(ticket: Ticket) -> void:
	var started := Time.get_ticks_usec()
	var advanced: Dictionary = ticket.job.advance(ticket.operation_budget)
	var duration := _elapsed_ms(started)
	ticket.metrics.advance_ms.append(duration)
	ticket.metrics.advance_calls = int(ticket.metrics.advance_calls)+1
	ticket.metrics.advance_max_ms = maxf(float(ticket.metrics.advance_max_ms),duration)
	ticket.progress = ticket.job.progress().duplicate(true)
	ticket.progress_history.append(ticket.progress.duplicate(true))
	ticket.metrics.operations = int(ticket.progress.get("operations",0))
	if not advanced.get("ok",false):
		_fail(ticket,str(advanced.get("error","generation advance failed")))
		return
	if ticket.job.is_done():
		ticket.actual = ticket.job.result().duplicate(true)
		ticket.phase = "validate"

func _validate(ticket: Ticket) -> void:
	var started := Time.get_ticks_usec()
	var expected: String = PROTOCOL.fingerprint(ticket.request_data,ticket.config,str(ticket.library.sha256))
	var actual: Dictionary = ticket.actual
	if actual.get("status") != "PASS" or actual.get("schema") != "mapgen/generation-result/v1":
		ticket.metrics.validate_ms = _elapsed_ms(started)
		_fail(ticket,"generation did not produce a completed PASS result")
		return
	if expected != ticket.provenance.get("expected_request_fingerprint") or actual.get("request_fingerprint") != expected:
		ticket.metrics.validate_ms = _elapsed_ms(started)
		_fail(ticket,"generation result differs from actual Protocol request fingerprint")
		return
	if not actual.get("map") is Dictionary or not actual.map.get("generator") is Dictionary or actual.map.generator.get("request_fingerprint") != expected:
		ticket.metrics.validate_ms = _elapsed_ms(started)
		_fail(ticket,"generation map differs from original Protocol request fingerprint")
		return
	var spawns: Variant = ticket.bindings.get("spawns")
	var point: Variant = spawns.get(ticket.binding_id) if spawns is Dictionary else null
	if not LevelContentValidation.point(point):
		ticket.metrics.validate_ms = _elapsed_ms(started)
		_fail(ticket,"unknown/invalid generated slice spawn binding: "+ticket.binding_id)
		return
	var spawn := Vector2(float(point[0]),float(point[1]))
	# Provider owns the one shared content converter. Preserve the original result.
	ticket.built = RuntimeMapV2Provider.load_generated_level(ticket.request,actual.duplicate(true),ticket.ids,spawn,ticket.bindings.duplicate(true),ticket.provenance.duplicate(true),ticket.binding_id)
	ticket.metrics.validate_ms = _elapsed_ms(started)
	if ticket.built == null or not ticket.built.accepted():
		_fail(ticket,ticket.built.error if ticket.built != null else "generated provider returned no LevelBuildResult")
		return
	ticket.phase = "ready"

func _lock_error(lock: Dictionary) -> String:
	if lock.get("version") != "0.3.0" or lock.get("implementation") != PROTOCOL.IMPLEMENTATION or lock.get("algorithm") != PROTOCOL.ALGORITHM:
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

func _elapsed_ms(started: int) -> float:
	return float(Time.get_ticks_usec()-started)/1000.0

func _cancel(ticket: Ticket, reason: String) -> void:
	if ticket.job != null:
		ticket.job.cancel()
		ticket.progress = ticket.job.progress().duplicate(true)
		ticket.progress_history.append(ticket.progress.duplicate(true))
		ticket.metrics.operations = int(ticket.progress.get("operations",0))
	if ticket.phase not in ["failed","committed"]:
		ticket.error = reason
		ticket.phase = "cancelled"
	ticket.built = null
	ticket.job = null
	ticket.library = null

func _fail(ticket: Ticket, message: String) -> void:
	if ticket.job != null:
		ticket.job.cancel()
		ticket.progress = ticket.job.progress().duplicate(true)
		ticket.progress_history.append(ticket.progress.duplicate(true))
		ticket.metrics.operations = int(ticket.progress.get("operations",0))
	ticket.error = message
	ticket.phase = "failed"
	ticket.built = null
	ticket.job = null
	ticket.library = null

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	# Explicit close remains the entrance's responsibility. During PREDELETE
	# self method dispatch is no longer valid: only unwind the owned pure job.
	_closed = true
	if _current != null:
		if _current.job != null: _current.job.cancel()
		_current.job = null
		_current.library = null
		_current.built = null
		_current = null

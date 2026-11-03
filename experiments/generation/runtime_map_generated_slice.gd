class_name RuntimeMapGeneratedSlice
extends RuntimeMapSlice
## Explicit candidate entrance. The official conformance profile grants nothing.
const DATA := preload("res://addons/mapgen/data_json.gd")
const PROFILE := preload("res://experiments/generation/runtime_map_generation_profile.gd")
const DEFAULT_INPUT_PROFILE := "conformance"
const DEFAULT_BINDINGS_PATH := "res://resources/levels/mapgen_host_v4/bindings.json"
const DEFAULT_BINDINGS_SHA256 := "182b4b50da807ace3b38b327645d156f02f73286d976b4de6dbace4590bc2809"
const REQUEST_BUILDER := preload("res://experiments/generation/runtime_map_generation_request.gd")
@export_enum("conformance", "controller") var generation_profile := "conformance"
@export_range(1,4096) var operation_budget := 128
var generation := RuntimeMapGenerationJob.new()
var ticket: RefCounted
var capability_snapshot: Dictionary = {}
var profile_inputs: Dictionary = {}
var segment: SegmentRespawn
var entry_admitted := false
var generation_receipt: Dictionary = {}
var _loading_layer: CanvasLayer
var _loading_label: Label
var _previous_phase := ""
var _pending_build: LevelBuildResult
var _assembly_started := 0
var _physics_admitted := false

func _start_source() -> void:
	session.controller.active = false
	_loading_layer = CanvasLayer.new()
	add_child(_loading_layer)
	_loading_label = Label.new()
	_loading_label.position = Vector2(24,24)
	_loading_layer.add_child(_loading_label)
	var cancel := Button.new()
	cancel.position = Vector2(24,170)
	cancel.text = "CANCEL / EXIT"
	cancel.pressed.connect(request_exit)
	_loading_layer.add_child(cancel)
	if not profile_inputs.get("ok",false):
		_generation_failure(str(profile_inputs.get("error","Profile was not captured before session start")))
		return
	var host := _read_host_bindings()
	if not host.get("ok",false):
		_generation_failure(str(host.get("error","Host selection recipe unreadable")))
		return
	var actual := REQUEST_BUILDER.from_controller(session.controller,session.player,int(profile_inputs.request.seed),profile_inputs.request)
	if not actual.ok:
		_generation_failure(actual.error)
		return
	capability_snapshot = actual.snapshot
	var algorithm_request: Dictionary = profile_inputs.request if generation_profile=="conformance" else actual.request
	request.capabilities = {"profile":generation_profile,"grapple":session.controller.traversal.hook_enabled,"weapon_id":str(session.controller.shoot_ability.weapon.id),"collision_half_extents":actual.snapshot.collision.half_extents_pixels.duplicate(),"abilities":actual.request.player.abilities.duplicate()}
	var ids: Array[String] = []
	if not host.bindings.get("selected_instances") is Array:
		_generation_failure("Host binding selection must be an array")
		return
	for id: Variant in host.bindings.selected_instances:
		if not id is String:
			_generation_failure("Host binding selection must contain string identities")
			return
		ids.append(id)
	ticket = generation.begin(self,session.lifetime,request,algorithm_request,profile_inputs.config,host.bindings,ids,spawn_binding,operation_budget)
	if ticket == null:
		_generation_failure("Generation source refused new job")
		return
	_source_observe("started")

func _profile_key() -> String:
	return DEFAULT_INPUT_PROFILE

func _source_seed() -> String:
	profile_inputs = PROFILE.read_profile(_profile_key())
	if not profile_inputs.get("ok",false):
		error = str(profile_inputs.get("error","Invalid locked generation profile"))
		return ""
	return str(profile_inputs.seed)

func _read_host_bindings() -> Dictionary:
	return RuntimeMapFrozenSource.read_binding_file(DEFAULT_BINDINGS_PATH,DEFAULT_BINDINGS_SHA256)

func _slice_description() -> String:
	return "actual ellipse-junction recipe / "+str(profile_inputs.get("seed",""))

func _needs_physics_admission() -> bool:
	return true

func _physics_admission() -> String:
	if not is_instance_valid(stage) or not stage.assembly_ok or not is_instance_valid(policy) or policy.lifetime!=session.lifetime:
		return "Generated physics admission has no current Stage/damage owner"
	if segment == null:
		segment = SegmentRespawn.new()
		segment.configure(session.controller,session.lifetime)
		segment.danger_bounds = stage.assembler.world_dangers()
		if not segment.add_anchor(&"generated_entry",stage.plan.spawn): return "Generated entry anchor could not be registered"
	if not segment.activate_anchor(&"generated_entry"):
		return "Generated entry is unsafe in actual physics; no body/three-foot support"
	policy.protect_player()
	entry_admitted = true
	return ""

func _process(_delta: float) -> void:
	if closed or ready_ok or ticket == null: return
	if _pending_build != null:
		if not generation.is_current(ticket,session.lifetime):
			_assembly_failure("Assembled generation became stale before commit")
		elif _physics_admitted:
			_finish_install()
		return
	generation.tick(ticket,session.lifetime)
	var phase := generation.phase(ticket)
	if phase != _previous_phase:
		_previous_phase = phase
		_source_observe(phase)
	_loading_label.text = "REAL MAPGEN 0.4.0 / %s\nProfile: %s (slice only)\n%s; no full-map playability claim\nESC or CANCEL to exit" % [phase,generation_profile,_slice_description()]
	if phase in ["failed","cancelled","stale"]:
		_generation_failure(generation.error(ticket))
		return
	if phase != "ready": return
	var built := generation.take_plan(ticket,session.lifetime)
	if built == null:
		_generation_failure("Current generated plan unavailable")
		return
	_assembly_started = Time.get_ticks_usec()
	if not generation.is_current(ticket,session.lifetime) or not _assemble_plan(built):
		_assembly_failure(error if not error.is_empty() else "Stale generated assembly")
		return
	_pending_build = built
	_physics_admitted = not _needs_physics_admission()
	if _physics_admitted: _finish_install()

func _physics_process(delta: float) -> void:
	if not closed and _pending_build != null and not _physics_admitted:
		if not generation.is_current(ticket,session.lifetime):
			_assembly_failure("Generation invalidated before physics admission")
			return
		var problem := _physics_admission()
		if not problem.is_empty():
			_assembly_failure(problem)
			return
		_physics_admitted = true
	super(delta)

func _finish_install() -> void:
	var built := _pending_build
	if not generation.is_current(ticket,session.lifetime) or not _commit_plan(built.plan):
		_assembly_failure(error if not error.is_empty() else "Stale generation before commit")
		return
	generation_receipt = {"profile":generation_profile,"source_kind":"generated_memory","identity":built.plan.get_meta("runtime_map_v2_identity").duplicate(true),"metrics":generation.metrics(ticket),"assembly_ms":float(Time.get_ticks_usec()-_assembly_started)/1000.0,"actual_hook_enabled":session.controller.traversal.hook_enabled,"request_abilities":generation.provenance(ticket,session.lifetime).request.player.abilities.duplicate()}
	var actual_output := generation.actual_result(ticket,session.lifetime)
	generation_receipt["output"] = {"status":actual_output.status,"seed":actual_output.map.seed,"request_fingerprint":actual_output.request_fingerprint,"instances":actual_output.map.instances.size(),"connections":actual_output.map.connections.size(),"content_entries":actual_output.content_store.size()}
	_label.text = "REAL GENERATED MAP / %s\n%s loading slice / A,D or arrows / ESC exit\nNo full-map, enemy, reward or Boss certification" % [generation_profile,_slice_description()]
	session.controller.active = true
	_loading_layer.queue_free()
	_pending_build = null
	_source_observe("committed")

func _approve_install() -> bool:
	if generation.commit(ticket,session.lifetime): return true
	error = "Stale or already committed generated plan"
	return false

func _load_source() -> LevelBuildResult:
	var refused := LevelBuildResult.new()
	refused.error = "Generated entrance reload is not enabled; exit and start a fresh job"
	return refused

func _close_source() -> void:
	_pending_build = null
	generation.close()
	_source_observe("source_closed")

func _assembly_failure(message: String) -> void:
	generation.fail_assembly(ticket,message)
	_pending_build = null
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
		stage = null
	if is_instance_valid(policy):
		remove_child(policy)
		policy.queue_free()
		policy = null
	_generation_failure(message)

func _generation_failure(message: String) -> void:
	error = message
	set_process(false)
	if is_instance_valid(_loading_label): _loading_label.text = "GENERATION FAILED\n"+message+"\nESC or CANCEL to exit"
	_source_observe("failed")

func _source_observe(event: String) -> void:
	if not diagnostics_enabled: return
	var observation := {"event":event,"phase":generation.phase(ticket),"profile":generation_profile,"source_kind":"generated_memory","ready":ready_ok,"closed":closed,"actual_hook_enabled":session.controller.traversal.hook_enabled if is_instance_valid(session.controller) else false,"error":error}
	if event == "committed": observation.merge(generation_receipt,true)
	print("MAPGEN_RUNTIME ",JSON.stringify(observation))

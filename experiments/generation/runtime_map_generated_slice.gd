class_name RuntimeMapGeneratedSlice
extends RuntimeMapSlice
## Explicit candidate entrance. The official conformance profile grants nothing.
const DATA := preload("res://addons/mapgen/data_json.gd")
const REQUEST_BUILDER := preload("res://experiments/generation/runtime_map_generation_request.gd")
@export_enum("conformance930001", "controller") var generation_profile := "conformance930001"
@export_range(1,4096) var operation_budget := 128
var generation := RuntimeMapGenerationJob.new()
var ticket: RefCounted
var capability_snapshot: Dictionary = {}
var generation_receipt: Dictionary = {}
var _loading_layer: CanvasLayer
var _loading_label: Label
var _previous_phase := ""

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
	var lock: Variant = JSON.parse_string(FileAccess.get_file_as_string(RuntimeMapGenerationJob.LOCK_PATH))
	if not lock is Dictionary or not lock.get("conformance") is Dictionary or not lock.conformance.get("request") is Dictionary or not lock.conformance.get("config") is Dictionary:
		_generation_failure("Invalid candidate lock")
		return
	for item: Dictionary in [lock.conformance.request,lock.conformance.config]:
		if not item.get("path") is String or not item.get("sha256") is String or not FileAccess.file_exists(item.path) or FileAccess.get_sha256(item.path) != item.sha256:
			_generation_failure("Algorithm input bytes differ from candidate lock")
			return
	var input: Dictionary = DATA.parse(FileAccess.get_file_as_string(lock.conformance.request.path))
	var config: Dictionary = DATA.parse(FileAccess.get_file_as_string(lock.conformance.config.path))
	var host := RuntimeMapFrozenSource.read_bindings()
	if not input.ok or not config.ok or not host.ok:
		_generation_failure("Algorithm inputs or host bindings could not be decoded")
		return
	var actual := REQUEST_BUILDER.from_controller(session.controller,session.player,930001,input.value)
	if not actual.ok:
		_generation_failure(actual.error)
		return
	capability_snapshot = actual.snapshot
	var algorithm_request: Dictionary = input.value if generation_profile == "conformance930001" else actual.request
	request.capabilities = {"profile":generation_profile,"grapple":session.controller.traversal.hook_enabled,"weapon_id":str(session.controller.shoot_ability.weapon.id),"collision_half_extents":actual.snapshot.collision.half_extents_pixels.duplicate(),"abilities":actual.request.player.abilities.duplicate()}
	ticket = generation.begin(self,session.lifetime,request,algorithm_request,config.value,host.bindings,RuntimeMapFrozenSource.IDS,spawn_binding,operation_budget)
	if ticket == null:
		_generation_failure("Generation source refused new job")
		return
	_source_observe("started")

func _process(_delta: float) -> void:
	if closed or ready_ok or ticket == null: return
	generation.tick(ticket,session.lifetime)
	var phase := generation.phase(ticket)
	if phase != _previous_phase:
		_previous_phase = phase
		_source_observe(phase)
	_loading_label.text = "REAL MAPGEN 0.3.0 / %s\nProfile: %s (slice only)\nM16 + M18 + M21; no full-map playability claim\nESC or CANCEL to exit" % [phase,generation_profile]
	if phase in ["failed","cancelled","stale"]:
		_generation_failure(generation.error(ticket))
		return
	if phase != "ready": return
	var built := generation.take_plan(ticket,session.lifetime)
	if built == null:
		_generation_failure("Current generated plan unavailable")
		return
	var started := Time.get_ticks_usec()
	if not _install_plan(built):
		generation.fail_assembly(ticket,error)
		_generation_failure(error)
		return
	generation_receipt = {"profile":generation_profile,"source_kind":"generated_memory","identity":built.plan.get_meta("runtime_map_v2_identity").duplicate(true),"metrics":generation.metrics(ticket),"assembly_ms":float(Time.get_ticks_usec()-started)/1000.0,"actual_hook_enabled":session.controller.traversal.hook_enabled,"request_abilities":generation.provenance(ticket,session.lifetime).request.player.abilities.duplicate()}
	var actual_output := generation.actual_result(ticket,session.lifetime)
	generation_receipt["output"] = {"status":actual_output.status,"seed":actual_output.map.seed,"request_fingerprint":actual_output.request_fingerprint,"instances":actual_output.map.instances.size(),"connections":actual_output.map.connections.size(),"content_entries":actual_output.content_store.size()}
	_label.text = "REAL GENERATED MAP / %s\nM16 + M18 + M21 loading slice / A,D or arrows / ESC exit\nNo full-map, enemy, reward or Boss certification" % generation_profile
	session.controller.active = true
	_loading_layer.queue_free()
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
	generation.close()
	_source_observe("source_closed")

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

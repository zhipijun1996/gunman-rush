class_name RuntimeMapM35Slice
extends RuntimeMapGeneratedSlice
## Independent actual ferry-gears slice. No fixed instance label or added geometry.
const BINDINGS_PATH := "res://resources/levels/mapgen_host_v4_gears/bindings.json"
const BINDINGS_SHA256 := "ef7fab5184d503c11d3ce0990f802acc620ec68ff070dacdbc242adec474ca4c"
const INPUT_PROFILE := "gears_conformance"
var terminal_failure := false
var _void_serial := 0

func _profile_key() -> String:
	return INPUT_PROFILE

func _read_host_bindings() -> Dictionary:
	return RuntimeMapFrozenSource.read_binding_file(BINDINGS_PATH,BINDINGS_SHA256)

func _slice_description() -> String:
	return "actual ferry-gears recipe / "+str(profile_inputs.get("seed",""))+" / full hazards, saw and two linear ferries"

func _needs_physics_admission() -> bool:
	return true

func _physics_admission() -> String:
	if not is_instance_valid(stage) or not stage.assembly_ok or stage.plan.modules.size()!=1 or stage.plan.modules[0].template_id!=&"game-plains-ferry-gears":
		return "Mechanism physics admission requires the actual original ferry-gears template"
	var resolved := generation.resolved_bindings(ticket,session.lifetime)
	if not resolved.get("selection_resolution") is Dictionary or resolved.selection_resolution.instances.size()!=1:
		return "Mechanism selection resolution is missing"
	var actual: Dictionary = resolved.selection_resolution.instances[0]
	if actual.instance_id!=stage.plan.modules[0].instance_id or actual.module_id!="game-plains-ferry-gears" or actual.content_version!=resolved.selection_recipe.root.content_version or actual.role!="traversal":
		return "Mechanism instance/template/version/role differs from the actual recipe"
	var problem := super()
	if not problem.is_empty(): return problem
	if not policy.environment_return_requested.is_connected(_environment_return):
		policy.environment_return_requested.connect(_environment_return)
	if not policy.player_fatal.is_connected(_player_fatal):
		policy.player_fatal.connect(_player_fatal)
	return ""

func _physics_process(delta: float) -> void:
	super(delta)
	if closed or not ready_ok or terminal_failure or not session.lifetime.active or not session.controller.active or not is_instance_valid(stage): return
	if DamageBoundary.should_return(session.player,stage.plan.bounds):
		_void_serial += 1
		var hit := DamageRequest.new()
		hit.token = session.lifetime.token()
		hit.actor_epoch = session.lifetime.actor_epoch
		hit.health_epoch = session.controller.actor_resources.health.epoch
		hit.target_id = &"player"
		hit.source_id = &"m35_void_boundary"
		hit.event_id = StringName("m35_void:%d:%d" % [session.lifetime.actor_epoch,_void_serial])
		hit.kind = DamageRequest.Kind.ENVIRONMENT
		hit.amount = 1.0
		hit.fall = true
		hit.physics_tick = Engine.get_physics_frames()
		policy.submit(hit)

func _environment_return() -> void:
	if closed or terminal_failure or segment == null: return
	if segment.return_to_anchor():
		policy.protect_player()
		if is_instance_valid(_label): _label.text = "FERRY-GEARS / environment damage: returned to original safe entry\nHP, world clock and run services retained / ESC exit"
	else:
		# Existing SegmentRespawn stops the controller on invalid content; no
		# blind fallback, new health state or forced safe coordinates are invented.
		error = "Ferry-gears has no safe entry anchor for environment return"
		if is_instance_valid(_label): _label.text = error+"\nESC exit"

func _player_fatal() -> void:
	if closed or terminal_failure: return
	terminal_failure = true
	session.controller.die()
	session.flow.end_failure(&"m35_player_death")
	if is_instance_valid(_label): _label.text = "FERRY-GEARS / zero HP: run ended through existing owner\nNo automatic restart; ESC exit"

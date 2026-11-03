class_name RuntimeMapM35Slice
extends RuntimeMapGeneratedSlice
## Independent generated M35 only. No neighbor, extra floor, seal or ability.
const BINDINGS_PATH := "res://resources/levels/mapgen_host_v3_m35/bindings.json"
const BINDINGS_SHA256 := "658ede2c388a4b0ddcf6efbcaa85633091b3b42fe7448f080d8d6eacf86ef4bf"
var segment: SegmentRespawn
var entry_admitted := false
var terminal_failure := false
var _void_serial := 0

func _read_host_bindings() -> Dictionary:
	return RuntimeMapFrozenSource.read_binding_file(BINDINGS_PATH,BINDINGS_SHA256)

func _slice_description() -> String:
	return "M35 only / full authored hazards, saw and two linear ferries"

func _needs_physics_admission() -> bool:
	return true

func _physics_admission() -> String:
	if not is_instance_valid(stage) or not stage.assembly_ok or stage.plan.modules.size()!=1 or stage.plan.modules[0].instance_id!="M35" or stage.plan.modules[0].template_id!=&"game-plains-ferry-gears":
		return "M35 physics admission requires exactly original game-plains-ferry-gears instance M35"
	if not is_instance_valid(policy) or policy.lifetime!=session.lifetime:
		return "M35 physics admission has no current damage owner"
	if segment == null:
		segment = SegmentRespawn.new()
		segment.configure(session.controller,session.lifetime)
		segment.danger_bounds = stage.assembler.world_dangers()
		if not segment.add_anchor(&"m35_entry",stage.plan.spawn): return "M35 entry anchor could not be registered"
	if not segment.activate_anchor(&"m35_entry"):
		return "M35 entry is unsafe in actual physics; no body/three-foot safe support"
	if not policy.environment_return_requested.is_connected(_environment_return):
		policy.environment_return_requested.connect(_environment_return)
	if not policy.player_fatal.is_connected(_player_fatal):
		policy.player_fatal.connect(_player_fatal)
	policy.protect_player()
	entry_admitted = true
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
		if is_instance_valid(_label): _label.text = "M35 / environment damage: returned to original safe entry\nHP, world clock and run services retained / ESC exit"
	else:
		# Existing SegmentRespawn stops the controller on invalid content; no
		# blind fallback, new health state or forced safe coordinates are invented.
		error = "M35 has no safe entry anchor for environment return"
		if is_instance_valid(_label): _label.text = error+"\nESC exit"

func _player_fatal() -> void:
	if closed or terminal_failure: return
	terminal_failure = true
	session.controller.die()
	session.flow.end_failure(&"m35_player_death")
	if is_instance_valid(_label): _label.text = "M35 / zero HP: run ended through existing owner\nNo automatic restart; ESC exit"

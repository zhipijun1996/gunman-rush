class_name WorldPermanentResult
extends Node2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("permanent") var state_scope := "permanent"
@export_enum("open_gate","lower_beam","settle_block") var result_kind := "open_gate"
@export var result_target_id := ""
var target: Node
var host: WorldRoomInteraction
var session: OrdinaryRoomSession
var latch: WorldElementSwitch
var before := {}
var phase := "ready":
	set(value):
		phase = value
		queue_redraw()

func element_bind(context: Dictionary) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	session = context.room.get_parent() as OrdinaryRoomSession
	target = context.runtime.nodes[result_target_id]
	if target is MechanismSolid: target.result_owned = true
	for node in context.room.find_children("*","",true,false):
		if node is WorldRoomInteraction and node.action_owner_id == element_id:
			host = node
	if session.state.value.receipts.has(host.action_id):
		phase = "completed"
		target.install_terminal(result_kind)

func begin(source: WorldElementSwitch) -> void:
	if phase != "ready" or session.state.action_candidate(host.action_id, session.room.room_id, section_id).is_empty(): return
	if not source.request_is_live(): return
	latch = source
	before = target.element_state().duplicate(true)
	if result_kind != "open_gate":
		var input := "set_pose" if result_kind == "lower_beam" else "release"
		var value: Variant = 0 if result_kind == "lower_beam" else null
		if not target.element_can_receive(input,value): return
		target.element_restore(target.element_propose(input,value))
	phase = "executing"

func _physics_process(_delta: float) -> void:
	if phase != "executing": return
	if not is_instance_valid(latch) or not latch.request_is_live():
		cancel_result()
		return
	if result_kind != "open_gate" and not target.result_at_terminal(result_kind): return
	phase = "committing"
	session._activate(latch.element_id)
	if phase == "committing": cancel_result()

func cancel_result() -> void:
	if not before.is_empty(): target.element_restore(before)
	if is_instance_valid(latch): latch.cancel_pending()
	phase = "ready"

func reset_execution() -> void:
	if session.state.value.receipts.has(host.action_id):
		phase = "completed"
		target.install_terminal(result_kind)
	else:
		if is_instance_valid(latch): latch.cancel_pending()
		phase = "ready"
	before.clear()
	latch = null

func world_candidate() -> Dictionary:
	return session.state.action_candidate(host.action_id,session.room.room_id,section_id)

func element_can_receive(input: String, value: bool) -> bool:
	return input == "request" and value and phase == "committing"

func element_state() -> Dictionary:
	return {"completed":phase == "completed"}

func element_propose(_input: String,_value: bool) -> Dictionary:
	return {"completed":true}

func element_restore(data: Dictionary) -> void:
	phase = "completed" if data.completed and session.state.value.receipts.has(host.action_id) else "ready"
	if phase == "completed": target.install_terminal(result_kind)

func _draw() -> void:
	MechanismRegionArt.stamp(self,"mount",Vector2.ZERO,Vector2(38,31))
	# Two retaining jaws meet until the permanent outcome has been received.
	var spread := 9 if phase == "completed" else 4
	for sign_x: int in [-1,1]:
		MechanismRegionArt.stamp(self,"finial",Vector2(sign_x*spread,-3),Vector2(13,22))
	var lit := phase in ["executing","committing","completed"]
	MechanismRegionArt.stamp(self,"lamp",Vector2(0,-2),Vector2(11,16),Color.WHITE if lit else Color("#757774"))

static func validate_configuration(p: Dictionary,row: Dictionary,doc: Dictionary) -> String:
	var hosts: Array = doc.entities.values().filter(func(other): return other.definition_id=="interaction.action" and other.properties.get("action_owner_id")==row.id)
	if hosts.size()!=1: return "action_owner_id:unique_host_required"
	if hosts[0].properties.section_id != p.section_id: return "action_owner_id:section_mismatch"
	for action: Variant in doc.get("actions",[]):
		if not action is Dictionary or not action.has("id"): return "action_id:invalid_action"
		if action.id == hosts[0].properties.action_id and action.get("repeat",false): return "action_id:permanent_result_requires_single_use"
	var latches := 0
	for other: Dictionary in doc.entities.values():
		if other.id != hosts[0].id and other.properties.get("action_id","") == hosts[0].properties.action_id and not str(hosts[0].properties.action_id).is_empty(): return "action_id:delegated_action_has_another_host"
		for link: Variant in other.properties.get("links",[]):
			if not link is Dictionary: return "signal_link_invalid"
			if link.get("target") == p.result_target_id: return "result_target_id:multiple_controllers"
			if link.get("target") != row.id: continue
			if other.definition_id != "switch.shot" or other.properties.repeat_enabled or other.properties.duration > 0 or other.properties.links.size() != 1:
				return "request:single_use_latch_required"
			if other.properties.section_id != p.section_id: return "request:section_mismatch"
			latches += 1
	if latches != 1: return "request:unique_latch_required"
	var expected := {"open_gate":"gate.masonry","lower_beam":"platform.rotating_beam","settle_block":"hazard.falling_weight"}
	var target: Dictionary = doc.entities.get(p.result_target_id,{})
	if target.get("definition_id") != expected[p.result_kind]: return "result_target_id:wrong_type"
	if target.properties.get("state_scope") != "attempt": return "result_target_id:attempt_required"
	if target.properties.get("gate_mode","signal") != "signal" or not str(target.properties.get("drive_id","")).is_empty(): return "result_target_id:controlled_by_another_source"
	if p.result_kind == "lower_beam" and (target.properties.initial_pose == 0 or target.properties.rotation_mode not in ["step","indexed"]): return "result_target_id:pose_control_required"
	if target.properties.get("section_id","main") != p.section_id: return "result_target_id:section_mismatch"
	for other: Dictionary in doc.entities.values():
		if other.id != row.id and other.definition_id == row.definition_id and other.properties.result_target_id == p.result_target_id:
			return "result_target_id:multiple_owners"
	return ""

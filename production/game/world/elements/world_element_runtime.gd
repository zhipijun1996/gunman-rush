class_name WorldElementRuntime
extends RefCounted
## Room-local addressing, atomic proposals, and type-owned state restore.
var nodes: Dictionary = {}
var kinds: Dictionary = {}
var initial := {}
var conditions: Array[WorldBoolCondition] = []

func bind(room: FixedWorldRoom, controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, saved: Dictionary, submit: Callable) -> void:
	for node: Node in room.find_children("*", "", true, false):
		if not node.has_method("element_state") or str(node.get("element_id")).is_empty(): continue
		var id := str(node.get("element_id")); nodes[id] = node; kinds[id] = WorldElementCatalog.component_for(node.get_script())
	var context := {"room":room,"controller":controller,"policy":policy,"lifetime":lifetime,"submit":submit,"runtime":self}
	for id: String in nodes:
		if nodes[id].has_method("element_bind"): nodes[id].call("element_bind", context)
	# Hydration never emits signals or success feedback.
	for id: String in nodes:
		if str(nodes[id].get("state_scope")) == "permanent" and saved.has(id) and saved[id] is Dictionary and saved[id].get("type") == kinds[id] and WorldElementCatalog.state_error(saved[id]).is_empty(): nodes[id].call("element_restore",saved[id].data)
		if nodes[id].has_method("can_commit"): room.mechanisms[id] = nodes[id]

	for node: Node in nodes.values():
		if node is WorldBoolCondition: _order_condition(node)
	var hydrated := {}
	for source: Node in nodes.values():
		if source is WorldElementSwitch and source.repeat_enabled:
			_route(source, {"active":source.is_open}, hydrated, true)
	var values := _outputs()
	for condition: WorldBoolCondition in conditions:
		var value := condition.evaluate(values)
		values[condition.element_id] = {"active":value}
		hydrated[condition.element_id] = packet(condition.element_id, {"active":value})
		_route(condition, values[condition.element_id], hydrated, true)
	for id: String in hydrated:
		if nodes[id].state_scope != "permanent" or not saved.has(id):
			nodes[id].element_restore(hydrated[id].data)

	for id: String in nodes:
		if nodes[id].state_scope == "attempt": initial[id] = nodes[id].element_state().duplicate(true)

func reset_section(section: String) -> void:
	for id: String in nodes:
		var node: Node = nodes[id]
		if ("section_id" in node and node.section_id != section) or (not "section_id" in node and section != "main"): continue
		if node.has_method("cancel_pending"): node.cancel_pending()
		if not initial.has(id): continue
		if node.has_method("reset_attempt"): node.reset_attempt()
		else: node.element_restore(initial[id].duplicate(true))
	for node: Node in nodes.values():
		if node is WorldPermanentResult and node.section_id == section: node.reset_execution()
	for condition: WorldBoolCondition in conditions:
		if condition.state_scope == "attempt" and condition.section_id == section:
			condition.element_restore({"active":condition.evaluate(_outputs())})

func _order_condition(condition: WorldBoolCondition) -> void:
	if condition in conditions: return
	for link: Dictionary in condition.sources:
		var child: Node = nodes[link.source_id]
		if child is WorldBoolCondition: _order_condition(child)
	conditions.append(condition)

func motion_owner(node: Node) -> Node:
	var seen := {}
	while node != null and "drive_id" in node and not str(node.drive_id).is_empty():
		if seen.has(node): return null
		seen[node] = true
		node = nodes.get(node.drive_id)
	return node

func _outputs() -> Dictionary:
	var values := {}
	for id: String in nodes:
		var output_names: Dictionary = WorldElementCatalog.catalog().behaviors[kinds[id]].outputs
		if output_names.is_empty(): continue
		var state: Dictionary = nodes[id].committed_outputs() if nodes[id].has_method("committed_outputs") else nodes[id].element_state()
		values[id] = {}
		for port: String in output_names:
			if state.has(port): values[id][port] = state[port]
	return values

func _route(source: Node, signals: Dictionary, changes: Dictionary, hydrate := false, initiator := "") -> bool:
	var ports: Dictionary = WorldElementCatalog.catalog().behaviors[kinds[source.element_id]].outputs
	for output: String in signals:
		if not WorldElementCatalog.signal_value_valid(ports.get(output,""),signals[output]): return false
	for link: Dictionary in source.get("links") if "links" in source else []:
		var output: String = link.get("output","active")
		if not signals.has(output): continue
		var input: String = link.get("input","set_active")
		var target: Node = nodes[link.target]
		if hydrate and input != "set_active" and not (target.has_method("hydrates_edge") and target.hydrates_edge(input)): continue
		if (target is WorldElementGear and input == "set_active" and not target.drive_id.is_empty()) or (target is WorldRotatingBeam and target.angle_owner != null):
			target = motion_owner(target)
		if target == null or not target.has_method("element_can_receive"): return false
		var candidate: Dictionary
		if target.has_method("element_input_candidate"):
			candidate = target.element_input_candidate(input, signals[output], initiator, hydrate)
		else:
			if not target.element_can_receive(input, signals[output]): return false
			candidate = target.element_propose(input, signals[output])
		if candidate.is_empty(): return false
		var id: String = target.element_id
		if changes.has(id) and changes[id].data != candidate: return false
		changes[id] = packet(id, candidate)
	return true

func _propagate(source: Node, signals: Dictionary, changes: Dictionary) -> bool:
	if not _route(source, signals, changes, false, source.element_id): return false
	if conditions.is_empty(): return true
	var values := _outputs()
	if not values.has(source.element_id): values[source.element_id] = {}
	values[source.element_id].merge(signals, true)
	for condition: WorldBoolCondition in conditions:
		var value := condition.evaluate(values)
		values[condition.element_id] = {"active":value}
		if value == condition.active: continue
		changes[condition.element_id] = packet(condition.element_id, {"active":value})
		if not _route(condition, values[condition.element_id], changes, false, source.element_id): return false
	return true

func request_reserved(id: String) -> bool:
	for target: Node in nodes.values():
		if target.has_method("holds_request") and target.holds_request(id): return true
	return false

func can_signal(source: Node, value: Variant, output := "active") -> bool:
	return _propagate(source, {output:value}, {})

func proposal(id: String) -> Dictionary:
	var source: Node = nodes.get(id)
	if source == null or not source.can_commit(): return {}
	var result := {id:packet(id,source.proposed_state())}
	var signals := {}
	if source.has_method("element_signals"):
		signals = source.element_signals()
	elif source.has_method("element_signal"):
		var signal_data: Dictionary = source.element_signal()
		signals[signal_data.output] = signal_data.value
	if not _propagate(source, signals, result): return {}
	for target: String in result:
		if not WorldElementCatalog.state_error(result[target]).is_empty(): return {}
	return result

func packet(id: String, data: Dictionary) -> Dictionary:
	return {"type":kinds[id],"version":WorldElementCatalog.catalog().behaviors[kinds[id]].state_version,"data":data}

func accept(id: String, proposed: Dictionary) -> void:
	for target: String in proposed: nodes[target].call("element_restore", proposed[target].data)
	nodes[id].call("accept_committed")

func snapshot() -> Dictionary:
	var result := {}
	for id: String in nodes:
		if str(nodes[id].get("state_scope")) == "permanent": result[id] = packet(id,nodes[id].call("element_state"))
	return result

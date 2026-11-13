class_name WorldElementRuntime
extends RefCounted
## Room-local addressing, atomic proposals, and type-owned state restore.
var nodes: Dictionary = {}
var kinds: Dictionary = {}

func bind(room: FixedWorldRoom, controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, saved: Dictionary, submit: Callable) -> void:
	for node: Node in room.find_children("*", "", true, false):
		if not node.has_method("element_state") or str(node.get("element_id")).is_empty(): continue
		var id := str(node.get("element_id")); nodes[id] = node; kinds[id] = WorldElementCatalog.component_for(node.get_script())
	var context := {"room":room,"controller":controller,"policy":policy,"lifetime":lifetime,"submit":submit,"runtime":self}
	for id: String in nodes:
		if nodes[id].has_method("element_bind"): nodes[id].call("element_bind", context)
	# Hydration never emits signals or success feedback.
	for id: String in nodes:
		if str(nodes[id].get("state_scope")) == "permanent" and saved.has(id) and saved[id].get("type") == kinds[id]: nodes[id].call("element_restore",saved[id].data)
		if nodes[id].has_method("can_commit"): room.mechanisms[id] = nodes[id]

func can_signal(source: Node, value: Variant, output := "active") -> bool:
	var source_kind := WorldElementCatalog.component_for(source.get_script())
	var type := str(WorldElementCatalog.catalog().behaviors[source_kind].get("outputs",{}).get(output,""))
	if not WorldElementCatalog.signal_value_valid(type,value): return false
	for link: Dictionary in source.links:
		if str(link.get("output","active")) != output: continue
		var target: Node = nodes.get(str(link.target))
		if target == null or not target.call("element_can_receive",str(link.get("input","set_active")), value): return false
	return true

func proposal(id: String) -> Dictionary:
	var source: Node = nodes.get(id)
	if source == null or not source.can_commit(): return {}
	var data: Dictionary = source.call("proposed_state")
	var signal_data: Dictionary = source.call("element_signal")
	if not can_signal(source,signal_data.value,str(signal_data.output)): return {}
	var result := {id:packet(id,data)}
	for link: Dictionary in source.links:
		if str(link.get("output","active")) != str(signal_data.output): continue
		var target := str(link.target)
		result[target] = packet(target,nodes[target].call("element_propose", str(link.get("input","set_active")), signal_data.value))
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

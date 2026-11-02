class_name PlainsRootBellPlacement
extends RefCounted
## Content admission stays closed until a different reviewer admits the actual
## visual/gameplay golden. No RNG calls; replace at most one existing lane guard.
const PRODUCTION_ADMITTED := false
const VERSION := "root-bell-placement-v1"

static func rejection_reasons(node: Dictionary, optional_lane: bool) -> Array[String]:
	var reasons: Array[String] = []
	if not optional_lane: reasons.append("not_optional_redundant_lane")
	if node.get("module_id", "") != "region_connection" or not node.has("geometry"):
		reasons.append("not_supported_connection")
		return reasons
	for label: String in ["ferry", "thorn", "low_arch", "merchant", "boss", "tutorial", "receiver"]:
		if str(node.id).contains(label) or str(node.get("role", "")).contains(label): reasons.append("forbidden_" + label)
	var geometry: Dictionary = node.geometry
	if geometry.get("platforms", []).is_empty():
		reasons.append("no_floor")
		return reasons
	var raw: Array = geometry.platforms[0]
	var floor := Rect2(raw[0], raw[1], raw[2], raw[3])
	if floor.size.x < 560: reasons.append("narrow_or_unique_landing")
	if geometry.get("one_way", []).has(0): reasons.append("one_way_receiver")
	if not geometry.get("ferries", []).is_empty() or not geometry.get("saws", []).is_empty() or not geometry.get("spikes", []).is_empty(): reasons.append("dynamic_or_hazard")
	var clearance := Rect2(floor.position + Vector2(100, -180), Vector2(maxf(0, floor.size.x - 200), 179))
	for i: int in range(1, geometry.platforms.size()):
		var other: Array = geometry.platforms[i]
		if clearance.intersects(Rect2(other[0], other[1], other[2], other[3])): reasons.append("low_clearance")
	return reasons

static func _optional(m: Dictionary, node: Dictionary) -> bool:
	for edge: Dictionary in m.connections:
		if str(edge.a) in [str(m.get("merchant_id", "")), str(m.get("prep_id", ""))] or str(edge.b) in [str(m.get("merchant_id", "")), str(m.get("prep_id", ""))]: continue
		if node.id != str(edge.id) + "_join" or edge.get("condition", "") != "open" or edge.get("kind", "") != "horizontal": continue
		var main_edge := false
		for spec: Dictionary in m.get("topology", {}).get("semantic_routes", {}).values():
			var areas: Array = spec.get("areas", [])
			for i: int in range(areas.size() - 1):
				if [str(edge.a), str(edge.b)] in [[str(areas[i]), str(areas[i+1])], [str(areas[i+1]), str(areas[i])]]: main_edge = true
		if main_edge: continue
		# Removing this lane must leave both ends connected, without a one-way
		# drop or hidden backside unlock. This protects the only route/receiver.
		var seen: Dictionary = {str(edge.a): true}
		var queue: Array = [str(edge.a)]
		while not queue.is_empty():
			var current: String = queue.pop_front()
			for other: Dictionary in m.connections:
				if other.id == edge.id or other.get("condition", "") != "open" or not other.get("bidirectional", false) or other.get("kind", "") == "drop": continue
				var next := str(other.b) if str(other.a) == current else str(other.a) if str(other.b) == current else ""
				if next.is_empty() or seen.has(next): continue
				seen[next] = true
				queue.append(next)
		return seen.has(str(edge.b))
	return false

static func apply(m: Dictionary, admitted: bool = PRODUCTION_ADMITTED) -> Dictionary:
	if not admitted: return {"version": VERSION, "status": "promotion_gated", "replaced": 0}
	var nodes: Array = m.nodes.duplicate()
	nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	for node: Dictionary in nodes:
		if not rejection_reasons(node, _optional(m, node)).is_empty(): continue
		var floor_data: Array = node.geometry.platforms[0]
		for enemy: Dictionary in m.enemies:
			if enemy.get("area", "") != node.id or not str(enemy.id).begins_with("plains/enemy/lane/"): continue
			enemy.behavior_id = "root_bell"
			enemy.patrol_radius = 0
			enemy.aerial = false
			enemy.position = [node.offset[0] + floor_data[0] + floor_data[2] * .5, node.offset[1] + floor_data[1] - 20]
			enemy.pattern = "ground_mark_interrupt"
			enemy.escape = "bait_fixed_ground_mark_then_walk_or_jump; shoot_actual_hp_to_interrupt"
			return {"version": VERSION, "status": "one_candidate", "replaced": 1, "id": enemy.id, "module": node.id}
	return {"version": VERSION, "status": "no_qualified_optional_lane", "replaced": 0}

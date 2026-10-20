class_name ForestFruitRoutes
extends RefCounted
## V14 presentation and bounded target retirement. No physics, grants or RNG.
const VERSION := "forest-fruit-routes-v14"
# Only promote a candidate here after a separately recorded single-target ablation.
const RETIRED_ANCHORS: Array[String] = ["thorn_mouth__rest_ring", "upper_spiral__rest_ring"]
const ABLATION_CANDIDATES: Array[String] = ["thorn_mouth__rest_ring", "upper_spiral__rest_ring", "broken_arch__return_catch_ring"]
const MAX_LOCAL_STEM := 128.0
const INNER_BOUGHS := [
	{"id":"inner_crown_side_bough","host_support_id":"root_spiral__left_bark","root":[-2430.0,1350.0],"points":[[-2430.0,1350.0],[-2320.0,1320.0],[-2230.0,1250.0],[-2110.0,1192.0],[-2072.0,1204.0]],"attachments":{"interwoven_crown_side_ring":[-2072.0,1204.0],"root_spiral__spiral_crown":[-2110.0,1192.0]},"standing_edge":false},
	{"id":"inner_hollow_fruit_bough","host_support_id":"root_spiral__crown","root":[-1800.0,1352.0],"points":[[-1800.0,1352.0],[-1830.0,1388.0],[-1885.0,1416.0],[-1935.0,1446.0],[-1962.0,1474.0]],"attachments":{"interwoven_hollow_b":[-1962.0,1474.0]},"standing_edge":false}
]
const DEEP_BOUGHS := [
	{"id":"deep_root_sapling","host_support_id":"interwoven_deep_basin","root":[110.0,1400.0],"points":[[110.0,1400.0],[40.0,1360.0],[15.0,1290.0],[20.0,1195.0],[38.0,1090.0],[60.0,1026.0]],"branches":[[[20.0,1195.0],[50.0,1202.0],[80.0,1216.0]]],"attachments":{"interwoven_deep_descent_ring":[60.0,1026.0],"interwoven_deep_a":[80.0,1216.0]},"standing_edge":false,"base_width":12.0}
]

static func install(m: Dictionary) -> void:
	var anchors: Array = []
	var pending: Array[String] = []
	var bindings := _route_bindings(m)
	var bough_attachments: Dictionary = {}
	m.fruit_boughs = INNER_BOUGHS.duplicate(true)
	m.fruit_boughs.append_array(DEEP_BOUGHS.duplicate(true))
	for bough: Dictionary in m.fruit_boughs:
		for target: String in bough.attachments:
			bough_attachments[target] = {"id":bough.id,"host":bough.host_support_id,"root":bough.attachments[target]}
	for original: Dictionary in m.hook_anchors:
		if str(original.id) in RETIRED_ANCHORS:
			continue
		var row: Dictionary = original.duplicate(true)
		row.fruit_route_bindings = bindings.get(str(row.id), []).duplicate()
		row.fruit_role = _role(m, row)
		row.fruit_role_basis = _role_basis(row)
		var host := _local_host(m, Vector2(row.position[0], row.position[1]))
		if bough_attachments.has(str(row.id)):
			var attachment: Dictionary = bough_attachments[str(row.id)]
			row.fruit_presentation = "rooted_fruit"
			row.fruit_bough_id = attachment.id
			row.fruit_host_support_id = attachment.host
			row.fruit_stem_root = attachment.root.duplicate()
		elif host.is_empty():
			# A floating fruit plus a long line would hide the spatial-design gap.
			row.fruit_presentation = "existing_marker_pending_local_support"
			pending.append(str(row.id))
		else:
			row.fruit_presentation = "rooted_fruit"
			row.fruit_host_support_id = host.id
			row.fruit_stem_root = host.point
		anchors.append(row)
	m.hook_anchors = anchors
	m.fruit_routes_contract = {
		"version": VERSION,
		"retired_anchors": RETIRED_ANCHORS.duplicate(),
		"pending_spatial_redesign": pending,
		"retained_target_positions": "exact_v13",
		"target_physics": "unchanged_grapple_target_layer8_radius12_and_hang_contract",
		"roles": ["recommended", "optional", "recovery", "gate", "boss"],
		"route_semantics": "recommendations_and_free_player_alternatives;_not_world_randomization",
		"visual_admission": "proposed_pending_actual_composition_review_and_player",
		"max_local_stem": MAX_LOCAL_STEM,
		"support_provenance": "actual_upper_perimeter_or_explicit_rooted_bough",
		"bough_geometry": "presentation_only_no_collision_or_standing_edge",
	}

static func _role(m: Dictionary, row: Dictionary) -> String:
	var id := str(row.id)
	if id == str(m.vine_gate.key_anchor):
		return "gate"
	var at := Vector2(row.position[0], row.position[1])
	var arena := Rect2(m.boss_arena[0], m.boss_arena[1], m.boss_arena[2], m.boss_arena[3])
	if arena.grow(32.0).has_point(at):
		return "boss"
	if row.has("recovery_role") or id.ends_with("return_catch_ring"):
		return "recovery"
	for binding: String in row.fruit_route_bindings:
		if binding.begins_with("fast:") or binding.begins_with("growth:"):
			return "recommended"
	return "optional"

static func _role_basis(row: Dictionary) -> String:
	match str(row.fruit_role):
		"gate": return "actual_vine_gate_key_anchor"
		"boss": return "actual_boss_arena_target"
		"recovery": return "authored_failure_recovery_or_factory_return_catch"
		"recommended": return "actual_fast_or_growth_edge_target_binding"
	return "optional_route_or_auxiliary_target;_not_fast_growth_recommended"

static func _route_bindings(m: Dictionary) -> Dictionary:
	var edges: Dictionary = {}
	var instances: Dictionary = {}
	var result: Dictionary = {}
	for edge: Dictionary in m.connections: edges[str(edge.id)] = edge
	for instance: Dictionary in m.geometry_instances: instances[str(instance.id)] = instance
	for route_name: String in ["fast", "growth", "high_return", "change_mind", "borer", "available"]:
		var route_edge_ids: Array = edges.keys() if route_name == "available" else m.routes.get(route_name, [])
		for edge_id: String in route_edge_ids:
			var edge: Dictionary = edges[edge_id]
			var instance: Dictionary = instances.get(str(edge.get("geometry_instance", "")), {})
			var mapping: Dictionary = instance.get("anchor_id_map", {})
			for action: Dictionary in edge.get("action_program", []):
				if str(action.get("action", "")) not in ["H", "HANG"]: continue
				var target := str(mapping.get(str(action.anchor), edge.get("rest_anchor_id", "") if str(action.action) == "HANG" else ""))
				_bind(result, target, route_name + ":" + edge_id + ":" + str(action.action))
			if edge.has("anchor_id"):
				_bind(result, str(edge.anchor_id), route_name + ":" + edge_id + ":explicit_target")
			# These formal non-program consumers resolve these exact local ids.
			var locals: Array[String] = []
			match str(edge.kind):
				"hollow_upper": locals = ["upper_window_ring"]
				"hollow_lower": locals = ["lower_window_ring"]
				"hollow_cavity": locals = ["cavity_ring_a", "cavity_ring_b"]
			for local: String in locals:
				_bind(result, str(mapping.get(local, "")), route_name + ":" + edge_id + ":" + local)
	return result

static func _bind(result: Dictionary, target: String, reason: String) -> void:
	if target.is_empty(): return
	if not result.has(target): result[target] = []
	if reason not in result[target]: result[target].append(reason)

static func _local_host(m: Dictionary, at: Vector2) -> Dictionary:
	# Attach to an actual local rectangle perimeter. A distant platform is not
	# permission to draw a new wall, long straight vine, or invented collision.
	var nearest := MAX_LOCAL_STEM
	var result: Dictionary = {}
	for support: Dictionary in m.platforms:
		var r := Rect2(support.rect[0], support.rect[1], support.rect[2], support.rect[3])
		# Fruit hangs from an actual side/upper contact. A nearby floor below
		# the target is not a license to grow a thin marker pole from the feet.
		if r.position.y > at.y - 18.0:
			continue
		var point := Vector2(clampf(at.x, r.position.x, r.end.x), minf(r.end.y, at.y - 18.0))
		if r.has_point(at):
			continue
		var perimeter := is_equal_approx(point.x,r.position.x) or is_equal_approx(point.x,r.end.x) or is_equal_approx(point.y,r.position.y) or is_equal_approx(point.y,r.end.y)
		if not perimeter:
			continue
		var distance := at.distance_to(point)
		if distance < nearest:
			nearest = distance
			result = {"id": str(support.id), "point": [point.x, point.y]}
	return result

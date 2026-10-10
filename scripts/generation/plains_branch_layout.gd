class_name PlainsBranchLayout
extends RefCounted
## A finite port graph: shared exploration then two separately assembled terminal routes.
## Content and phase choices use only this map stream. No live player access.
const VERSION := 4
const BLUEPRINT_VERSION := 2
const BLUEPRINTS := ["bridge_crossing", "windmill_ascent", "sanctuary", "compatibility"]
const BRIDGE_GEARS := ["plains_gear_brook", "plains_gear_glade"]
const STEADY := ["plains_meadow_gap", "plains_perch_rise", "plains_skip_stones"]
const ATTEMPTS := 4
const PROFILE_PATH := "res://config/plains_branch_profile.json"

func budget() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	return data if data is Dictionary else {}
const SAFE := ["plains_micro_landing", "plains_micro_stool", "micro_board"]
const ENCOUNTERS := {
	"bramble_crossing": {"primary": ["plains_bramble_causeway", "plains_bramble_ridge"], "pool": ["plains_thorn_bridge", "plains_thorn_steps", "plains_bramble_causeway", "plains_bramble_ridge"]},
	"perch_climb": {"primary": ["plains_high_perches", "plains_perch_double"], "pool": ["plains_high_perches", "plains_perch_double", "plains_skip_stones", "plains_perch_rise"]},
	"windmill_ferry": {"primary": ["plains_ferry_one", "plains_ferry_two"], "pool": ["plains_gear_brook", "plains_gear_glade", "plains_perch_rise", "plains_thorn_steps"]}
}
const LIGHT := ["plains_micro_rise", "plains_meadow_gap", "plains_perch_rise", "plains_skip_stones", "plains_thorn_bridge", "plains_thorn_steps", "plains_gear_brook", "plains_gear_glade"]

func generate(seed_value: int, tuning: PlayerTuning, index: int, type: StringName, profile: String, g: RandomStageGenerator, requested_blueprint: String = "") -> Dictionary:
	if requested_blueprint not in ["", "bridge_crossing", "windmill_ascent", "sanctuary"]:
		return g._failure("Unknown requested stage blueprint")
	for attempt: int in ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + attempt * 104729
		var rest := type in [&"shop", &"health_reward"]
		var blueprint := "sanctuary" if rest else requested_blueprint
		if blueprint.is_empty() or blueprint == "sanctuary":
			blueprint = _pick(["bridge_crossing", "windmill_ascent"], rng)
		if rest: blueprint = "sanctuary"
		var families: Array = ["bramble_crossing"] if blueprint == "bridge_crossing" else ["perch_climb"]
		if blueprint == "windmill_ascent" and index >= int(budget().ferry_introduction_stage): families.append("windmill_ferry")
		families = families.filter(func(key: String): return ENCOUNTERS[key].primary.any(func(id: String): return g.definition_for(id).supports(tuning)))
		var encounter := "sanctuary" if rest else _pick(families, rng) if not families.is_empty() else "meadow_compatibility"
		if encounter == "meadow_compatibility": blueprint = "compatibility"
		var pool: Array = LIGHT if encounter in ["sanctuary", "meadow_compatibility"] else ENCOUNTERS[encounter].pool
		var common: Array[String] = ["micro_board", "micro_board"]
		var recoil := not rest and (index >= int(budget().recoil_introduction_stage) or type == &"item_reward") and g.definition_for("plains_recoil_step").supports(tuning)
		if not rest:
			common.append(_compatible_pick(LIGHT if encounter == "meadow_compatibility" else ENCOUNTERS[encounter].primary, tuning, rng, g))
			common.append(_pick(SAFE, rng))
			# Distinct spatial grammar, not merely a family label: bridge returns to
			# its original height; ascent adds a complete 200px staircase, then
			# a 260px recoil transfer separated by genuine recovery landings.
			common.append("plains_perch_double" if blueprint == "windmill_ascent" and g.definition_for("plains_perch_double").supports(tuning) else "plains_recovery_bridge" if blueprint == "bridge_crossing" and g.definition_for("plains_recovery_bridge").supports(tuning) else _compatible_pick(["plains_meadow_gap", "plains_thorn_bridge", "plains_gear_brook"], tuning, rng, g))
			common.append(_pick(SAFE, rng))
			# Introduce a timed grounded obstacle only after the recovery lesson.
			# Rest floors isolate the input demands and preserve readable landings.
			if blueprint == "bridge_crossing" and index >= int(budget().gear_introduction_stage) and BRIDGE_GEARS.all(func(id: String): return g.definition_for(id).supports(tuning)):
				common.append(_pick(BRIDGE_GEARS, rng))
				common.append(_pick(SAFE, rng))
			if blueprint == "windmill_ascent" and recoil:
				common.append("plains_recoil_step")
				common.append(_pick(SAFE, rng))
		common.append("plains_fork_rest" if rest else "plains_fork_paths")
		var upper: Array[String] = []
		var lower: Array[String] = []
		# The upper route is the optional harder approach. The lower route has
		# no hazards/recoil requirement; it keeps both shots for player recovery.
		upper.append("plains_recoil_step" if recoil else _pick(SAFE, rng) if rest else _compatible_pick(["plains_thorn_bridge", "plains_thorn_steps"], tuning, rng, g))
		lower.append(_pick(SAFE, rng) if rest else _compatible_pick(STEADY, tuning, rng, g))
		var length := 1 if rest else (rng.randi_range(2, 3) if type == &"coin_reward" else rng.randi_range(1, 2)) if blueprint == "windmill_ascent" else rng.randi_range(3, 4) if type == &"coin_reward" else rng.randi_range(1, 3)
		for slot: int in length:
			upper.append(_pick(SAFE, rng))
			lower.append(_pick(SAFE, rng))
			if not rest and slot % 2 == 0:
				upper.append(_compatible_pick(pool if encounter != "windmill_ferry" else LIGHT, tuning, rng, g))
				lower.append(_compatible_pick(STEADY, tuning, rng, g))
		if rest:
			lower.append("micro_board")
		upper.append("plains_door_landing")
		lower.append("plains_door_landing")
		var manifest := _assemble(seed_value, tuning, profile, common, upper, lower, rng, attempt, g, index, type, encounter, blueprint)
		# Extend the farther endpoint with safe floor, preserving both authored
		# paths and hazards rather than move a door into the middle of a route.
		var minimum_separation := float(budget().service_min_door_separation if rest else budget().action_min_door_separation)
		for extension: int in 3:
			var a := Vector2(manifest.terminal_exits[0].position[0], manifest.terminal_exits[0].position[1])
			var b := Vector2(manifest.terminal_exits[1].position[0], manifest.terminal_exits[1].position[1])
			if a.distance_to(b) >= minimum_separation:
				break
			var path: Array[String] = lower if b.x >= a.x else upper
			path.insert(path.size() - 1, "micro_board")
			manifest = _assemble(seed_value, tuning, profile, common, upper, lower, rng, attempt, g, index, type, encounter, blueprint)
		var result := g.validate_manifest(manifest, tuning)
		if result.ok:
			return {"ok": true, "error": "", "manifest": manifest}
	# Explicit bounded same-type low pressure fallback. It still has two complete
	# terminal routes; it does not silently move one door back into the common path.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var fallback := _assemble(seed_value, tuning, profile, ["micro_board", "micro_board", "plains_fork_rest"], ["micro_board", "plains_door_landing"], ["micro_board", "micro_board", "micro_board", "micro_board", "plains_door_landing"], rng, 0, g, index, type, "bounded_sanctuary", "compatibility")
	fallback["branch_fallback_reason"] = "four_spatial_collision_attempts_exhausted"
	fallback.manifest_hash = g._manifest_hash(fallback)
	var checked := g.validate_manifest(fallback, tuning)
	return {"ok": true, "error": "", "manifest": fallback} if checked.ok else checked

func _pick(pool: Array, rng: RandomNumberGenerator) -> String:
	return str(pool[rng.randi_range(0, pool.size() - 1)])
func _compatible_pick(pool: Array, tuning: PlayerTuning, rng: RandomNumberGenerator, g: RandomStageGenerator) -> String:
	var compatible: Array = pool.filter(func(id: String): return g.definition_for(id).supports(tuning))
	return _pick(compatible, rng) if not compatible.is_empty() else "micro_board"

func _assemble(seed_value: int, tuning: PlayerTuning, profile: String, common: Array[String], upper: Array[String], lower: Array[String], rng: RandomNumberGenerator, attempt: int, g: RandomStageGenerator, stage_index: int, stage_type: StringName, encounter: String, blueprint: String) -> Dictionary:
	# Reuse the versioned physics/environment header. The actual graph replaces
	# every dummy node; there is no dummy geometry in the assembled stage.
	var dummy: Array[String] = ["micro_board", "micro_board", "micro_board", "micro_board", "micro_board", "route_junction"]
	var m := g._assemble_manifest(dummy, seed_value, tuning, attempt, "", rng, profile, true)
	m.layout_id = "branched_terminal_paths"
	m["branch_version"] = VERSION
	m["blueprint_id"] = blueprint
	m["blueprint_version"] = BLUEPRINT_VERSION
	m["encounter_family"] = encounter
	m["encounter_version"] = 1
	m["branch_budget"] = budget()
	m["branch_stage_index"] = stage_index
	m["branch_stage_type"] = str(stage_type)
	m["branch_fallback_reason"] = ""
	m["common_path"] = []
	m["terminal_paths"] = []
	m.nodes = []
	m.seams = []
	var parent := -1
	for id: String in common:
		parent = _append(m, id, parent, "", rng, g)
		m.common_path.append(parent)
	var fork_index := parent
	var terminals: Array = []
	for branch_index: int in 2:
		var path: Array = []
		parent = fork_index
		var first_port := "fork_up" if branch_index == 0 else "fork_right"
		for id: String in upper if branch_index == 0 else lower:
			parent = _append(m, id, parent, first_port if path.is_empty() else "", rng, g)
			path.append(parent)
		m.terminal_paths.append(path)
		var node: Dictionary = m.nodes[parent]
		var d := g.definition_for(node.module_id, node.mirrored, node.reverse_traversal)
		terminals.append({"id": "door_%d" % branch_index, "node": parent, "port_id": str(d.exit_port.port_id), "position": g._point_array(d.exit_port.position + Vector2(node.offset[0], node.offset[1]))})
	m.terminal_exits = terminals
	m["fork_node"] = fork_index
	m["branch_profiles"] = branch_profiles(m, g)
	m.spatial_family = "branched_%s" % ("recoil_ascent" if upper[0].begins_with("plains_recoil_") else "meadow_paths")
	var bounds := Rect2()
	for i: int in m.nodes.size():
		var n: Dictionary = m.nodes[i]
		var d := g.definition_for(n.module_id, n.mirrored, n.reverse_traversal)
		var b := Rect2(d.world_bounds.position + Vector2(n.offset[0], n.offset[1]), d.world_bounds.size)
		bounds = b if i == 0 else bounds.merge(b)
	m.world_bounds = g._rect_array(bounds)
	m.route_graph = route_graph(m, g)
	m.manifest_hash = g._manifest_hash(m)
	return m

func _append(m: Dictionary, id: String, parent: int, port_id: String, rng: RandomNumberGenerator, g: RandomStageGenerator) -> int:
	var i: int = m.nodes.size()
	var mirrored := id in g.LOCAL_REFLECTION_IDS and rng.randi_range(0, 1) == 1
	var d := g.definition_for(id, mirrored, mirrored)
	var offset := Vector2.ZERO
	if parent >= 0:
		var p: Dictionary = m.nodes[parent]
		var pd := g.definition_for(p.module_id, p.mirrored, p.reverse_traversal)
		var port := pd.exit_port
		if not port_id.is_empty():
			for candidate: PlatformingModulePort in pd.get_exit_ports():
				if str(candidate.port_id) == port_id: port = candidate
		offset = Vector2(p.offset[0], p.offset[1]) + port.position - d.entry_port.position
		m.seams.append({"id": "seam_%02d" % (i - 1), "from": parent, "to": i, "from_port_id": str(port.port_id), "point": g._point_array(port.position + Vector2(p.offset[0], p.offset[1]))})
	var phases: Array = []
	for saw: ModuleSawDefinition in d.saws: phases.append({"id": str(saw.source_id), "phase": rng.randi_range(0, 3) * .25})
	for ferry: ModuleMovingPlatformDefinition in d.ferries: phases.append({"id": str(ferry.platform_id), "phase": rng.randi_range(0, 3) * .25})
	m.nodes.append({"id": "module_%02d" % i, "module_id": id, "mirrored": mirrored, "reverse_traversal": mirrored, "entry_port_id": str(d.entry_port.port_id), "exit_port_id": str(d.exit_port.port_id), "version": d.definition_version, "content_hash": g.content_hash(id), "offset": g._point_array(offset), "initial_phases": phases, "pressure": g._pressure(d)})
	return i

func branch_profiles(m: Dictionary, g: RandomStageGenerator) -> Array:
	var profiles: Array = []
	for path: Array in m.terminal_paths:
		var challenge := false
		for index: int in path:
			var n: Dictionary = m.nodes[index]
			var d := g.definition_for(n.module_id, n.mirrored, n.reverse_traversal)
			challenge = challenge or g._hazardous(d) or d.requires_burst
		profiles.append({"risk": "challenge" if challenge else "steady", "bonus_coins": int(budget().challenge_bonus_coins) if challenge else 0, "bonus_notes": int(budget().challenge_bonus_notes) if challenge else 0})
	return profiles

func route_graph(m: Dictionary, g: RandomStageGenerator) -> Dictionary:
	var graph := g._route_graph(m.nodes)
	# Remove the chain's implicit docks: graph docks are driven by real seams.
	graph.edges = graph.edges.filter(func(e: Dictionary): return e.kind != "coincident_dock")
	for seam: Dictionary in m.seams:
		var from_node: Dictionary = m.nodes[seam.from]
		var from_id := str(from_node.id) + ":exit"
		if str(seam.from_port_id) == "fork_up":
			var d := g.definition_for(from_node.module_id)
			from_id = str(from_node.id) + ":anchor_%d" % (d.anchors.size() - 1)
		graph.edges.append({"from": from_id, "to": str(m.nodes[seam.to].id) + ":entry", "kind": "coincident_dock"})
	return graph

func validate(m: Dictionary, tuning: PlayerTuning, g: RandomStageGenerator) -> Dictionary:
	if not g._same_data(m.get("branch_budget"),budget()) or not g._numeric(m.get("branch_stage_index")) or m.branch_stage_index < 1 or m.branch_stage_index > 7 or m.branch_stage_index != floorf(m.branch_stage_index) or m.get("branch_stage_type") not in ["combat", "coin_reward", "item_reward", "shop", "health_reward"] or g.PROFILES.get(m.profile_id) == null or PlainsStageGenerator.new().profile_for(int(m.branch_stage_index),StringName(m.branch_stage_type)) != m.profile_id:
		return g._failure("Invalid branch difficulty/type contract")
	if m.has("stage_index") and (m.stage_index != m.branch_stage_index or m.stage_type != m.branch_stage_type):
		return g._failure("Branch room metadata mismatch")
	if not m.local_reflections or m.mirrored or m.development_only or m.get("branch_version") != VERSION or not m.get("branch_fallback_reason") is String or m.branch_fallback_reason not in ["", "four_spatial_collision_attempts_exhausted"]:
		return g._failure("Invalid branch scope/version/fallback")
	if not m.get("nodes") is Array or m.nodes.size() < 7 or m.nodes.size() > int(budget().max_nodes) or not m.get("seams") is Array or m.seams.size() != m.nodes.size() - 1 or not m.get("common_path") is Array or not m.get("terminal_paths") is Array or m.terminal_paths.size() != 2:
		return g._failure("Invalid bounded branch graph")
	var family: Variant = m.get("encounter_family")
	if not family is String or m.get("encounter_version") != 1 or family not in ENCOUNTERS.keys() + ["sanctuary", "meadow_compatibility", "bounded_sanctuary"]:
		return g._failure("Missing versioned encounter family")
	if family == "bounded_sanctuary" and m.branch_fallback_reason.is_empty() or not m.branch_fallback_reason.is_empty() and family != "bounded_sanctuary":
		return g._failure("Encounter fallback identity mismatch")
	if m.branch_stage_type in ["shop", "health_reward"] and family not in ["sanctuary", "bounded_sanctuary"] or family == "sanctuary" and m.branch_stage_type not in ["shop", "health_reward"]:
		return g._failure("Service encounter conflicts with room type")
	if ENCOUNTERS.has(family) and (m.nodes.size() < 3 or m.nodes[2].get("module_id") not in ENCOUNTERS[family].primary):
		return g._failure("Encounter family lacks its actual defining module")
	if family == "windmill_ferry" and int(m.branch_stage_index) < int(budget().ferry_introduction_stage):
		return g._failure("Ferry encounter precedes introduction")
	if m.get("blueprint_version") != BLUEPRINT_VERSION or m.get("blueprint_id") not in BLUEPRINTS:
		return g._failure("Missing versioned stage blueprint")
	if m.blueprint_id == "bridge_crossing" and family != "bramble_crossing" or m.blueprint_id == "windmill_ascent" and family not in ["perch_climb", "windmill_ferry"] or m.blueprint_id == "sanctuary" and family != "sanctuary" or m.blueprint_id == "compatibility" and family not in ["meadow_compatibility", "bounded_sanctuary"]:
		return g._failure("Blueprint and actual encounter contradict")
	var defs: Array[PlatformingModuleDefinition] = []
	var offsets: Array[Vector2] = []
	var bounds := Rect2()
	for i: int in m.nodes.size():
		var n: Variant = m.nodes[i]
		if not n is Dictionary or n.get("id") != "module_%02d" % i or not n.get("module_id") is String or not n.get("mirrored") is bool or not n.get("reverse_traversal") is bool or n.reverse_traversal != n.mirrored or not g._valid_array(n.get("offset"),2):
			return g._failure("Invalid branch node")
		var d := g.definition_for(n.module_id, n.mirrored, n.reverse_traversal)
		if d == null or not d.supports(tuning) or n.get("content_hash") != g.content_hash(n.module_id) or n.get("version") != d.definition_version or n.get("entry_port_id") != str(d.entry_port.port_id) or n.get("exit_port_id") != str(d.exit_port.port_id) or not g._same_data(n.get("pressure"),g._pressure(d)) or not g._valid_phases(n.get("initial_phases"),d):
			return g._failure("Invalid branch content/phase/capability")
		var offset := Vector2(n.offset[0],n.offset[1])
		if (i == 0 and (offset != Vector2.ZERO or n.module_id != "micro_board" or n.mirrored)) or d.anchors.any(func(p: Vector2): return p.y + offset.y > 282.001):
			return g._failure("Branch spawn must stay lowest safe landing")
		var dock := Rect2()
		var parent := -1
		if i > 0:
			var seam: Variant = m.seams[i-1]
			if not seam is Dictionary or seam.get("id") != "seam_%02d"%(i-1) or not g._numeric(seam.get("from")) or seam.from != floorf(seam.from) or seam.from < 0 or seam.from >= i or seam.get("to") != i or not seam.get("from_port_id") is String or not g._valid_array(seam.get("point"),2) or seam.has("rect") or seam.has("anchor"):
				return g._failure("Invalid branch seam identity")
			parent = int(seam.from)
			var port: PlatformingModulePort
			for candidate: PlatformingModulePort in defs[parent].get_exit_ports():
				if str(candidate.port_id) == seam.from_port_id: port = candidate
			if port == null or not port.supports(tuning): return g._failure("Missing or incompatible branch port")
			var point := port.position + offsets[parent]
			if point != Vector2(seam.point[0],seam.point[1]) or offset != point - d.entry_port.position or port.direction != d.entry_port.direction or not g._clear_dock(point,defs[parent],offsets[parent]) or not g._clear_dock(point,d,offset):
				return g._failure("Branch transform/clearance disconnected")
			dock = Rect2(point+Vector2(-g.DOCK_HALF_WIDTH,18),Vector2(g.DOCK_HALF_WIDTH*2,g.DOCK_DEPTH))
		for j: int in defs.size():
			if not g._compatible_geometry(defs[j],offsets[j],d,offset,dock if j==parent else Rect2()):
				return g._failure("Branch geometry or hazard sweeps overlap %d:%s with %d:%s" % [j,defs[j].module_id,i,d.module_id])
		defs.append(d);offsets.append(offset)
		var b := Rect2(d.world_bounds.position + offset,d.world_bounds.size)
		bounds = b if i==0 else bounds.merge(b)
	var common: Array = m.common_path
	if common.size()<3 or m.get("fork_node") != common[-1] or not common[0] == 0 or not g._numeric(m.get("fork_node")) or m.fork_node < 2 or m.fork_node >= m.nodes.size(): return g._failure("Invalid common route/fork")
	var fork := int(m.fork_node)
	if str(m.nodes[fork].module_id) not in ["plains_fork_paths", "plains_fork_rest"]: return g._failure("Fork must use validated independent ports")
	var visited: Array = common.duplicate()
	for branch_index: int in 2:
		var path: Variant = m.terminal_paths[branch_index]
		if not path is Array or path.size()<2: return g._failure("Each door needs an actual nonempty branch")
		var previous := fork
		for value: Variant in path:
			if not g._numeric(value) or value != floorf(value) or value<=fork or value>=m.nodes.size() or value in visited: return g._failure("Invalid disjoint branch ownership")
			var seam: Dictionary = m.seams[int(value)-1]
			if seam.from != previous or (previous==fork and seam.from_port_id != ("fork_up" if branch_index==0 else "fork_right")): return g._failure("Route ownership differs from actual docking")
			visited.append(value);previous=int(value)
		if m.nodes[previous].module_id != "plains_door_landing": return g._failure("Terminal door needs a plain landing")
	for i: int in common.size():
		if common[i] != i or i>0 and m.seams[i-1].from != i-1: return g._failure("Common path disconnected")
	if visited.size()!=m.nodes.size(): return g._failure("Unowned node or intermediate door")
	if not g._same_data(m.get("branch_profiles"), branch_profiles(m, g)):
		return g._failure("Branch reward/risk profile differs from actual hazards")
	if m.blueprint_id in ["bridge_crossing", "windmill_ascent"]:
		if m.branch_profiles[0].risk != "challenge" or m.branch_profiles[1].risk != "steady":
			return g._failure("Action blueprint needs distinct challenge and steady choices")
		var rise := defs[0].entry_port.position.y - (defs[fork].entry_port.position.y + offsets[fork].y)
		if m.blueprint_id == "bridge_crossing" and absf(rise) > 1 or m.blueprint_id == "windmill_ascent" and rise < 400:
			return g._failure("Blueprint lacks its recorded horizontal/ascent geometry")
		if m.common_path.size() < 7 or m.blueprint_id == "windmill_ascent" and m.nodes[4].module_id != "plains_perch_double":
			return g._failure("Blueprint lacks its defining observation/challenge rhythm")
		if m.blueprint_id == "bridge_crossing" and g.definition_for("plains_recovery_bridge").supports(tuning) and m.nodes[4].module_id != "plains_recovery_bridge":
			return g._failure("Bridge blueprint lacks the validated recoil recovery opportunity")
		if m.blueprint_id == "bridge_crossing":
			var needs_gear := int(m.branch_stage_index) >= int(budget().gear_introduction_stage) and BRIDGE_GEARS.all(func(id: String): return g.definition_for(id).supports(tuning))
			if m.common_path.size() != (9 if needs_gear else 7) or needs_gear and m.nodes[6].module_id not in BRIDGE_GEARS:
				return g._failure("Bridge rhythm must introduce a timed gear after recovery and observation")
		for slot: int in range(3, m.common_path.size() - 1, 2):
			if m.nodes[slot].module_id not in SAFE:
				return g._failure("Blueprint must retain safe observation floors between encounters")
	var shape_family := "branched_recoil_ascent" if str(m.nodes[int(m.terminal_paths[0][0])].module_id).begins_with("plains_recoil_") else "branched_meadow_paths"
	if m.get("spatial_family") != shape_family: return g._failure("Recorded branch family differs from actual modules")
	for path: Array in m.terminal_paths:
		var route := common + path
		var pressure_chain := 0
		var hazard_count := 0
		var recoil_count := 0
		var ferry_count := 0
		var b := budget()
		for slot: int in route.size():
			var d := defs[int(route[slot])]
			var rest: bool = m.branch_stage_type in ["shop","health_reward"] or not m.branch_fallback_reason.is_empty()
			var max_pressure := int(b.service_max_pressure) if rest else int(b.early_max_pressure) if int(m.branch_stage_index)<int(b.recoil_introduction_stage) and m.branch_stage_type != "item_reward" else int(b.action_max_pressure)
			if slot < int(b.safe_start_nodes) and d.module_id != &"micro_board" or d.platform_pressure > max_pressure or d.timing_pressure > (0 if rest else int(b.max_timing_pressure)):
				return g._failure("Branch route exceeds pressure or safe start budget")
			pressure_chain = pressure_chain + 1 if g._high_pressure(d) else 0
			hazard_count += 1 if g._hazardous(d) else 0
			recoil_count += 1 if d.requires_burst else 0
			ferry_count += 1 if not d.ferries.is_empty() else 0
			if pressure_chain > int(b.max_pressure_chain) or hazard_count > (0 if rest else int(b.max_hazards_per_route)) or recoil_count > int(b.max_recoil_per_route) or ferry_count > int(b.max_ferry_modules_per_route):
				return g._failure("Branch route exceeds mechanism/continuous pressure budget")
	if not m.get("terminal_exits") is Array or m.terminal_exits.size()!=2: return g._failure("Two terminal doors required")
	for i: int in 2:
		var node_index := int(m.terminal_paths[i][-1])
		var expected := {"id":"door_%d"%i,"node":node_index,"port_id":str(defs[node_index].exit_port.port_id),"position":g._point_array(defs[node_index].exit_port.position+offsets[node_index])}
		if not g._same_data(m.terminal_exits[i],expected): return g._failure("Door is not at its branch end")
	var first_door := Vector2(m.terminal_exits[0].position[0],m.terminal_exits[0].position[1])
	var second_door := Vector2(m.terminal_exits[1].position[0],m.terminal_exits[1].position[1])
	var minimum_separation := float(budget().service_min_door_separation if m.branch_stage_type in ["shop","health_reward"] else budget().action_min_door_separation)
	if first_door.distance_to(second_door) < minimum_separation:
		return g._failure("Terminal doors violate the room's independent approach separation")
	if not g._valid_array(m.get("world_bounds"),4) or g._array_rect(m.world_bounds)!=bounds or not g._same_data(m.get("route_graph"),route_graph(m,g)): return g._failure("Branch bounds/path graph mismatch")
	return {"ok":true,"error":""}

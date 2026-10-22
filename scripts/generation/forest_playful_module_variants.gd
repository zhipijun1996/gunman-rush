class_name ForestPlayfulModuleVariants
extends RefCounted
## Old Forest movement grammar, with explicit alternate receiving ports.
## Candidate data only: neither a Motor nor a production admission decision.
const VERSION := "forest-old-language-variants-v1"
const AIR := preload("res://scripts/generation/forest_air_chain_geometry.gd")
const CORRIDORS := preload("res://scripts/generation/forest_thorn_corridor_modules.gd")
const MOUTH := preload("res://scripts/generation/forest_thorn_mouth_geometry.gd")
const HOLLOW := preload("res://scripts/generation/forest_hollow_trunk_geometry.gd")
const BIBLE_SHA := "a7bad8323af64a7be0577132e5d988a6e1b781d9e1ac1639d37f9d65935194e3"

static func catalogue() -> Array[Dictionary]:
	return [
		{"id":"forked_bough_hh","difficulty":"normal","identity":"two opposed fruits reach a high bough; its outer lip returns to a lower exit"},
		{"id":"side_root_rh","difficulty":"normal","identity":"recoil opens the side-fruit approach; a broad upper shore and a different lower root exit remain visible"},
		{"id":"rooted_double_window","difficulty":"normal","identity":"one solid trunk with an upper forward window and a lower inward return to another root"},
		{"id":"descending_borer_elbow","difficulty":"hard","identity":"two fruit cells turn downward through a thorn-covered real root elbow; a broad lower root catches a miss"},
		{"id":"fallen_arch_canopy","difficulty":"hard","identity":"recoil beneath a fallen trunk, then turn upward around its broken end; the lower root is a different return"},
		{"id":"thorn_side_outlet","difficulty":"normal","identity":"side-hook through a real bark mouth toward the upper root, or take the lower outer outlet"},
		{"id":"l_hollow_reward_loop","difficulty":"normal","identity":"descend around a real root elbow for an optional cache, then choose the lower return mouth or the far outward exit"},
		{"id":"z_hollow_inner_cache","difficulty":"hard","identity":"three solid root levels reverse direction toward a middle-left cache; a cheap outer fall reaches a different lower exit without that cache"},
	]

static func build(id: String) -> Dictionary:
	var data: Dictionary
	match id:
		"forked_bough_hh": data = _forked_bough_hh()
		"side_root_rh": data = _side_root_rh()
		"rooted_double_window": data = _rooted_double_window()
		"descending_borer_elbow": data = _descending_borer_elbow()
		"fallen_arch_canopy": data = _fallen_arch_canopy()
		"thorn_side_outlet": data = _thorn_side_outlet()
		"l_hollow_reward_loop": data = _l_hollow_reward_loop()
		"z_hollow_inner_cache": data = _z_hollow_inner_cache()
		_: return {}
	return _finish(data,id)

static func _forked_bough_hh() -> Dictionary:
	var data: Dictionary = AIR.build("hook_hook").duplicate(true)
	# The two targets and airborne phrase remain the old HH language. Raising
	# its broad receiver changes the actual destination; it needs fresh Motor
	# evidence, not the old low-receiver proof.
	_support(data,"crown").rect = [280.0,-112.0,320.0,160.0]
	_support(data,"crown").one_way = false
	data.goal = [355.0,-130.0]
	_mount_fruits(data)
	_widen_retry_root(data)
	_lower_outlet(data)
	data.derivations = ["receiver_raised_88wu_from_the_old_HH", "single_wide_retry_root_lip", "different_lower_exit_beyond_the_receiving_bough"]
	data.play_contract = {
		"observe":"From the broad root, read the side fruit, the higher return fruit and the upper receiving bough together.",
		"decision":"Take the high fruit hand-off to continue upward, or use the lower root outlet to change destination.",
		"alternative":"Real jump/recoil alternatives remain legal; the two H inputs are an intended phrase, never a password.",
		"recovery":"A missed chain lands on the wide root basin; one western root lip returns to the departure.",
		"counterexample":"Compare a full held jump and legal recoil, and a missed second H; do not infer value from two accepted H events."}
	return data

static func _side_root_rh() -> Dictionary:
	var data: Dictionary = AIR.build("recoil_hook").duplicate(true)
	_support(data,"crown").rect = [280.0,-112.0,320.0,160.0]
	_support(data,"crown").one_way = false
	data.hook_anchors[0].position = [300.0,-170.0]
	data.goal = [355.0,-130.0]
	_mount_fruits(data)
	_widen_retry_root(data)
	_lower_outlet(data)
	data.derivations = ["target_raised_100wu_and_receiver_raised_88wu_from_the_old_RH", "single_wide_retry_root_lip", "different_lower_exit_beyond_the_receiving_bough"]
	data.play_contract = {
		"observe":"The side fruit is above the direct ground ray; the wide receiving branch is visible on its far side.",
		"decision":"Create the higher approach with an early recoil, then catch the fruit; after landing choose the upper continuation or the lower outer root.",
		"alternative":"Ordinary held-jump/H or recoil-only strategies remain legal and must be compared with the intended RH.",
		"recovery":"Failure falls to the same broad root; one outside root lip restores the departure without an added ladder.",
		"counterexample":"Verify the raised fruit is truly capturable from the real launch. A recorded R then H without useful contact does not pass."}
	return data

static func _lower_outlet(data: Dictionary) -> void:
	data.platforms.append({"id":"outer_root_exit","rect":[650.0,18.0,260.0,32.0],"one_way":true})
	data.scene_language["outer_root_exit"] = "living_bough"
	data.ports = {
		"entry":_port(data.spawn,"entry","departure"),
		"crown":_port(data.goal,"crown","upper_onward"),
		"lower_exit":_port([720.0,0.0],"outer_root_exit","different_lower_onward"),
		"basin":_port([720.0,202.0],"recovery","shared_recovery")}
	data.routes = {
		"main":{"kind":"airborne_chain","from_port":"entry","to_port":"crown","action_program":data.action_program.duplicate(true),"path":[data.spawn.duplicate(),data.goal.duplicate()]},
		"outer_descent":{"kind":"drop_through","from_port":"crown","to_port":"lower_exit","path":[data.goal.duplicate(),[640.0,-130.0],[720.0,0.0]],
			"steps":[{"kind":"drop_through","from_support_id":"crown","support_id":"outer_root_exit","takeoff":[568.0,-130.0],"landing":[720.0,0.0],"path":[[568.0,-130.0],[640.0,-130.0],[720.0,0.0]]}]},
		"miss_to_basin":{"kind":"drop_through","from_port":"lower_exit","to_port":"basin","path":[[720.0,0.0],[720.0,202.0]],
			"steps":[{"kind":"drop_through","from_support_id":"outer_root_exit","support_id":"recovery","takeoff":[720.0,0.0],"landing":[720.0,202.0],"path":[[720.0,0.0],[720.0,202.0]]}]},
		"retry":{"kind":"ordinary_sequence","from_port":"basin","to_port":"entry","path":[[720.0,202.0],[-275.0,202.0],[-275.0,100.0],[0.0,0.0]],
			"steps":[{"kind":"walk","support_id":"recovery","landing":[-275.0,202.0]},
				{"kind":"jump_rise","from_support_id":"recovery","support_id":"recovery_step","takeoff":[-275.0,202.0],"landing":[-275.0,100.0]},
				{"kind":"jump_gap","from_support_id":"recovery_step","support_id":"entry","takeoff":[-275.0,100.0],"landing":[-165.0,0.0]},
				{"kind":"walk","support_id":"entry","landing":data.spawn.duplicate()}]}}
	data.alternate_port_contract = {"upper":"crown","lower":"lower_exit","failure":"basin","world_must_bind_different_destinations":true,"native_verified":false}

static func _mount_fruits(data: Dictionary) -> void:
	for anchor: Dictionary in data.hook_anchors:
		var at := _point(anchor.position)
		anchor.host_support_id = "crown"
		anchor.stem_root = [280.0,at.y] if at.x < 280.0 else [at.x,-112.0]
		anchor.fruit_presentation = "rooted_fruit"
		anchor.fruit_role = "main"

static func _widen_retry_root(data: Dictionary) -> void:
	# A single side-root lip is not a column of repeated floating steps. It is
	# outside the solid departure and does not intercept the primary flight.
	_support(data,"recovery_step").rect = [-305.0,118.0,160.0,24.0]
	data.world_bounds = [-340.0,-450.0,1300.0,800.0]

static func _finish(data: Dictionary,id: String) -> Dictionary:
	data.id = id
	data.version = VERSION
	data.entry_support_id = "entry"
	data.exit_support_id = "crown"
	data.requires = ["grapple"]
	if not data.has("source_factory"):
		data.source_factory = _source("res://scripts/generation/forest_air_chain_geometry.gd",AIR.VERSION)
	data.bible_sha256 = BIBLE_SHA
	for row: Dictionary in catalogue():
		if str(row.id) == id:
			data.identity = str(row.identity)
			data.difficulty = str(row.difficulty)
			break
	data.admission = {"geometry":"candidate","motor":"unverified","visual":"unverified","production_pool":false}
	data.resource_contract = {"new_abilities":false,"physics_override":false,"health_override":false,"shot_refill_override":false}
	if not data.has("chain_contract"):
		data.chain_contract = {"continuous_airborne":true,"midair_floor_allowed":false,"hook_restoration":"actual_contact_kick_completion","fixed_anchor_does_not_refill_shots":true,"production_pool":false,"native_verified":false}
	data.danger_hosts = []
	data.danger_faces = []
	for surface: Dictionary in data.get("danger_surfaces",[]):
		data.danger_hosts.append(str(surface.host_support_id))
		data.danger_faces.append(str(surface.face))
	data.world_bounds = _bounds(data)
	return data

static func _bounds(data: Dictionary) -> Array:
	var bounds := Rect2(_point(data.spawn),Vector2.ONE)
	bounds = bounds.expand(_point(data.goal))
	for row: Dictionary in data.platforms:
		bounds = bounds.merge(Rect2(float(row.rect[0]),float(row.rect[1]),float(row.rect[2]),float(row.rect[3])))
	for row: Dictionary in data.hook_anchors:
		bounds = bounds.expand(_point(row.position))
	bounds = bounds.grow(32.0)
	return [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]

static func _support(data: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in data.platforms:
		if str(row.id) == id: return row
	return {}

static func _port(at: Array,support: String,role: String) -> Dictionary:
	return {"position":at.duplicate(),"support_id":support,"role":role,"native_verified":false}

static func _point(pair: Array) -> Vector2:
	return Vector2(float(pair[0]),float(pair[1]))

static func _rooted_double_window() -> Dictionary:
	var data: Dictionary = HOLLOW.build("deep_zeroR").duplicate(true)
	_rename_support(data,"belly_entry","entry")
	_rename_support(data,"outer_crown","crown")
	data.action_program = [{"action":"H","anchor":"upper_window_ring"},{"action":"R","direction":[-1.0,0.0]}]
	# Actual local trajectory receives on the connected middle-window lip
	# before continuing to the outer crown. This is a legitimate module
	# landing, not a continuously airborne phrase. Keep the real support.
	data.chain_contract = {"continuous_airborne":false,"midair_floor_allowed":true,"hook_restoration":"actual_contact_kick_completion","fixed_anchor_does_not_refill_shots":true,"receiving_supports":["trunk_between_windows","crown"],"production_pool":false,"native_verified":false}
	data.scene_language = _hollow_language(data)
	data.source_factory = _source("res://scripts/generation/forest_hollow_trunk_geometry.gd",HOLLOW.VERSION)
	for anchor: Dictionary in data.hook_anchors:
		if str(anchor.id) == "upper_window_ring":
			_mount(anchor,"trunk_above_window",[216.0,-98.0],"main")
		else:
			_mount(anchor,"inner_root",[120.0,220.0],"return")
	data.ports = {"entry":_port(data.spawn,"entry","upper_window_departure"),
		"crown":_port(data.goal,"crown","upper_forward_destination"),
		"outer_root":_port([420.0,282.0],"outer_root","lower_window_approach"),
		"inner_root":_port([120.0,202.0],"inner_root","different_inward_root_destination")}
	data.routes = {"main":_air_route("entry","crown",data.action_program,[data.spawn.duplicate(),data.goal.duplicate()]),
		"outer_descent":{"kind":"drop_through","from_port":"crown","to_port":"outer_root","path":[data.goal.duplicate(),[640.0,-42.0],[640.0,282.0],[420.0,282.0]],
			"steps":[{"kind":"drop_through","from_support_id":"crown","support_id":"outer_root","takeoff":[568.0,-42.0],"landing":[640.0,282.0],"path":[[568.0,-42.0],[640.0,-42.0],[640.0,282.0]]},
				{"kind":"walk","support_id":"outer_root","landing":[420.0,282.0]}]},
		"lower_inward_return":{"kind":"airborne_chain","from_port":"outer_root","to_port":"inner_root","takeoff":[370.0,282.0],"jump_before_hook":true,
			"action_program":[{"action":"H","anchor":"lower_window_ring"},{"action":"R","direction":[1.0,0.0]}],"path":[[420.0,282.0],[370.0,282.0],[120.0,202.0]]}}
	data.recovery = {"mode":"actual_lower_root_ports","miss_supports":["outer_root","inner_root","outer_sump"],"safe_ports":["outer_root","inner_root"],"native_verified":false}
	data.return = {"route":"outer_descent_then_lower_inward_return","different_exit_port":"inner_root","native_verified":false}
	data.play_contract = {"observe":"Two openings belong to one real trunk. The upper crown and the lower inward root are separate destinations.",
		"decision":"Cross the upper window toward the crown, or use the outer-root descent to approach the lower opening and return inward.",
		"recovery":"The solid inner root and outer root receive failed crossings; they must connect into the world's root loop, not a copied ladder.",
		"counterexample":"Compare ordinary jump/recoil at the upper window and a no-enemy lower return; bind the two exit ports to genuinely different world nodes."}
	data.derivations = ["old_complete_double_window_geometry_retained", "explicit_upper_and_lower_world_ports", "roots_and_fruit_hosts_share_actual_collision_bodies"]
	data.alternate_port_contract = {"upper":"crown","lower":"inner_root","world_must_bind_different_destinations":true,"native_verified":false}
	data.erase("candidate_itinerary")
	return data

static func _descending_borer_elbow() -> Dictionary:
	var data: Dictionary = HOLLOW.build_cavity_elbow().duplicate(true)
	_rename_support(data,"cavity_observe","entry")
	_rename_support(data,"cavity_exit","crown")
	# Extend the existing outside observation branch away from the cavity.
	# The flight-side edge at x-220 and the entire elbow remain unchanged.
	_support(data,"entry").rect = [-460.0,-300.0,240.0,24.0]
	data.action_program = [{"action":"H","anchor":"cavity_ring_a"},{"action":"R","direction":[-1.0,0.0]},
		{"action":"H","anchor":"cavity_ring_b"},{"action":"R","direction":[-1.0,0.0]}]
	for anchor: Dictionary in data.hook_anchors:
		match str(anchor.id):
			"upper_window_ring": _mount(anchor,"trunk_above_window",[216.0,-98.0],"return")
			"lower_window_ring": _mount(anchor,"inner_root",[120.0,220.0],"return")
			"cavity_ring_a": _mount(anchor,"belly_roof_upper",[-35.0,-434.0],"main")
			"cavity_ring_b": _mount(anchor,"trunk_above_window",[310.0,-182.0],"main")
	# Split each danger across the real two-part elbow host. The complete old
	# danger union stays exact; a remote host label is not surface attachment.
	data.dangers = [[-220.0,-430.0,390.0,20.0],[-220.0,-300.0,260.0,24.0],
		[170.0,-210.0,40.0,24.0],[210.0,-210.0,120.0,24.0],
		[170.0,-390.0,40.0,20.0],[210.0,-390.0,120.0,20.0]]
	data.danger_surfaces = [{"danger_index":0,"host_support_id":"belly_roof_upper","face":"down"},
		{"danger_index":1,"host_support_id":"belly_roof","face":"up"},
		{"danger_index":2,"host_support_id":"elbow_lower_lip","face":"up"},
		{"danger_index":3,"host_support_id":"trunk_above_window","face":"up"},
		{"danger_index":4,"host_support_id":"elbow_upper_lip","face":"down"},
		{"danger_index":5,"host_support_id":"trunk_upper_cap","face":"down"}]
	data.danger_presentations = [{"facing":"down"},{"facing":"up"},{"facing":"up"},{"facing":"up"},{"facing":"down"},{"facing":"down"}]
	_translate_geometry(data,Vector2(245.0,318.0))
	data.source_factory = _source("res://scripts/generation/forest_hollow_trunk_geometry.gd","forest-hollow-horizontal-elbow-candidate-v2")
	data.scene_language = _hollow_language(data)
	data.ports = {"entry":_port(data.spawn,"entry","outside_observation"),
		"crown":_port(data.goal,"crown","downward_outer_exit"),
		"inner_root":_port([365.0,520.0],"inner_root","inward_failure_recovery"),
		"outer_root":_port([665.0,600.0],"outer_root","outward_failure_recovery")}
	data.consumer_contract = {"kind":"hollow_cavity","motion":"descending_elbow","from_port":"S","to_port":"C","standing_first_hook":true,"real_bay_observation_frames":12}
	data.routes = {"main":{"kind":"hollow_cavity","motion":"descending_elbow","from_port":"entry","to_port":"crown","action_program":data.action_program.duplicate(true),"path":[data.spawn.duplicate(),[355.0,0.0],data.goal.duplicate()]},
		"outer_descent":{"kind":"drop_through","from_port":"crown","to_port":"outer_root","path":[data.goal.duplicate(),[900.0,90.0],[900.0,600.0],[665.0,600.0]],
			"steps":[{"kind":"drop_through","from_support_id":"crown","support_id":"outer_root","takeoff":[813.0,90.0],"landing":[900.0,600.0],"path":[[813.0,90.0],[900.0,90.0],[900.0,600.0]]},
				{"kind":"walk","support_id":"outer_root","landing":[665.0,600.0]}]}}
	data.recovery = {"mode":"world_connected_root_ports","miss_supports":["inner_root","outer_root","outer_sump"],"safe_ports":["inner_root","outer_root"],
		"consumer_required":"Connect lower ports into the real root network; no isolated ladder or assumed return to the high entry.","native_verified":false}
	data.return = {"route":"outer_descent","different_exit_port":"outer_root","native_verified":false}
	data.play_contract = {"observe":"The first horizontal cell opens into a lower second cell; pale thorns are attached to the actual cap and lower bark.",
		"decision":"Use the inner observation bay as a stable beat, or keep the next side-hook/recoil phrase airborne through the downward elbow.",
		"recovery":"A miss reaches real inner/outer root floors. The world must connect those different low ports into its root loop.",
		"counterexample":"Compare a strong recoil-only passage, a stopped bay crossing and the intended two-cell phrase. Never claim continuous air if the real bay was touched."}
	data.derivations = ["old_descending_elbow_geometry", "outside_observation_branch_widened_away_from_flight", "coordinate_normalization_only", "hazard_union_split_at_true_host_seams"]
	data.chain_contract = {"continuous_airborne":false,"midair_floor_allowed":true,"hook_restoration":"actual_contact_kick_completion","fixed_anchor_does_not_refill_shots":true,"production_pool":false,"native_verified":false}
	data.erase("candidate_itinerary")
	return data

static func _air_route(start: String,finish: String,program: Array,path: Array) -> Dictionary:
	return {"kind":"airborne_chain","from_port":start,"to_port":finish,"action_program":program.duplicate(true),"path":path.duplicate(true),"native_verified":false}

static func _mount(anchor: Dictionary,host: String,root: Array,role: String) -> void:
	anchor.host_support_id = host
	anchor.stem_root = root.duplicate()
	anchor.fruit_presentation = "rooted_fruit"
	anchor.fruit_role = role

static func _source(path: String,version: String) -> Dictionary:
	return {"path":path,"version":version,"sha256":FileAccess.get_sha256(path)}

static func _rename_support(data: Dictionary,old_id: String,new_id: String) -> void:
	for row: Dictionary in data.platforms:
		if str(row.id) == old_id: row.id = new_id
	_rewrite_support_references(data,old_id,new_id)

static func _rewrite_support_references(value: Variant,old_id: String,new_id: String) -> void:
	if value is Array:
		for item: Variant in value: _rewrite_support_references(item,old_id,new_id)
	elif value is Dictionary:
		for key: Variant in value:
			if str(key) in ["support_id","from_support_id","host_support_id","entry_support_id","exit_support_id","reward_support_id","safe_observation_support","start_support","landing_support","goal_support","support"] and value[key] is String and str(value[key]) == old_id:
				value[key] = new_id
			else: _rewrite_support_references(value[key],old_id,new_id)

static func _translate_geometry(data: Dictionary,offset: Vector2) -> void:
	# Route slices in the original factory can share step Dictionaries. Split
	# those records before translating so every coordinate moves exactly once.
	data.steps = data.get("steps",[]).duplicate(true)
	for route_name: String in data.get("routes",{}):
		if data.routes[route_name] is Array: data.routes[route_name] = data.routes[route_name].duplicate(true)
	data.spawn = _pair(_point(data.spawn)+offset)
	data.goal = _pair(_point(data.goal)+offset)
	for row: Dictionary in data.platforms:
		row.rect[0] = float(row.rect[0])+offset.x
		row.rect[1] = float(row.rect[1])+offset.y
	for anchor: Dictionary in data.hook_anchors:
		anchor.position = _pair(_point(anchor.position)+offset)
		if anchor.has("stem_root"): anchor.stem_root = _pair(_point(anchor.stem_root)+offset)
	for danger: Array in data.dangers:
		danger[0] = float(danger[0])+offset.x
		danger[1] = float(danger[1])+offset.y
	for window: Dictionary in data.get("windows",[]):
		window.clear_rect[0] = float(window.clear_rect[0])+offset.x
		window.clear_rect[1] = float(window.clear_rect[1])+offset.y
	for key: String in data.get("nodes",{}):
		data.nodes[key].position = _pair(_point(data.nodes[key].position)+offset)
	_translate_steps(data.get("steps",[]),offset)
	for key: String in data.get("routes",{}):
		if data.routes[key] is Array: _translate_steps(data.routes[key],offset)
	if data.has("reward_position"): data.reward_position = _pair(_point(data.reward_position)+offset)
	if data.has("recovery_start"): data.recovery_start = _pair(_point(data.recovery_start)+offset)

static func _hollow_language(data: Dictionary) -> Dictionary:
	var language: Dictionary = {}
	for row: Dictionary in data.platforms:
		var id := str(row.id)
		language[id] = "living_bough" if bool(row.one_way) else "root_ground" if "root" in id or id == "entry" else "hollow_trunk"
	return language

static func _pair(point: Vector2) -> Array:
	return [point.x,point.y]

static func _fallen_arch_canopy() -> Dictionary:
	var data: Dictionary = AIR.build("arch_four").duplicate(true)
	# Same deliberate v15 retirement: this old prototype strip has no root
	# host. It is not silently moved onto the flight or hidden by a renderer.
	data.dangers = []
	data.danger_surfaces = []
	data.retired_source_dangers = {"rects":[[82.0,100.0,790.0,18.0]],"reason":"same_v15_unhosted_prototype_retirement","no_other_collision_change":true}
	for anchor: Dictionary in data.hook_anchors:
		match str(anchor.id):
			"side_ring": _mount(anchor,"root_arch",[200.0,-111.0],"main")
			"arch_exit_ring": _mount(anchor,"crown",[500.0,-199.0],"main")
			"crown_ring": _mount(anchor,"crown",[500.0,-222.0],"main")
			"return_catch_ring": _mount(anchor,"root_arch",[349.0,-111.0],"return")
	data.ports = {"entry":_port(data.spawn,"entry","under_arch_departure"),"crown":_port(data.goal,"crown","upper_canopy_destination"),
		"lower_root":_port([800.0,202.0],"recovery","different_shared_root_destination")}
	data.routes = {"main":_air_route("entry","crown",data.action_program,[data.spawn.duplicate(),[200.0,-40.0],[470.0,-130.0],data.goal.duplicate()]),
		"outer_root_descent":{"kind":"drop_through","from_port":"crown","to_port":"lower_root","path":[data.goal.duplicate(),[800.0,-240.0],[800.0,202.0]],
			"steps":[{"kind":"drop_through","from_support_id":"crown","support_id":"recovery","takeoff":[728.0,-240.0],"landing":[800.0,202.0],"path":[[728.0,-240.0],[800.0,-240.0],[800.0,202.0]]}]}}
	data.play_contract = {"observe":"One thick fallen trunk covers the start; its far broken end exposes a higher crown and a wide lower root.",
		"decision":"Round the outer bark and turn upward to the canopy, or descend outside the receiving crown into a different root loop.",
		"recovery":"The whole lower root receives a miss. Shared-world attachment must keep this catch away from a neighbouring airborne phrase.",
		"counterexample":"Compare held jump plus real recoil with the intended H/R/H/H; do not require all named actions if a clearer cheap route exists."}
	data.derivations = ["old_arch_four_platforms_targets_and_program_retained", "exact_v15_unhosted_strip_retirement", "explicit_lower_root_return_port"]
	return data

static func _thorn_side_outlet() -> Dictionary:
	var data: Dictionary = MOUTH.build().duplicate(true)
	data.source_factory = _source("res://scripts/generation/forest_thorn_mouth_geometry.gd",MOUTH.VERSION)
	_mount(data.hook_anchors[0],"root_arch",[200.0,-111.0],"main")
	# These original strips straddle their actual solid faces: down-facing
	# bark at y-110 and the crown's left face at x250. They are not floating
	# up-facing tiles. The v15 surface consumer uses the same real seams.
	data.danger_surfaces = [{"danger_index":0,"host_support_id":"root_arch","face":"down","surface_y":-110.0},
		{"danger_index":1,"host_support_id":"crown","face":"left","surface_x":250.0}]
	data.danger_presentations = [{"facing":"down"},{"facing":"left"}]
	data.platforms.append({"id":"outer_outlet","rect":[650.0,48.0,280.0,24.0],"one_way":true})
	data.scene_language = _hollow_language(data)
	data.scene_language["outer_outlet"] = "living_bough"
	data.ports = {"entry":_port(data.spawn,"entry","side_fruit_observation"),
		"crown":_port(data.goal,"crown","upper_mouth_onward"),
		"lower_exit":_port([750.0,30.0],"outer_outlet","different_lower_outward_destination"),
		"basin":_port([750.0,122.0],"recovery","lower_recovery_root")}
	data.routes = {"main":_air_route("entry","crown",data.action_program,[data.spawn.duplicate(),[200.0,-40.0],data.goal.duplicate()]),
		"outer_descent":{"kind":"drop_through","from_port":"crown","to_port":"lower_exit","path":[data.goal.duplicate(),[630.0,-42.0],[750.0,30.0]],
			"steps":[{"kind":"drop_through","from_support_id":"crown","support_id":"outer_outlet","takeoff":[538.0,-42.0],"landing":[750.0,30.0],"path":[[538.0,-42.0],[630.0,-42.0],[750.0,30.0]]}]}}
	data.play_contract = {"observe":"A narrow bark mouth has pale down-facing thorns above and thorns around the receiver's actual left face; the upper shore is broad.",
		"decision":"Use the side fruit and recoil to reach the upper mouth, then select its upper continuation or the lower outward outlet.",
		"recovery":"Misses reach the broad root below, where the original single western root lip gives a local retry.",
		"counterexample":"A lower-root journey is a legitimate alternate destination, not free access to the upper reward. Keep full-held jump/recoil alternatives legal and test the real thorn sweep."}
	data.derivations = ["old_side_hook_thorn_mouth_body_targets_program_and_danger_union_retained", "explicit_real_down_and_left_thorn_faces", "different_lower_root_outlet"]
	return data

static func _l_hollow_reward_loop() -> Dictionary:
	var data: Dictionary = CORRIDORS.build("thorn_l_root_turn").duplicate(true)
	_remove_ladder(data)
	_rename_support(data,"exit","crown")
	_translate_geometry(data,Vector2(-40.0,18.0))
	# The floor, root elbow, actual danger union and ordinary crossings remain
	# exact. Only the old repeated return ladder is retired in this version.
	data.action_program = []
	data.scene_language = _hollow_language(data)
	data.source_factory = _source("res://scripts/generation/forest_thorn_corridor_modules.gd",CORRIDORS.VERSION)
	_mount(data.hook_anchors[0],"fruit_bough",[648.0,-15.0],"optional")
	_hold_normal_crossings(data.steps)
	var reward_steps: Array = data.steps.slice(0,4).duplicate(true)
	reward_steps.append({"kind":"walk","support_id":"receiver","landing":data.reward_position.duplicate()})
	var return_steps: Array = [
		{"kind":"walk","support_id":"receiver","landing":[664.0,160.0]},
		{"kind":"jump_gap","from_support_id":"receiver","support_id":"elbow_root","takeoff":[664.0,160.0],"landing":[488.0,160.0],"hold_until_ceiling_or_receiver":true},
		{"kind":"walk","support_id":"elbow_root","landing":[232.0,160.0]},
		{"kind":"drop_through","from_support_id":"elbow_root","support_id":"catch","takeoff":[232.0,160.0],"landing":[152.0,320.0],"path":[[232.0,160.0],[152.0,160.0],[152.0,320.0]]}]
	data.ports = {"entry":_port(data.spawn,"entry","optional_elbow_departure"),
		"crown":_port(data.goal,"crown","far_outward_exit"),
		"cache":_port(data.reward_position,"receiver","elbow_cache"),
		"lower_rejoin":_port([152.0,320.0],"catch","different_lower_return_mouth")}
	data.routes = {"main":_ordinary_route("entry","crown",data.steps),
		"reward":_ordinary_route("entry","cache",reward_steps),
		"reward_other_exit":_ordinary_route("cache","lower_rejoin",return_steps),
		"reward_onward":_ordinary_route("cache","crown",data.steps.slice(4).duplicate(true))}
	data.consumer_contract = {"kind":"ordinary_sequence","steps_route":"main","optional_reward_loop":true,"full_held_jump_to_receiver":true}
	data.chain_contract = {"continuous_airborne":false,"midair_floor_allowed":true,"production_pool":false,"native_verified":false}
	data.branch_reward_contract = {"reward_route":"reward","return_route":"reward_other_exit","reward_support_id":"receiver","reward_position":data.reward_position.duplicate(),
		"world_reward_required":true,"no_exit_coin_override":true,"native_verified":false}
	data.recovery = {"support":"catch","safe_port":"lower_rejoin","removed_ladder":true,"world_must_connect_lower_port":true,"native_verified":false}
	data.return = {"route":"reward_other_exit","different_exit_port":"lower_rejoin","native_verified":false}
	data.play_contract = {"observe":"A vertical rooted limb and its joined overhead bough form a broad downward elbow; the cache is on its far receiving root.",
		"decision":"Drop into the elbow to earn the cache, then return through the visible lower-left mouth or continue through the far lower-right exit.",
		"alternative":"A full-held ordinary thorn jump is legal. The side fruit is optional; no H/R chain is invented to fit an airborne test.",
		"recovery":"One continuous root catches a miss and connects to another world root node; the old four-step external ladder is absent.",
		"counterexample":"Verify both reward-then-return and reward-then-onward with actual pickup settlement; bind lower_rejoin to a real earlier root, not another copied reward room."}
	data.derivations = ["rooted_L_body_and_danger_union_retained", "retired_four_generic_return_rungs", "reward_then_two_real_exit_choices", "rigid_spawn_normalization"]
	_clean_corridor_metadata(data)
	return data

static func _z_hollow_inner_cache() -> Dictionary:
	var data: Dictionary = CORRIDORS.build("thorn_z_root_switchback").duplicate(true)
	_remove_ladder(data)
	_rename_support(data,"upper_root","entry")
	_rename_support(data,"lower_root","crown")
	_translate_geometry(data,Vector2(-40.0,18.0))
	data.action_program = []
	data.risk_reward = {"coins":8,"notes":1,"tier":"high","optional":true,"return_required":true}
	data.scene_language = _hollow_language(data)
	data.source_factory = _source("res://scripts/generation/forest_thorn_corridor_modules.gd",CORRIDORS.VERSION)
	_mount(data.hook_anchors[0],"entry",[536.0,65.0],"optional")
	_mount(data.hook_anchors[1],"middle_root",[760.0,353.0],"optional")
	_hold_normal_crossings(data.steps)
	# Walk directly to the real cache after the inward thorn crossing. Do not
	# add the old extra64wu there-and-back merely to follow an authored list.
	var reward_steps: Array = data.steps.slice(0,6).duplicate(true)
	reward_steps.append({"kind":"walk","support_id":"middle_root","landing":data.reward_position.duplicate()})
	var back_steps: Array = [{"kind":"walk","support_id":"middle_root","landing":[184.0,288.0]},
		{"kind":"drop_through","from_support_id":"middle_root","support_id":"crown","takeoff":[184.0,288.0],"landing":[88.0,576.0],"path":[[184.0,288.0],[88.0,288.0],[88.0,576.0]]}]
	data.ports = {"entry":_port(data.spawn,"entry","upper_root_departure"),
		"crown":_port(data.goal,"crown","lower_outward_onward"),
		"outer_middle":_port([1032.0,288.0],"middle_root","choose_inner_cache_or_outer_drop"),
		"cache":_port(data.reward_position,"middle_root","middle_left_inner_cache"),
		"lower_rejoin":_port([88.0,576.0],"crown","different_inward_return_mouth"),
		"basin":_port([1320.0,832.0],"catch","outside_catch_root")}
	data.routes = {"main":_ordinary_route("entry","crown",data.steps),
		"reward":_ordinary_route("entry","cache",reward_steps),
		"reward_other_exit":_ordinary_route("cache","lower_rejoin",back_steps),
		"outer_approach":_ordinary_route("entry","outer_middle",data.steps.slice(0,4).duplicate(true)),
		"outer_fast_drop":{"kind":"ordinary_outer_descent","from_port":"outer_middle","to_port":"crown","from_support_id":"middle_root","support_id":"crown","outside_side":1,
			"outside_x":1256.0,"clear_body_top_below_y":356.0,"landing":data.goal.duplicate(),
			"input_contract":"walk outside the solid middle root; wait for the actual full body to clear its underside, then steer inward to the lower receiver","native_verified":false}}
	data.consumer_contract = {"kind":"ordinary_sequence","steps_route":"main","optional_reward_loop":true,"full_held_jump_to_receiver":true}
	data.chain_contract = {"continuous_airborne":false,"midair_floor_allowed":true,"production_pool":false,"native_verified":false}
	data.branch_reward_contract = {"reward_route":"reward","return_route":"reward_other_exit","reward_support_id":"middle_root","reward_position":data.reward_position.duplicate(),
		"world_reward_required":true,"no_exit_coin_override":true,"ordinary_outer_route_skips_cache":true,"native_verified":false}
	data.recovery = {"support":"catch","safe_port":"basin","removed_ladder":true,"world_must_connect_lower_port":true,"native_verified":false}
	data.return = {"route":"reward_other_exit","different_exit_port":"lower_rejoin","native_verified":false}
	data.play_contract = {"observe":"The right upper opening leads to a broad middle root; the valuable cache is on its opposite left side, above another left opening.",
		"decision":"Take the inner thorn crossing for the cache and leave through the lower-left mouth, or decline it and use the outer-right fall to the lower-right destination.",
		"alternative":"Full-held normal jumps cross the attached thorn patches. Optional opposite fruit/recoil approaches are not required passwords.",
		"recovery":"Three broad real roots catch each descent; the bottom basin joins the world's root network, with no external return ladder.",
		"counterexample":"A fast outside descent is allowed but must not receive the middle-left cache. Verify real body clearance below the middle root and actual reward/OR settlement separately."}
	data.derivations = ["rooted_Z_body_and_danger_union_retained", "retired_generic_return_rungs", "inner_cache_vs_outer_fast_destination", "removed_redundant_cache_walkback", "rigid_spawn_normalization"]
	_clean_corridor_metadata(data)
	return data

static func _remove_ladder(data: Dictionary) -> void:
	var retained: Array = []
	var removed: Array = []
	for row: Dictionary in data.platforms:
		if str(row.id).begins_with("return_root_"): removed.append(row.duplicate(true))
		else: retained.append(row)
	data.platforms = retained
	data.retired_ladder_supports = removed

static func _translate_steps(steps: Array,offset: Vector2) -> void:
	for step: Dictionary in steps:
		for key: String in ["takeoff","landing"]:
			if step.has(key): step[key] = _pair(_point(step[key])+offset)
		if step.has("path"):
			for index: int in step.path.size(): step.path[index] = _pair(_point(step.path[index])+offset)

static func _hold_normal_crossings(steps: Array) -> void:
	for step: Dictionary in steps:
		if str(step.get("kind","")) in ["jump_gap","jump_rise"]: step.hold_until_ceiling_or_receiver = true

static func _ordinary_route(start: String,finish: String,steps: Array) -> Dictionary:
	return {"kind":"ordinary_sequence","from_port":start,"to_port":finish,"steps":steps.duplicate(true),"native_verified":false}

static func _clean_corridor_metadata(data: Dictionary) -> void:
	# Source contracts used old local coordinates and old return ladder IDs.
	# New routes/ports above are the sole authoritative executable records.
	for key: String in ["corridor_contract","shortcut_contract","optional_phrases","recovery_start","reward_outbound_step_count","branch_reward_contract"]:
		if key == "branch_reward_contract": continue
		data.erase(key)

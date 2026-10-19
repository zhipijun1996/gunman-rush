class_name ForestInterwovenExpedition
extends RefCounted
## V13 first golden: short grounded lessons feed two genuinely distinct canopy paths.
## A data producer only. Every new traversal remains pending real Motor admission.
const VERSION := "forest-interwoven-canopy-v13"
const API := preload("res://scripts/generation/forest_expedition_layout.gd")
const BASE := preload("res://scripts/generation/thorn_forest_region_v2_v10.gd")

static func install(m: Dictionary) -> void:
	var previous_routes: Dictionary = m.routes.duplicate(true)
	# The approach crosses a real gap before descending into the existing basin.
	API._platform(m,"interwoven_root_bridge",Rect2(-2090,1900,100,24),true,"living_bough","interwoven_root_bay","approach_before_safe_drop")
	API._platform(m,"interwoven_lesson_bough",Rect2(-1830,1850,200,24),true,"living_bough","interwoven_root_bay","first_actual_grounded_focus_reset")
	API._platform(m,"interwoven_inner_bough",Rect2(-2140,1580,190,24),true,"canopy_perch","interwoven_inner_hollow","observe_two_routes_after_HH")
	API._platform(m,"interwoven_upper_launch",Rect2(-2400,1460,190,24),true,"living_bough","interwoven_root_hollow","cross_back_before_crown")
	_anchor(m,"interwoven_lesson_ring",Vector2(-1780,1782),"interwoven_root_bay")
	_anchor(m,"interwoven_hollow_a",Vector2(-1880,1662),"interwoven_inner_hollow")
	_anchor(m,"interwoven_hollow_b",Vector2(-1960,1500),"interwoven_inner_hollow")
	_anchor(m,"interwoven_upper_cross_ring",Vector2(-2120,1370),"interwoven_root_hollow")
	_anchor(m,"interwoven_crown_side_ring",Vector2(-2070,1230),"root_spiral")
	API._area(m,"root_bay",Vector2(-1935,1982),"ROOT BAY / GROUND RESTORES AIM","junction")
	API._area(m,"root_bay_lesson",Vector2(-1780,1832),"LIVING ROOT / ONE HOOK THEN LAND","tutorial")
	API._area(m,"interwoven_inner",Vector2(-2030,1562),"INNER HOLLOW / CROWN OR THORN PASSAGE?","junction")
	API._area(m,"interwoven_upper",Vector2(-2300,1442),"SIDE ROOT / THE CROWN IS LEFT AND ABOVE","junction")
	API._edge(m,"root_bay_approach","arrival","root_bay","ordinary_sequence",[[-2200.0,1882.0],[-2050.0,1882.0],[-1970.0,1982.0],[-1935.0,1982.0]],[
		API._step("jump_gap",Vector2(-2150,1882),Vector2(-2050,1882),"root_spiral__entry","interwoven_root_bridge"),
		{"kind":"walk","landing":[-2010.0,1882.0],"support_id":"interwoven_root_bridge"},
		{"kind":"drop_through","path":[[-2010.0,1882.0],[-1970.0,1882.0],[-1970.0,1982.0],[-1935.0,1982.0]],"landing":[-1935.0,1982.0],"from_support_id":"interwoven_root_bridge","support_id":"thorn_mouth__recovery"}])
	_phrase(m,"root_bay_lesson_flight","root_bay","root_bay_lesson","lesson_H","thorn_mouth__recovery","interwoven_lesson_bough")
	_phrase(m,"inner_hollow_HH","root_bay_lesson","interwoven_inner","inner_HH","interwoven_lesson_bough","interwoven_inner_bough")
	_phrase(m,"upper_root_RH","interwoven_inner","interwoven_upper","upper_RH","interwoven_inner_bough","interwoven_upper_launch")
	_phrase(m,"upper_root_crown_H","interwoven_upper","root_spiral_crown","crown_H","interwoven_upper_launch","root_spiral__crown")
	_phrase(m,"inner_thorn_HR","interwoven_inner","thorn_mouth_mouth","inner_HR","interwoven_inner_bough","thorn_mouth__entry")
	_install_deep_root_golden(m)
	# A five-action landing needs an observation bank before the existing line guard.
	# Keep this enemy and all of its stats; only v13 relocates its authored occupancy.
	for enemy: Dictionary in m.enemies:
		if str(enemy.id) == "hollow_route__inner_thread":
			enemy.position = [500.0,806.0]
			enemy.line_start = [470.0,802.0]
			enemy.line_end = [520.0,802.0]
			enemy.authored_body_sweep = [487.0,792.0,26.0,28.0]
	# The receiver is west of the wall. A direct vertical crown drop is now real.
	API._edge(m,"crown_inner_return","root_spiral_crown","interwoven_inner","ordinary_sequence",[[-2050.0,1322.0],[-2030.0,1322.0],[-2030.0,1562.0]],[
		{"kind":"drop_through","path":[[-2050.0,1322.0],[-2030.0,1322.0],[-2030.0,1562.0]],"landing":[-2030.0,1562.0],"from_support_id":"root_spiral__crown","support_id":"interwoven_inner_bough"}])
	API._edge(m,"inner_bay_return","interwoven_inner","root_bay","ordinary_sequence",[[-2030.0,1562.0],[-1980.0,1982.0],[-1935.0,1982.0]],[
		{"kind":"drop_through","path":[[-2030.0,1562.0],[-1980.0,1562.0],[-1980.0,1982.0],[-1935.0,1982.0]],"landing":[-1935.0,1982.0],"from_support_id":"interwoven_inner_bough","support_id":"thorn_mouth__recovery"}])
	var lesson_prefix: Array = ["root_bay_approach","root_bay_lesson_flight","inner_hollow_HH"]
	var inner: Array = lesson_prefix.duplicate()
	inner.append("inner_thorn_HR")
	var upper: Array = lesson_prefix.duplicate()
	upper.append_array(["upper_root_RH","upper_root_crown_H"])
	var rng := RunRandomStream.new(str(m.seed),"forest_interwoven","map_%s"%m.map_index,VERSION)
	var first_inner: bool = rng.next_int(2) == 0
	for route_name: String in ["fast","growth","high_return","change_mind","borer"]:
		# High return deliberately keeps the existing optional uninterrupted skill line.
		if route_name == "high_return":
			m.routes[route_name] = previous_routes[route_name].duplicate()
			continue
		var via_inner: bool = first_inner if route_name in ["fast","change_mind"] else not first_inner
		var prefix: Array = inner.duplicate() if via_inner else upper.duplicate()
		prefix.append_array(_suffix(previous_routes[route_name],"thorn_mouth_flight" if via_inner else "lower_fork_approach"))
		m.routes[route_name] = prefix
	# Preserve western reward returns; other growth paths discover the deep camp first.
	var west_reward: bool = bool(m.choices.get("west_reward",false))
	if not west_reward:
		var deep_route: Array = _prefix_through(m.routes.growth,"broken_arch_flight")
		deep_route.append_array(["interwoven_deep_descent","interwoven_deep_ascent"])
		if API._point(m.merchant_position) == Vector2(360,802):
			deep_route.append("interwoven_root_to_camp")
		else:
			deep_route.append("interwoven_root_to_D")
			deep_route.append_array(BASE._route(m,"D","camp"))
		deep_route.append_array(BASE._route(m,"camp","cache"))
		deep_route.append_array(BASE._route(m,"cache","gate_ready"))
		m.routes.growth = deep_route
	m.choices.interwoven_midroute = "upper_west_reward_existing_order" if west_reward else "deep_root_camp_first"
	m.choices.interwoven_midroute_basis = "actual_existing_west_reward; no additional random draw"
	for edge: Dictionary in m.connections:
		if str(edge.id) in ["root_spiral_flight","root_spiral_rest_flight"]:
			edge.optional_skill_shortcut = true
	for area: Dictionary in m.areas:
		if area.id == "arrival":area.label = "ROOT FORK / SHORT RESTING ROUTE OR CANOPY SKILL LINE"
	m.entry_contract = {"selected":"root_bay","optional_skill_route":"root_spiral","reason":"real_grounded_recovery_before_the_first_HH_decision","native_verified":false}
	m.interwoven_contract = {"version":VERSION,"scope":"interwoven_entry_and_deep_root_candidate","splits":["arrival","interwoven_inner","broken_arch_crown"],"rejoins":["root_spiral_crown","thorn_mouth_mouth","interwoven_root_landing","M"],"grounded_rest_supports":["thorn_mouth__recovery","interwoven_lesson_bough","interwoven_inner_bough","interwoven_upper_launch","interwoven_deep_basin"],"phrases":["H","HH","RH","H","R_HANG_R","RH_descending","HRHHR_580_rise"],"deep_root_rise":580.0,"deep_root_first_landing":"hollow__inner_root","held_hang_resets_focus":false,"discovery_order_change":"non-west-reward growth descends to deep root and actual camp before cache; west-reward seeds retain their existing upper/reward route without a forced deep-camp detour","native_verified":false,"production_pool":false,"admission":"candidate; geometry evidence and formal full-route evidence remain separately source-bound"}
	m.vertical_contract.version = VERSION
	m.vertical_contract.early_choice = "root bay short grounded phrases or optional uninterrupted root spiral"
	m.vertical_contract.continuous_phrases = 7
	m.interwoven_contract.legacy_canopy_phrases_retained = 7
	m.interwoven_contract.actual_route_phrases = "route_dependent; inspect the selected edge programs, not the legacy count"
	m.choices.interwoven_first_branch = "inner" if first_inner else "upper"
	m.streams.interwoven = "forest_interwoven"
	m.stream_positions.interwoven = rng.position()
	m.scene_structure_kinds.merge({"interwoven_root_bay":"rootland","interwoven_inner_hollow":"root_hollow","interwoven_root_hollow":"bough_relay"})
	m.expedition_hints = [
		{"position":[-2200.0,1790.0],"text":"East: short flights with broad resting roots.\nAbove: the uninterrupted canopy skill line.","radius":210.0},
		{"position":[-1935.0,1930.0],"text":"Jump first, then hook up. Move left and LAND on the wide root.\nGround restores the airborne aim budget; hanging does not.","radius":190.0},
		{"position":[-2030.0,1500.0],"text":"Left: recoil and hook back toward the crown.\nRight: recoil toward the hanging ring, then fire down.","radius":180.0}]

	# These two side-entry casts need a short jump rise before releasing H.
	# Five existing trace ticks are input choreography, never a movement change.
	for edge: Dictionary in m.connections:
		if str(edge.id) in ["root_bay_lesson_flight","upper_root_crown_H"]:
			edge.first_hook_delay = 5

static func _suffix(route: Array, first: String) -> Array:
	var index: int = route.find(first)
	assert(index >= 0)
	return route.slice(index)

static func _anchor(m: Dictionary, id: String, at: Vector2, structure: String) -> void:
	m.hook_anchors.append({"id":id,"position":API.pair(at),"scene_kind":"copper_growth_ring","structure_id":structure})

static func build(phrase: String) -> Dictionary:
	var rows: Dictionary = {
		"lesson_H":{"spawn":[-1935.0,1982.0],"goal":[-1780.0,1832.0],"program":[{"action":"H","anchor":"a"}],"anchors":{"a":"interwoven_lesson_ring"}},
		"inner_HH":{"spawn":[-1805.0,1832.0],"goal":[-2030.0,1562.0],"program":[{"action":"H","anchor":"a"},{"action":"H","anchor":"b"}],"anchors":{"a":"interwoven_hollow_a","b":"interwoven_hollow_b"}},
		"upper_RH":{"spawn":[-2030.0,1562.0],"goal":[-2300.0,1442.0],"program":[{"action":"R","direction":[1,0]},{"action":"H","anchor":"a"}],"anchors":{"a":"interwoven_upper_cross_ring"}},
		"crown_H":{"spawn":[-2230.0,1442.0],"goal":[-2050.0,1322.0],"program":[{"action":"H","anchor":"a"}],"anchors":{"a":"interwoven_crown_side_ring"}},
		"deep_descent_RH":{"spawn":[-237.0,956.0],"goal":[200.0,1382.0],"bounds":[-650.0,650.0,1550.0,900.0],"program":[{"action":"R","direction":[-1,0]},{"action":"H","anchor":"a"}],"anchors":{"a":"interwoven_deep_descent_ring"}},
		"deep_ascent_HRHHR":{"spawn":[200.0,1382.0],"goal":[400.0,802.0],"bounds":[-100.0,600.0,1000.0,950.0],"program":[{"action":"H","anchor":"a"},{"action":"R","direction":[0,1]},{"action":"H","anchor":"b"},{"action":"H","anchor":"c"},{"action":"R","direction":[-1,0]}],"anchors":{"a":"interwoven_deep_a","b":"interwoven_deep_b","c":"interwoven_deep_c"}},
		"inner_HR":{"spawn":[-2030.0,1562.0],"goal":[-1695.0,1280.0],"program":[{"action":"R","direction":[-1,0]},{"action":"HANG","anchor":"a"},{"action":"R","direction":[0,1]}],"anchors":{"a":"thorn_retry_exit_ring"}}}
	if not rows.has(phrase):return {}
	var row: Dictionary = rows[phrase]
	return {"id":phrase,"version":VERSION,"spawn":row.spawn.duplicate(),"goal":row.goal.duplicate(),"action_program":row.program.duplicate(true),"anchor_bindings":row.anchors.duplicate(true),"world_bounds":row.get("bounds",[-2550.0,1150.0,1200.0,1000.0]).duplicate(),"chain_contract":{"continuous_airborne":true,"midair_floor_allowed":false,"production_pool":false,"native_verified":false}}

static func _phrase(m: Dictionary,id: String,a: String,b: String,phrase: String,entry: String,crown: String) -> void:
	var raw: Dictionary = build(phrase)
	var instance_id: String = "interwoven_"+phrase
	var platform_map: Dictionary = {"entry":entry,"crown":crown}
	raw.platforms = []
	for local: String in ["entry","crown"]:
		var source: Dictionary = API._platform_by_id(m,str(platform_map[local]))
		raw.platforms.append({"id":local,"rect":source.rect.duplicate(),"one_way":source.one_way})
	raw.dangers = []
	raw.hook_anchors = []
	for local: String in raw.anchor_bindings:
		for anchor: Dictionary in m.hook_anchors:
			if str(anchor.id) == str(raw.anchor_bindings[local]):
				raw.hook_anchors.append({"id":local,"position":anchor.position.duplicate(),"hang_enabled":bool(anchor.get("hang_enabled",false))})
	var instance: Dictionary = {"id":instance_id,"factory":"res://scripts/generation/forest_interwoven_expedition.gd","geometry_version":VERSION,"local_geometry":raw,"translation":[0.0,0.0],"platform_id_map":platform_map,"anchor_id_map":raw.anchor_bindings.duplicate(true),"danger_indices":[]}
	m.geometry_instances.append(instance)
	API._air_edge(m,id,a,b,instance)
	m.connections[-1].entry_support_id = entry
	m.connections[-1].native_verified = false
	m.connections[-1].focus_recovery = "actual_ground_contact_after_phrase; no hanging refill"
	if phrase == "inner_HR":
		m.connections[-1].kind = "hanging_chain"
		m.connections[-1].rest_anchor_id = "thorn_retry_exit_ring"
		m.connections[-1].hang_observation_frames = 18


static func _install_deep_root_golden(m: Dictionary) -> void:
	API._platform(m,"interwoven_deep_basin",Rect2(95,1400,200,24),false,"root_earth","interwoven_deep_root","grounded_recovery_below_the_old_root")
	_anchor(m,"interwoven_deep_descent_ring",Vector2(60,1050),"interwoven_deep_root")
	_anchor(m,"interwoven_deep_a",Vector2(80,1240),"interwoven_deep_root")
	_anchor(m,"interwoven_deep_b",Vector2(220,920),"interwoven_deep_root")
	_anchor(m,"interwoven_deep_c",Vector2(270,780),"hollow")
	API._area(m,"interwoven_root_landing",Vector2(400,802),"INNER ROOT LIP / CAMP OR OLD HOLLOW","junction")
	API._area(m,"interwoven_deep_basin",Vector2(200,1382),"DEEP ROOT / REST, THEN CURVE AROUND THE ROOT LIP","junction")
	_phrase(m,"interwoven_deep_descent","broken_arch_crown","interwoven_deep_basin","deep_descent_RH","broken_arch__crown","interwoven_deep_basin")
	_phrase(m,"interwoven_deep_ascent","interwoven_deep_basin","interwoven_root_landing","deep_ascent_HRHHR","interwoven_deep_basin","hollow__inner_root")
	API._edge(m,"interwoven_root_to_D","interwoven_root_landing","D","walk",[[400.0,802.0],[720.0,802.0]])
	if API._point(m.merchant_position) == Vector2(360,802):
		API._edge(m,"interwoven_root_to_camp","interwoven_root_landing","camp","walk",[[400.0,802.0],[360.0,802.0]])
	m.scene_structure_kinds["interwoven_deep_root"] = "root_hollow"

static func _prefix_through(route: Array, last: String) -> Array:
	var at: int = route.find(last)
	assert(at >= 0)
	return route.slice(0,at+1)

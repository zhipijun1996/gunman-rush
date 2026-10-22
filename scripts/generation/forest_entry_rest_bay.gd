class_name ForestEntryRestBay
extends RefCounted
## V17 only: one broad resting branch splits the early 270wu HH climb.
## The original continuous HH and the upper skill route remain available.
const VERSION := "forest-entry-rest-bay-v1"
const API := preload("res://scripts/generation/forest_expedition_layout.gd")

static func install(m: Dictionary) -> void:
	API._platform(m,"varied_entry_rest_bay",Rect2(-2050,1790,165,40),true,"living_bough","varied_entry_hollow","single_observation_branch_west_of_the_first_hook_ray")
	API._area(m,"varied_entry_rest",Vector2(-1980,1772),"HOLLOW REST / READ THE NEXT FRUIT","tutorial")
	_phrase(m,"varied_entry_first_H","root_bay_lesson","varied_entry_rest",Vector2(-1805,1832),Vector2(-1980,1772),"interwoven_lesson_bough","varied_entry_rest_bay","interwoven_hollow_a")
	# Step to the open eastern shoulder before casting. Casting vertically
	# from the resting centre hits the old inner branch's real underside.
	_phrase(m,"varied_entry_second_H","varied_entry_rest","interwoven_inner",Vector2(-1900,1772),Vector2(-2030,1562),"varied_entry_rest_bay","interwoven_inner_bough","interwoven_hollow_b")
	for name: String in m.routes:
		if name.begins_with("legacy_"): continue
		var route: Array = []
		for id: String in m.routes[name]:
			if id == "inner_hollow_HH": route.append_array(["varied_entry_first_H","varied_entry_second_H"])
			else: route.append(id)
		m.routes[name] = route
	m.routes.varied_entry_trial = ["root_bay_approach","root_bay_lesson_flight","varied_entry_first_H","varied_entry_second_H"]
	m.route_goals.varied_entry_trial = "interwoven_inner"
	m.routes.varied_original_entry_trial = ["root_bay_approach","root_bay_lesson_flight","inner_hollow_HH"]
	m.route_goals.varied_original_entry_trial = "interwoven_inner"
	m.routes.varied_original_skill_trial = ["root_spiral_flight"]
	m.route_goals.varied_original_skill_trial = "root_spiral_crown"
	m.entry_contract = {"selected":"root_bay","optional_skill_route":"root_spiral","reason":"old_forest_entry_preserved; one_actual_broad_rest_splits_the_early_270wu_HH","rest_support":"varied_entry_rest_bay","continuous_HH_retained":"inner_hollow_HH","native_verified":false}
	m.scene_structure_kinds.varied_entry_hollow = "root_hollow"

static func _phrase(m: Dictionary,id: String,a: String,b: String,start: Vector2,goal: Vector2,entry: String,crown: String,anchor_id: String) -> void:
	var anchors: Array = []
	for anchor: Dictionary in m.hook_anchors:
		if str(anchor.id) == anchor_id: anchors.append({"id":"fruit","position":anchor.position.duplicate(),"hang_enabled":bool(anchor.get("hang_enabled",false))})
	var raw := {"id":id,"version":VERSION,"spawn":API.pair(start),"goal":API.pair(goal),"action_program":[{"action":"H","anchor":"fruit"}],"platforms":[],"hook_anchors":anchors,"dangers":[],"chain_contract":{"continuous_airborne":true,"midair_floor_allowed":false,"production_pool":false,"native_verified":false}}
	for key: String in ["entry","crown"]:
		var row: Dictionary = API._platform_by_id(m,entry if key == "entry" else crown)
		raw.platforms.append({"id":key,"rect":row.rect.duplicate(),"one_way":row.one_way})
	var instance := {"id":id,"factory":"res://scripts/generation/forest_entry_rest_bay.gd","geometry_version":VERSION,"local_geometry":raw,"translation":[0.0,0.0],"platform_id_map":{"entry":entry,"crown":crown},"anchor_id_map":{"fruit":anchor_id},"danger_indices":[],"native_verified":false}
	m.geometry_instances.append(instance)
	API._air_edge(m,id,a,b,instance)
	m.connections[-1].entry_support_id = entry
	m.connections[-1].native_verified = false
	m.connections[-1].first_hook_delay = 5

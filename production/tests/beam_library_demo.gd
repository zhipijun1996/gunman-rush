extends OrdinaryRoomSession

static func layout(region := "gear_city", showcase := false) -> Dictionary:
	var doc := {"schema":3,"room_id":"mechanism-foundry","bounds":[0,0,4160,768],
		"root":{"definition_id":"room.standard","definition_version":1,"properties":{"start_point":[160,494],"region_id":region,"terrain_material":region}},
		"entities":{}}
	var placements := [
		["platform.solid","floor",Vector2(0,512),{"rect":[0,512,4160,256]}],
		["assembly.windchime_bell_walkway","walkway",Vector2(360,310),{"member_offsets":{"bell":[-96,184]}}],
		["platform.rotating_beam","beam",Vector2(1040,345),{}],
		["terrain.extending","growth",Vector2(1280,360),{}],
		["hazard.falling_weight","weight",Vector2(1500,288),{"pressure_weight":true}],
		["hazard.cyclic_press","press",Vector2(1690,265),{}],
		["terrain.push_crate","crate",Vector2(1880,480),{"pressure_weight":true}],
		["assembly.windchime_flip_bridge","flip",Vector2(2260,330),{}],
		["assembly.dual_route_switch","routes",Vector2(2750,422),{}]]
	if showcase:
		doc.bounds[2] = 5280
		placements[0][3].rect[2] = 5280
		doc.actions = [{"id":"open_foundry","room_id":"mechanism-foundry","section_id":"main","grants":["foundry_open"]}]
		placements.append_array([
			["platform.rotating_beam","indexed",Vector2(3140,362),{"rotation_mode":"indexed","angles_deg":[-32,0,60,130]}],
			["platform.rotating_beam","continuous",Vector2(3380,362),{"rotation_mode":"continuous","angular_speed_deg":65}],
			["platform.rotating_beam","balance",Vector2(3630,373),{"rotation_mode":"load_tilt"}],
			["platform.rotating_beam","spiked",Vector2(3900,368),{"rotation_mode":"contact_flip","initial_pose":1}],
			["terrain.extending","rooted",Vector2(4190,490),{"growth_mode":"rooted"}],
			["assembly.one_shot_route","shortcut",Vector2(4680,480),{"action_id":"open_foundry","member_offsets":{"result":[96,-96]}}]])
	for placement: Array in placements:
		var grouped := str(placement[0]).begins_with("assembly.")
		var result := WorldElementCatalog.instantiate_definition(placement[0],placement[1],placement[2],region,placement[3] if grouped else {})
		if result.has("error"): return result
		if not grouped and not placement[3].is_empty(): result.entities[placement[1]].properties.merge(placement[3],true)
		doc.entities.merge(result.entities)
	return doc

func _ready() -> void:
	super()
	var error := open(layout())
	if not error.is_empty(): push_error(error)

extends OrdinaryRoomSession

static func layout() -> Dictionary:
	var doc := {"schema":3,"room_id":"mechanism-foundry","bounds":[0,0,4160,768],
		"root":{"definition_id":"room.standard","definition_version":1,"properties":{"start_point":[160,494],"region_id":"gear_city","terrain_material":"gear_city"}},
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
	for placement: Array in placements:
		var grouped := str(placement[0]).begins_with("assembly.")
		var result := WorldElementCatalog.instantiate_definition(placement[0],placement[1],placement[2],"gear_city",placement[3] if grouped else {})
		if result.has("error"): return result
		if not grouped and not placement[3].is_empty(): result.entities[placement[1]].properties.merge(placement[3],true)
		doc.entities.merge(result.entities)
	return doc

func _ready() -> void:
	super()
	var error := open(layout())
	if not error.is_empty(): push_error(error)

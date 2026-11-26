extends RefCounted
## Cross-instance invariants shared by placement validation and room loading.

static var world_flags: WorldContentCatalog
static var standing_body := Rect2()

static func validate_configuration(p: Dictionary,row: Dictionary,doc: Dictionary) -> String:
	if p.has("platform_size") and minf(p.platform_size[0],p.platform_size[1]) <= 0: return "platform_size:positive_required"
	match str(row.definition_id):
		"platform.moving":
			if not str(p.activation_flag).is_empty() and not known_flag(p.activation_flag,doc): return "activation_flag:unknown"
			if p.motion_mode == "call_dock" and (p.call_points.size()!=2 or p.call_radius<=0 or p.initial_dock not in [0.0,1.0,0,1]): return "call_points:invalid_terminal"
			if not p.drive_id.is_empty():
				var drive: Dictionary = doc.entities.get(p.drive_id,{})
				if drive.get("definition_id","") not in ["internal.counterweight","internal.mechanism_orbit"] or p.motion_mode != "cycle": return "drive_id:incompatible"
				if drive.properties.section_id != p.section_id or drive.properties.state_scope != p.state_scope: return "drive_id:scope_mismatch"
			if p.motion_mode == "follow_water":
				var source: Dictionary = doc.entities.get(p.water_source_id,{})
				if source.get("definition_id") != "zone.water_level": return "water_source_id:missing"
				if source.properties.section_id != p.section_id or p.state_scope != "attempt": return "water_source_id:scope_mismatch"
				if not WorldRoomValidation.rectangle(source.properties.bounds): return "water_source_id:invalid_basin"
				var basin := FixedWorldProvider.rect(source.properties.bounds)
				if p.position[0] < basin.position.x or p.position[0] > basin.end.x: return "position:outside_basin"
				var level: float = source.properties.high_surface_y if source.properties.initial_level=="high" else source.properties.low_surface_y
				var size := FixedWorldProvider.point(p.platform_size)
				var start := Rect2(Vector2(p.position[0],basin.position.y+level+p.draft_offset)-size*.5,size)
				var error := float_start_error(start,doc)
				if not error.is_empty(): return error
			elif not str(p.water_source_id).is_empty(): return "water_source_id:requires_follow_water"
			if p.motion_mode == "manual_cart":
				if minf(p.cart_max_speed,minf(p.cart_acceleration,p.cart_deceleration))<=0 or p.initial_path_progress < 0 or p.initial_path_progress>1: return "cart_motion:invalid"
			if p.motion_mode != "follow_water" and p.drive_id.is_empty():
				var points: Array = p.route if not p.route.is_empty() else [p.endpoint]
				if not valid_path(points,Vector2.ZERO): return "route:zero_length_segment"
			# A port must agree with the selected movement owner and mode.
			for source: Dictionary in doc.entities.values():
				for link: Variant in source.properties.get("links",[]):
					if not link is Dictionary or link.get("target") != row.id: continue
					if not p.drive_id.is_empty() or p.motion_mode == "follow_water": return "input:motion_owned_elsewhere"
					if link.get("input","set_active") == "call_dock" and p.motion_mode != "call_dock": return "input:requires_call_dock"
		"zone.water_level":
			if p.high_surface_y < 0 or p.low_surface_y <= p.high_surface_y or p.low_surface_y > p.bounds[3] or p.surface_speed <= 0: return "surface_levels:invalid"
		"platform.shot_rail":
			if p.stations.size()<2 or not valid_path(p.stations.slice(1),FixedWorldProvider.point(p.stations[0])): return "stations:invalid"
			if floorf(p.start_station)!=p.start_station or p.start_station<0 or p.start_station>=p.stations.size(): return "start_station:out_of_range"
			if p.move_speed<=0 or p.direction_dot_min<=0 or p.direction_dot_min>1: return "move_speed_or_direction:invalid"
		"platform.windchime_dandelion":
			if p.sink_speed<=0 or p.rise_speed<=0 or p.max_sink<=0: return "sink:positive_required"
			if not valid_path(p.route if not p.route.is_empty() else [p.endpoint],Vector2.ZERO): return "route:zero_length_segment"
		"internal.counterweight","internal.mechanism_orbit":
			var members := []
			for unit: Dictionary in doc.entities.values():
				if unit.properties.get("drive_id","") == row.id and unit.definition_id == "platform.moving": members.append(unit.id)
			if row.definition_id == "internal.counterweight":
				if p.carrier_ids.size()!=2 or p.carrier_ids[0]==p.carrier_ids[1] or not p.carrier_ids.all(func(id):return id in members): return "counterweight:invalid_carrier_ids"
				if members.size()!=2 or p.stroke[0]<=0 or p.stroke[1]<=0 or p.rest_progress<0 or p.rest_progress>1 or minf(p.return_rate,p.loaded_rate)<=0: return "counterweight:requires_two_carriers_and_positive_travel"
			else:
				if members.is_empty() or p.period<=0 or p.radius<=0 or members.size()!=p.angle_offsets_deg.size(): return "orbit:invalid_members_or_radius"
				if p.carrier_ids.size()!=members.size(): return "orbit:invalid_carrier_ids"
				var used: Array[float] = []
				for id: String in members:
					var key: Variant = p.carrier_ids.find_key(id)
					if key == null: return "orbit:unbound_carrier"
					var offset: Variant = p.angle_offsets_deg.get(key)
					if not WorldRoomValidation.number(offset): return "angle_offsets_deg:member_missing"
					var normalized := fposmod(float(offset),360.0)
					for prior in used:
						if is_equal_approx(prior,normalized): return "angle_offsets_deg:duplicate"
					used.append(normalized)
	return ""

static func valid_path(points: Array,start: Vector2) -> bool:
	var prior := start
	for pair: Variant in points:
		if not WorldRoomValidation.vector(pair): return false
		var next := FixedWorldProvider.point(pair)
		if prior.is_equal_approx(next): return false
		prior = next
	return true

static func known_flag(flag: String,doc: Dictionary) -> bool:
	for action: Variant in doc.get("actions",[]):
		if action is Dictionary and action.get("grants",[]) is Array and flag in action.get("grants",[]): return true
	if world_flags == null:
		world_flags = WorldContentCatalog.new()
		if not world_flags.load_locked().ok:
			world_flags = null
			return false
	return world_flags.lookup("flags",flag).ok

static func float_start_error(deck: Rect2, doc: Dictionary) -> String:
	if not standing_body.has_area():
		var player := (load("res://game/player/player.tscn") as PackedScene).instantiate()
		var collision := player.get_node("CollisionShape2D") as CollisionShape2D
		standing_body = collision.transform * collision.shape.get_rect()
		player.free()
	var spawn: Variant = doc.root.properties.get("start_point")
	if WorldRoomValidation.vector(spawn):
		var at_spawn := Rect2(FixedWorldProvider.point(spawn)+standing_body.position,standing_body.size)
		if deck.intersects(at_spawn): return "water_source_id:initial_player_overlaps_float"
	var headroom := Rect2(Vector2(deck.get_center().x-standing_body.size.x*.5,deck.position.y-standing_body.size.y),standing_body.size)
	for terrain: Dictionary in doc.entities.values():
		match str(terrain.component):
			"array:platforms":
				if not WorldRoomValidation.rectangle(terrain.properties.rect): continue
				var solid := FixedWorldProvider.rect(terrain.properties.rect)
				if deck.intersects(solid): return "water_source_id:initial_float_obstructed"
				if headroom.intersects(solid): return "water_source_id:initial_rider_obstructed"
			"array:terrain_polygons":
				var points: Variant = terrain.properties.get("points",[])
				if not points is Array or points.size()<3: continue
				var outline := PackedVector2Array()
				for p: Variant in points:
					if not WorldRoomValidation.vector(p): break
					outline.append(FixedWorldProvider.point(p))
				if outline.size()!=points.size(): continue
				if overlaps_polygon(deck,outline): return "water_source_id:initial_float_obstructed"
				if overlaps_polygon(headroom,outline): return "water_source_id:initial_rider_obstructed"
	return ""

static func overlaps_polygon(rect: Rect2, outline: PackedVector2Array) -> bool:
	var corners := PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	return not Geometry2D.intersect_polygons(corners,outline).is_empty()

extends RefCounted
## Cross-field and binding checks that need more than a single field's schema.
static func validate_configuration(p: Dictionary,row: Dictionary,doc: Dictionary) -> String:
	match str(row.definition_id):
		"platform.rotating_beam":
			if p.rotation_mode in ["step","indexed"]:
				if p.angles_deg.size()<2 or (p.rotation_mode=="step" and p.angles_deg.size()!=2): return "angles_deg:count"
				var unique: Array[float] = []
				for angle: Variant in p.angles_deg:
					if not WorldRoomValidation.number(angle): return "angles_deg:number_required"
					var normalized := fposmod(float(angle),360)
					for previous: float in unique:
						if is_zero_approx(angle_difference(deg_to_rad(previous),deg_to_rad(normalized))): return "angles_deg:repeated"
					unique.append(normalized)
				if p.initial_pose != floorf(p.initial_pose) or p.initial_pose<0 or p.initial_pose>=p.angles_deg.size(): return "initial_pose:outside_range"
			if p.rotation_mode == "load_tilt":
				if p.pivot_fraction<=0 or p.pivot_fraction>=1: return "pivot_fraction:interior_required"
				if absf(p.rest_angle_deg)+p.max_tilt_deg>=90: return "max_tilt_deg:outside_support_limits"
				if p.balance_half_width>=p.beam_length*minf(p.pivot_fraction,1.0-p.pivot_fraction): return "balance_half_width:outside_beam"
			if p.rotation_mode == "contact_flip" and ((p.initial_pose != 0 and p.initial_pose != 1) or not is_equal_approx(p.pivot_fraction,0.5)): return "contact_flip:central_pivot_and_binary_pose"
			if not str(p.drive_id).is_empty():
				var owner: Dictionary = doc.entities.get(p.drive_id,{})
				if owner.get("definition_id") == "platform.rotating_beam":
					if p.rotation_mode not in ["step","continuous","indexed"] or p.rotation_mode != owner.properties.rotation_mode or not str(owner.properties.drive_id).is_empty(): return "drive_id:independent_matching_beam_required"
					return validate_follower_ports(row,owner,doc)
				if owner.get("definition_id") not in ["internal.route_switch","internal.sequence_wave"] or p.rotation_mode != "step": return "drive_id:invalid_rotation_binding"
				if owner.properties.get("motion_mode","synchronized_beams") != "synchronized_beams": return "drive_id:signal_coordinator"
				var grouped: Array = owner.properties.get("members_order",[])
				for list: Array in owner.properties.get("groups",{}).values(): grouped = grouped + list
				if row.id not in grouped: return "drive_id:member_not_declared"
		"terrain.extending":
			if p.initial_length>p.max_length: return "initial_length:exceeds_max_length"
			if p.growth_mode=="rooted" and FixedWorldProvider.point(p.growth_axis).is_zero_approx(): return "growth_axis:zero"
		"hazard.falling_weight":
			if p.landing_offset[0] != 0 or p.landing_offset[1]<=0: return "landing_offset:must_be_vertically_down"
			if not landing_supported(p,doc): return "landing_offset:support_required"
		"hazard.cyclic_press":
			if p.hazard_depth > p.body_size[1]: return "hazard_depth:exceeds_body"
		"internal.route_switch","internal.sequence_wave":
			return validate_driver(p,row,doc)
	return envelope_error(p,row.definition_id,doc)

static func envelope_error(p: Dictionary,kind: String,doc: Dictionary) -> String:
	if kind not in ["terrain.extending","hazard.falling_weight","hazard.cyclic_press","platform.rotating_beam"]: return ""
	if kind == "platform.rotating_beam" and p.rotation_mode != "contact_flip": return ""
	var origin := FixedWorldProvider.point(p.position)
	var local := Rect2()
	var angles: Array[float] = [0.0]
	match kind:
		"terrain.extending":
			var rooted: bool = p.growth_mode == "rooted"
			local = Rect2(0 if rooted else -p.max_length/2,-p.thickness/2,p.max_length,p.thickness)
			if rooted: angles[0] = FixedWorldProvider.point(p.growth_axis).angle()
		"platform.rotating_beam":
			local = Rect2(-p.beam_length/2,-p.beam_thickness/2,p.beam_length,p.beam_thickness+p.hazard_depth)
			var radius := maxf(local.position.length(),local.end.length())
			var samples := maxi(1,ceili(PI*radius/2))
			for step: int in range(1,samples+1): angles.append(PI*step/samples)
		_:
			var size := FixedWorldProvider.point(p.body_size)
			var travel: float = p.stroke if kind == "hazard.cyclic_press" else p.landing_offset[1]
			local = Rect2(-size/2,size+Vector2.DOWN*travel)
	var solids: Array[PackedVector2Array] = []
	for entity: Dictionary in doc.entities.values():
		if entity.definition_id in ["platform.solid","platform.one_way"]:
			solids.append(UnderworldPolygonTerrain.rectangle_points(FixedWorldProvider.rect(entity.properties.rect)))
		elif entity.definition_id == "terrain.polygon":
			var polygon := PackedVector2Array()
			for pt: Array in entity.properties.points: polygon.append(FixedWorldProvider.point(pt))
			solids.append(polygon)
	var room_bounds := FixedWorldProvider.rect(doc.bounds) if doc.has("bounds") else Rect2()
	var corners := UnderworldPolygonTerrain.rectangle_points(local.grow(-0.01))
	for angle: float in angles:
		var occupied := Transform2D(angle,origin)*corners
		if room_bounds.has_area() and not room_bounds.encloses(UnderworldPolygonTerrain.bounds(occupied)): return "mechanism_sweep:outside_room"
		for solid: PackedVector2Array in solids:
			if not Geometry2D.intersect_polygons(occupied,solid).is_empty(): return "mechanism_sweep:fixed_terrain"
	return ""

static func validate_follower_ports(row: Dictionary,owner: Dictionary,doc: Dictionary) -> String:
	var writers := {}
	for source: Dictionary in doc.entities.values():
		for link: Dictionary in source.properties.get("links",[]):
			var target: Dictionary = doc.entities.get(link.get("target",""),{})
			if target.is_empty() or (target.id != owner.id and (target.definition_id != row.definition_id or target.properties.drive_id != owner.id)): continue
			var port: String = link.get("input","set_active")
			if (owner.properties.rotation_mode == "continuous" and port != "set_active") or (owner.properties.rotation_mode != "continuous" and port not in ["toggle","set_pose"]):
				return "follower_input_not_allowed:"+str(target.id)+":"+port
			if writers.has(port): return "multiple_drive_inputs:"+str(owner.id)+":"+port
			writers[port] = true
	return ""

static func landing_supported(p: Dictionary,doc: Dictionary) -> bool:
	var destination := FixedWorldProvider.point(p.position)+FixedWorldProvider.point(p.landing_offset)
	var half := FixedWorldProvider.point(p.body_size)/2
	var foot := destination+Vector2.DOWN*half.y
	for candidate: Dictionary in doc.entities.values():
		var props: Dictionary = candidate.properties
		var rect := Rect2()
		match str(candidate.definition_id):
			"platform.solid","platform.one_way": rect = FixedWorldProvider.rect(props.rect)
			"switch.pressure":
				var size := FixedWorldProvider.point(props.plate_size)
				rect = Rect2(FixedWorldProvider.point(props.position)-size/2,size)
			"terrain.polygon":
				var y := UnderworldPolygonTerrain.surface_below(props.points,foot-Vector2.DOWN*0.25)
				if absf(y-foot.y)<=0.5: return true
		if rect.has_area() and absf(rect.position.y-foot.y)<=0.5 and foot.x+half.x > rect.position.x and foot.x-half.x < rect.end.x: return true
	return false

static func validate_driver(p: Dictionary,row: Dictionary,doc: Dictionary) -> String:
	var is_wave: bool = row.definition_id == "internal.sequence_wave"
	var synced: bool = is_wave or p.motion_mode == "synchronized_beams"
	var ids: Array = []
	if is_wave:
		if p.members_order.is_empty(): return "members_order:required"
		ids = p.members_order.duplicate()
	else:
		if not p.groups.get("A") is Array or not p.groups.get("B") is Array or p.groups.size()!=2 or p.groups.A.is_empty() or p.groups.B.is_empty(): return "groups:two_nonempty_required"
		ids = p.groups.A + p.groups.B
	var seen := {}
	for id: Variant in ids:
		if not id is String or seen.has(id) or not doc.entities.has(id): return "members:unknown_or_repeated:"+str(id)
		seen[id] = true
		var target: Dictionary = doc.entities[id]
		if target.properties.get("section_id","main") != p.section_id or target.properties.get("state_scope","permanent") != p.state_scope: return "members:recovery_boundary:"+id
		if synced:
			if target.definition_id!="platform.rotating_beam" or target.properties.rotation_mode!="step" or target.properties.drive_id!=row.id: return "members:step_beam_binding:"+id
		else:
			if target.definition_id not in ["gate.masonry","platform.moving","platform.rotating_beam","hazard.periodic_emitter"]: return "groups:unsupported_member:"+id
			var binding: Variant = p.target_bindings.get(id,p.target_bindings.get(id.get_file(),{"input":"set_active","active":true,"inactive":false}))
			if not binding is Dictionary or not binding.has("active") or not binding.has("inactive"): return "target_bindings:missing_values:"+id
			if binding.active == binding.inactive: return "target_bindings:distinct_values:"+id
			var type: String = WorldElementCatalog.catalog().behaviors[target.component].inputs.get(binding.get("input",""),"")
			if not WorldElementCatalog.signal_value_valid(type,binding.active) or not WorldElementCatalog.signal_value_valid(type,binding.inactive): return "target_bindings:port_or_type:"+id
			if target.definition_id=="platform.rotating_beam":
				if not str(target.properties.drive_id).is_empty(): return "target_bindings:beam_already_driven"
				if binding.input=="set_pose":
					for idx: Variant in [binding.active,binding.inactive]:
						if target.properties.rotation_mode not in ["step","indexed"] or idx!=floorf(idx) or idx<0 or idx>=target.properties.angles_deg.size(): return "target_bindings:pose:"+id
				elif binding.input!="set_active" or target.properties.rotation_mode not in ["continuous","load_tilt"]: return "target_bindings:beam_mode:"+id
	for source: Dictionary in doc.entities.values():
		for link: Dictionary in source.properties.get("links",[]):
			if not seen.has(link.get("target")): continue
			var port: String = link.get("input","set_active")
			if synced and port in ["toggle","set_active","set_pose"]: return "member_motion_owned_by_driver:"+str(link.target)
			if not synced:
				var id: String = link.target
				var binding: Dictionary = p.target_bindings.get(id,p.target_bindings.get(id.get_file(),{"input":"set_active"}))
				if port == binding.input: return "member_input_owned_by_driver:"+id
	return ""

static func control_dependencies(doc: Dictionary) -> Dictionary:
	var graph := {}
	for row: Dictionary in doc.entities.values():
		var ids: Array = []
		if row.definition_id=="internal.sequence_wave": ids = row.properties.members_order
		elif row.definition_id=="internal.route_switch": ids = row.properties.groups.A+row.properties.groups.B
		for target: String in ids:
			if not graph.has(target): graph[target] = []
			graph[target].append(row.id)
	return graph

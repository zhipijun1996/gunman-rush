extends RefCounted

static func configure(definition: Dictionary,members: Array,options: Dictionary) -> String:
	var config := {}
	for key: String in definition.creation_fields:
		config[key] = definition.creation_fields[key].default
	config.merge(options,true)
	if config.state_scope != "attempt" or config.section_id.is_empty(): return "state_scope:requires_attempt_section"
	var roles := {}
	for member: Dictionary in members:
		member.properties = member.get("properties",{}).duplicate(true)
		member.properties.section_id = config.section_id
		member.properties.state_scope = config.state_scope
		roles[member.id] = member
	if config.has("member_offsets"):
		for role: Variant in config.member_offsets:
			if not roles.has(role) or (definition.id=="assembly.windchime_windmill" and role not in ["drive","bell"]) or not WorldRoomValidation.vector(config.member_offsets[role]): return "member_offsets:invalid"
			roles[role].offset = config.member_offsets[role]
	match str(definition.id):
		"assembly.bell_carrier":
			roles.bell.properties.initial_active = config.initial_running
			roles.carrier.properties.initial_running = config.initial_running
			for key: String in config:
				if key.begins_with("carrier."): roles.carrier.properties[key.trim_prefix("carrier.")] = config[key]
		"assembly.counterweight_pair":
			if config.rest_progress<0 or config.rest_progress>1 or minf(config.loaded_rate,config.return_rate)<=0: return "counterweight:invalid_rate_or_rest"
			for dict: Dictionary in [config.upper_offsets,config.stroke,config.platform_sizes]:
				if dict.size()!=2 or not dict.has("A") or not dict.has("B"): return "counterweight:requires_A_and_B"
			roles.drive.offset = config.driver_offset
			roles.drive.properties.merge({"rest_progress":config.rest_progress,"loaded_rate":config.loaded_rate,"return_rate":config.return_rate,"stroke":[config.stroke.A,config.stroke.B]}, true)
			for key: String in ["A","B"]:
				if not WorldRoomValidation.number(config.stroke[key]) or config.stroke[key]<=0: return "stroke:positive_required"
				if not WorldRoomValidation.vector(config.upper_offsets[key]) or not WorldRoomValidation.vector(config.platform_sizes[key]): return "counterweight:invalid_point"
				if minf(config.platform_sizes[key][0],config.platform_sizes[key][1])<=0: return "platform_sizes:positive_required"
				var progress: float = config.rest_progress if key=="A" else 1.0-config.rest_progress
				roles[key].offset = [config.upper_offsets[key][0],config.upper_offsets[key][1]+config.stroke[key]*progress]
				roles[key].properties.platform_size = config.platform_sizes[key]
		"assembly.windchime_windmill":
			if config.angle_offsets_deg.is_empty() or config.radius<=0 or config.period<=0: return "orbit:invalid_period_radius_or_offsets"
			roles.bell.properties.initial_active = config.initial_running
			var offsets := {}
			var carrier_ids := {}
			for i: int in config.angle_offsets_deg.size():
				var value: Variant = config.angle_offsets_deg[i]
				if not WorldRoomValidation.number(value): return "angle_offsets_deg:number_required"
				var angle := fposmod(float(value),360.0)
				for other: float in offsets.values():
					if is_equal_approx(angle,other): return "angle_offsets_deg:duplicate"
				var role := "carrier_"+str(i)
				offsets[role] = angle
				carrier_ids[role] = role
				var at := FixedWorldProvider.point(roles.drive.offset) + Vector2.from_angle(deg_to_rad(config.initial_angle_deg+angle))*float(config.radius)
				var member := {"id":role,"definition":"platform.moving","offset":[at.x,at.y],"instance_refs":{"drive_id":"drive"},
					"properties":{"section_id":config.section_id,"state_scope":config.state_scope,"platform_size":config.platform_size}}
				if roles.has(role):
					roles[role].merge(member,true)
				else: members.append(member)
			for i: int in range(members.size()-1,-1,-1):
				if str(members[i].id).begins_with("carrier_") and not offsets.has(members[i].id): members.remove_at(i)
			roles.drive.instance_refs = {"carrier_ids":carrier_ids}
			roles.drive.properties.merge({"radius":config.radius,"period":config.period,"angle_offsets_deg":offsets,"initial_angle_deg":config.initial_angle_deg,
				"initial_running":config.initial_running,"direction":config.direction},true)
	return ""

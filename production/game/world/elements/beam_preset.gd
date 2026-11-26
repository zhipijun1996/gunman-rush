extends RefCounted
## Builds the concrete editable boards and their one room-local coordinator.
static func configure(d: Dictionary,members: Array,o: Dictionary) -> String:
	var fields: Dictionary = d.creation_fields
	var options := {}
	for key: String in fields: options[key] = o.get(key,fields[key].default)
	var offsets: Dictionary = fields.member_offsets.default.duplicate(true)
	offsets.merge(options.member_offsets,true)
	var section: String = options.section_id
	if section.is_empty(): return "section_id:required"
	var shared := {"state_scope":options.state_scope,"section_id":section}
	var wave: bool = d.id == "assembly.windchime_bell_walkway"
	var route_targets: bool = d.id == "assembly.dual_route_switch"
	var groups: Dictionary = options.get("groups",{})
	var ids: Array = []
	if wave: ids = options.members_order
	else:
		if not groups.get("A") is Array or not groups.get("B") is Array or groups.size()!=2 or groups.A.is_empty() or groups.B.is_empty(): return "groups:two_nonempty_required"
		ids = groups.A + groups.B
	var seen := {}
	var driver_id := "driver" if route_targets else "drive"
	if ids.is_empty(): return "members_order:empty"
	for role: Variant in ids:
		if not role is String or role.is_empty() or "/" in role or role in ["bell",driver_id] or seen.has(role):
			return "members:invalid_or_repeated:"+str(role)
		seen[role] = true
	for role: Variant in options.member_offsets:
		if (not seen.has(role) and role not in ["bell",driver_id]) or not WorldRoomValidation.vector(options.member_offsets[role]):
			return "member_offsets:invalid:"+str(role)
	for key: String in ["deployed_angles_deg","folded_angles_deg","target_bindings"]:
		for role: Variant in options.get(key,{}):
			if role not in ids: return key+":unknown_member:"+str(role)
	var initial_route: String = options.get("initial_route","A")
	members.clear()
	var bell := shared.duplicate()
	bell.merge({"repeat_enabled":true,"initial_active":initial_route == "B","duration":0})
	var bell_entry := {"id":"bell","definition":"switch.shot","offset":offsets.bell,"properties":bell}
	if options.has("bell.access_points"):
		# C01 access points are authored absolute. The expander adds the group
		# origin, independently of the switch's own member offset.
		bell_entry["group_points"] = {"access_points":options["bell.access_points"]}
	members.append(bell_entry)
	var driver := shared.duplicate()
	var refs := {}
	if wave:
		refs.members_order = ids
		for key: String in ["warning_duration","deploy_duration","start_interval","hold_duration","retract_duration"]: driver[key] = options[key]
	else:
		refs.groups = groups
		driver.merge({"initial_route":initial_route,"warning_duration":options.warning_duration,
			"motion_mode":"targets" if route_targets else "synchronized_beams",
			"turn_duration":options.get("turn_duration",0.4),"target_bindings":options.get("target_bindings",{})})
	members.append({"id":driver_id,"definition":"internal.sequence_wave" if wave else "internal.route_switch",
		"offset":offsets[driver_id],"properties":driver,"instance_refs":refs})
	for i: int in ids.size():
		var role: String = ids[i]
		var props := shared.duplicate()
		var member := {"id":role,"definition":"platform.rotating_beam","offset":offsets.get(role,[i*160,0]),"properties":props}
		if route_targets:
			var details: Variant = options.target_bindings.get(role,{})
			if not details is Dictionary: return "target_bindings:dictionary_required:"+role
			member.definition = details.get("definition","gate.masonry")
			if member.definition not in ["gate.masonry","platform.moving","platform.rotating_beam","hazard.periodic_emitter"]: return "target_bindings:unsupported_definition:"+role
		else:
			var deployed: Variant = options.deployed_angles_deg.get(role,0.0)
			var folded: Variant = options.folded_angles_deg.get(role,90.0)
			if not WorldRoomValidation.number(deployed) or not WorldRoomValidation.number(folded) or is_zero_approx(fposmod(float(folded)-float(deployed),360.0)): return "angles_deg:distinct_required:"+role
			props.merge({"beam_length":options.beam_size[0],"beam_thickness":options.beam_size[1],
				"pivot_fraction":0.0,"angles_deg":[deployed,folded],"rotation_mode":"step",
				"initial_pose":1 if wave or role not in groups[initial_route] else 0})
			member.instance_refs = {"drive_id":driver_id}
		members.append(member)
	return ""

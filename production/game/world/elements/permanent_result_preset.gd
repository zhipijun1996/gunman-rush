extends RefCounted

static func configure(definition: Dictionary,members: Array, options: Dictionary) -> String:
	var kind: String = options.get("result_kind","open_gate")
	var offsets: Dictionary = options.get("member_offsets",{})
	for key: String in offsets:
		if key not in ["latch","action","coordinator","result"] or not WorldRoomValidation.vector(offsets[key]): return "member_offsets:invalid:"+key
	for member: Dictionary in members:
		member.offset = offsets.get(member.id, member.offset)
		var props: Dictionary = member.get("properties",{}).duplicate(true)
		props.section_id = options.get("section_id","main")
		match str(member.id):
			"action": props.action_id = options.get("action_id","")
			"coordinator": props.result_kind = kind
			"result":
				member.definition = definition.result_types[kind]
				if kind == "lower_beam":
					props.pivot_fraction = 0
					props.angles_deg = [0,-90]
					props.initial_pose = 1
		member.properties = props
	return ""

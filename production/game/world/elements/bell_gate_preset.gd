extends RefCounted

## Expand authoring choices once. The room owns the resulting real member values.
static func configure(definition: Dictionary, members: Array, options: Dictionary) -> String:
	var fields: Dictionary = definition.creation_fields
	var mode: String = options.get("mode", fields.mode.default)
	var preset: Dictionary = definition.mode_defaults[mode]
	var duration: float = options.get("bell.duration", preset.duration)
	if (mode == "timed") != (duration > 0): return "bell.duration:invalid_for_mode"
	var section: String = options.get("section_id", fields.section_id.default)
	if section.is_empty(): return "section_id:required"
	var offsets: Dictionary = options.get("member_offsets", {})
	for id: Variant in offsets:
		if id not in ["bell", "gate"] or not WorldRoomValidation.vector(offsets[id]):
			return "member_offsets:invalid:"+str(id)
	for member: Dictionary in members:
		member.offset = offsets.get(member.id, member.offset)
		member.properties = {"state_scope":preset.state_scope, "section_id":section}
		if member.id == "bell": member.properties.duration = duration
		elif options.has("gate.bounds"): member.properties.bounds = options["gate.bounds"].duplicate()
	return ""

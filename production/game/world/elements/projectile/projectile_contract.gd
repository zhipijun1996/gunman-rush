extends RefCounted
## Cross-field checks shared by the authored projectile family.
static func angles_valid(angles: Array, initial: Variant) -> bool:
	if angles.size()<2 or not WorldRoomValidation.number(initial) or initial!=int(initial) or initial<0 or initial>=angles.size(): return false
	var normalized := []
	for a: Variant in angles:
		if not WorldRoomValidation.number(a): return false
		var n := fposmod(a,360)
		for other: float in normalized:
			if is_zero_approx(angle_difference(deg_to_rad(n),deg_to_rad(other))): return false
		normalized.append(n)
	return true

static func validate_configuration(p: Dictionary,row: Dictionary,_doc: Dictionary) -> String:
	if p.has("projectile_categories"):
		var error := ProjectileField.validate_configuration(p,row,{})
		if not error.is_empty(): return error
	match str(row.definition_id):
		"zone.projectile_drag":
			if p.speed_scale<=0 or p.speed_scale>1: return "speed_scale:range"
		"zone.projectile_barrier":
			if p.line_points.size()!=2 or FixedWorldProvider.point(p.line_points[0]).is_equal_approx(FixedWorldProvider.point(p.line_points[1])): return "line_points:distinct_pair"
		"surface.projectile_mirror":
			if p.orientation_mode=="indexed":
				if not angles_valid(p.normal_angles_deg,p.initial_index): return "normal_angles_deg:distinct_angles_and_valid_index"
				if FixedWorldProvider.point(p.control_offset).length()<=p.mirror_length/2+p.control_radius+ProjectileFlight.EPS: return "control_offset:overlaps_sweep"
		"terrain.breakable":
			if not ProjectileField.valid_list(p.accepted_attacks,["shot","charged_shot","explosion","bomb"]): return "accepted_attacks:invalid"
			if p.break_mode=="local_cells":
				if p.bounds[2]*p.bounds[3]/(p.cell_size*p.cell_size)>4096: return "bounds:cell_snapshot_too_large"
				for side: float in [p.bounds[2],p.bounds[3]]:
					if not is_equal_approx(side/p.cell_size,round(side/p.cell_size)): return "bounds:cell_size_mismatch"
		"hazard.periodic_emitter":
			if FixedWorldProvider.point(p.base_direction).is_zero_approx(): return "base_direction:nonzero"
			if p.emit_mode=="stream" and p.aim_mode=="track_lock": return "aim_mode:stream_cannot_track"
			if p.aim_mode=="manual_index" and not angles_valid(p.manual_angles_deg,p.initial_aim_index): return "manual_angles_deg:distinct_angles_and_valid_index"
			var def: Dictionary = WorldElementCatalog.catalog().definitions[row.definition_id]
			if p.emit_mode=="projectile":
				var id: String = def.bindings.projectile_profile if p.projectile_profile=="inherit" else p.projectile_profile
				if not ProjectileImpact.profile(id).has("lifetime"): return "projectile_profile:unknown"
			elif WorldHazardArea.profile(def.bindings.stream_profile if p.stream_profile=="inherit" else p.stream_profile).is_empty(): return "stream_profile:unknown"
	return ""

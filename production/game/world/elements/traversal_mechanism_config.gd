extends RefCounted

static var player_radius := 0.0

static func passenger_radius() -> float:
	if player_radius > 0: return player_radius
	var scene := load("res://game/player/player.tscn") as PackedScene
	var state := scene.get_state()
	for i: int in state.get_node_count():
		if state.get_node_name(i) != &"CollisionShape2D": continue
		for j: int in state.get_node_property_count(i):
			if state.get_node_property_name(i,j) == &"shape":
				var body := state.get_node_property_value(i,j) as RectangleShape2D
				player_radius = body.size.length()*.5
				return player_radius
	return INF

static func validate_configuration(p: Dictionary, row: Dictionary, _doc: Dictionary) -> String:
	for key: String in ["face_size","portal_size","body_size"]:
		if p.has(key) and minf(p[key][0],p[key][1]) <= 0: return key+":positive_dimensions_required"
	for key: String in ["wind_acceleration","wind_speed_cap","launch_speed","sphere_radius","pulse_radius","pulse_interval_s","rise_speed","rise_distance","bubble_radius","ring_radius","pull_speed","return_speed","zipline_speed","retract_speed","retracted_length"]:
		if p.has(key) and p[key] <= 0: return key+":positive_value_required"
	for key: String in ["phase_offset","endpoint_dwell","rearm_distance","exit_clearance","respawn_delay_s","return_delay_s","retract_warning_s"]:
		if p.has(key) and p[key] < 0: return key+":nonnegative_required"
	if p.has("initial_available") and not p.initial_available and p.cooldown_s <= 0: return "initial_available:cooldown_required"
	match str(row.definition_id):
		"zone.environment":
			if p.mode == "wind" and p.wind_pattern == "directional" and FixedWorldProvider.point(p.wind_direction).is_zero_approx(): return "wind_direction:zero"
			if p.mode == "wind" and p.wind_pattern == "vortex" and p.bounds[2] != p.bounds[3]: return "bounds:vortex_requires_square"
		"traversal.rising_bubble":
			if p.bubble_radius < passenger_radius(): return "bubble_radius:passenger_does_not_fit"
		"traversal.launcher":
			if p.launch_mode == "contact" and FixedWorldProvider.point(p.launch_direction).is_zero_approx(): return "launch_direction:zero"
			if p.launch_mode == "radial_pulse" and (p.pulse_warning_s <= 0 or p.pulse_warning_s >= p.pulse_interval_s): return "pulse_warning_s:outside_period"
		"surface.motion":
			for key: String in ["walk_speed_scale","walk_acceleration_scale","brake_scale","reverse_acceleration_scale"]:
				if p[key] > 1 or p[key] < 0 or (p[key] == 0 and key != "brake_scale"): return key+":invalid_ratio"
		"traversal.portal_pair":
			if FixedWorldProvider.point(p.paired_offset).is_zero_approx(): return "paired_offset:coincident"
			if p.facings.size() != 2: return "facings:pair_required"
			for facing: Variant in p.facings:
				if facing not in ["left","right","up","down"]: return "facings:invalid_direction"
		"traversal.pull_block":
			if FixedWorldProvider.point(p.endpoint).is_zero_approx(): return "endpoint:zero"
			if p.rest_progress < 0 or p.rest_progress > 1: return "rest_progress:invalid_ratio"
			var ring := FixedWorldProvider.point(p.ring_offset)
			var half := FixedWorldProvider.point(p.body_size) / 2
			if ring.distance_to(ring.clamp(-half,half)) < p.ring_radius: return "ring_offset:inside_body"
		"traversal.moving_hook":
			var end := FixedWorldProvider.point(p.endpoint)
			if p.motion_mode == "cycle" and p.route.is_empty() and end.is_zero_approx(): return "endpoint:zero"
			if p.period < 0.051: return "period:too_short"
			if p.motion_mode != "cycle" and not p.route.is_empty(): return "route:cycle_only"
			if p.motion_mode == "zipline" and end.y <= 0: return "endpoint:lower_station_required"
			if p.motion_mode == "retract" and end.length() <= p.retracted_length: return "retracted_length:outside_travel"
			var prev := Vector2.ZERO
			for raw: Array in p.route:
				var point := FixedWorldProvider.point(raw)
				if point == prev: return "route:zero_segment"
				prev = point
	return ""

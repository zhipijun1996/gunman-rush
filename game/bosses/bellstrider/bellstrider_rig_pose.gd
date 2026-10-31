class_name BellstriderRigPose
extends RefCounted
const HULL_POINTS := [
	Vector2(-70, 10),
	Vector2(-59, -4),
	Vector2(48, -5),
	Vector2(66, 5),
	Vector2(70, 29),
	Vector2(57, 43),
	Vector2(-57, 43),
	Vector2(-70, 30)
]
## One motor-local rig for the painted machine AND the real weakpoint.
## All clocks belong to Encounter. Sampling never advances a clock or an actor.
const WHEEL_RADIUS := 21.0
const WEAK_SIZE := Vector2(30, 36)


static func sample(data: Dictionary) -> Dictionary:
	var mode: StringName = data.get("mode", &"observe")
	var phase := int(data.get("phase", 1))
	var direction := -1.0 if float(data.get("direction", 1)) < 0 else 1.0
	var age := maxf(0.0, float(data.get("state_age", 0.0)))
	var duration := maxf(0.001, float(data.get("state_duration", 1.0)))
	var fight_age := float(data.get("fight_age", 0.0))
	var travel := float(data.get("travel", 0.0))
	var speed := absf(float(data.get("speed", 0.0)))
	var warning := clampf(float(data.get("warning_progress", age / duration)), 0, 1)
	var combo := bool(data.get("combo", false))
	var ring_age := float(data.get("ring_strike_age", -1.0))
	var bell_hit_age := float(data.get("bell_hit_age", -1.0))
	var armour_hit_age := float(data.get("armour_hit_age", -1.0))
	var dead := mode == &"dead"
	var death_age := maxf(0.0, float(data.get("death_age", 0.0)))
	var death_duration := maxf(0.001, float(data.get("death_duration", 1.8)))
	var death := clampf(death_age / death_duration, 0, 1) if dead else 0.0
	var idle := sin(fight_age * 3.4) * 0.65
	var drive := minf(1.0, speed / 380.0)
	# Tyres stay on the support plane. Only the sprung load rides over them.
	var body_y := idle + sin(travel / 15.0) * drive * 1.3
	var body_angle := sin(fight_age * 1.8) * 0.004 + drive * 0.035
	var mast_angle := sin(fight_age * 2.1 - 0.5) * 0.012
	var bell_angle := sin(fight_age * 2.1 - 1.2) * 0.036
	var launcher_angle := -0.10
	var panel_angle := 0.24 if phase >= 2 else 0.0
	var clapper_angle := sin(fight_age * 2.1 - 1.5) * 0.04
	var strike := _decay(ring_age, 0.30)
	var bell_hit := _decay(bell_hit_age, 0.24)
	var armour_hit := _decay(armour_hit_age, 0.18)
	if mode in [&"roll_warning", &"combo_warning"]:
		var load := smoothstep(0.0, 0.82, warning)
		body_y = load * 7.0
		body_angle = load * (0.105 if combo else 0.075)
		mast_angle = -load * 0.10
		bell_angle = load * (0.78 if combo else 0.54)
		panel_angle += load * (0.22 if combo else 0.08)
		# A chosen return charge has a visibly different two-stage ratchet.
		if combo:
			body_y += sin(warning * PI * 4.0) * 1.4 * load
	elif mode == &"roll":
		var launch := smoothstep(0.0, 0.23, age)
		body_y = lerpf(7.0, -1.5, launch) + sin(travel / 12.0) * drive * 1.5
		body_angle = lerpf(0.075, 0.12, launch)
		mast_angle = lerpf(-0.10, -0.065, launch)
		bell_angle = lerpf(0.54 if not combo else 0.78, 0.16, launch)
		bell_angle += sin(age * 10.0) * exp(-age * 2.8) * 0.14
	elif mode in [&"combo_brake", &"combo_turn"]:
		var brake := smoothstep(0.0, 0.25, age)
		body_y = lerpf(-1.5, 6.0, brake)
		body_angle = lerpf(0.12, -0.09, brake)
		mast_angle = lerpf(-0.065, 0.17, brake)
		bell_angle = lerpf(0.16, -0.58, brake)
		panel_angle += 0.24
		if mode == &"combo_turn":
			body_y = 6.0 + sin(age / duration * PI) * 1.0
			body_angle = -0.09 * (1.0 - smoothstep(0.0, duration, age))
			mast_angle = 0.17 * (1.0 - smoothstep(0.0, duration, age))
			bell_angle = -0.58 * (1.0 - smoothstep(0.0, duration, age))
	elif mode in [&"ring_warning", &"rings"]:
		var brace := smoothstep(0.0, 0.80, warning) if mode == &"ring_warning" else 1.0
		body_y = brace * 5.0
		body_angle = -0.02 * brace
		mast_angle = 0.035 * brace
		bell_angle = -0.53 * brace
		panel_angle += brace * 0.22
		if mode == &"rings":
			# The clapper contacts on the accepted strike tick; the heavy shell
			# responds after contact rather than teleporting to its follow-through.
			bell_angle += (
				sin(maxf(0, ring_age) * 12.0) * exp(-maxf(0, ring_age) * 6.0) * 0.65
				if ring_age >= 0.0
				else 0.0
			)
			mast_angle += sin(maxf(0, ring_age) * 62.0) * strike * 0.035
			body_y += sin(maxf(0, ring_age) * 48.0) * strike * 1.5
			clapper_angle = strike * 1.0
	elif mode in [&"lob_aim", &"lob_lock", &"lob_warning", &"lob"]:
		var lift := smoothstep(0.0, 0.30, age) if mode in [&"lob_aim", &"lob_warning"] else 1.0
		body_y = lift * 4.0
		body_angle = -0.025 * lift
		mast_angle = -0.025 * lift
		bell_angle = sin(fight_age * 2.1) * 0.06
		launcher_angle = lerpf(-0.10, float(data.get("launcher_aim", -0.82)), lift)
		if mode == &"lob":
			launcher_angle += exp(-age * 10.0) * 0.32
	elif mode == &"neck":
		var recovery := clampf(float(data.get("recovery_progress", age / duration)), 0, 1)
		var brake := smoothstep(0.0, 0.20, age)
		body_y = lerpf(-1.5, 8.0, brake)
		body_angle = lerpf(0.12, 0.025, brake)
		mast_angle = lerpf(-0.065, 0.20, brake)
		bell_angle = -sin(age * 6.7) * exp(-age * 2.1) * 0.42
		bell_angle -= 0.15 * brake
		# The last 0.3s releases the loaded suspension without resetting the bell.
		var release := smoothstep(0.78, 1.0, recovery)
		body_y *= 1.0 - release
		mast_angle *= 1.0 - release
		body_angle *= 1.0 - release
		bell_angle *= 1.0 - release
	elif mode == &"phase_transition":
		var open := smoothstep(0.0, duration * 0.75, age)
		panel_angle = open * 0.35
		body_y = sin(age * 17.0) * exp(-age * 1.8) * 2.5
		bell_angle = sin(age * 8.0) * exp(-age * 1.2) * 0.15
	# Accepted local impacts are additive. Neither starts a new action clock.
	var armour_vibration := (
		Vector2(
			sin(maxf(0, armour_hit_age) * 65.0) * 1.8, sin(maxf(0, armour_hit_age) * 43.0) * 0.9
		)
		* armour_hit
	)
	# Most of the accepted impact stays in the contacted armour plate.
	body_y += armour_vibration.y * 0.3
	body_angle += armour_vibration.x * 0.002
	bell_angle += sin(maxf(0, bell_hit_age) * 34.0 + 0.5) * bell_hit * 0.23
	var face := Transform2D(Vector2(direction, 0), Vector2(0, 1), Vector2.ZERO)
	var body_local := Transform2D(body_angle, Vector2(0, body_y))
	var mast_local := body_local * Transform2D(mast_angle, Vector2(-7, -2))
	var bell_local := (
		mast_local * Transform2D(bell_angle, Vector2(0, -106)) * Transform2D(0.0, Vector2(0, 24))
	)
	var launcher_local := body_local * Transform2D(launcher_angle, Vector2(43, 4))
	var wheel_angle := travel / WHEEL_RADIUS
	var left_wheel := face * Transform2D(wheel_angle * direction, Vector2(-49, 44))
	var right_wheel := face * Transform2D(wheel_angle * direction, Vector2(49, 44))
	if dead:
		# Jam -> side settle -> mast joint tears loose -> cold static remains.
		var drop := smoothstep(0.12, 0.58, death)
		var loosen := smoothstep(0.38, 0.88, death)
		body_local = Transform2D(drop * 0.115, Vector2(-drop * 7, drop * 16))
		mast_local = body_local * Transform2D(loosen * 1.54, Vector2(-7, -2))
		bell_local = Transform2D(
			loosen * 1.14, Vector2(lerpf(-7, 44, loosen), lerpf(-84, 44, loosen))
		)
		launcher_local = (
			body_local * Transform2D(-0.10 + loosen * 0.62, Vector2(43, 4 + loosen * 13))
		)
		left_wheel = face * Transform2D(wheel_angle * direction, Vector2(-49, 44))
		right_wheel = (
			face * Transform2D(wheel_angle * direction + drop * 0.13, Vector2(49 + drop * 5, 44))
		)
		panel_angle = 0.24 + loosen * 0.6
		strike = 0.0
		bell_hit = _decay(death_age, 0.24)
		armour_hit = 0.0
		armour_vibration = Vector2.ZERO
		clapper_angle = loosen * 0.8
	var jam_age := minf(death_age, 0.28)
	var gear_angle := travel / 13.0 + fight_age * 0.8
	if dead:
		gear_angle = (
			travel / 13.0
			+ (fight_age - death_age) * 0.8
			+ 0.8 * (jam_age - jam_age * jam_age / 0.56)
		)
	var result := {
		"body_transform": face * body_local,
		"mast_transform": face * mast_local,
		"bell_transform": face * bell_local,
		"launcher_transform": face * launcher_local,
		"left_wheel": left_wheel,
		"right_wheel": right_wheel,
		"wheel_radius": WHEEL_RADIUS,
		"weak_size": WEAK_SIZE,
		"wheel_angle": wheel_angle,
		"panel_angle": panel_angle,
		"clapper_angle": clapper_angle,
		"bell_flash": bell_hit,
		"armour_flash": armour_hit,
		"armour_vibration": armour_vibration,
		"ring_pulse": strike,
		"gear_angle": gear_angle,
		"warm_light": (0.55 if phase >= 2 else 0.20) * (1.0 - smoothstep(0.5, 0.95, death)),
		"death_progress": death,
		"death_age": death_age,
		"bell_hit_age": bell_hit_age,
		"armour_hit_age": armour_hit_age,
		"mode": mode,
		"phase": phase,
		"fight_age": fight_age,
		"travel": travel,
		"speed": speed,
		"direction": direction,
		"combo": combo,
		"combo_index": int(data.get("combo_index", 0))
	}
	var previous: Dictionary = data.get("transition_from", {})
	if not previous.is_empty():
		if dead:
			_death_bridge(result, previous, face, death)
		else:
			# A bounded entry bridge comes from the exact preceding accepted pose.
			# It is geometry-only, never a recursive clock or a saved action replay.
			var bridge := smoothstep(0.0, 0.16, age)
			for key: String in [
				"body_transform", "mast_transform", "bell_transform", "launcher_transform"
			]:
				if previous.has(key):
					var start: Transform2D = previous[key]
					var target: Transform2D = result[key]
					if start.determinant() * target.determinant() < 0:
						# Change facing once, retaining the world attachment centre.
						start.x = -start.x
					result[key] = start.interpolate_with(target, bridge)
			for key: String in ["panel_angle", "clapper_angle"]:
				if previous.has(key) and not (mode == &"rings" and key == "clapper_angle"):
					result[key] = lerpf(float(previous[key]), float(result[key]), bridge)
	return result


static func _death_bridge(
	result: Dictionary, previous: Dictionary, face: Transform2D, death: float
) -> void:
	if not previous.has("body_transform"):
		return
	var inverse := face.affine_inverse()
	var initial_body: Transform2D = inverse * previous.body_transform
	var final_body := Transform2D(0.115, Vector2(-7, 16))
	var body := initial_body.interpolate_with(final_body, smoothstep(0.12, 0.58, death))
	result.body_transform = face * body
	var loosen := smoothstep(0.38, 0.88, death)
	if previous.has("mast_transform"):
		var initial_mast: Transform2D = inverse * previous.mast_transform
		var attachment := initial_body.affine_inverse() * initial_mast
		var mast := body * attachment.interpolate_with(Transform2D(1.54, Vector2(-7, -2)), loosen)
		result.mast_transform = face * mast
		if previous.has("bell_transform"):
			var initial_bell: Transform2D = inverse * previous.bell_transform
			var attached := mast * initial_mast.affine_inverse() * initial_bell
			result.bell_transform = (
				face * attached.interpolate_with(Transform2D(1.14, Vector2(44, 44)), loosen)
			)
	if previous.has("launcher_transform"):
		var initial_launcher: Transform2D = inverse * previous.launcher_transform
		var attachment := initial_body.affine_inverse() * initial_launcher
		result.launcher_transform = (
			face * body * attachment.interpolate_with(Transform2D(0.52, Vector2(43, 17)), loosen)
		)


static func _decay(age: float, seconds: float) -> float:
	return pow(1.0 - clampf(age / seconds, 0, 1), 2.0) if age >= 0.0 and age < seconds else 0.0

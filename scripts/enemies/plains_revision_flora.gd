class_name PlainsRevisionFlora
extends RefCounted
## Body-space joints for the three planted/winged plains organisms.
## The host owns every clock, accepted hit and contact. This leaf only bends
## the same neutral skin; it never draws an intent marker or moves an Actor.

static func deform(point: Vector2, uv: Vector2, size: Vector2, pose: Dictionary, kind: StringName) -> Vector2:
	if not size.is_finite() or size.x <= 0.0 or size.y <= 0.0: return point
	var p := point
	match kind:
		&"sentry": p = _sentry(point, uv, size, pose)
		&"fan_sentry": p = _fan(point, uv, size, pose)
		&"root_bell": p = _root_bell(point, uv, size, pose)
	if kind != &"fan_sentry" and bool(pose.get("dead",false)) and float(pose.get("death",0.0))<.16:
		# Lethal handoff keeps the captured loaded or hurt joints intact.
		var live := pose.duplicate()
		live["dead"] = false
		var current := deform(point,uv,size,live,kind)
		p = current.lerp(p,smoothstep(0.0,.16,float(pose.get("death",0.0))))
	# Cosmetic joints may approach the floor, but never fold pixels through it.
	# The host supplies a separate falling/contact transform for aerial deaths.
	if not bool(pose.get("air", false)) or (bool(pose.get("dead", false)) and float(pose.get("death", 0.0)) > 0.0):
		p.y = minf(p.y, 0.0)
	return p

static func _pivot(unit: Vector2, size: Vector2) -> Vector2:
	return Vector2((unit.x - 0.5) * size.x, (unit.y - 1.0) * size.y)

static func _joint(point: Vector2, unit_pivot: Vector2, size: Vector2, angle: float, weight: float) -> Vector2:
	var root := _pivot(unit_pivot, size)
	return point.lerp(root + (point - root).rotated(angle), clampf(weight, 0.0, 1.0))

static func _scale_part(point: Vector2, unit_pivot: Vector2, size: Vector2, factor: Vector2, weight: float) -> Vector2:
	var root := _pivot(unit_pivot, size)
	return point.lerp(root + (point - root) * factor, clampf(weight, 0.0, 1.0))

static func _window(start: float, end: float, value: float) -> float:
	return smoothstep(start, end, value)

static func _sentry(point: Vector2, uv: Vector2, size: Vector2, pose: Dictionary) -> Vector2:
	var upper := 1.0 - _window(0.67, 0.91, uv.y)
	var muzzle := _window(0.69, 0.81, uv.x) * (1.0 - _window(0.44, 0.56, uv.y))
	var sac := (1.0 - _window(0.48, 0.65, uv.x)) * _window(0.18, 0.34, uv.y) * (1.0 - _window(0.68, 0.84, uv.y))
	var leaves := (1.0 - _window(0.64, 0.78, uv.x)) * (1.0 - _window(0.64, 0.84, uv.y)) * (1.0 - sac * 0.85)
	var legs := _window(0.70, 0.91, uv.y)
	var front := _window(0.49, 0.70, uv.x)
	var p := point
	if bool(pose.get("dead", false)):
		var d := clampf(float(pose.get("death", 0.0)), 0.0, 1.0)
		var deflate := _window(0.00, 0.31, d)
		var muzzle_drop := _window(0.12, 0.54, d)
		var front_fold := _window(0.27, 0.59, d)
		var rear_fold := _window(0.35, 0.69, d)
		var topple := _window(0.43, 0.86, d)
		var leaf_drop := _window(0.68, 1.00, d)
		# The chamber empties before its support is lost. A substantial hollow
		# shell remains; this is not a whole sprite shrink/fade death.
		p = _scale_part(p, Vector2(0.30, 0.53), size, Vector2(1.0 - 0.19 * deflate, 1.0 - 0.23 * deflate), sac)
		p = _joint(p, Vector2(0.70, 0.34), size, 0.80 * muzzle_drop, muzzle)
		p = _joint(p, Vector2(0.60, 0.75), size, -0.91 * front_fold, legs * front)
		p = _joint(p, Vector2(0.32, 0.76), size, 0.80 * rear_fold, legs * (1.0 - front))
		p = _joint(p, Vector2(0.42, 0.86), size, 0.56 * topple, upper)
		p.y += size.y * 0.23 * topple * upper
		p = _joint(p, Vector2(0.47, 0.51), size, (0.46 if uv.x > 0.48 else -0.50) * leaf_drop, leaves)
		return p
	var clock := float(pose.get("clock", 0.0))
	var load := clampf(float(pose.get("load", 0.0)), 0.0, 1.0)
	var strike := clampf(float(pose.get("strike", 0.0)), 0.0, 1.0)
	var recovery := clampf(float(pose.get("recovery", 0.0)), 0.0, 1.0)
	var hurt := clampf(float(pose.get("hurt", 0.0)), 0.0, 1.0)
	var turn := float(pose.get("turn", 0.0))
	var breath := sin(clock * 3.1) * 0.012 * (1.0 - load)
	var inflation := 0.18 * load - 0.13 * strike - 0.13 * hurt + breath
	p = _scale_part(p, Vector2(0.30, 0.53), size, Vector2(1.0 + inflation, 1.0 + inflation * 0.65), sac)
	# The nozzle aims independently of the planted support, then retracts.
	p = _joint(p, Vector2(0.70, 0.34), size, float(pose.get("aim",0.0))*load -0.12 * load + 0.29 * strike + 0.10 * turn + 0.20 * hurt, muzzle)
	p.x -= size.x * (0.075 * strike + 0.035 * hurt) * muzzle
	p = _joint(p, Vector2(0.45, 0.81), size, -0.035 * load - 0.15 * strike + 0.04 * recovery, upper)
	p.x -= size.x * 0.035 * strike * upper
	# Broad leaves answer the chamber's release after the hard nozzle recoil.
	var leaf_spring := 0.22 * recovery * sin((1.0 - recovery) * PI * 2.0)
	p = _joint(p, Vector2(0.47, 0.51), size, (1.0 if uv.x > 0.48 else -1.0) * (-0.12 * load + 0.17 * strike + leaf_spring + 0.10 * hurt), leaves)
	return p

static func _fan(point: Vector2, uv: Vector2, size: Vector2, pose: Dictionary) -> Vector2:
	var wing_height := 1.0 - _window(0.52, 0.74, uv.y)
	var left_wing := (1.0 - _window(0.32, 0.47, uv.x)) * wing_height
	var right_wing := _window(0.53, 0.68, uv.x) * wing_height
	var body := (1.0 - _window(0.16, 0.34, absf(uv.x - 0.44))) * _window(0.35, 0.52, uv.y)
	var feet := _window(0.76, 0.94, uv.y)
	var p := point
	if bool(pose.get("dead", false)):
		var d := clampf(float(pose.get("death", 0.0)), 0.0, 1.0)
		var left_drop := maxf(_window(0.00, 0.37, d), 0.82 * _window(0.00, 0.18, d))
		var right_drop := maxf(_window(0.21, 0.69, d), 0.58 * _window(0.01, 0.22, d))
		var roll := maxf(_window(0.31, 0.80, d), 0.55 * _window(0.00, 0.16, d))
		var sprawl := _window(0.66, 1.00, d)
		# The second wing has one bounded failed correction. It cannot keep
		# flapping after the body has settled, even if the world clock advances.
		var failed_beat := sin(_window(0.20, 0.58, d) * TAU) * 0.21 * (1.0 - _window(0.55, 0.72, d))
		p = _joint(p, Vector2(0.45, 0.43), size, -0.94 * left_drop, left_wing)
		p = _joint(p, Vector2(0.59, 0.43), size, 0.70 * right_drop + failed_beat, right_wing)
		p = _joint(p, Vector2(0.44, 0.77), size, 0.56 * roll, body)
		p.y += size.y * 0.17 * roll * body
		p.x += size.x * 0.10 * roll * body
		p = _joint(p, Vector2(0.56, 0.79), size, -0.75 * roll, feet)
		# Final loose wing spread is wider than the side-lying abdomen. The
		# two fans retain their own hinges instead of collapsing as one slab.
		p.x += size.x * 0.07 * sprawl * (right_wing - left_wing)
		p.y += size.y * 0.075 * sprawl * maxf(left_wing, right_wing)
		# Once grounded collapse is complete, return before reading a running
		# clock: the settled fan is exactly static on every following draw.
		if d >= 1.0: return p
		var death_age := maxf(0.0, float(pose.get("death_clock", 0.0)))
		var captured := pose.duplicate()
		captured["dead"] = false
		var live := _fan(point, uv, size, captured)
		# The lethal handoff starts at the exact captured load/hurt/wing pose.
		# Airborne loss uses the corpse owner's advancing age, never the frozen
		# live locomotion clock, and remains present through first contact.
		var air_loss := _window(0.00, 0.19, death_age)
		var late_wing := _window(0.07, 0.31, death_age)
		var air_roll := _window(0.06, 0.38, death_age)
		var weak_beat := sin(death_age * TAU * 7.0) * exp(-death_age * 4.5) * _window(0.02, 0.07, death_age) * 0.20
		var falling := _joint(live, Vector2(0.45, 0.43), size, -0.80 * air_loss, left_wing)
		falling = _joint(falling, Vector2(0.59, 0.43), size, 0.50 * late_wing + weak_beat, right_wing)
		falling = _joint(falling, Vector2(0.44, 0.77), size, 0.31 * air_roll, body)
		falling.y += size.y * 0.055 * air_roll * body
		falling.x += size.x * 0.035 * air_roll * body
		falling = _joint(falling, Vector2(0.56, 0.79), size, -0.40 * air_roll, feet)
		# death is contact-relative, so the same airborne pose is used at d=0
		# on either side of landing. A short contact blend then carries it into
		# the folded ground pose without resetting to the captured live fan.
		return falling.lerp(p, _window(0.00, 0.20, d))
	var clock := float(pose.get("clock", 0.0))
	var load := clampf(float(pose.get("load", 0.0)), 0.0, 1.0)
	var strike := clampf(float(pose.get("strike", 0.0)), 0.0, 1.0)
	var recovery := clampf(float(pose.get("recovery", 0.0)), 0.0, 1.0)
	var hurt := clampf(float(pose.get("hurt", 0.0)), 0.0, 1.0)
	var flight_beat := sin(clock * 12.5) * 0.11 * (1.0 - 0.90 * load)
	var fan_open := 0.37 * load + 0.14 * strike - 0.12 * recovery
	p = _joint(p, Vector2(0.45, 0.43), size, -fan_open - flight_beat + 0.10 * hurt, left_wing)
	p = _joint(p, Vector2(0.59, 0.43), size, fan_open + flight_beat - 0.07 * hurt, right_wing)
	# Expansion is horizontal and symmetric. Shooting gives the central mass
	# a short backward pitch while both wing roots visibly brace it.
	p.x += size.x * 0.055 * load * (right_wing - left_wing)
	p = _joint(p, Vector2(0.44, 0.74), size, -0.19 * strike + 0.05 * recovery, body)
	p = _scale_part(p, Vector2(0.42, 0.69), size, Vector2(1.0 - 0.10 * hurt, 1.0 - 0.07 * hurt), body)
	p.x -= size.x * 0.04 * strike * body
	p = _joint(p, Vector2(0.56, 0.79), size, 0.10 * strike + sin(clock * 5.0) * 0.035 * (1.0 - load), feet)
	return p

static func _root_bell(point: Vector2, uv: Vector2, size: Vector2, pose: Dictionary) -> Vector2:
	var main_stem := 1.0 - _window(0.80, 0.97, uv.y)
	var upper_stem := 1.0 - _window(0.45, 0.72, uv.y)
	var bell := _window(0.60, 0.71, uv.x) * (1.0 - _window(0.46, 0.61, uv.y))
	var leaf := _window(0.16, 0.34, absf(uv.x - 0.5)) * (1.0 - _window(0.66, 0.88, uv.y))
	var p := point
	if bool(pose.get("dead", false)):
		var d := clampf(float(pose.get("death", 0.0)), 0.0, 1.0)
		var lower_fold := _window(0.03, 0.43, d)
		var upper_fold := _window(0.20, 0.66, d)
		var bell_drop := _window(0.41, 0.83, d)
		var leaf_wilt := _window(0.67, 1.00, d)
		var ring_settle := _window(0.75, 1.00, d)
		# Three connected stem segments yield in order. Their root weights are
		# exactly zero at the foot, so the root does not slide during collapse.
		p = _joint(p, Vector2(0.50, 0.94), size, 0.38 * lower_fold, main_stem)
		p = _joint(p, Vector2(0.50, 0.68), size, 0.46 * upper_fold, upper_stem)
		p = _joint(p, Vector2(0.70, 0.20), size, 0.51 * bell_drop, bell)
		p.y += size.y * 0.17 * bell_drop * upper_stem
		# One damped contact swing, expressed in progress rather than a clock;
		# death=1 is bit-for-bit static on all subsequent draws.
		var swing := sin(ring_settle * TAU * 1.25) * (1.0 - ring_settle) * 0.16
		p = _joint(p, Vector2(0.70, 0.20), size, swing, bell)
		p = _joint(p, Vector2(0.50, 0.58), size, (-0.54 if uv.x < 0.5 else 0.63) * leaf_wilt, leaf)
		return p
	var clock := float(pose.get("clock", 0.0))
	var load := clampf(float(pose.get("load", 0.0)), 0.0, 1.0)
	var strike := clampf(float(pose.get("strike", 0.0)), 0.0, 1.0)
	var recovery := clampf(float(pose.get("recovery", 0.0)), 0.0, 1.0)
	var hurt := clampf(float(pose.get("hurt", 0.0)), 0.0, 1.0)
	var breath := sin(clock * 2.6) * 0.018
	var hurt_rebound := sin((1.0 - hurt) * PI * 1.5) * hurt * 0.17
	# Load bends the stalk rearward and lifts the heavy bell; release brings
	# both connected upper segments down into the accepted pulse event.
	p = _joint(p, Vector2(0.50, 0.94), size, breath - 0.19 * load + 0.25 * strike + hurt_rebound, main_stem)
	p = _joint(p, Vector2(0.50, 0.68), size, -0.10 * load + 0.19 * strike + 0.05 * recovery + hurt_rebound * 0.6, upper_stem)
	p = _joint(p, Vector2(0.70, 0.20), size, -0.17 * load + 0.39 * strike - 0.07 * recovery + 0.13 * hurt, bell)
	p.y -= size.y * 0.035 * load * bell
	var leaf_lag := sin((1.0 - recovery) * PI * 2.0) * recovery * 0.09
	p = _joint(p, Vector2(0.50, 0.58), size, (1.0 if uv.x > 0.5 else -1.0) * (0.09 * load - 0.15 * strike + leaf_lag + breath), leaf)
	return p

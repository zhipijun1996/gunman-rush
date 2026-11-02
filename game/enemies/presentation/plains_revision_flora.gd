class_name PlainsRevisionFlora
extends RefCounted
## Body-space joints for the three planted/winged plains organisms.
## The host owns every clock, accepted hit and contact. This leaf only bends
## the same neutral skin; it never draws an intent marker or moves an Actor.

# One draw-local prepared pose owns this lazy death geometry. Only size/pose
# expressions live here; UV/weight selection and point operations stay below.
class Geometry extends RefCounted:
	var size: Vector2
	var kind: StringName
	var death: float
	var death_clock: float
	var center: Vector2
	var parent_angle: float
	var body_target: Vector2
	var sac_scale: Vector2
	var nozzle_hinge: Vector2
	var nozzle_angle: float
	var leaf_hinge: Vector2
	var upper_leaf_hinge: Vector2
	var rear_leaf_hinge: Vector2
	var leaf_angle: float
	var upper_leaf_angle: float
	var rear_leaf_angle: float
	var front_hip: Vector2
	var rear_hip: Vector2
	var moved_front_hip: Vector2
	var moved_rear_hip: Vector2
	var front_leg_angle: float
	var rear_leg_angle: float
	var left_root: Vector2
	var right_root: Vector2
	var body_root: Vector2
	var feet_root: Vector2
	var left_angle: float
	var right_angle: float
	var body_angle: float
	var feet_angle: float
	var body_y: float
	var body_x: float
	var sprawl_x: float
	var sprawl_y: float
	var falling_left_angle: float
	var falling_right_angle: float
	var falling_body_angle: float
	var falling_feet_angle: float
	var falling_body_y: float
	var falling_body_x: float
	var contact_blend: float

static func _death_geometry(size: Vector2, pose: PlainsRevisionPose, kind: StringName) -> Geometry:
	var geometry := pose.flora_death_geometry as Geometry
	# Only the unfinished fan reads the corpse clock; neither leaf reads air.
	var death_clock := pose.death_clock if kind == &"fan_sentry" and not (pose.death >= 1.0) else 0.0
	if geometry != null and geometry.size == size and geometry.kind == kind and geometry.death == pose.death and geometry.death_clock == death_clock:
		return geometry
	geometry = Geometry.new()
	geometry.size = size
	geometry.kind = kind
	geometry.death = pose.death
	geometry.death_clock = death_clock
	var d := pose.death
	if kind == &"sentry":
		var deflate := _window(0.00, 0.32, d)
		var topple := _window(0.28, 0.78, d)
		var leaf_drop := _window(0.65, 1.00, d)
		var center := _pivot(Vector2(0.30, 0.53), size)
		var parent_angle := 0.70 * topple
		var body_target := center + Vector2(size.x * 0.06, size.y * 0.28) * topple
		geometry.center = center
		geometry.parent_angle = parent_angle
		geometry.body_target = body_target
		geometry.sac_scale = Vector2(1.0 - 0.12 * deflate, 1.0 - 0.36 * deflate)
		geometry.nozzle_hinge = body_target + (_pivot(Vector2(0.70, 0.34),size)-center).rotated(parent_angle)
		geometry.nozzle_angle = -0.76 * _window(0.13,0.78,d)
		geometry.leaf_hinge = body_target + (_pivot(Vector2(0.47,0.31),size)-center).rotated(parent_angle)
		geometry.upper_leaf_hinge = body_target + (_pivot(Vector2(0.43,0.23),size)-center).rotated(parent_angle)
		geometry.rear_leaf_hinge = body_target + (_pivot(Vector2(0.42,0.32),size)-center).rotated(parent_angle)
		geometry.leaf_angle = -1.48*leaf_drop
		geometry.upper_leaf_angle = -1.58*leaf_drop
		geometry.rear_leaf_angle = -1.22*leaf_drop
		geometry.front_hip = _pivot(Vector2(0.61,0.74),size)
		geometry.rear_hip = _pivot(Vector2(0.34,0.75),size)
		geometry.moved_front_hip = body_target+(geometry.front_hip-center).rotated(parent_angle)
		geometry.moved_rear_hip = body_target+(geometry.rear_hip-center).rotated(parent_angle)
		geometry.front_leg_angle = -1.12*_window(0.25,0.68,d)
		geometry.rear_leg_angle = 1.18*_window(0.34,0.76,d)
	else:
		var left_drop := maxf(_window(0.00, 0.37, d), 0.82 * _window(0.00, 0.18, d))
		var right_drop := maxf(_window(0.21, 0.69, d), 0.58 * _window(0.01, 0.22, d))
		var roll := maxf(_window(0.31, 0.80, d), 0.55 * _window(0.00, 0.16, d))
		var sprawl := _window(0.66, 1.00, d)
		var failed_beat := sin(_window(0.20, 0.58, d) * TAU) * 0.21 * (1.0 - _window(0.55, 0.72, d))
		geometry.left_root = _pivot(Vector2(0.45, 0.43), size)
		geometry.right_root = _pivot(Vector2(0.59, 0.43), size)
		geometry.body_root = _pivot(Vector2(0.44, 0.77), size)
		geometry.feet_root = _pivot(Vector2(0.56, 0.79), size)
		geometry.left_angle = -0.94 * left_drop
		geometry.right_angle = 0.70 * right_drop + failed_beat
		geometry.body_angle = 0.56 * roll
		geometry.feet_angle = -0.75 * roll
		geometry.body_y = size.y * 0.17 * roll
		geometry.body_x = size.x * 0.10 * roll
		geometry.sprawl_x = size.x * 0.07 * sprawl
		geometry.sprawl_y = size.y * 0.075 * sprawl
		if not (d >= 1.0):
			var death_age := maxf(0.0, pose.death_clock)
			var air_loss := _window(0.00, 0.19, death_age)
			var late_wing := _window(0.07, 0.31, death_age)
			var air_roll := _window(0.06, 0.38, death_age)
			var weak_beat := sin(death_age * TAU * 7.0) * exp(-death_age * 4.5) * _window(0.02, 0.07, death_age) * 0.20
			geometry.falling_left_angle = -0.80 * air_loss
			geometry.falling_right_angle = 0.50 * late_wing + weak_beat
			geometry.falling_body_angle = 0.31 * air_roll
			geometry.falling_feet_angle = -0.40 * air_roll
			geometry.falling_body_y = size.y * 0.055 * air_roll
			geometry.falling_body_x = size.x * 0.035 * air_roll
			geometry.contact_blend = _window(0.00, 0.20, d)
	pose.flora_death_geometry = geometry
	return geometry

static func deform(point: Vector2, uv: Vector2, size: Vector2, pose: Dictionary, kind: StringName) -> Vector2:
	return deform_prepared(point, uv, size, PlainsRevisionPose.prepare(pose), kind, PlainsRevisionWeights.new(uv, kind))

static func deform_prepared(point: Vector2, uv: Vector2, size: Vector2, pose: PlainsRevisionPose, kind: StringName, weights: PlainsRevisionWeights) -> Vector2:
	if not size.is_finite() or size.x <= 0.0 or size.y <= 0.0: return point
	var p := point
	match kind:
		&"sentry": p = _sentry(point, uv, size, pose, weights)
		&"fan_sentry": p = _fan(point, uv, size, pose, weights)
		&"root_bell": p = _root_bell(point, uv, size, pose, weights)
	if kind != &"fan_sentry" and pose.dead and pose.raw_death<.16:
		# Lethal handoff keeps the captured loaded or hurt joints intact.
		var live := pose.live
		var current := deform_prepared(point,uv,size,live,kind,weights)
		p = current.lerp(p,smoothstep(0.0,.16,pose.raw_death))
	# Cosmetic joints may approach the floor, but never fold pixels through it.
	# The host supplies a separate falling/contact transform for aerial deaths.
	if not pose.air or (pose.dead and pose.raw_death > 0.0):
		p.y = minf(p.y, 0.0)
	return p

static func _pivot(unit: Vector2, size: Vector2) -> Vector2:
	return Vector2((unit.x - 0.5) * size.x, (unit.y - 1.0) * size.y)

static func _joint(point: Vector2, unit_pivot: Vector2, size: Vector2, angle: float, weight: float) -> Vector2:
	var root := _pivot(unit_pivot, size)
	return _joint_at(point,root,angle,weight)

static func _joint_at(point: Vector2, root: Vector2, angle: float, weight: float) -> Vector2:
	return point.lerp(root + (point - root).rotated(angle), clampf(weight, 0.0, 1.0))

static func _scale_part(point: Vector2, unit_pivot: Vector2, size: Vector2, factor: Vector2, weight: float) -> Vector2:
	var root := _pivot(unit_pivot, size)
	return point.lerp(root + (point - root) * factor, clampf(weight, 0.0, 1.0))

static func _window(start: float, end: float, value: float) -> float:
	return smoothstep(start, end, value)

static func _sentry(point: Vector2, uv: Vector2, size: Vector2, pose: PlainsRevisionPose, weights: PlainsRevisionWeights) -> Vector2:
	var upper := weights.upper
	var muzzle := weights.muzzle
	var sac := weights.sac
	var leaves := weights.leaves
	var legs := weights.legs
	var front := weights.front
	var p := point
	if pose.dead:
		var geometry := _death_geometry(size, pose, &"sentry")
		var center := geometry.center
		var parent_angle := geometry.parent_angle
		var body_target := geometry.body_target
		# The sac carries its nozzle and leaves. Their hinges are transformed
		# with this parent, rather than rotating about abandoned upright pivots.
		var emptied := point.lerp(center + (point - center) * geometry.sac_scale, clampf(sac, 0.0, 1.0))
		var carried := body_target + (emptied - center).rotated(parent_angle)
		var nozzle_hinge := geometry.nozzle_hinge
		var nozzle := nozzle_hinge + (carried-nozzle_hinge).rotated(geometry.nozzle_angle)
		carried = carried.lerp(nozzle,muzzle)
		# Upper, rear and front leaves have separate attachments. Late droop
		# lays their tips beside the emptied chamber instead of making a pole.
		var leaf_hinge := geometry.leaf_hinge
		var leaf_angle := geometry.leaf_angle
		if uv.y < 0.23:
			leaf_hinge = geometry.upper_leaf_hinge
			leaf_angle = geometry.upper_leaf_angle
		elif uv.x < 0.39:
			leaf_hinge = geometry.rear_leaf_hinge
			leaf_angle = geometry.rear_leaf_angle
		carried = carried.lerp(leaf_hinge+(carried-leaf_hinge).rotated(leaf_angle),leaves)
		# Folding legs stop supporting the parent mass. Their hips travel with
		# the chamber; feet release outward instead of remaining planted props.
		var hip := geometry.front_hip if front>0.5 else geometry.rear_hip
		var moved_hip := geometry.moved_front_hip if front>0.5 else geometry.moved_rear_hip
		var leg_angle := geometry.front_leg_angle if front>0.5 else geometry.rear_leg_angle
		var folded_leg := moved_hip+(point-hip).rotated(leg_angle)
		return carried.lerp(folded_leg,legs)

	var load := pose.load
	var strike := pose.strike
	var recovery := pose.recovery
	var hurt := pose.hurt
	var turn := pose.raw_turn
	var quiet := pose.flora_quiet
	var drive := pose.drive
	var breath := pose.sentry_breath_sin * 0.026 * (1.0 - load)
	var inflation := 0.18 * load - 0.13 * strike - 0.13 * hurt + breath
	if sac != 0.0:
		p = _scale_part(p, Vector2(0.30, 0.53), size, Vector2(1.0 + inflation, 1.0 + inflation * 0.65), sac)
	# The nozzle aims independently of the planted support, then retracts.
	if muzzle != 0.0:
		p = _joint(p, Vector2(0.70, 0.34), size, pose.aim*load -0.12 * load + 0.29 * strike + 0.10 * turn + 0.20 * hurt +.028*pose.sentry_muzzle_sin*quiet-.035*drive, muzzle)
	p.x -= size.x * (0.075 * strike + 0.035 * hurt) * muzzle
	var chamber_angle := -0.035*load-0.15*strike+0.04*recovery+.021*pose.sentry_body_sin*quiet-.043*drive
	if upper != 0.0:
		p = _joint(p, Vector2(0.45, 0.81), size, chamber_angle, upper)
	p.x -= size.x * 0.035 * strike * upper
	# Broad leaves answer the chamber's release after the hard nozzle recoil.
	var leaf_spring := 0.22 * recovery * pose.recovery_return_sin
	var leaf_root := _joint(_pivot(Vector2(.47,.51),size),Vector2(.45,.81),size,chamber_angle,1.0)
	leaf_root.x -= size.x*.035*strike
	var leaf_idle := .060*pose.sentry_leaf_sin*quiet+.035*drive
	if leaves != 0.0:
		p = _joint_at(p,leaf_root,(1.0 if uv.x > 0.48 else -1.0)*(-.12*load+.17*strike+leaf_spring+.10*hurt+leaf_idle),leaves)
	# The leg tops answer the chamber's weight shift; toes retain their root.
	var knee := weights.sentry_knee
	p.x += size.x*.012*pose.sentry_body_sin*quiet*(front*2.0-1.0)*knee
	return p

static func _fan(point: Vector2, uv: Vector2, size: Vector2, pose: PlainsRevisionPose, weights: PlainsRevisionWeights) -> Vector2:
	var wing_height := weights.wing_height
	var left_wing := weights.left_wing
	var right_wing := weights.right_wing
	var body := weights.body
	var feet := weights.feet
	var p := point
	if pose.dead:
		var d := pose.death
		var geometry := _death_geometry(size, pose, &"fan_sentry")
		# The second wing has one bounded failed correction. It cannot keep
		# flapping after the body has settled, even if the world clock advances.
		if left_wing != 0.0:
			p = _joint_at(p, geometry.left_root, geometry.left_angle, left_wing)
		if right_wing != 0.0:
			p = _joint_at(p, geometry.right_root, geometry.right_angle, right_wing)
		if body != 0.0:
			p = _joint_at(p, geometry.body_root, geometry.body_angle, body)
		p.y += geometry.body_y * body
		p.x += geometry.body_x * body
		if feet != 0.0:
			p = _joint_at(p, geometry.feet_root, geometry.feet_angle, feet)
		# Final loose wing spread is wider than the side-lying abdomen. The
		# two fans retain their own hinges instead of collapsing as one slab.
		p.x += geometry.sprawl_x * (right_wing - left_wing)
		p.y += geometry.sprawl_y * maxf(left_wing, right_wing)
		# Once grounded collapse is complete, return before reading a running
		# clock: the settled fan is exactly static on every following draw.
		if d >= 1.0: return p
		var captured := pose.live
		var live := _fan(point, uv, size, captured, weights)
		# The lethal handoff starts at the exact captured load/hurt/wing pose.
		# Airborne loss uses the corpse owner's advancing age, never the frozen
		# live locomotion clock, and remains present through first contact.
		var falling := _joint_at(live, geometry.left_root, geometry.falling_left_angle, left_wing)
		if right_wing != 0.0:
			falling = _joint_at(falling, geometry.right_root, geometry.falling_right_angle, right_wing)
		if body != 0.0:
			falling = _joint_at(falling, geometry.body_root, geometry.falling_body_angle, body)
		falling.y += geometry.falling_body_y * body
		falling.x += geometry.falling_body_x * body
		if feet != 0.0:
			falling = _joint_at(falling, geometry.feet_root, geometry.falling_feet_angle, feet)
		# death is contact-relative, so the same airborne pose is used at d=0
		# on either side of landing. A short contact blend then carries it into
		# the folded ground pose without resetting to the captured live fan.
		return falling.lerp(p, geometry.contact_blend)

	var load := pose.load
	var strike := pose.strike
	var recovery := pose.recovery
	var hurt := pose.hurt
	var drive := pose.drive
	var flight_beat := pose.fan_wing_sin * 0.14 * (1.0 - 0.90 * load)
	var fan_open := 0.37 * load + 0.14 * strike - 0.12 * recovery
	if left_wing != 0.0:
		p = _joint(p, Vector2(0.45, 0.43), size, -fan_open - flight_beat + 0.10 * hurt, left_wing)
	if right_wing != 0.0:
		p = _joint(p, Vector2(0.59, 0.43), size, fan_open + flight_beat - 0.07 * hurt, right_wing)
	# Expansion is horizontal and symmetric. Shooting gives the central mass
	# a short backward pitch while both wing roots visibly brace it.
	p.x += size.x * 0.055 * load * (right_wing - left_wing)
	var carried_lift := pose.fan_body_sin*(1.0-.85*load)
	# Wing roots answer first; the copper mass follows the downstroke and the
	# feet trail a little later. Neither uses an independent whole-image bob.
	p.y -= size.y*.019*carried_lift*maxf(body,wing_height*.52)
	if body != 0.0:
		p = _joint(p, Vector2(0.44, 0.74), size, -0.19 * strike + 0.05 * recovery+.025*pose.fan_pitch_sin*(1.0-load)-.055*drive, body)
	if body != 0.0:
		p = _scale_part(p, Vector2(0.42, 0.69), size, Vector2(1.0 - 0.10 * hurt, 1.0 - 0.07 * hurt), body)
	p.x -= size.x * 0.04 * strike * body
	if feet != 0.0:
		p = _joint(p, Vector2(0.56, 0.79), size, 0.10 * strike + pose.fan_feet_sin * 0.065 * (1.0 - load)-.065*drive, feet)
	return p

static func _root_bell(point: Vector2, uv: Vector2, size: Vector2, pose: PlainsRevisionPose, weights: PlainsRevisionWeights) -> Vector2:
	_prepare_root_geometry(size, pose)
	var main_stem := weights.main_stem
	var upper_stem := weights.upper_stem
	var bell := weights.bell
	var leaf := weights.leaf
	var p := point
	if pose.dead:
		var droop := pose.root_droop
		var crown := pose.root_crown
		var destination := pose.root_destination
		var stem := _carry_stem(point,uv.y,pose)
		# The lower root remains fixed; both stem bones deliver their real
		# moving endpoint to the crown. Nothing rotates about the old arch.
		var lower_angle := pose.root_lower_angle
		var upper_angle := pose.root_upper_angle
		var crown_angle := pose.root_crown_angle
		var crown_body := destination+(point-crown).rotated(crown_angle)
		var upper_weight := weights.upper_weight
		p = stem.lerp(crown_body,upper_weight)
		# Bell orientation remains hanging under gravity while its hanger is
		# transported down. Its actual clapper/rim reaches the floor at d=.72.
		var hanger := pose.root_hanger
		var moved_hanger := pose.root_moved_hanger
		var swing := pose.root_swing
		var bell_pose := moved_hanger+(point-hanger).rotated(swing)
		# Include the copper mouth and clapper down to their actual alpha rim.
		# The live crown mask fades at y=.46 and cannot carry these lower pixels.
		var dead_bell := weights.dead_bell
		p = p.lerp(bell_pose,dead_bell)
		# Leaf attachments follow the appropriate stem segment, then their
		# blades yield independently. They no longer hold a raised canopy.
		var hinge_uv := Vector2(0.43,0.40) if uv.y<0.47 else Vector2(0.46,0.62)
		if uv.y<0.17: hinge_uv=Vector2(0.62,0.17)
		var top_left := weights.top_left
		var top_right := weights.top_right
		if top_left>0.3: hinge_uv=Vector2(0.43,0.34)
		elif top_right>0.3: hinge_uv=Vector2(0.62,0.17)
		var hinge := _pivot(hinge_uv,size)
		var moved_hinge := _carry_stem(hinge,hinge_uv.y,pose)
		if hinge_uv.y<0.32: moved_hinge=destination+(hinge-crown).rotated(crown_angle)
		var attached_angle := upper_angle if hinge_uv.y<0.55 else lower_angle
		var leaf_angle := (-0.98 if uv.x<0.46 else 0.80)*droop
		if top_left>0.3: leaf_angle=-2.1*droop
		elif top_right>0.3: leaf_angle=1.2*droop
		var leaf_pose := moved_hinge+(point-hinge).rotated(attached_angle*(1.0-droop)+leaf_angle)
		var leaf_mask := maxf(leaf,maxf(top_left,top_right))*(1.0-dead_bell)
		return p.lerp(leaf_pose,leaf_mask)

	p = _joint_at(p, pose.root_base, pose.root_lower_angle, main_stem)
	p = _joint_at(p,pose.root_elbow,pose.root_upper_angle,upper_stem)
	# Child hinges are transported by the two flexible stem segments. Bell and
	# leaf motion are then delayed about those actual carried attachments.
	p = _joint_at(p,pose.root_moved_hanger,pose.root_bell_angle,bell)
	p.y -= size.y * 0.035 * pose.load * bell
	p = _joint_at(p,pose.root_moved_leaf,(1.0 if uv.x>.5 else -1.0)*pose.root_leaf_angle,leaf)
	return p

# Same expressions and Vector2 operations as the former per-vertex calculation.
# Only size/pose terms move here; point/UV/weights remain in the single consumer.
static func _prepare_root_geometry(size: Vector2, pose: PlainsRevisionPose) -> void:
	if pose.root_geometry_ready and pose.root_geometry_size == size: return
	if pose.dead:
		var d := pose.death
		var fold := _window(0.03,0.72,d)
		var droop := _window(0.58,1.00,d)
		var root := _pivot(Vector2(0.43,0.90),size)
		var elbow := _pivot(Vector2(0.43,0.55),size)
		var crown := _pivot(Vector2(0.61,0.17),size)
		var destination := crown.lerp(_pivot(Vector2(0.55,0.58),size),fold)
		var bent := _fold_elbow(root,elbow,crown,destination)
		var lower_angle := (bent-root).angle()-(elbow-root).angle()
		var upper_angle := (destination-bent).angle()-(crown-elbow).angle()
		var crown_angle := upper_angle*(1.0-fold)
		var hanger := _pivot(Vector2(0.72,0.20),size)
		var moved_hanger := destination+(hanger-crown).rotated(crown_angle)
		var swing_progress := _window(0.72,1.00,d)
		var swing := sin(swing_progress*TAU*1.25)*(1.0-swing_progress)*0.11
		pose.root_base = root
		pose.root_elbow = elbow
		pose.root_crown = crown
		pose.root_destination = destination
		pose.root_bent = bent
		pose.root_lower_angle = lower_angle
		pose.root_upper_angle = upper_angle
		pose.root_crown_angle = crown_angle
		pose.root_droop = droop
		pose.root_hanger = hanger
		pose.root_moved_hanger = moved_hanger
		pose.root_swing = swing
	else:
		var load := pose.load
		var strike := pose.strike
		var recovery := pose.recovery
		var hurt := pose.hurt
		var breath := pose.root_stem_sin * 0.018
		var hurt_rebound := pose.root_hurt_sin * hurt * 0.17
		var quiet := pose.flora_quiet
		var live_lower_angle := breath*quiet-.19*load+.25*strike+hurt_rebound
		var live_upper_angle := .015*pose.root_upper_sin*quiet-.10*load+.19*strike+.05*recovery+hurt_rebound*.6
		var moved_elbow := _joint(_pivot(Vector2(.50,.68),size),Vector2(.50,.94),size,live_lower_angle,1.0)
		var live_hanger := _joint(_pivot(Vector2(.70,.20),size),Vector2(.50,.94),size,live_lower_angle,1.0)
		live_hanger = _joint_at(live_hanger,moved_elbow,live_upper_angle,1.0)
		var bell_lag := (.044*pose.root_bell_sin-breath*.5)*quiet
		var leaf_lag := pose.recovery_return_sin * recovery * 0.09
		var moved_leaf := _joint(_pivot(Vector2(.50,.58),size),Vector2(.50,.94),size,live_lower_angle,1.0)
		moved_leaf = _joint_at(moved_leaf,moved_elbow,live_upper_angle,1.0-_window(.45,.72,.58))
		pose.root_base = _pivot(Vector2(0.50, 0.94), size)
		pose.root_lower_angle = live_lower_angle
		pose.root_upper_angle = live_upper_angle
		pose.root_elbow = moved_elbow
		pose.root_moved_hanger = live_hanger
		pose.root_moved_leaf = moved_leaf
		pose.root_bell_angle = -.17*load+.39*strike-.07*recovery+.13*hurt+bell_lag
		pose.root_leaf_angle = .09*load-.15*strike+leaf_lag+.058*pose.root_leaf_sin*quiet
	pose.root_geometry_size = size
	pose.root_geometry_ready = true

# Two connected rigid stem bones, with the bend directed to the slack side.
static func _fold_elbow(root:Vector2, elbow:Vector2, tip:Vector2, target:Vector2)->Vector2:
	var first := root.distance_to(elbow)
	var second := elbow.distance_to(tip)
	var delta := target-root
	var distance := clampf(delta.length(),absf(first-second)+0.001,first+second-0.001)
	var along := (first*first-second*second+distance*distance)/(2.0*distance)
	var height := sqrt(maxf(0.0,first*first-along*along))
	var axis := delta.normalized()
	return root+axis*along+Vector2(axis.y,-axis.x)*height

static func _carry_stem(point:Vector2, uv_y:float, pose:PlainsRevisionPose)->Vector2:
	var lower := pose.root_base+(point-pose.root_base).rotated(pose.root_lower_angle)
	var upper := pose.root_bent+(point-pose.root_elbow).rotated(pose.root_upper_angle)
	var joint_blend := 1.0-_window(0.50,0.60,uv_y)
	var carried := lower.lerp(upper,joint_blend)
	return point.lerp(carried,1.0-_window(0.87,0.97,uv_y))

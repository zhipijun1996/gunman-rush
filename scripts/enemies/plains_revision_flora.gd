class_name PlainsRevisionFlora
extends RefCounted
## Body-space joints for the three planted/winged plains organisms.
## The host owns every clock, accepted hit and contact. This leaf only bends
## the same neutral skin; it never draws an intent marker or moves an Actor.

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
		var d := pose.death
		var deflate := _window(0.00, 0.32, d)
		var topple := _window(0.28, 0.78, d)
		var leaf_drop := _window(0.65, 1.00, d)
		var center := _pivot(Vector2(0.30, 0.53), size)
		var parent_angle := 0.70 * topple
		# The sac carries its nozzle and leaves. Their hinges are transformed
		# with this parent, rather than rotating about abandoned upright pivots.
		var body_target := center + Vector2(size.x * 0.06, size.y * 0.28) * topple
		var emptied := _scale_part(point, Vector2(0.30, 0.53), size, Vector2(1.0 - 0.12 * deflate, 1.0 - 0.36 * deflate), sac)
		var carried := body_target + (emptied - center).rotated(parent_angle)
		var nozzle_hinge := body_target + (_pivot(Vector2(0.70, 0.34),size)-center).rotated(parent_angle)
		var nozzle := nozzle_hinge + (carried-nozzle_hinge).rotated(-0.76 * _window(0.13,0.78,d))
		carried = carried.lerp(nozzle,muzzle)
		# Upper, rear and front leaves have separate attachments. Late droop
		# lays their tips beside the emptied chamber instead of making a pole.
		var leaf_hinge_uv := Vector2(0.47,0.31)
		var leaf_angle := -1.48
		if uv.y < 0.23:
			leaf_hinge_uv = Vector2(0.43,0.23)
			leaf_angle = -1.58
		elif uv.x < 0.39:
			leaf_hinge_uv = Vector2(0.42,0.32)
			leaf_angle = -1.22
		var leaf_hinge := body_target + (_pivot(leaf_hinge_uv,size)-center).rotated(parent_angle)
		carried = carried.lerp(leaf_hinge+(carried-leaf_hinge).rotated(leaf_angle*leaf_drop),leaves)
		# Folding legs stop supporting the parent mass. Their hips travel with
		# the chamber; feet release outward instead of remaining planted props.
		var hip_uv := Vector2(0.61,0.74) if front>0.5 else Vector2(0.34,0.75)
		var hip := _pivot(hip_uv,size)
		var moved_hip := body_target+(hip-center).rotated(parent_angle)
		var fold := _window(0.25 if front>0.5 else 0.34,0.68 if front>0.5 else 0.76,d)
		var leg_angle := -1.12 if front>0.5 else 1.18
		var folded_leg := moved_hip+(point-hip).rotated(leg_angle*fold)
		return carried.lerp(folded_leg,legs)

	var clock := pose.clock
	var load := pose.load
	var strike := pose.strike
	var recovery := pose.recovery
	var hurt := pose.hurt
	var turn := pose.raw_turn
	var quiet := 1.0-clampf(load+strike,0.0,1.0)*.8
	var drive := pose.drive
	var breath := sin(clock * 3.1) * 0.026 * (1.0 - load)
	var inflation := 0.18 * load - 0.13 * strike - 0.13 * hurt + breath
	p = _scale_part(p, Vector2(0.30, 0.53), size, Vector2(1.0 + inflation, 1.0 + inflation * 0.65), sac)
	# The nozzle aims independently of the planted support, then retracts.
	p = _joint(p, Vector2(0.70, 0.34), size, pose.aim*load -0.12 * load + 0.29 * strike + 0.10 * turn + 0.20 * hurt +.028*sin(clock*2.2-.55)*quiet-.035*drive, muzzle)
	p.x -= size.x * (0.075 * strike + 0.035 * hurt) * muzzle
	var chamber_angle := -0.035*load-0.15*strike+0.04*recovery+.021*sin(clock*2.2)*quiet-.043*drive
	p = _joint(p, Vector2(0.45, 0.81), size, chamber_angle, upper)
	p.x -= size.x * 0.035 * strike * upper
	# Broad leaves answer the chamber's release after the hard nozzle recoil.
	var leaf_spring := 0.22 * recovery * sin((1.0 - recovery) * PI * 2.0)
	var leaf_root := _joint(_pivot(Vector2(.47,.51),size),Vector2(.45,.81),size,chamber_angle,1.0)
	leaf_root.x -= size.x*.035*strike
	var leaf_idle := .060*sin(clock*2.2-.9)*quiet+.035*drive
	p = _joint_at(p,leaf_root,(1.0 if uv.x > 0.48 else -1.0)*(-.12*load+.17*strike+leaf_spring+.10*hurt+leaf_idle),leaves)
	# The leg tops answer the chamber's weight shift; toes retain their root.
	var knee := weights.sentry_knee
	p.x += size.x*.012*sin(clock*2.2)*quiet*(front*2.0-1.0)*knee
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
		var death_age := maxf(0.0, pose.death_clock)
		var captured := pose.live
		var live := _fan(point, uv, size, captured, weights)
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
	var clock := pose.clock
	var load := pose.load
	var strike := pose.strike
	var recovery := pose.recovery
	var hurt := pose.hurt
	var beat := clock*12.5
	var drive := pose.drive
	var flight_beat := sin(beat) * 0.14 * (1.0 - 0.90 * load)
	var fan_open := 0.37 * load + 0.14 * strike - 0.12 * recovery
	p = _joint(p, Vector2(0.45, 0.43), size, -fan_open - flight_beat + 0.10 * hurt, left_wing)
	p = _joint(p, Vector2(0.59, 0.43), size, fan_open + flight_beat - 0.07 * hurt, right_wing)
	# Expansion is horizontal and symmetric. Shooting gives the central mass
	# a short backward pitch while both wing roots visibly brace it.
	p.x += size.x * 0.055 * load * (right_wing - left_wing)
	var carried_lift := sin(beat-.52)*(1.0-.85*load)
	# Wing roots answer first; the copper mass follows the downstroke and the
	# feet trail a little later. Neither uses an independent whole-image bob.
	p.y -= size.y*.019*carried_lift*maxf(body,wing_height*.52)
	p = _joint(p, Vector2(0.44, 0.74), size, -0.19 * strike + 0.05 * recovery+.025*sin(beat-.72)*(1.0-load)-.055*drive, body)
	p = _scale_part(p, Vector2(0.42, 0.69), size, Vector2(1.0 - 0.10 * hurt, 1.0 - 0.07 * hurt), body)
	p.x -= size.x * 0.04 * strike * body
	p = _joint(p, Vector2(0.56, 0.79), size, 0.10 * strike + sin(beat-1.1) * 0.065 * (1.0 - load)-.065*drive, feet)
	return p

static func _root_bell(point: Vector2, uv: Vector2, size: Vector2, pose: PlainsRevisionPose, weights: PlainsRevisionWeights) -> Vector2:
	var main_stem := weights.main_stem
	var upper_stem := weights.upper_stem
	var bell := weights.bell
	var leaf := weights.leaf
	var p := point
	if pose.dead:
		var d := pose.death
		var fold := _window(0.03,0.72,d)
		var droop := _window(0.58,1.00,d)
		var root := _pivot(Vector2(0.43,0.90),size)
		var elbow := _pivot(Vector2(0.43,0.55),size)
		var crown := _pivot(Vector2(0.61,0.17),size)
		var destination := crown.lerp(_pivot(Vector2(0.55,0.58),size),fold)
		var bent := _fold_elbow(root,elbow,crown,destination)
		var stem := _carry_stem(point,uv.y,root,elbow,crown,bent,destination)
		# The lower root remains fixed; both stem bones deliver their real
		# moving endpoint to the crown. Nothing rotates about the old arch.
		var lower_angle := (bent-root).angle()-(elbow-root).angle()
		var upper_angle := (destination-bent).angle()-(crown-elbow).angle()
		var crown_angle := upper_angle*(1.0-fold)
		var crown_body := destination+(point-crown).rotated(crown_angle)
		var upper_weight := weights.upper_weight
		p = stem.lerp(crown_body,upper_weight)
		# Bell orientation remains hanging under gravity while its hanger is
		# transported down. Its actual clapper/rim reaches the floor at d=.72.
		var hanger := _pivot(Vector2(0.72,0.20),size)
		var moved_hanger := destination+(hanger-crown).rotated(crown_angle)
		var swing_progress := _window(0.72,1.00,d)
		var swing := sin(swing_progress*TAU*1.25)*(1.0-swing_progress)*0.11
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
		var moved_hinge := _carry_stem(hinge,hinge_uv.y,root,elbow,crown,bent,destination)
		if hinge_uv.y<0.32: moved_hinge=destination+(hinge-crown).rotated(crown_angle)
		var attached_angle := upper_angle if hinge_uv.y<0.55 else lower_angle
		var leaf_angle := (-0.98 if uv.x<0.46 else 0.80)*droop
		if top_left>0.3: leaf_angle=-2.1*droop
		elif top_right>0.3: leaf_angle=1.2*droop
		var leaf_pose := moved_hinge+(point-hinge).rotated(attached_angle*(1.0-droop)+leaf_angle)
		var leaf_mask := maxf(leaf,maxf(top_left,top_right))*(1.0-dead_bell)
		return p.lerp(leaf_pose,leaf_mask)

	var clock := pose.clock
	var load := pose.load
	var strike := pose.strike
	var recovery := pose.recovery
	var hurt := pose.hurt
	var breath := sin(clock * 2.6) * 0.018
	var hurt_rebound := sin((1.0 - hurt) * PI * 1.5) * hurt * 0.17
	# Load bends the stalk rearward and lifts the heavy bell; release brings
	# both connected upper segments down into the accepted pulse event.
	var quiet := 1.0-clampf(load+strike,0.0,1.0)*.8
	var live_lower_angle := breath*quiet-.19*load+.25*strike+hurt_rebound
	var live_upper_angle := .015*sin(clock*2.6-.5)*quiet-.10*load+.19*strike+.05*recovery+hurt_rebound*.6
	var moved_elbow := _joint(_pivot(Vector2(.50,.68),size),Vector2(.50,.94),size,live_lower_angle,1.0)
	p = _joint(p, Vector2(0.50, 0.94), size, live_lower_angle, main_stem)
	p = _joint_at(p,moved_elbow,live_upper_angle,upper_stem)
	# Child hinges are transported by the two flexible stem segments. Bell and
	# leaf motion are then delayed about those actual carried attachments.
	var live_hanger := _joint(_pivot(Vector2(.70,.20),size),Vector2(.50,.94),size,live_lower_angle,1.0)
	live_hanger = _joint_at(live_hanger,moved_elbow,live_upper_angle,1.0)
	var bell_lag := (.044*sin(clock*2.6-.95)-breath*.5)*quiet
	p = _joint_at(p,live_hanger,-.17*load+.39*strike-.07*recovery+.13*hurt+bell_lag,bell)
	p.y -= size.y * 0.035 * load * bell
	var leaf_lag := sin((1.0 - recovery) * PI * 2.0) * recovery * 0.09
	var moved_leaf := _joint(_pivot(Vector2(.50,.58),size),Vector2(.50,.94),size,live_lower_angle,1.0)
	moved_leaf = _joint_at(moved_leaf,moved_elbow,live_upper_angle,1.0-_window(.45,.72,.58))
	p = _joint_at(p,moved_leaf,(1.0 if uv.x>.5 else -1.0)*(.09*load-.15*strike+leaf_lag+.058*sin(clock*2.6-1.2)*quiet),leaf)
	return p

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

static func _carry_stem(point:Vector2, uv_y:float, root:Vector2, elbow:Vector2, tip:Vector2, bent:Vector2, target:Vector2)->Vector2:
	var lower_angle := (bent-root).angle()-(elbow-root).angle()
	var upper_angle := (target-bent).angle()-(tip-elbow).angle()
	var lower := root+(point-root).rotated(lower_angle)
	var upper := bent+(point-elbow).rotated(upper_angle)
	var joint_blend := 1.0-_window(0.50,0.60,uv_y)
	var carried := lower.lerp(upper,joint_blend)
	return point.lerp(carried,1.0-_window(0.87,0.97,uv_y))

class_name PlainsRevisionGround
extends RefCounted
## Presentation-only, right-facing anatomy. Feet are the common (0, 0) anchor.
## State values and locomotion distance are sampled by the owning presentation.

static func deform(point: Vector2, uv: Vector2, size: Vector2, pose: Dictionary, kind: StringName) -> Vector2:
	return deform_prepared(point, uv, size, PlainsRevisionPose.prepare(pose), kind, PlainsRevisionWeights.new(uv, kind))

static func deform_prepared(point: Vector2, uv: Vector2, size: Vector2, pose: PlainsRevisionPose, kind: StringName, weights: PlainsRevisionWeights) -> Vector2:
	var clock := pose.clock
	var stride := pose.stride
	var travel := pose.travel
	var load := pose.load
	var strike := pose.strike
	var recovery := pose.recovery
	var hurt := pose.hurt
	var turn := pose.turn
	var air := pose.air
	var vertical := pose.vertical
	var p := point
	match kind:
		&"patrol": p = _patrol_live(p, uv, size, clock, stride, travel, hurt, turn, weights)
		&"charger": p = _charger_live(p, uv, size, clock, stride, travel, load, strike, recovery, hurt, weights)
		&"hopper": p = _hopper_live(p, uv, size, clock, stride, travel, load, strike, recovery, hurt, air, vertical, weights)
	p = _vitality(p,uv,size,pose,kind, weights)
	if not pose.dead: return p
	var death := pose.death
	if death<=0.0: return p
	# The first lethal picture is the sampled live pose. The settled picture is
	# derived only from anatomy and progress, so no breath/gait/twitch survives.
	var target := point
	match kind:
		&"patrol": target = _patrol_dead(point, uv, size, death, weights)
		&"charger": target = _charger_dead(point, uv, size, death, weights)
		&"hopper": target = _hopper_dead(point, uv, size, death, weights)
	p = p.lerp(target, smoothstep(0.0, 0.14, death))
	p.y = minf(p.y, 0.0)
	return p

static func _at(unit: Vector2, size: Vector2) -> Vector2:
	return Vector2((unit.x - 0.5) * size.x, (unit.y - 1.0) * size.y)

static func _joint(point: Vector2, unit: Vector2, size: Vector2, angle: float, weight: float) -> Vector2:
	if weight == 0.0: return point
	var pivot := _at(unit, size)
	return _joint_at(point, pivot, angle, weight)

static func _joint_at(point: Vector2, pivot: Vector2, angle: float, weight: float) -> Vector2:
	if weight == 0.0: return point
	return point.lerp(pivot + (point - pivot).rotated(angle), clampf(weight, 0.0, 1.0))

static func _vitality(point: Vector2, uv: Vector2, size: Vector2, pose: PlainsRevisionPose, kind: StringName, weights: PlainsRevisionWeights) -> Vector2:
	# Carry weight through the chest/hip while toes retain their support. This
	# is deliberately not a common translation applied to the entire picture.
	var p := point
	var clock := pose.clock
	var stride := pose.stride
	var travel := pose.travel
	var drive := pose.drive
	var delayed := pose.appendage_follow
	var quiet := 1.0-clampf(pose.raw_load+pose.raw_strike,0.0,1.0)*.75
	var upper := weights.ground_upper
	match kind:
		&"patrol":
			var head := weights.patrol_head
			var chest := upper*(1.0-.72*head)
			var breath := sin(clock*3.6)*quiet
			var pivot := _at(Vector2(.46,.69),size)
			p = p.lerp(pivot+(p-pivot)*Vector2(1.0+.010*breath,1.0+.023*breath),chest)
			# Downward weight transfer coincides with the swing foot's return.
			p.y += size.y*.040*absf(sin(stride))*travel*upper
			p = _joint(p,Vector2(.46,.76),size,-.060*drive+.018*sin(stride-.22)*travel,chest)
			p = _joint(p,Vector2(.74,.49),size,.028*sin(clock*2.1-.65)*quiet+.043*sin(stride-.65)*delayed-.075*drive,head)
			p.x += size.x*.011*sin(stride-.55)*delayed*head
		&"charger":
			var head := weights.charger_head
			var shell := upper*(1.0-.65*head)
			var breath := sin(clock*2.8)*quiet
			var pivot := _at(Vector2(.45,.73),size)
			p = p.lerp(pivot+(p-pivot)*Vector2(1.0+.007*breath,1.0+.024*breath),shell)
			p.y += size.y*.027*absf(sin(stride))*travel*quiet*upper
			p = _joint(p,Vector2(.58,.76),size,-.047*drive+.019*sin(stride-.38)*travel,shell)
			p = _joint(p,Vector2(.68,.60),size,.022*sin(clock*1.9-.80)*quiet+.033*sin(stride-.75)*delayed-.036*drive,head)
			# The fore knee yields a little; the planted toe does not drift.
			var knee := weights.charger_knee
			p = _joint(p,Vector2(.55,.64),size,.027*breath*(1.0-travel),knee)
		&"hopper":
			var grounded := 0.0 if pose.air else 1.0
			var belly := weights.ground_belly
			var breath := sin(clock*3.5)*quiet
			var pivot := _at(Vector2(.43,.53),size)
			p = p.lerp(pivot+(p-pivot)*Vector2(1.0+.018*breath,1.0+.029*breath),belly)
			p.y += size.y*.025*absf(sin(stride))*travel*grounded*upper
			p = _joint(p,Vector2(.49,.72),size,-.043*drive*grounded,upper)
			p = _joint(p,Vector2(.79,.52),size,.029*sin(clock*2.4-.7)*quiet+.038*sin(stride-.7)*delayed*grounded-.045*drive,weights.hopper_head)
			var thigh := weights.hopper_thigh
			p = _joint(p,Vector2(.49,.60),size,.022*breath*(1.0-travel)*grounded,thigh)
	return p

static func _patrol_live(point: Vector2, uv: Vector2, size: Vector2, clock: float, stride: float, travel: float, hurt: float, turn: float, weights: PlainsRevisionWeights) -> Vector2:
	var p := point
	var front := weights.front_leg
	var rear := weights.rear_leg
	var fore_phase := stride
	var rear_phase := stride + PI
	# Opposed contact/swing halves: one foot bears weight while the other lifts.
	p.x += size.x * 0.065 * travel * (sin(fore_phase) * front + sin(rear_phase) * rear)
	p.y -= size.y * 0.075 * travel * (maxf(0.0, cos(fore_phase)) * front + maxf(0.0, cos(rear_phase)) * rear)
	p = _joint(p, Vector2(0.64, 0.57), size, sin(fore_phase) * travel * 0.13, front)
	p = _joint(p, Vector2(0.28, 0.66), size, sin(rear_phase) * travel * 0.13, rear)
	var upper := weights.ground_upper
	p.y -= size.y * (0.017 * travel * absf(sin(stride)) + 0.006 * sin(clock * 3.6)) * upper
	var head := weights.patrol_head
	# The head looks ahead of the torso. The trunk answers only a strong turn.
	# Negative is a pending reversal: look back toward the new travel side
	# while the trunk still retains its previous facing.
	p.x += size.x * (0.095 if turn<0.0 else 0.052) * turn * head
	p = _joint(p, Vector2(0.74, 0.49), size, -0.17 * turn + 0.10 * hurt, head)
	p = _joint(p, Vector2(0.46, 0.75), size, -0.035 * smoothstep(0.42, 1.0, turn), upper)
	# A short stumble folds a knee and puts the head behind the load-bearing foot.
	p = _joint(p, Vector2(0.28, 0.66), size, hurt * 0.31, rear)
	p = _joint(p, Vector2(0.64, 0.57), size, -hurt * 0.22, front)
	p.x -= size.x * 0.035 * hurt * upper
	p.y += size.y * 0.06 * hurt * upper
	return p

static func _charger_live(point: Vector2, uv: Vector2, size: Vector2, clock: float, stride: float, travel: float, load: float, strike: float, recovery: float, hurt: float, weights: PlainsRevisionWeights) -> Vector2:
	var p := point
	var fore := weights.charger_foreleg
	var hind := weights.rear_leg
	var upper := weights.ground_upper
	var head := weights.charger_head
	var shell := weights.charger_shell
	var gait := travel * (1.0 - 0.75 * load)
	p.x += size.x * 0.055 * gait * (sin(stride) * fore + sin(stride + PI) * hind)
	p.y -= size.y * 0.045 * gait * (maxf(0.0, cos(stride)) * fore + maxf(0.0, cos(stride + PI)) * hind)
	# Forelegs compress under the lowered horn; the rear legs load behind them.
	p = _joint(p, Vector2(0.55, 0.64), size, -0.34 * load - 0.24 * recovery, fore)
	p = _joint(p, Vector2(0.30, 0.64), size, 0.23 * load - 0.54 * strike, hind)
	p.y += size.y * 0.085 * load * upper
	p.x += size.x * 0.070 * strike * upper
	p = _joint(p, Vector2(0.68, 0.60), size, 0.23 * load - 0.12 * strike - 0.08 * recovery, head)
	# During braking the front limbs stop first. A damped shell overshoot carries
	# the rear mass forward while the horn is already lifting out of its strike.
	var brake := sin(recovery * PI) * recovery
	p.x += size.x * (0.045 * recovery + 0.034 * brake) * shell
	p = _joint(p, Vector2(0.62, 0.72), size, 0.075 * recovery + 0.065 * brake, shell)
	# Impact shakes the armour locally, instead of squashing the entire animal.
	var shiver := sin((1.0 - hurt) * PI * 5.0) * hurt * hurt
	p.x += size.x * 0.026 * shiver * shell
	p.y += size.y * 0.015 * shiver * shell
	p = _joint(p, Vector2(0.47, 0.67), size, shiver * 0.035, shell)
	p.y -= size.y * 0.004 * sin(clock * 2.8) * shell
	return p

static func _hopper_live(point: Vector2, uv: Vector2, size: Vector2, clock: float, stride: float, travel: float, load: float, strike: float, recovery: float, hurt: float, air: bool, vertical: float, weights: PlainsRevisionWeights) -> Vector2:
	var p := point
	var hind := weights.hopper_hind
	var fore := weights.front_leg
	var upper := weights.ground_upper
	var belly := weights.ground_belly
	var fold := (0.65 + 0.35 * clampf(absf(vertical) / 220.0, 0.0, 1.0)) if air else 0.0
	var extend := strike * (1.0 - 0.65 * fold)
	# Hip and ankle have opposing axes: preload closes the knee; push-off opens
	# the large thigh and extends its long lower segment behind the abdomen.
	p = _joint(p, Vector2(0.49, 0.60), size, 0.38 * load - 0.62 * extend + 0.37 * fold + 0.18 * recovery, hind)
	var ankle := weights.hopper_ankle
	p = _joint(p, Vector2(0.28, 0.72), size, -0.55 * load + 0.78 * extend - 0.58 * fold - 0.22 * recovery, ankle)
	p.y += size.y * (0.13 * load + 0.09 * recovery - 0.055 * extend) * upper
	p.x += size.x * 0.045 * extend * upper
	p = _joint(p, Vector2(0.76, 0.68), size, -0.20 * load + 0.28 * extend - 0.26 * fold + 0.16 * recovery, fore)
	# Real landing/recovery makes a second, smaller upward response, not a
	# perpetual idle bounce. At the end of recovery both feet carry the body.
	var bounce := sin(recovery * PI * 2.0) * recovery * (1.0 - recovery)
	p.y += size.y * 0.07 * bounce * upper
	p.x += size.x * 0.03 * sin(stride) * travel * (fore + 0.5 * hind) * (1.0 - fold)
	p.y -= size.y * 0.005 * sin(clock * 3.5) * upper
	# A seed-soft abdomen pulls in toward its upper hip after an accepted hit.
	var belly_pivot := _at(Vector2(0.43, 0.53), size)
	var contracted := belly_pivot + (p - belly_pivot) * Vector2(1.0 - hurt * 0.11, 1.0 - hurt * 0.13)
	p = p.lerp(contracted, belly)
	p = _joint(p, Vector2(0.79, 0.52), size, hurt * 0.11, weights.hopper_head)
	return p

static func _patrol_dead(point: Vector2, uv: Vector2, size: Vector2, death: float, weights: PlainsRevisionWeights) -> Vector2:
	var p := point
	var front := weights.front_leg
	var rear := weights.rear_leg
	var first_knee := smoothstep(0.08, 0.38, death)
	var second_knee := smoothstep(0.24, 0.58, death)
	var topple := smoothstep(0.30, 0.80, death)
	var head_drop := smoothstep(0.67, 0.98, death)
	var stumble := sin(clampf(death / 0.30, 0.0, 1.0) * PI) * (1.0 - smoothstep(0.22, 0.36, death))
	p = _joint(p, Vector2(0.64, 0.57), size, -1.03 * first_knee, front)
	p = _joint(p, Vector2(0.28, 0.66), size, 0.92 * second_knee, rear)
	var trunk := weights.ground_upper * (1.0 - 0.8 * weights.patrol_head)
	p = _joint(p, Vector2(0.48, 0.70), size, 0.26 * topple - 0.08 * stumble, trunk)
	# The first GPU corpse became a thin strip: folding knees must lower the
	# trunk without removing its ribcage volume. Keep a full, rounded side.
	var depth := lerpf(1.0, 0.68, topple)
	p.y *= depth
	# Folded toes already meet the support plane. Lower the ribcage onto them
	# instead of leaving the chest suspended above those few contact pixels.
	var chest_drop := size.y * 0.12 * topple
	p.y += chest_drop * weights.ground_upper
	p.x += size.x * (0.045 * stumble + 0.055 * topple) * weights.ground_upper
	# Bend at the lowered neck, not its old upright coordinate. The pale face
	# comes to rest ahead of the chest rather than being driven into its pixels.
	var neck := _at(Vector2(0.74, 0.49), size)
	neck.y *= depth
	neck.y += chest_drop * PlainsRevisionWeights.ground_upper_at(Vector2(0.74, 0.49))
	p = _joint_at(p, neck, 0.34 * head_drop, weights.patrol_head)
	p.x += size.x * 0.055 * head_drop * weights.patrol_head
	p.y += size.y * 0.09 * head_drop * weights.patrol_head
	return p

static func _charger_dead(point: Vector2, uv: Vector2, size: Vector2, death: float, weights: PlainsRevisionWeights) -> Vector2:
	var p := point
	var fore := weights.charger_foreleg
	var hind := weights.rear_leg
	var head := weights.charger_head
	var kneel := smoothstep(0.02, 0.31, death)
	var roll := smoothstep(0.24, 0.78, death)
	var hind_fold := smoothstep(0.42, 0.84, death)
	var horn_contact := smoothstep(0.50, 0.73, death)
	var shell_contact := smoothstep(0.68, 0.96, death)
	p = _joint(p, Vector2(0.55, 0.64), size, -1.15 * kneel, fore)
	p = _joint(p, Vector2(0.30, 0.63), size, 0.93 * hind_fold, hind)
	var shell := weights.ground_upper * (1.0 - 0.75 * head)
	p = _joint(p, Vector2(0.56, 0.70), size, 0.19 * roll + 0.055 * shell_contact, shell)
	# Knees and hind legs supply the height loss; the shell keeps its volume.
	var depth := lerpf(1.0, 0.70, roll)
	p.y *= depth
	p.x += size.x * (0.035 * kneel + 0.045 * roll) * weights.ground_upper
	var neck := _at(Vector2(0.68, 0.60), size)
	neck.y *= depth
	p = _joint_at(p, neck, 0.19 * horn_contact, head)
	p.y += size.y * 0.045 * horn_contact * head
	# The armour answers the first horn contact once; amplitude tends to zero at
	# final rest, and there is no clock-driven movement in the permanent corpse.
	var knock := sin(clampf((death - 0.67) / 0.29, 0.0, 1.0) * PI) * (1.0 - shell_contact)
	p.y -= size.y * 0.035 * knock * shell
	return p

static func _hopper_dead(point: Vector2, uv: Vector2, size: Vector2, death: float, weights: PlainsRevisionWeights) -> Vector2:
	var hind := weights.hopper_hind
	var fore := weights.front_leg
	var release := smoothstep(0.01, 0.60, death)
	var belly_drop := smoothstep(0.17, 0.63, death)
	var head_drop := smoothstep(0.48, 0.81, death)
	var stop := smoothstep(0.78, 0.94, death)
	var twitch := sin(clampf((death - 0.66) / 0.25, 0.0, 1.0) * PI) * (1.0 - stop)
	# The round abdomen's lower rim is y=.81 in the master. Translate that
	# mass to contact instead of squeezing its height and leaving a standing hip.
	var body_shift := Vector2(0.0, size.y * (0.19 * belly_drop - 0.012 * twitch))
	var p := point + body_shift
	var old_hip := _at(Vector2(0.49, 0.60), size)
	var old_knee := _at(Vector2(0.20, 0.09), size)
	var old_foot := _at(Vector2(0.05, 0.98), size)
	var hip := old_hip + body_shift
	var thigh_length := old_hip.distance_to(old_knee)
	var shin_length := old_knee.distance_to(old_foot)
	# Commit the final foot beside the animal first. The near-straight chain is
	# outside the abdomen, and its toe has enough height for its actual thickness
	# rather than relying on the outer floor clamp to cut away a hanging shin.
	var foot := (old_foot + body_shift).lerp(Vector2(hip.x - (thigh_length + shin_length) * 0.97, -size.y * 0.06), release)
	var knee := _hopper_knee(hip, foot, thigh_length, shin_length)
	var thigh_point := _hopper_segment_map(point, old_hip, old_knee, hip, knee)
	var shin_point := _hopper_segment_map(point, old_knee, old_foot, knee, foot)
	var thigh_distance := point.distance_to(Geometry2D.get_closest_point_to_segment(point, old_hip, old_knee))
	var shin_distance := point.distance_to(Geometry2D.get_closest_point_to_segment(point, old_knee, old_foot))
	# Both transforms meet at the knee; only the small joint neighbourhood blends.
	var shin_weight := smoothstep(-size.x * 0.035, size.x * 0.035, thigh_distance - shin_distance)
	var hind_point := thigh_point.lerp(shin_point, shin_weight)
	p = p.lerp(hind_point, hind)
	# The short front limbs similarly roll outward to the right of the belly.
	# Their hip follows the translated mass; their foot retains its bone length.
	var old_front_hip := _at(Vector2(0.76, 0.68), size)
	var old_front_foot := _at(Vector2(0.95, 0.98), size)
	var front_hip := old_front_hip + body_shift
	var front_length := old_front_hip.distance_to(old_front_foot)
	var front_y := -size.y * 0.04
	var front_dy := clampf(front_y - front_hip.y, -front_length * 0.96, front_length * 0.96)
	var spread_front := front_hip + Vector2(sqrt(maxf(0.0, front_length * front_length - front_dy * front_dy)), front_dy)
	var front_foot := (old_front_foot + body_shift).lerp(spread_front, release)
	p = p.lerp(_hopper_segment_map(point, old_front_hip, old_front_foot, front_hip, front_foot), fore)
	# Head descent is a child of the lowered abdomen, and happens after contact.
	var neck := _at(Vector2(0.79, 0.52), size) + body_shift
	p = _joint_at(p, neck, 0.56 * head_drop, weights.hopper_head)
	p.x += size.x * 0.025 * head_drop * weights.hopper_head
	p.y += size.y * 0.085 * head_drop * weights.hopper_head
	return p

static func _hopper_segment_map(point: Vector2, old_start: Vector2, old_end: Vector2, new_start: Vector2, new_end: Vector2) -> Vector2:
	return new_start + (point - old_start).rotated((old_end - old_start).angle_to(new_end - new_start))

static func _hopper_knee(hip: Vector2, foot: Vector2, thigh_length: float, shin_length: float) -> Vector2:
	var to_foot := foot - hip
	var distance := clampf(to_foot.length(), absf(thigh_length - shin_length) + 0.0001, thigh_length + shin_length - 0.0001)
	var direction := to_foot.normalized()
	var along := (thigh_length * thigh_length - shin_length * shin_length + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, thigh_length * thigh_length - along * along))
	# Leftward leg uses the upper branch, keeping the knee clear of the ground.
	return hip + direction * along + Vector2(-direction.y, direction.x) * height

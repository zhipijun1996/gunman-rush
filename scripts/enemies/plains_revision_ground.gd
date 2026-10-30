class_name PlainsRevisionGround
extends RefCounted
## Presentation-only, right-facing anatomy. Feet are the common (0, 0) anchor.
## State values and locomotion distance are sampled by the owning presentation.

static func deform(point: Vector2, uv: Vector2, size: Vector2, pose: Dictionary, kind: StringName) -> Vector2:
	var clock := float(pose.get("clock", 0.0))
	var stride := float(pose.get("stride", 0.0))
	var travel := clampf(float(pose.get("travel", 0.0)), 0.0, 1.0)
	var load := clampf(float(pose.get("load", 0.0)), 0.0, 1.0)
	var strike := clampf(float(pose.get("strike", 0.0)), 0.0, 1.0)
	var recovery := clampf(float(pose.get("recovery", 0.0)), 0.0, 1.0)
	var hurt := clampf(float(pose.get("hurt", 0.0)), 0.0, 1.0)
	var turn := clampf(float(pose.get("turn", 0.0)), -1.0, 1.0)
	var air := bool(pose.get("air", false))
	var vertical := float(pose.get("vertical", 0.0))
	var p := point
	match kind:
		&"patrol": p = _patrol_live(p, uv, size, clock, stride, travel, hurt, turn)
		&"charger": p = _charger_live(p, uv, size, clock, stride, travel, load, strike, recovery, hurt)
		&"hopper": p = _hopper_live(p, uv, size, clock, stride, travel, load, strike, recovery, hurt, air, vertical)
	p = _vitality(p,uv,size,pose,kind)
	if not bool(pose.get("dead", false)): return p
	var death := clampf(float(pose.get("death", 0.0)), 0.0, 1.0)
	if death<=0.0: return p
	# The first lethal picture is the sampled live pose. The settled picture is
	# derived only from anatomy and progress, so no breath/gait/twitch survives.
	var target := point
	match kind:
		&"patrol": target = _patrol_dead(point, uv, size, death)
		&"charger": target = _charger_dead(point, uv, size, death)
		&"hopper": target = _hopper_dead(point, uv, size, death)
	p = p.lerp(target, smoothstep(0.0, 0.14, death))
	p.y = minf(p.y, 0.0)
	return p

static func _at(unit: Vector2, size: Vector2) -> Vector2:
	return Vector2((unit.x - 0.5) * size.x, (unit.y - 1.0) * size.y)

static func _joint(point: Vector2, unit: Vector2, size: Vector2, angle: float, weight: float) -> Vector2:
	var pivot := _at(unit, size)
	return _joint_at(point, pivot, angle, weight)

static func _joint_at(point: Vector2, pivot: Vector2, angle: float, weight: float) -> Vector2:
	return point.lerp(pivot + (point - pivot).rotated(angle), clampf(weight, 0.0, 1.0))

static func _upper(uv: Vector2) -> float:
	return 1.0 - smoothstep(0.58, 0.80, uv.y)

static func _head(uv: Vector2) -> float:
	return smoothstep(0.58, 0.77, uv.x) * (1.0 - smoothstep(0.59, 0.78, uv.y))

static func _front_leg(uv: Vector2) -> float:
	return smoothstep(0.50, 0.67, uv.x) * smoothstep(0.60, 0.83, uv.y)

static func _rear_leg(uv: Vector2) -> float:
	return (1.0 - smoothstep(0.41, 0.58, uv.x)) * smoothstep(0.59, 0.83, uv.y)

static func _patrol_head(uv: Vector2) -> float:
	# The new master places the pale face at (0.86, 0.39), beyond its copper
	# shoulder. Keep that shoulder with the trunk instead of stretching the neck.
	return smoothstep(0.66, 0.81, uv.x) * (1.0 - smoothstep(0.65, 0.81, uv.y))

static func _charger_head(uv: Vector2) -> float:
	# Ivory horns and the low jaw are below the shell's shoulder line.
	return smoothstep(0.62, 0.78, uv.x) * (1.0 - smoothstep(0.85, 0.98, uv.y))

static func _charger_foreleg(uv: Vector2) -> float:
	# Its front foot is x=0.64 in the thick, long master: the patrol mask would
	# otherwise leave most of this leg behind when the shell drives forward.
	return smoothstep(0.42, 0.59, uv.x) * smoothstep(0.65, 0.84, uv.y) * (1.0 - smoothstep(0.75, 0.86, uv.x))

static func _hopper_hind(uv: Vector2) -> float:
	# The conspicuous thigh reaches all the way up to (0.20, 0.09). Its upper
	# segment, knee and low ankle must share a chain, not leave a still top half.
	return 1.0 - smoothstep(0.38, 0.57, uv.x)

static func _hopper_head(uv: Vector2) -> float:
	return smoothstep(0.72, 0.86, uv.x) * (1.0 - smoothstep(0.70, 0.85, uv.y))

static func _vitality(point: Vector2, uv: Vector2, size: Vector2, pose: Dictionary, kind: StringName) -> Vector2:
	# Carry weight through the chest/hip while toes retain their support. This
	# is deliberately not a common translation applied to the entire picture.
	var p := point
	var clock := float(pose.get("clock",0.0))
	var stride := float(pose.get("stride",0.0))
	var travel := clampf(float(pose.get("travel",0.0)),0.0,1.0)
	var drive := clampf(float(pose.get("drive",0.0)),-1.0,1.0)
	var delayed := clampf(float(pose.get("appendage_follow",travel)),0.0,1.0)
	var quiet := 1.0-clampf(float(pose.get("load",0.0))+float(pose.get("strike",0.0)),0.0,1.0)*.75
	var upper := _upper(uv)
	match kind:
		&"patrol":
			var head := _patrol_head(uv)
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
			var head := _charger_head(uv)
			var shell := upper*(1.0-.65*head)
			var breath := sin(clock*2.8)*quiet
			var pivot := _at(Vector2(.45,.73),size)
			p = p.lerp(pivot+(p-pivot)*Vector2(1.0+.007*breath,1.0+.024*breath),shell)
			p.y += size.y*.027*absf(sin(stride))*travel*quiet*upper
			p = _joint(p,Vector2(.58,.76),size,-.047*drive+.019*sin(stride-.38)*travel,shell)
			p = _joint(p,Vector2(.68,.60),size,.022*sin(clock*1.9-.80)*quiet+.033*sin(stride-.75)*delayed-.036*drive,head)
			# The fore knee yields a little; the planted toe does not drift.
			var knee := _charger_foreleg(uv)*(1.0-smoothstep(.90,.99,uv.y))
			p = _joint(p,Vector2(.55,.64),size,.027*breath*(1.0-travel),knee)
		&"hopper":
			var grounded := 0.0 if bool(pose.get("air",false)) else 1.0
			var belly := (1.0-smoothstep(.59,.77,uv.x))*smoothstep(.20,.45,uv.y)*(1.0-smoothstep(.70,.87,uv.y))
			var breath := sin(clock*3.5)*quiet
			var pivot := _at(Vector2(.43,.53),size)
			p = p.lerp(pivot+(p-pivot)*Vector2(1.0+.018*breath,1.0+.029*breath),belly)
			p.y += size.y*.025*absf(sin(stride))*travel*grounded*upper
			p = _joint(p,Vector2(.49,.72),size,-.043*drive*grounded,upper)
			p = _joint(p,Vector2(.79,.52),size,.029*sin(clock*2.4-.7)*quiet+.038*sin(stride-.7)*delayed*grounded-.045*drive,_hopper_head(uv))
			var thigh := _hopper_hind(uv)*(1.0-smoothstep(.83,.99,uv.y))
			p = _joint(p,Vector2(.49,.60),size,.022*breath*(1.0-travel)*grounded,thigh)
	return p

static func _patrol_live(point: Vector2, uv: Vector2, size: Vector2, clock: float, stride: float, travel: float, hurt: float, turn: float) -> Vector2:
	var p := point
	var front := _front_leg(uv)
	var rear := _rear_leg(uv)
	var fore_phase := stride
	var rear_phase := stride + PI
	# Opposed contact/swing halves: one foot bears weight while the other lifts.
	p.x += size.x * 0.065 * travel * (sin(fore_phase) * front + sin(rear_phase) * rear)
	p.y -= size.y * 0.075 * travel * (maxf(0.0, cos(fore_phase)) * front + maxf(0.0, cos(rear_phase)) * rear)
	p = _joint(p, Vector2(0.64, 0.57), size, sin(fore_phase) * travel * 0.13, front)
	p = _joint(p, Vector2(0.28, 0.66), size, sin(rear_phase) * travel * 0.13, rear)
	var upper := _upper(uv)
	p.y -= size.y * (0.017 * travel * absf(sin(stride)) + 0.006 * sin(clock * 3.6)) * upper
	var head := _patrol_head(uv)
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

static func _charger_live(point: Vector2, uv: Vector2, size: Vector2, clock: float, stride: float, travel: float, load: float, strike: float, recovery: float, hurt: float) -> Vector2:
	var p := point
	var fore := _charger_foreleg(uv)
	var hind := _rear_leg(uv)
	var upper := _upper(uv)
	var head := _charger_head(uv)
	var shell := (1.0 - smoothstep(0.62, 0.80, uv.x)) * upper
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

static func _hopper_live(point: Vector2, uv: Vector2, size: Vector2, clock: float, stride: float, travel: float, load: float, strike: float, recovery: float, hurt: float, air: bool, vertical: float) -> Vector2:
	var p := point
	var hind := _hopper_hind(uv)
	var fore := _front_leg(uv)
	var upper := _upper(uv)
	var belly := (1.0 - smoothstep(0.59, 0.77, uv.x)) * smoothstep(0.20, 0.45, uv.y) * (1.0 - smoothstep(0.70, 0.87, uv.y))
	var fold := (0.65 + 0.35 * clampf(absf(vertical) / 220.0, 0.0, 1.0)) if air else 0.0
	var extend := strike * (1.0 - 0.65 * fold)
	# Hip and ankle have opposing axes: preload closes the knee; push-off opens
	# the large thigh and extends its long lower segment behind the abdomen.
	p = _joint(p, Vector2(0.49, 0.60), size, 0.38 * load - 0.62 * extend + 0.37 * fold + 0.18 * recovery, hind)
	var ankle := hind * smoothstep(0.69, 0.87, uv.y)
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
	p = _joint(p, Vector2(0.79, 0.52), size, hurt * 0.11, _hopper_head(uv))
	return p

static func _patrol_dead(point: Vector2, uv: Vector2, size: Vector2, death: float) -> Vector2:
	var p := point
	var front := _front_leg(uv)
	var rear := _rear_leg(uv)
	var first_knee := smoothstep(0.08, 0.38, death)
	var second_knee := smoothstep(0.24, 0.58, death)
	var topple := smoothstep(0.30, 0.80, death)
	var head_drop := smoothstep(0.67, 0.98, death)
	var stumble := sin(clampf(death / 0.30, 0.0, 1.0) * PI) * (1.0 - smoothstep(0.22, 0.36, death))
	p = _joint(p, Vector2(0.64, 0.57), size, -1.03 * first_knee, front)
	p = _joint(p, Vector2(0.28, 0.66), size, 0.92 * second_knee, rear)
	var trunk := _upper(uv) * (1.0 - 0.8 * _patrol_head(uv))
	p = _joint(p, Vector2(0.48, 0.70), size, 0.26 * topple - 0.08 * stumble, trunk)
	# The first GPU corpse became a thin strip: folding knees must lower the
	# trunk without removing its ribcage volume. Keep a full, rounded side.
	var depth := lerpf(1.0, 0.68, topple)
	p.y *= depth
	p.x += size.x * (0.045 * stumble + 0.055 * topple) * _upper(uv)
	# Bend at the lowered neck, not its old upright coordinate. The pale face
	# comes to rest ahead of the chest rather than being driven into its pixels.
	var neck := _at(Vector2(0.74, 0.49), size)
	neck.y *= depth
	p = _joint_at(p, neck, 0.34 * head_drop, _patrol_head(uv))
	p.x += size.x * 0.055 * head_drop * _patrol_head(uv)
	p.y += size.y * 0.035 * head_drop * _patrol_head(uv)
	return p

static func _charger_dead(point: Vector2, uv: Vector2, size: Vector2, death: float) -> Vector2:
	var p := point
	var fore := _charger_foreleg(uv)
	var hind := _rear_leg(uv)
	var head := _charger_head(uv)
	var kneel := smoothstep(0.02, 0.31, death)
	var roll := smoothstep(0.24, 0.78, death)
	var hind_fold := smoothstep(0.42, 0.84, death)
	var horn_contact := smoothstep(0.50, 0.73, death)
	var shell_contact := smoothstep(0.68, 0.96, death)
	p = _joint(p, Vector2(0.55, 0.64), size, -1.15 * kneel, fore)
	p = _joint(p, Vector2(0.30, 0.63), size, 0.93 * hind_fold, hind)
	var shell := _upper(uv) * (1.0 - 0.75 * head)
	p = _joint(p, Vector2(0.56, 0.70), size, 0.19 * roll + 0.055 * shell_contact, shell)
	# Knees and hind legs supply the height loss; the shell keeps its volume.
	var depth := lerpf(1.0, 0.70, roll)
	p.y *= depth
	p.x += size.x * (0.035 * kneel + 0.045 * roll) * _upper(uv)
	var neck := _at(Vector2(0.68, 0.60), size)
	neck.y *= depth
	p = _joint_at(p, neck, 0.19 * horn_contact, head)
	p.y += size.y * 0.045 * horn_contact * head
	# The armour answers the first horn contact once; amplitude tends to zero at
	# final rest, and there is no clock-driven movement in the permanent corpse.
	var knock := sin(clampf((death - 0.67) / 0.29, 0.0, 1.0) * PI) * (1.0 - shell_contact)
	p.y -= size.y * 0.035 * knock * shell
	return p

static func _hopper_dead(point: Vector2, uv: Vector2, size: Vector2, death: float) -> Vector2:
	var hind := _hopper_hind(uv)
	var fore := _front_leg(uv)
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
	p = _joint_at(p, neck, 0.56 * head_drop, _hopper_head(uv))
	p.x += size.x * 0.025 * head_drop * _hopper_head(uv)
	p.y += size.y * 0.085 * head_drop * _hopper_head(uv)
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

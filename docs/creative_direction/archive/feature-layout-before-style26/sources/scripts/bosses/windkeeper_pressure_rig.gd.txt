class_name WindkeeperPressureRig
extends RefCounted
## One motor-local pose for the visible guardian and its damaging body/limbs.
## Pure sampling: no clocks, actors, resources or combat state are advanced.
const BODY_OUTLINE := [Vector2(-71,-24), Vector2(-53,-38), Vector2(43,-37), Vector2(70,-20), Vector2(71,18), Vector2(49,36), Vector2(-49,34), Vector2(-72,15)]
const HEAD_OUTLINE := [Vector2(-27,-18), Vector2(-12,-29), Vector2(17,-24), Vector2(31,-8), Vector2(28,19), Vector2(6,27), Vector2(-24,17)]
const HIP_ANCHORS := [Vector2(45,20), Vector2(23,15), Vector2(-46,21), Vector2(-28,15)]
const FOOT_ANCHORS := [Vector2(69,65), Vector2(43,62), Vector2(-68,65), Vector2(-43,62)]
const GAIT_PHASES := [0.0, 0.5, 0.40, 0.90]


static func sample(data: Dictionary) -> Dictionary:
	var mode: StringName = data.get("mode", &"observe")
	var phase := int(data.get("phase", 1))
	var facing := -1.0 if float(data.get("direction", 1)) < 0 else 1.0
	var age := maxf(0.0, float(data.get("state_age", 0.0)))
	var duration := maxf(.001, float(data.get("state_duration", 1.0)))
	var progress := clampf(age / duration, 0, 1)
	var fight := maxf(0.0, float(data.get("fight_age", 0.0)))
	var travel := float(data.get("travel", 0.0))
	var speed := absf(float(data.get("speed", 0.0)))
	var remaining := int(data.get("group_remaining", 0))
	var foot_index := clampi(int(data.get("foot_index", 0)), 0, 1)
	var double_stomp := bool(data.get("double_stomp", false))
	var high := bool(data.get("sweep_high", false))
	var death_age := maxf(0, float(data.get("death_age", 0)))
	var dead := mode == &"dead"
	var body_shift := Vector2(0, sin(fight * 3.1) * .9)
	var body_angle := sin(fight * 1.4) * .008
	var head_angle := sin(fight * 2.3 - .5) * .025
	var head_shift := Vector2.ZERO
	var sail_open := .24 if phase == 1 else .80 if phase == 2 else .96
	var sail_tension := .18
	var bell_swing := sin(fight * 2.8 - .9) * .07
	var shoulder_twist := 0.0
	var blade_angle := -.70
	var core_energy := .62 + sin(fight * 4.0) * .04
	var feet: Array[Vector2] = []
	for index: int in 4:
		feet.append(FOOT_ANCHORS[index])
	# Feet remain on the support plane through each stance. Walking motion is
	# measured world travel, with an independent swing interval for every foot.
	if mode in [&"approach", &"turn"] and speed > 1:
		for index: int in 4:
			var cycle := fposmod(travel / 96.0 + GAIT_PHASES[index], 1.0)
			var foot: Vector2 = FOOT_ANCHORS[index]
			if cycle < .64:
				foot.x += 30.0 - cycle / .64 * 60.0
			else:
				var swing := (cycle - .64) / .36
				foot.x += lerpf(-30, 30, swing)
				foot.y -= sin(swing * PI) * 23.0
			feet[index] = foot
		body_shift.y += sin(travel / 96 * TAU * 2) * 2.1
		body_angle += .025
		head_angle -= .035
	# A pursuit between frozen combo members is preparation, not a recovery.
	# Keep the sails/chest loaded while the feet execute their real gait.
	if mode in [&"approach", &"turn"] and int(data.get("attack_index", 0)) > 0 and int(data.get("group_total", 0)) > 1:
		body_shift += Vector2(3, 5)
		body_angle += .035
		head_angle -= .055
		sail_tension = .72
		sail_open = maxf(sail_open, .76)
		core_energy = maxf(core_energy, .85)
	if mode == &"turn":
		body_angle -= sin(progress * PI) * .07
		head_angle += sin(progress * PI) * .14
		feet[0].x += sin(progress * PI) * 12
		feet[2].x -= sin(progress * PI) * 9
	if mode == &"stomp_warning":
		var load := smoothstep(0, .82, progress)
		body_shift += Vector2(-11, -3) * load
		body_angle -= .10 * load
		feet[foot_index] += Vector2(-12, -53) * load
		if double_stomp:
			feet[1-foot_index] += Vector2(13,-22) * load
			sail_open += .14 * load
			head_angle -= .14 * load
		else:
			head_angle += .055 * load
		bell_swing += .23 * load
	elif mode == &"stomp":
		var strike := smoothstep(0, .55, progress)
		var settling := sin(clampf((progress-.55)/.45,0,1) * PI)
		body_shift += Vector2(lerpf(-11,4,strike), lerpf(-3,10,strike)-settling*3)
		body_angle += lerpf(-.10,.055,strike)
		feet[foot_index] += Vector2(-12,-53) * (1-strike)
		if double_stomp and remaining > 0:
			feet[1-foot_index] += Vector2(13,-22)
		bell_swing -= sin(progress*PI) * .32
		sail_tension = .45
	elif mode == &"lunge_warning":
		var load := smoothstep(0,.85,progress)
		body_shift += Vector2(-10,18)*load
		body_angle += .10*load
		feet[0].x += 13*load
		feet[1].x += 8*load
		feet[2].x -= 16*load
		feet[3].x -= 12*load
		head_angle += .17*load
		sail_open *= 1-.35*load
		bell_swing += .27*load
	elif mode == &"lunge":
		# Motor owns the real rise/fall. Only articulation is changed here.
		var launch := smoothstep(0,.22,progress)
		var landing := smoothstep(.72,1,progress)
		body_shift.y += lerpf(18,-2,launch)+landing*15
		body_angle += lerpf(.10,-.035,launch)-landing*.055
		feet[0] += Vector2(lerpf(13,28,launch),-34*sin(progress*PI))
		feet[1] += Vector2(lerpf(8,19,launch),-26*sin(progress*PI))
		feet[2] += Vector2(-30*sin(progress*PI),-12*sin(progress*PI))
		feet[3] += Vector2(-22*sin(progress*PI),-21*sin(progress*PI))
		sail_open *= .65 + landing*.35
		bell_swing += sin(progress*PI)*.38
	elif mode in [&"sweep_warning", &"sweep"]:
		var preparing := mode == &"sweep_warning"
		var load := smoothstep(0,.84,progress) if preparing else 1.0
		var swing := 0.0 if preparing else smoothstep(0,.92,progress)
		shoulder_twist = lerpf(-.24,.25,swing)*load
		body_shift += Vector2(-7+12*swing,-7 if high else 6)*load
		body_angle += shoulder_twist*.35
		head_angle -= shoulder_twist*.70
		feet[0].x += 14*load
		feet[1].x += 6*load
		feet[2].x -= 13*load
		feet[3].x -= 5*load
		blade_angle = lerpf(-.85,.10,swing) if high else lerpf(.05,.95,swing)
		sail_open = minf(1,sail_open+.12*load)
		sail_tension = .95
		bell_swing -= shoulder_twist*.85
	elif mode in [&"gust_warning", &"gust"]:
		var preparing := mode == &"gust_warning"
		var load := smoothstep(0,.85,progress) if preparing else 1.0
		var release := 0.0 if preparing else sin(progress*PI)
		body_shift += Vector2(-9+13*release,6)*load
		body_angle += (-.05+.10*release)*load
		feet[0].x += 17*load
		feet[1].x += 10*load
		feet[2].x -= 15*load
		feet[3].x -= 8*load
		head_angle -= .12*load
		sail_open = lerpf(sail_open,1,load)
		sail_tension = 1.0 if preparing else .75
		bell_swing += (-.25+.45*release)*load
	elif mode in [&"seeds_warning", &"seeds"]:
		var preparing := mode == &"seeds_warning"
		var load := smoothstep(0,.82,progress) if preparing else 1.0
		var recoil := 0.0 if preparing else exp(-age*12)*.14
		body_shift += Vector2(-7,-11)*load
		body_angle -= (.06+recoil)*load
		head_shift += Vector2(-5,-13)*load
		head_angle -= (.38-recoil)*load
		feet[0].x -= 5*load
		feet[2].x -= 12*load
		sail_open = minf(1,sail_open+.18*load)
		sail_tension = .78
		core_energy = 1.0
	elif mode in [&"platform_warning", &"platform"]:
		var preparing := mode == &"platform_warning"
		var load := smoothstep(0,.87,progress) if preparing else 1.0
		var strike := 0.0 if preparing else smoothstep(0,.55,progress)
		body_shift += Vector2(12,4)*load
		body_angle += .115*load
		head_shift += Vector2(8,-5)*load
		head_angle += .13*load
		feet[1].x += 10*load
		feet[2].x -= 18*load
		feet[3].x -= 11*load
		# Actual target is already in motor-local space, including real facing.
		# Only the rig itself is mirrored below, never this locked world point.
		feet[0].y -= 62*load*(1-strike)
		sail_tension = .92
		bell_swing += .28*load
	elif mode == &"link":
		body_shift += Vector2(4,8)
		body_angle += .055
		feet[1] += Vector2(9,-19)
		sail_open = maxf(sail_open,.76)
		sail_tension = .95
		core_energy = .9
	elif mode == &"recover":
		var release := smoothstep(0,1,progress)
		body_shift += Vector2(4,9)*(1-release)
		body_angle += .055*(1-release)
		head_shift += Vector2(2,9)*sin(progress*PI)
		head_angle += .22*sin(progress*PI)
		sail_open *= 1-.54*smoothstep(0,.68,progress)
		sail_tension = .12
		bell_swing *= exp(-age*3.3)
		core_energy = .46
	elif mode == &"phase_transition":
		var opening := smoothstep(0,.85,progress)
		body_shift.y -= 8*sin(progress*PI)
		head_angle -= .24*sin(progress*PI)
		sail_open *= opening
		sail_tension = .85
		bell_swing += sin(progress*PI*3)*.14
		core_energy = .95
	elif mode == &"intro":
		head_angle -= sin(progress*PI)*.25
		sail_open *= smoothstep(0,1,progress)
		body_shift.y += 6*(1-smoothstep(0,.75,progress))
	if bool(data.get("combo_movement", false)):
		sail_tension = maxf(sail_tension, .72)
		core_energy = maxf(core_energy, .85)
	var hurt_age := float(data.get("hurt_age", data.get("bell_hit_age", -1)))
	if hurt_age >= 0 and hurt_age < .16 and not dead:
		body_shift.x -= sin(hurt_age/.16*PI)*2.0
		head_angle += sin(hurt_age/.16*PI)*.055
	if dead:
		var kneel := smoothstep(.05,.75,death_age)
		var settle := smoothstep(.55,1.6,death_age)
		body_shift = Vector2(-9*settle,70*settle+14*kneel*(1-settle))
		body_angle = .17*settle
		head_shift = Vector2(4,14*settle)
		head_angle = .26*settle
		sail_open *= 1-.95*smoothstep(.35,1.7,death_age)
		sail_tension = 0.0
		bell_swing = sin(death_age*7)*exp(-death_age*3)*.16 if death_age < 1.8 else 0.0
		core_energy = maxf(0,1-death_age/.65)
		for index: int in 4:
			feet[index] = feet[index].lerp(Vector2(feet[index].x*1.10,61+float(index%2)*2),settle)
	var face := Transform2D(Vector2(facing,0),Vector2(0,1),Vector2.ZERO)
	var body := face*Transform2D(body_angle,Vector2(0,-55)+body_shift)
	var head := body*Transform2D(head_angle,Vector2(64,-12)+head_shift)
	var hips: Array[Vector2] = []
	var knees: Array[Vector2] = []
	for index: int in 4:
		feet[index] = face*feet[index]
		hips.append(body*HIP_ANCHORS[index])
		knees.append(hips[index].lerp(feet[index],.54)+Vector2(facing*(16 if index<2 else -19),-7))
	if mode in [&"platform_warning", &"platform"]:
		var target: Vector2 = data.get("attack_target_local",Vector2.ZERO)
		if target.is_finite() and target != Vector2.ZERO:
			var extension := smoothstep(0,.87,progress) if mode == &"platform_warning" else 1.0
			var strike := 0.0 if mode == &"platform_warning" else smoothstep(0,.55,progress)
			var raised_target := target-Vector2(0,74*(1-strike))
			feet[0] = feet[0].lerp(raised_target,extension)
			knees[0] = hips[0].lerp(feet[0],.54)+Vector2(-facing*18,-19)
	if dead:
		var fold := smoothstep(.05,1.4,death_age)
		for index: int in 4:
			knees[index] = knees[index].lerp(Vector2(feet[index].x+facing*(11 if index<2 else -11),56),fold)
	var hub := body*Vector2(3,-30)
	var blade_axis := face.basis_xform(Vector2.from_angle(blade_angle+body_angle))
	var body_points := PackedVector2Array()
	var head_points := PackedVector2Array()
	for point: Vector2 in BODY_OUTLINE: body_points.append((body*point).round())
	for point: Vector2 in HEAD_OUTLINE: head_points.append((head*point).round())
	return {"body_transform":body,"head_transform":head,
		"core_transform":body*Transform2D(0,Vector2(39,-2)),
		"hips":hips,"knees":knees,"feet":feet,
		"body_shape_points":body_points,"head_shape_points":head_points,
		"blade_start":hub+blade_axis*22,"blade_end":hub+blade_axis*157,
		"blade_hub":hub,"blade_width":14.0,"strike_radius":15.0,"foot_radius":12.0,
		"seed_origin":head*Vector2(27,-4),"gust_direction":Vector2(facing,0),
		"sail_open":clampf(sail_open,0,1),"sail_tension":sail_tension,
		"bell_swing":bell_swing,"shoulder_twist":shoulder_twist,
		"core_energy":core_energy,"direction":facing,"mode":mode,"phase":phase,
		"state_age":age,"progress":progress,"fight_age":fight,
		"death_age":death_age,"dead":dead,"double_stomp":double_stomp,
		"group_remaining":remaining,"foot_index":foot_index,"sweep_high":high}


static func blend(previous: Dictionary, target: Dictionary, weight: float) -> Dictionary:
	# Called by Encounter, never by Presentation alone. Collision and drawing
	# therefore see the same short, accepted transition between action poses.
	if previous.is_empty() or target.is_empty() or weight >= 1.0:
		return target
	if float(previous.get("direction",1)) != float(target.get("direction",1)):
		# Interpolating opposite reflected bases would collapse the guardian or
		# rotate it upside down. The owner's readable turn controls the mirror.
		return target
	var amount := clampf(weight,0,1)
	var pose := target.duplicate(true)
	for key: String in ["body_transform","head_transform","core_transform"]:
		var before: Transform2D = previous[key]
		pose[key] = before.interpolate_with(target[key],amount)
	for key: String in ["hips","knees","feet"]:
		var points: Array[Vector2] = []
		var old_points: Array = previous[key]
		var next_points: Array = target[key]
		if old_points.size() != next_points.size(): continue
		for index: int in next_points.size():
			var before: Vector2 = old_points[index]
			points.append(before.lerp(next_points[index],amount))
		pose[key] = points
	for key: String in ["blade_start","blade_end","blade_hub"]:
		var before: Vector2 = previous[key]
		pose[key] = before.lerp(target[key],amount)
	for key: String in ["sail_open","sail_tension","bell_swing","shoulder_twist","core_energy"]:
		pose[key] = lerpf(float(previous[key]),float(target[key]),amount)
	# Hull polygons are rebuilt from the interpolated transforms, exactly as
	# drawn, rather than separately linearly blending rotated polygon points.
	var body: Transform2D = pose.body_transform
	var head: Transform2D = pose.head_transform
	var body_points := PackedVector2Array()
	var head_points := PackedVector2Array()
	for point: Vector2 in BODY_OUTLINE: body_points.append((body*point).round())
	for point: Vector2 in HEAD_OUTLINE: head_points.append((head*point).round())
	pose.body_shape_points = body_points
	pose.head_shape_points = head_points
	pose.seed_origin = head*Vector2(27,-4)
	return pose

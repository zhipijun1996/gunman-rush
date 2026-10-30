extends RefCounted
## Bounded observer/anatomy fixtures, not natural combat or visual approval.
## Actor positions below are explicit scripted observer inputs. Actual factory,
## Actor.presentation_state, motion clock, opaque source pixels and rigs are used.

static func run(tree: SceneTree) -> Dictionary:
	var report := {"assertions":0,"failures":[],"checks":[],"samples":[],"scope":"Six real opaque skins plus both real diver skins; scripted locomotion-observer inputs, no combat/pixel/listening acceptance"}
	for kind: StringName in [&"patrol",&"charger",&"hopper",&"sentry",&"fan_sentry",&"root_bell"]:
		_geometry(kind,report)
	await _observer(tree,report)
	for style: StringName in [&"legacy",&"underworld"]:
		await _diver(tree,style,report)
	return report

static func _check(report: Dictionary, ok: bool, label: String) -> void:
	report.assertions += 1
	report.checks.append({"label":label,"passed":ok})
	if not ok:
		report.failures.append(label)
		printerr("FAIL: ",label)

static func _pose(clock: float = 0.0) -> Dictionary:
	return {"clock":clock,"stride":.5,"travel":0.0,"drive":0.0,"body_follow":0.0,"appendage_follow":0.0,"load":0.0,"strike":0.0,"recovery":0.0,"hurt":0.0,"turn":0.0,"air":false,"vertical":0.0,"dead":false,"death":0.0,"death_clock":0.0,"landing":0.0}

static func _opaque_units(texture: Texture2D) -> Array[Vector2]:
	var image := texture.get_image()
	var units: Array[Vector2] = []
	for y: int in 33:
		for x: int in 33:
			var pixel := Vector2i(roundi(float(x)/32.0*(image.get_width()-1)),roundi(float(y)/32.0*(image.get_height()-1)))
			if image.get_pixelv(pixel).a >= .7:
				units.append(Vector2(pixel)/Vector2(image.get_size()))
	return units

static func _foot_units(texture: Texture2D) -> Array[Vector2]:
	# Use actual lowest opaque pixels, rather than transparent mesh corners.
	var image := texture.get_image()
	var feet: Array[Vector2] = []
	for x: int in 33:
		var px := roundi(float(x)/32.0*(image.get_width()-1))
		for py: int in range(image.get_height()-1,-1,-1):
			if image.get_pixel(px,py).a < .7: continue
			if float(py)/image.get_height() >= .94:
				feet.append(Vector2(px,py)/Vector2(image.get_size()))
			break
	return feet

static func _geometry(kind: StringName, report: Dictionary) -> void:
	var rig := PlainsRevisionSkin.new(kind)
	var units := _opaque_units(rig.texture)
	var first := _pose(.11)
	first.air = kind == &"fan_sentry"
	var largest := 0.0
	var upper_largest := 0.0
	var nonrigid := 0.0
	var finite := true
	for time: float in [.43,.89]:
		var later := first.duplicate(true)
		later.clock = time
		var reference := Vector2.ZERO
		var has_reference := false
		for uv: Vector2 in units:
			var point := rig.bounds.position+uv*rig.bounds.size
			var before := rig.deform(point,uv,first)
			var after := rig.deform(point,uv,later)
			var delta := after-before
			finite = finite and before.is_finite() and after.is_finite()
			largest = maxf(largest,delta.length())
			if uv.y>.15 and uv.y<.75: upper_largest=maxf(upper_largest,delta.length())
			if has_reference: nonrigid=maxf(nonrigid,delta.distance_to(reference))
			else:
				reference=delta
				has_reference=true
	_check(report,units.size()>=12,String(kind)+" uses at least12 actually opaque source probes")
	_check(report,finite,String(kind)+" sampled idle anatomy remains finite")
	_check(report,upper_largest>.10,String(kind)+" idle moves visible upper anatomy, not feet alone")
	_check(report,nonrigid>.08,String(kind)+" idle opaque points do not share one rigid image translation")
	var foot_largest := 0.0
	if kind != &"fan_sentry":
		var feet := _foot_units(rig.texture)
		var later := first.duplicate(true)
		later.clock=.89
		for uv: Vector2 in feet:
			var point := rig.bounds.position+uv*rig.bounds.size
			foot_largest=maxf(foot_largest,rig.deform(point,uv,later).distance_to(rig.deform(point,uv,first)))
		_check(report,not feet.is_empty(),String(kind)+" planted-foot probes are actual opaque source pixels")
		_check(report,foot_largest<.45,String(kind)+" idle supports stay within a subpixel band while the upper body moves")
	# Nonzero observer and attack/hurt inputs must survive the lethal first image.
	var captured := _pose(.37)
	captured.merge({"travel":.85,"drive":-.65,"body_follow":.7,"appendage_follow":.4,"load":.6,"strike":.3,"recovery":.2,"hurt":.55,"turn":-.7,"air":kind==&"fan_sentry"},true)
	var lethal := captured.duplicate(true)
	lethal.dead=true
	var ended := lethal.duplicate(true)
	ended.death=1.0
	var distant := ended.duplicate(true)
	distant.merge({"clock":170.0,"stride":80.0,"travel":0.0,"drive":1.0,"body_follow":0.0,"appendage_follow":1.0,"load":0.0,"strike":1.0,"hurt":1.0,"turn":1.0,"death_clock":90.0,"air":true,"vertical":-200.0},true)
	var handoff := true
	var settled := true
	var above_floor := true
	for uv: Vector2 in units:
		var point := rig.bounds.position+uv*rig.bounds.size
		handoff=handoff and rig.deform(point,uv,captured).is_equal_approx(rig.deform(point,uv,lethal))
		var rest := rig.deform(point,uv,ended)
		settled=settled and rest.is_equal_approx(rig.deform(point,uv,distant))
		above_floor=above_floor and rest.y<=.0001
	_check(report,handoff,String(kind)+" death0 preserves captured drive, appendage and hurt anatomy")
	_check(report,settled,String(kind)+" death1 ignores changed clock, motion, drive and attack inputs")
	_check(report,above_floor,String(kind)+" settled opaque samples stay above the support plane")
	report.samples.append({"id":"opaque_anatomy/"+String(kind),"opaque_points":units.size(),"idle_max":largest,"upper_max":upper_largest,"nonrigid_spread":nonrigid,"foot_max":foot_largest})

static func _values(motion: PlainsMotion02) -> Array:
	return [motion.clock,motion.stride,motion.travel,motion.drive,motion.body_follow,motion.appendage_follow]

static func _observer(tree: SceneTree, report: Dictionary) -> void:
	var world := Node2D.new()
	world.name="ExplicitMotionObserverFixture"
	world.process_mode=Node.PROCESS_MODE_DISABLED
	tree.root.add_child(world)
	var motor := EnemyFactory.create_for_behavior(&"patrol")
	_check(report,motor!=null,"observer uses the actual patrol factory")
	if motor==null:
		world.queue_free()
		await tree.process_frame
		return
	world.add_child(motor)
	var actor := motor.get_node("Actor") as EnemyActor
	actor.set_physics_process(false)
	actor.brain.enabled=false
	var host := motor.get_node("Presentation") as Node2D
	var motion := host.get("body_motion") as PlainsMotion02
	var visual := host.get("revision_visual") as PlainsRevisionVisual
	_check(report,motion!=null and visual!=null,"observer samples actual installed articulated motion/visual")
	if motion==null or visual==null:
		world.queue_free()
		await tree.process_frame
		return
	motion.synchronize(actor)
	var positive_drive := 0.0
	var appendage_lags := false
	var body_lags := false
	var dt := 1.0/60.0
	var step := actor.definition.patrol_speed*dt
	for _i: int in 40:
		motor.position.x+=step
		motion.advance(actor,dt)
		positive_drive=maxf(positive_drive,motion.drive)
		body_lags=body_lags or motion.body_follow<motion.travel-.02
		appendage_lags=appendage_lags or motion.appendage_follow<motion.body_follow-.02
	_check(report,motion.stride>0.0 and motion.travel>.7,"real Actor snapshot displacement produces gait and travel")
	_check(report,positive_drive>.05 and body_lags and appendage_lags,"start-up has positive drive and ordered mass/appendage follow")
	var before := _values(motion)
	for _i: int in 8: visual.refresh(0.0)
	_check(report,_values(motion)==before,"repeated installed visual refresh0 cannot advance observer clocks or inertia")
	motion.advance(actor,0.0)
	_check(report,_values(motion)==before,"zero-delta observer call cannot advance clocks or inertia")
	var old_pause := tree.paused
	tree.paused=true
	var lifecycle: RefCounted=host.get("lifecycle")
	var advanced: bool=lifecycle.call("advance",dt)
	tree.paused=old_pause
	_check(report,not advanced and _values(motion)==before,"actual lifecycle rejects paused motion clock advancement")
	var negative_drive := 0.0
	for _i: int in 180:
		motion.advance(actor,dt)
		negative_drive=minf(negative_drive,motion.drive)
	_check(report,negative_drive<-.03,"stopping produces a separate bounded braking response")
	_check(report,motion.travel<.001 and absf(motion.drive)<.001 and motion.body_follow<.001 and motion.appendage_follow<.001,"idle settles all observer inertia without a persistent gait")
	var still_stride := motion.stride
	for _i: int in 20: motion.advance(actor,dt)
	_check(report,is_equal_approx(motion.stride,still_stride),"stationary observation never invents another footstep")
	for _i: int in 12:
		motor.position.x+=step
		motion.advance(actor,dt)
	var old_stride := motion.stride
	motor.position.x+=200.0
	motion.advance(actor,dt)
	_check(report,is_equal_approx(motion.stride,old_stride) and motion.drive==0.0 and is_equal_approx(motion.body_follow,motion.travel) and is_equal_approx(motion.appendage_follow,motion.travel),"teleport rebases follow without manufacturing gait or impact inertia")
	var epoch := actor.health.epoch
	_check(report,actor.health.configure(actor.definition.health_definition),"actual HealthState accepts observer epoch reset")
	motion.sync_epoch(actor)
	_check(report,actor.health.epoch>epoch and _values(motion)==[0.0,0.0,0.0,0.0,0.0,0.0],"new health epoch clears every observer clock and follow value")
	_check(report,actor.restore_instance_health(0.0),"official instance restore prepares terminal observer fixture")
	motion.sync_epoch(actor)
	before=_values(motion)
	motor.position.x+=1.0
	motion.advance(actor,dt)
	_check(report,_values(motion)==before,"terminal observer does not advance live clock, gait or inertia")
	report.samples.append({"id":"actual_motion_observer","start_drive":positive_drive,"stop_drive":negative_drive,"epoch_before_reset":epoch,"epoch_after_reset":actor.health.epoch,"scope":"Scripted Motor positions; real Actor snapshots/observer/lifecycle, not natural movement or combat"})
	var reference: WeakRef=weakref(motor)
	world.queue_free()
	await tree.process_frame
	await tree.process_frame
	_check(report,reference.get_ref()==null,"observer fixture releases actual Motor, visual and remains owners")

static func _diver(tree: SceneTree, style: StringName, report: Dictionary) -> void:
	var world := Node2D.new()
	world.name="ExplicitDiverAnatomyFixture"
	world.process_mode=Node.PROCESS_MODE_DISABLED
	tree.root.add_child(world)
	var motor := EnemyFactory.create_for_behavior(&"diver")
	_check(report,motor!=null,String(style)+" diver uses actual factory")
	if motor==null:
		world.queue_free()
		await tree.process_frame
		return
	world.add_child(motor)
	var actor := motor.get_node("Actor") as EnemyActor
	actor.set_physics_process(false)
	actor.brain.enabled=false
	if style==&"underworld":
		var installer: Script=load("res://scripts/underworld_plains/underworld_actor_installer.gd")
		var installed: Dictionary=installer.call("install",world)
		_check(report,int(installed.get("enemies",0))==1,"diver uses actual formal Underworld installer")
	var host := motor.get_node("Presentation") as Node2D
	var frames := host.get("feedback_frames") as EnemyFeedback01Frames
	var motion := host.get("body_motion") as PlainsMotion02
	_check(report,frames!=null and motion!=null,String(style)+" diver observes actual frame source and motion")
	if frames==null or motion==null:
		world.queue_free()
		await tree.process_frame
		return
	var texture := frames.canonical_live_texture()
	var bounds := frames.canonical_live_bounds()
	motion.call("_prepare",texture,bounds)
	var visible: Rect2=motion.get("_visible")
	var units := _opaque_units(texture)
	var finite := true
	var upper_max := 0.0
	var lower_max := 0.0
	var nonrigid := 0.0
	var terminal_static := true
	var reference_delta := Vector2.ZERO
	var has_reference := false
	for uv: Vector2 in units:
		var point := bounds.position+uv*bounds.size
		var body_uv := (point-visible.position)/visible.size
		motion.clock=.11
		var first: Vector2=motion.call("_deform",point,body_uv,&"diver",false,0.0)
		motion.clock=.43
		var later: Vector2=motion.call("_deform",point,body_uv,&"diver",false,0.0)
		finite=finite and first.is_finite() and later.is_finite()
		if body_uv.y<.45: upper_max=maxf(upper_max,first.distance_to(later))
		if body_uv.y>.45 and body_uv.y<.92: lower_max=maxf(lower_max,first.distance_to(later))
		var delta := later-first
		if has_reference: nonrigid=maxf(nonrigid,delta.distance_to(reference_delta))
		else:
			reference_delta=delta
			has_reference=true
		var ended: Vector2=motion.call("_deform",point,body_uv,&"diver",true,0.0)
		motion.clock=190.0
		motion.drive=1.0
		var distant: Vector2=motion.call("_deform",point,body_uv,&"diver",true,1.0)
		terminal_static=terminal_static and ended.is_equal_approx(distant)
		motion.drive=0.0
	_check(report,units.size()>=12 and finite,String(style)+" diver probes actual opaque anatomy with finite joints")
	_check(report,upper_max>.10 and lower_max>.05,String(style)+" diver wing/rotor and body both participate in idle")
	_check(report,motion.body_bob(&"diver")==0.0 and nonrigid>.10,String(style)+" diver motion is carried by anatomy without a host image bob")
	_check(report,terminal_static,String(style)+" diver terminal bypass ignores live clock and drive; corpse owner tested separately")
	report.samples.append({"id":"opaque_diver/"+String(style),"opaque_points":units.size(),"upper_max":upper_max,"body_max":lower_max,"host_bob":motion.body_bob(&"diver"),"scope":"Actual installed canonical source; body observer only, not full corpse animation or visual approval"})
	var reference: WeakRef=weakref(motor)
	world.queue_free()
	await tree.process_frame
	await tree.process_frame
	_check(report,reference.get_ref()==null,String(style)+" diver fixture releases its actual Motor and owner")

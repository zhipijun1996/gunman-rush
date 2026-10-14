extends "res://tests/all_weapons_runner.gd"
var measurements: Array[Dictionary]=[]
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/action_budget")
	for hz: int in [30,60,120]:
		Engine.physics_ticks_per_second=hz;dt=1.0/hz
		# Godot applies a changed fixed rate after its existing accumulator drains.
		for i: int in 12:await physics_frame
		await budgets(hz)
		await pause_and_apex(hz)
		await hook_assist(hz)
	Engine.physics_ticks_per_second=60;dt=1.0/60
	await shared_skill_aim()
	await laser_skill_preserved()
	await drawing_read_only()
	var file := FileAccess.open("res://build/action_budget/native_trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"real Controller input -> sole Motor paths, no result injection; resource boundary explicitly initialized for skill tests","checks":checks,"failures":failures,"measurements":measurements},"\t"));file.close()
	world.free();await process_frame
	print("ACTION BUDGET: %s assertions, %s failures" % [checks,failures]);quit(1 if failures else 0)
func equip_id(id: String) -> void:
	check(controller.shoot_ability.equip(load("res://resources/weapons/%s.tres" % id)),"equip "+id)
	controller.router.activate_device(&"gamepad")
func budgets(hz: int) -> void:
	for ground: bool in [false,true]:
		for id: String in ["pulse_gun","shadow_shuriken","recoil_bomb","triple_machine_gun","sustained_laser","fan_shuriken","remote_boomerang","magnetic_mine","collapse_singularity","laser_cannon"]:
			await fixture(Vector2(100,682 if ground else -1000));await tick(3);equip_id(id)
			var d := motor.weapon_motion.base_distance(motor.tuning,ground)
			var start := motor.position
			var blink_lengths: Array[float]=[]
			motor.weapon_blinked.connect(func(a: Vector2,b: Vector2)->void:blink_lengths.append(a.distance_to(b)))
			if id in ["sustained_laser","laser_cannon"]:
				motor.normal_velocity=Vector2(330,500);motor.apply_impulse(Vector2(120,800))
				controller.router.set_aim(&"gamepad",Vector2.RIGHT,true);await tick()
				check(motor.position==start and motor.velocity==Vector2.ZERO and motor.normal_velocity==Vector2.ZERO,"laser first accepted frame stops every velocity")
				check(controller.shoot_ability.behavior()._beam_start.distance_to(start)<80 and controller.shoot_ability.behavior()._beam_point.distance_to(start)>80,"laser first stopped frame already shows collision-checked beam")
				for sample: int in 12:
					await tick()
					var segment := controller.shoot_ability.behavior().beam_visual_segment()
					var muzzle := (motor.get_node("CourierVisual") as CourierVisual).visible_muzzle_position()
					check(segment.size()==2 and segment[0].distance_to(muzzle)<.01 and segment[0].distance_to(segment[1])<=controller.shoot_ability.weapon.range_limit+.01,"moving accelerating laser drawing stays attached to real muzzle and within range")
			elif id=="magnetic_mine" and ground:
				body(Rect2(140,0,16,700));await physics_frame
				controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(8)
				check(controller.shoot_ability.behavior().current_entities().size()==1,"ground mine remains a real remote object")
				controller.router.request_action(&"weapon_context")
			else:
				controller.router.request_action(&"shoot_release",Vector2.RIGHT)
				if id=="magnetic_mine":
					await tick();check(controller.shoot_ability.behavior().current_entities().is_empty() and not controller.shoot_ability.behavior()._fx.is_empty(),"air mine explodes immediately with real blast feedback")
			await tick(ceili(.85/dt))
			if id=="remote_boomerang":
				check(blink_lengths.size()==1 and absf(blink_lengths[0]-d)<.1,"boomerang first stage is exact shared blink")
				controller.router.request_action(&"weapon_context")
				var recall_path := 0.0
				for i: int in ceili(.2/dt):
					var before := motor.position;await tick();recall_path+=before.distance_to(motor.position)
					if motor.recoil_burst_remaining<=0:break
				check(absf(recall_path-d*.5)<.1,"boomerang manual recall second stage path is .5D")
				measurements.append({"recall_path":recall_path,"hz":hz,"ground":ground})
			var actual := absf(motor.position.x-start.x)
			if id=="remote_boomerang":actual=blink_lengths[0]+float(measurements[-1].recall_path)
			var ratio := 1.5 if id in ["triple_machine_gun","sustained_laser","fan_shuriken","remote_boomerang","laser_cannon"] else 1.0
			check(absf(actual-d*ratio)<.2,"%s total %sD ground=%s %sHz actual=%.4f expected=%.4f" % [id,ratio,ground,hz,actual,d*ratio])
			if id=="fan_shuriken":check(blink_lengths.size()==2 and absf(blink_lengths[0]-d)<.1 and absf(blink_lengths[1]-.5*d)<.1,"fan blink stages D + .5D")
			if id in ["sustained_laser","laser_cannon"]:
				check(controller.shoot_ability.behavior().phase==&"idle" and motor.recoil_velocity==Vector2.ZERO,"full duration closes laser and clears drive")
				var packets := controller.shoot_ability.packet_id;await tick(ceili(.2/dt))
				check(controller.shoot_ability.packet_id==packets,"holding after timeout cannot auto repeat")
			measurements.append({"weapon":id,"hz":hz,"ground":ground,"d":d,"distance":actual,"ratio":ratio,"blinks":blink_lengths})
func pause_and_apex(hz: int) -> void:
	for id: String in ["shadow_shuriken","remote_boomerang"]:
		await fixture(Vector2(100,-1000));await tick();equip_id(id)
		controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		for i: int in 12:
			await tick()
			if motor.weapon_pause_remaining>0:break
		check(motor.weapon_pause_remaining>0,"blink has a visible pause")
		var start := motor.position
		controller.router.set_move_axis(1)
		var held := 0.0
		while motor.weapon_pause_remaining>0:
			await tick();held+=dt
			check(motor.position==start and motor.velocity==Vector2.ZERO and motor.normal_velocity==Vector2.ZERO and motor.recoil_velocity==Vector2.ZERO,"pause cancels every speed even against move input")
		check(held>=motor.weapon_motion.blink_pause_seconds and held<motor.weapon_motion.blink_pause_seconds+dt+.001,"blink pause lasts configured game time")
	for id: String in ["pulse_gun","triple_machine_gun","recoil_bomb","magnetic_mine","sustained_laser"]:
		await fixture(Vector2(100,-1000));await tick();equip_id(id)
		motor.normal_velocity.y=1000
		if id=="sustained_laser":controller.router.set_aim(&"gamepad",Vector2.DOWN,true)
		else:controller.router.request_action(&"shoot_release",Vector2.DOWN)
		await tick()
		for i: int in ceili(.7/dt):
			if motor.recoil_burst_remaining<=0 and controller.shoot_ability.rounds_remaining==0 and controller.shoot_ability.behavior().phase!=&"beam":break
			await tick()
		check(motor.weapon_apex_remaining>0 and motor.normal_velocity.y==0,"%s clears latent fall at end %sHz" % [id,hz])
		var endpoint := motor.position.y
		await tick();check(motor.normal_velocity.y==0 and is_equal_approx(motor.position.y,endpoint),"first post-recoil tick stays at apex")
		await tick(ceili(.3/dt));check(motor.normal_velocity.y>0 and motor.normal_velocity.y<motor.tuning.gravity*.3+1,"apex resumes bounded ordinary fall")
func hook_assist(hz: int) -> void:
	for side: int in [-1,1]:
		await fixture(Vector2(100,100));controller.traversal.grant(&"grapple")
		var anchor := GrappleAnchor.new();anchor.position=Vector2(100-side*260,114);world.add_child(anchor);await physics_frame
		controller.router.activate_device(&"gamepad");controller.router.set_aim(&"gamepad",Vector2(-side,0),true);await tick()
		check(controller.traversal.guide_active and controller.traversal.guide_target_valid,"guide uses expanded head near-miss probe")
		controller.router.request_action(&"grapple",Vector2(-side,0))
		var launched := false
		for i: int in ceili(1.1/dt):
			await tick()
			if controller.traversal.state==&"hook_kick":
				launched=true
				check(signf(motor.velocity.x)==side and motor.velocity.y<0 and absf(absf(motor.velocity.x)+motor.velocity.y)<.1,"hook launch is physical 45 degrees toward incoming side")
				break
		check(launched,"slightly missed center is captured and actually pulled")
	await fixture(Vector2(100,100));controller.traversal.grant(&"grapple")
	body(Rect2(220,-100,20,400));var behind := GrappleAnchor.new();behind.position=Vector2(260,94);world.add_child(behind);await physics_frame
	controller.router.activate_device(&"gamepad");controller.router.set_aim(&"gamepad",Vector2.RIGHT,true);await tick()
	check(controller.traversal.guide_active and not controller.traversal.guide_target_valid and controller.traversal.guide_point.x<=220.1,"assist cannot highlight a target behind a wall")
	controller.router.request_action(&"grapple",Vector2.RIGHT);await tick(ceili(.6/dt))
	check(motor.position.x<208 and controller.traversal.state==&"free","expanded head cannot pull through a wall")
	await fixture(Vector2(100,100));controller.traversal.grant(&"grapple")
	controller.router.request_action(&"grapple",Vector2.UP)
	var retract_ticks := 0;var saw_fly := false;var saw_retract := false;var furthest := 0.0;var initial_retract_length := 0.0
	for i: int in ceili(.8/dt):
		await tick();var traversal := controller.traversal
		saw_fly=saw_fly or traversal.state==&"hook_fly"
		if traversal.state in [&"hook_fly",&"hook_miss"]:furthest=maxf(furthest,traversal.hook_start.distance_to(traversal.hook_tip))
		if traversal.state==&"hook_retract":
			if not saw_retract:initial_retract_length=traversal.hook_tip.distance_to(motor.position+Vector2(0,-6))
			saw_retract=true;retract_ticks+=1
		if saw_retract and traversal.state==&"free":break
	check(saw_fly and saw_retract and furthest<=controller.traversal.definition.hook_range+.1,"miss extends visibly and never exceeds finite range")
	var safe_reel_time := initial_retract_length/(controller.traversal.definition.hook_return_speed-motor.tuning.max_normal_fall_speed)+dt
	check(retract_ticks*dt<=safe_reel_time+.001 and controller.traversal.state==&"free" and controller.traversal.hook_used,"miss retracts fast without refunding air hook %s ticks=%s state=%s used=%s" % [hz,retract_ticks,controller.traversal.state,controller.traversal.hook_used])
func touch(overlay: TouchOverlay,index: int,point: Vector2,pressed: bool) -> void:
	var event := InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=pressed;overlay.handle_touch(event)
func shared_skill_aim() -> void:
	await fixture();equip_id("blade_bloom")
	var pad := GamepadAdapter.new();pad.router=controller.router;world.add_child(pad);pad.set_physics_process(false)
	for i: int in 6:pad.sample_tick(Vector2.ZERO,Vector2(1,-1))
	pad.sample_tick(Vector2.ZERO,Vector2(1,-1),false,false,false,true)
	var actions := controller.router.consume_actions(100000)
	check(actions.size()==1 and actions[0].type==&"weapon_skill" and actions[0].direction.distance_to(Vector2(1,-1).normalized())<.01,"gamepad skill uses main right stick")
	for i: int in 6:pad.sample_tick(Vector2.ZERO,Vector2.ZERO)
	check(controller.router.consume_actions(100001).is_empty(),"skill aim neutral does not emit primary")
	for i: int in 6:pad.sample_tick(Vector2.ZERO,Vector2.LEFT)
	for i: int in 6:pad.sample_tick(Vector2.ZERO,Vector2.ZERO)
	actions=controller.router.consume_actions(100002)
	check(actions.size()==1 and actions[0].type==&"shoot_release","next fresh gamepad aim still fires after skill")
	await fixture();equip_id("blade_bloom");controller.router.weapon_skill_available=true
	var overlay := TouchOverlay.new();overlay.router=controller.router;overlay.aim_origin=motor;world.add_child(overlay);overlay.set_enabled(true)
	touch(overlay,3,overlay.right_center,true)
	var drag := InputEventScreenDrag.new();drag.index=3;drag.position=overlay.right_center+Vector2(-60,-40);overlay.handle_touch(drag)
	var aim := controller.router.aim_direction
	var keyboard := motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
	var synthetic := InputEventMouseMotion.new();synthetic.device=0;synthetic.position=Vector2(400,200);synthetic.relative=Vector2(2,1)
	await create_timer(float(InputRouter.TOUCH_MOUSE_GUARD_USEC)/1000000+.05).timeout
	keyboard._unhandled_input(synthetic)
	check(controller.router.current_device==&"touch" and controller.router.aim_direction==aim,"browser device-0 mouse cannot steal active touch main aim")
	touch(overlay,4,overlay.skill_center,true);touch(overlay,4,overlay.skill_center+Vector2(20,0),false)
	actions=controller.router.consume_actions(100000)
	check(actions.size()==1 and actions[0].type==&"weapon_skill" and actions[0].direction.distance_to(aim)<.01,"touch skill button uses main shoot rod, ignores button drag direction")
	touch(overlay,3,drag.position,false)
	check(controller.router.consume_actions(100001).is_empty(),"touch aim release after skill never emits primary")
	keyboard._unhandled_input(synthetic)
	check(controller.router.current_device==&"touch","post-release browser mouse cannot reclaim immediately")
	await create_timer(float(InputRouter.TOUCH_MOUSE_GUARD_USEC)/1000000+.05).timeout
	keyboard._unhandled_input(synthetic)
	check(controller.router.current_device==&"keyboard_mouse","genuine later mouse movement can switch devices again")
	controller.router.clear("pause");check(controller.router.skill_direction()==Vector2.UP,"pause clears stale skill direction")
func laser_skill_preserved() -> void:
	await fixture(Vector2(100,-1000));await tick();equip_id("laser_cannon")
	controller.combat_energy.current=controller.shoot_ability.weapon.skill_cost
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,true);await tick(5)
	controller.router.request_action(&"weapon_skill",Vector2.RIGHT);await tick()
	check(controller.shoot_ability.behavior().phase==&"charge" and controller.combat_energy.current==0,"valid main-aim skill takes over laser primary with separate atomic cost")
	var beam_ticks := 0;var shot_seen := false
	for i: int in 60:
		await tick()
		if controller.shoot_ability.behavior().phase==&"beam":beam_ticks+=1
		if motor.recoil_burst_remaining>0:shot_seen=true
	check(shot_seen and beam_ticks==0,"Lv3 active remains instant cannon burst, never sustained primary")

func drawing_read_only()->void:
	# Explicit presentation boundary, not an input-driven player route.
	await fixture(Vector2(100,-1000));await tick();equip_id("sustained_laser")
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,true);await tick(8)
	var visual := motor.get_node("CourierVisual") as CourierVisual
	visual.set_aim_direction(Vector2.LEFT);visual.set_facing(-1);visual._process(0)
	var arm_before := visual.arm.transform
	var serial_before := controller.shoot_ability.behavior()._entity_serial
	var at := motor.position
	var balance := controller.actor_resources.stamina.current
	var runtime := controller.shoot_ability.behavior()
	for i: int in 4:
		runtime.beam_visual_segment();visual.visible_muzzle_position()
	check(visual.aim_direction==Vector2.LEFT and visual.facing==-1 and visual.arm.transform==arm_before,"drawing and diagnostics never prepare/repaint aim or facing")
	check(runtime._entity_serial==serial_before and motor.position==at and controller.actor_resources.stamina.current==balance,"drawing cannot create receipts, movement or resource transactions")

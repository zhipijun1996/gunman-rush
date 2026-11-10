extends "res://tests/world/plains_intro.gd"
var combat: RefCounted
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://wake_wall_isolated.json";root.add_child(app)
	await load_review("P-R03")
	var body:=PlayerPresentationRuntime.current_body(app.player)
	check(body.authored_pose.waking and body.rotation==0,"formal P03 begins authored prone pose without rotating body")
	var paused_age:=body.authored_pose.age
	paused=true;await ticks(12)
	check(is_equal_approx(body.authored_pose.age,paused_age),"pause freezes authored wake timeline")
	paused=false
	var frames: Dictionary={}
	for i: int in 130:
		frames[body.authored_pose.frame]=true
		await ticks(1)
		if app.introduction.dialogue_active:break
	check(frames.has(0) and frames.has(3) and frames.has(7),"wake reaches prone, hands/knee support and standing frames")
	check(app.introduction.dialogue_active and not app.controller.shoot_ability.enabled,"wake ends in dialogue without granting gun")
	app.introduction.advance()
	for direction: int in [-1,1]:
		app.controller.router.set_camera_look(&"keyboard_mouse",direction)
		await ticks(4)
		check(body.authored_pose.frame<12,"look animation waits for actual camera acceptance")
		await ticks(40)
		check(app.camera.looking and body.authored_pose.frame in ([13,14] if direction<0 else [16,17]),"camera accepts matching authored look pose "+str(direction))
		app.controller.router.set_camera_look(&"keyboard_mouse",0)
		await ticks(12)
		check(body.authored_pose.frame<12,"release returns from look to ordinary pose")
	app.controller.router.set_aim(&"keyboard_mouse",Vector2.UP,true)
	app.controller.router.set_camera_look(&"keyboard_mouse",-1)
	await ticks(45)
	check(not app.camera.looking and body.authored_pose.frame<12,"upward aim cannot trigger looking pose")
	app.controller.router.clear("look test done")
	app.controller.router.set_camera_look(&"keyboard_mouse",-1);await ticks(40)
	app.controller.router.request_action(&"jump");await ticks(2)
	check(not app.camera.looking and body.authored_pose.frame<12,"jump immediately cancels look pose")
	body.authored_pose.begin_wake(app.controller);app.controller.session_id+=1;await ticks(2)
	check(not body.authored_pose.waking,"actor epoch change clears stale wake pose")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
	combat=preload("res://tests/combat_tests.gd").new();combat.tree=self
	for side: int in [1,-1]:
		await combat.fixture(Vector2(80,0));combat.world.get_child(0).free()
		var actor: PlayerController=combat.controller
		actor.air_focus_ability.enabled=false
		actor.traversal.grant(&"wall_climb")
		combat.body(Rect2(100 if side==1 else 36,-600,24,1800))
		actor.router.set_move_axis(side)
		for i:int in 60:
			await combat.ticks(1)
			if actor.traversal.state==&"wall_attach":break
		check(actor.traversal.state==&"wall_attach","real inward contact attaches on side "+str(side))
		var start_y:float=actor.motor.position.y
		await combat.ticks(8)
		check(absf(actor.motor.position.y-start_y)<.01,"first wall contact holds falling body")
		await combat.ticks(22)
		var early:float=actor.motor.velocity.y
		check(early>0 and early<5,"early slide remains slow "+str(early))
		await combat.ticks(50)
		var middle:float=actor.motor.velocity.y
		await combat.ticks(60)
		check(middle>early and actor.motor.velocity.y>middle and actor.motor.velocity.y<=75.01,"slide accelerates continuously to existing cap")
		actor.traversal.on_weapon_fired();await combat.ticks(1)
		check(actor.motor.wall_slide_limit>70,"same-wall pose cancellation does not refresh hold")
		actor.router.request_action(&"jump");await combat.ticks(1)
		check(actor.motor.velocity.y<0 and actor.motor.velocity.x*side<0,"wall jump responds immediately from accelerated slide")
	combat.world.free();await ticks(2)
	print("WAKE WALL: ",failures," failures");quit(failures)

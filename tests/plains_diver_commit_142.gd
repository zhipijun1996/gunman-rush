extends "res://tools/art/capture_plains_enemy_context.gd"
## Real formal Actor AI/physics. Target positions/frozen player and late wall are explicit fixtures.
var checks:=0
var failures:=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("DIVER COMMIT FAILURE: ",label)
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://diver_commit_142.json";app.settings_path="user://diver_commit_settings.json"
	root.add_child(app);app.start_new();await settle();app.load_room("P-R06","");await settle()
	app.player.set_physics_process(false)
	app.controller.set_physics_process(false)
	for scenario: Dictionary in [
		{"player":Vector2(1170,878),"enemy":Vector2(1290,760),"dodge":false,"wall":false},
		{"player":Vector2(1290,878),"enemy":Vector2(1170,760),"dodge":true,"wall":false},
		{"player":Vector2(1170,710),"enemy":Vector2(1290,830),"dodge":false,"wall":false},
		{"player":Vector2(1170,878),"enemy":Vector2(1290,760),"dodge":false,"wall":true}]:
		app.player.reset_at(scenario.player)
		var body:=EnemyFactory.create_for_behavior(&"diver");body.position=scenario.enemy;app.room.add_child(body)
		var actor:=body.get_node("Actor") as EnemyActor
		actor.bind_encounter(app.controller,app.policy,app.lifetime,&"diver_commit",[])
		var behavior:=actor.attack_behavior
		for frame: int in 180:
			await physics_frame
			if behavior.state==&"telegraph":break
		check(behavior.state==&"telegraph","real AI enters readable warning")
		var locked: Vector2=behavior.attack_goal
		print("LOCK ",scenario," actual=",app.player.global_position," goal=",locked)
		check(locked.is_equal_approx(scenario.player),"warning locks actual player XY, without patrol clamp or fixed nest depth")
		if scenario.dodge:app.player.global_position+=Vector2(-100,-100)
		for frame: int in 100:
			await physics_frame
			if behavior.state==&"attack":break
		check(behavior.state==&"attack","warning reaches a real committed attack")
		var origin:=body.global_position
		var wall: StaticBody2D
		if scenario.wall:
			wall=StaticBody2D.new();wall.position=origin.lerp(locked,.5)
			var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(14,200);collision.shape=shape;wall.add_child(collision);app.room.add_child(wall)
		var finish:=[Vector2.INF]
		behavior.state_changed.connect(func(state: StringName)->void:
			if state==&"recovery" and not (finish[0] as Vector2).is_finite():finish[0]=body.global_position)
		var straight:=true
		for frame: int in 90:
			await physics_frame
			check(behavior.attack_goal==locked,"committed target is not retargeted after player moves")
			if behavior.state==&"recovery":break
			straight=straight and absf((body.global_position-origin).cross((locked-origin).normalized()))<.1
		check(straight,"real movement stays on the warned straight line")
		check((finish[0] as Vector2).is_finite(),"attack completes or is blocked within its authored duration")
		print("FINISH ",origin," -> ",finish[0]," target=",locked)
		if scenario.wall:
			check((finish[0] as Vector2).distance_to(locked)>20 and body.global_position.x>wall.global_position.x,"late solid obstruction stops the dive instead of tunnelling")
			wall.queue_free()
		elif scenario.dodge:
			check((finish[0] as Vector2).distance_to(locked)<.2,"when player dodges away, full dive reaches the original locked point before recovery")
		else:
			var contact_bounds:=Rect2(locked-Vector2(27,35),Vector2(54,70))
			check(contact_bounds.has_point(finish[0]),"dive reaches the actual player collision body rather than stopping short in empty air")
		body.queue_free();await ticks(3)
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
	print("PLAINS DIVER COMMIT: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

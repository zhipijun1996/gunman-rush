extends SceneTree
## Explicit placement/damage fixtures isolate the user's lifetime and geometry counterexamples.
## The current plains_intro suite drives the real six-room route; Boss probes use explicit isolated fixtures.
var app: FixedWorldApp
var failures:=0
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print("DEMO CHECK ",ok," ",label)
	if not ok: failures+=1
func ticks(n: int) -> void:
	for i: int in n: await physics_frame
func settle() -> void:
	for i: int in 180:
		await physics_frame
		if not app.busy: return
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://world_demo_regressions.json"
	app.settings_path="user://world_demo_regressions_settings.json"
	for path: String in [app.save_path,app.settings_path]:
		for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R21","");await settle()
	var id:="P-R21:encounter:01"
	var enemy: EnemyActor=app.room.enemies[id]
	check(enemy.damageable.receive_damage({"event_id":"fixture_defeat","amount":99,"source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":enemy.damageable.actor_id,"target_epoch":enemy.damageable.damage_epoch}),"accepted enemy damage fixture enters actual frame arbitration")
	await ticks(180)
	var remains:=EnemyPresentationBinding.remains(enemy.motor.get_node("Presentation"))
	check(enemy.health.terminal and remains!=null and remains.visible and remains.settled,"real death leaves a visible settled corpse")
	var hp:=app.controller.actor_resources.health.current
	app.player.reset_at(enemy.motor.position);await ticks(100)
	check(app.controller.actor_resources.health.current==hp,"dead enemy cannot leave continuing contact damage")
	app.load_room("P-R01","INTRO-P24-P01:P-R01");await settle()
	app.load_room("P-R21","");await settle();await ticks(4)
	enemy=app.room.enemies[id]
	remains=EnemyPresentationBinding.remains(enemy.motor.get_node("Presentation"))
	check(enemy.health.terminal and remains.visible,"ordinary revisit restores the corpse without resurrecting the actor")
	app.load_room("P-R21","");await settle()
	id="P-R21:exit_right_guard";enemy=app.room.enemies[id]
	enemy.damageable.receive_damage({"event_id":"rest_fixture_defeat","amount":99,"source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":enemy.damageable.actor_id,"target_epoch":enemy.damageable.damage_epoch})
	await ticks(180)
	remains=EnemyPresentationBinding.remains(enemy.motor.get_node("Presentation"))
	var old_room:=app.room
	# Test-only rest anchor isolates deferred refresh in an occupied room.
	app.room.rest_point=app.room.start_point
	app.player.reset_at(app.room.rest_point);await ticks(3)
	app._interact();await ticks(4)
	for rest_tick:int in 300:
		if not is_instance_valid(app.rest_sequence) or not app.rest_sequence.active:break
		await ticks(1)
	check(app.room==old_room and enemy.health.terminal and remains.visible,"real rest interaction does not spawn a new enemy in the active room")
	app.load_room("P-R01","");await settle()
	app.load_room("P-R21","");await settle()
	check(not app.room.enemies[id].health.terminal,"leaving and re-entering applies the deferred new-cycle refresh")
	for room_id: String in app.content.data.rooms:
		app.load_room(room_id,"");await settle()
		for door: Dictionary in app.room.contract.doors:
			if door.target_implemented: continue
			check(not app.room.doors.any(func(d: Dictionary) -> bool: return d.id==door.id),"unbuilt connection stays data-only instead of a crowded fake exit")
			# Front entrances are interaction points, not holes through a boundary wall.
			if door.get("front_door",false):continue
			var p:=FixedWorldProvider.point(door.position_candidate.local_world_units)
			# Unbuilt external ports can be candidate coordinates inside/outside the
			# revised room; check the actual nearest same-facing sealed boundary.
			var nearest:=INF;var boundary_point:=p
			for edge:Dictionary in app.room.contract.world_geometry.boundary:
				if edge.side!=door.direction:continue
				var at:=Geometry2D.get_closest_point_to_segment(p,FixedWorldProvider.point(edge.from),FixedWorldProvider.point(edge.to))
				if at.distance_squared_to(p)<nearest:nearest=at.distance_squared_to(p);boundary_point=at
			p=boundary_point+(Vector2(16,0) if door.direction=="left" else Vector2(-16,0) if door.direction=="right" else Vector2(0,16) if door.direction=="up" else Vector2(0,-16))
			var query:=PhysicsPointQueryParameters2D.new();query.position=p;query.collision_mask=1
			var shares_live_passage:=app.room.doors.any(func(d:Dictionary)->bool:
				if d.direction!=door.direction:return false
				var at:=FixedWorldProvider.point(d.position_candidate.local_world_units)
				return absf(at.x-boundary_point.x)<1 and boundary_point.y>at.y-96 and boundary_point.y<at.y if d.direction in ["left","right"] else absf(at.y-boundary_point.y)<1 and absf(at.x-boundary_point.x)<64)
			if shares_live_passage:continue # Candidate adds no second opening.
			check(is_finite(nearest) and not app.get_world_2d().direct_space_state.intersect_point(query).is_empty(),"unbuilt exit has sealed actual boundary "+room_id+" "+str(door.id))

	preload("res://tests/world/authored_room_fixture.gd").install(app,"P-R14")
	app.load_room("P-R14","");await settle()
	var zoom:=app.camera.zoom
	app.player.reset_at(Vector2(1572,742));await ticks(6)
	check(app.room.battle_started and app.room.seals.all(func(s: StaticBody2D) -> bool: return s.collision_layer==1),"whole body entering the inner arena seals both entrances")
	check(app.camera.zoom==zoom and not app.camera.top_level,"Boss activation retains ordinary camera scale and following")
	app.player.reset_at(Vector2(1590,742));app.controller.router.set_source_axis(&"keyboard_mouse",1,true);await ticks(30);app.controller.router.clear("fixture_end")
	check(app.player.position.x<1632,"the actual inner-room seal prevents walking back to the outer approach")
	app.room.finish_battle();await ticks(3)
	check(app.room.seals.all(func(s: StaticBody2D) -> bool: return s.collision_layer==0),"committed victory opens the inner-room entrances")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	print("WORLD DEMO: %d assertions, %d failures" % [checks,failures]);quit(failures)

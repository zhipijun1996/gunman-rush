extends SceneTree
## Explicit placement/damage fixtures isolate the user's lifetime and geometry counterexamples.
## The separate first_loop suite still drives the unmodified real route and Boss combat.
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
	root.add_child(app);app.start_new();await settle()
	var id:="P-R03:practice:01"
	var enemy: EnemyActor=app.room.enemies[id]
	check(enemy.damageable.receive_damage({"event_id":"fixture_defeat","amount":99,"source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":enemy.damageable.actor_id,"target_epoch":enemy.damageable.damage_epoch}),"accepted enemy damage fixture enters actual frame arbitration")
	await ticks(180)
	var remains:=EnemyPresentationBinding.remains(enemy.motor.get_node("Presentation"))
	check(enemy.health.terminal and remains!=null and remains.visible and remains.settled,"real death leaves a visible settled corpse")
	var hp:=app.controller.actor_resources.health.current
	app.player.reset_at(enemy.motor.position);await ticks(100)
	check(app.controller.actor_resources.health.current==hp,"dead enemy cannot leave continuing contact damage")
	app.load_room("P-R01","START-P03-P01:P-R01");await settle()
	app.load_room("P-R03","");await settle();await ticks(4)
	enemy=app.room.enemies[id]
	remains=EnemyPresentationBinding.remains(enemy.motor.get_node("Presentation"))
	check(enemy.health.terminal and remains.visible,"ordinary revisit restores the corpse without resurrecting the actor")
	app.load_room("P-R06","room-link-139:P-R06");await settle()
	id="P-R06:charger:01";enemy=app.room.enemies[id]
	enemy.damageable.receive_damage({"event_id":"rest_fixture_defeat","amount":99,"source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":enemy.damageable.actor_id,"target_epoch":enemy.damageable.damage_epoch})
	await ticks(180)
	remains=EnemyPresentationBinding.remains(enemy.motor.get_node("Presentation"))
	var old_room:=app.room
	app.player.reset_at(app.room.rest_point);await ticks(3)
	app._interact();await ticks(4)
	check(app.room==old_room and enemy.health.terminal and remains.visible,"real rest interaction does not spawn a new enemy in the active room")
	app.load_room("P-R08","room-link-139:P-R08");await settle()
	app.load_room("P-R06","room-link-139:P-R06");await settle()
	check(not app.room.enemies[id].health.terminal,"leaving and re-entering applies the deferred new-cycle refresh")
	app.load_room("P-R06","room-link-139:P-R06")
	var low:=INF;var high:=-INF
	while app.busy:
		await physics_frame
		if app.room!=null and app.room.room_id=="P-R06": low=minf(low,app.player.position.y);high=maxf(high,app.player.position.y)
	check(app.player.is_on_floor() and high-low>12 and high-low<100,"upward passage uses a short physical hop onto the nearby support")
	hp=app.controller.actor_resources.health.current
	app.player.reset_at(Vector2(1200,798));await ticks(100)
	check(app.player.is_on_floor() and app.controller.actor_resources.health.current==hp,"ordinary bottom floor is safe away from the doorway")
	for room_id: String in app.content.data.rooms:
		app.load_room(room_id,"");await settle()
		for door: Dictionary in app.room.contract.doors:
			if door.target_implemented: continue
			check(not app.room.doors.any(func(d: Dictionary) -> bool: return d.id==door.id),"unbuilt connection stays data-only instead of a crowded fake exit")
			var p:=FixedWorldProvider.point(door.position_candidate.local_world_units)
			p+=Vector2(16,-48) if door.direction=="left" else Vector2(-16,-48) if door.direction=="right" else Vector2(0,16) if door.direction=="up" else Vector2(0,-16)
			var query:=PhysicsPointQueryParameters2D.new();query.position=p;query.collision_mask=1
			check(not app.get_world_2d().direct_space_state.intersect_point(query).is_empty(),"unbuilt exit is continuous physical wall/floor")
	app.load_room("P-R14","L02:P-R14");await settle()
	var zoom:=app.camera.zoom
	app.player.reset_at(Vector2(1390,654));await ticks(6)
	check(app.room.battle_started and app.room.seals.all(func(s: StaticBody2D) -> bool: return s.collision_layer==1),"whole body entering the inner arena seals both entrances")
	check(app.camera.zoom==zoom and not app.camera.top_level,"Boss activation retains ordinary camera scale and following")
	app.player.reset_at(Vector2(1418,654));app.controller.router.set_source_axis(&"keyboard_mouse",1,true);await ticks(30);app.controller.router.clear("fixture_end")
	check(app.player.position.x<1440,"the actual inner-room seal prevents walking back to the outer approach")
	app.room.finish_battle();await ticks(3)
	check(app.room.seals.all(func(s: StaticBody2D) -> bool: return s.collision_layer==0),"committed victory opens the inner-room entrances")
	app.queue_free();await ticks(5)
	print("WORLD DEMO: %d assertions, %d failures" % [checks,failures]);quit(failures)

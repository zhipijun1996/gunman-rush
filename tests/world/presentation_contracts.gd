extends SceneTree
## Placement fixtures isolate visible handoff/camera/hazard behavior; first_loop drives the real route.
var app: FixedWorldApp
var failures:=0
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print("PRESENTATION CHECK ",ok," ",label)
	if not ok: failures+=1
func ticks(n: int) -> void:
	for i: int in n: await physics_frame
func settle() -> void:
	for i: int in 180:
		await physics_frame
		if not app.busy: return
func key(code: Key,down: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down
	root.push_input(event,true)
func visible_motion(room_id: String,entry: String,axis: int) -> float:
	app.load_room(room_id,entry)
	var low:=INF;var high:=-INF
	while app.busy:
		await physics_frame
		if app.room.room_id==room_id and not app.ui.curtain.visible:
			low=minf(low,app.player.position[axis]);high=maxf(high,app.player.position[axis])
	return high-low if is_finite(low) else 0.0
func run() -> void:
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://world_presentation_test.json"
	app.settings_path="user://world_presentation_settings.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle()
	check(app.context_target().get("kind","")=="sign","starting notice board is reachable without floating instructions")
	key(KEY_UP,true);await ticks(3);key(KEY_UP,false);await ticks(2)
	check(app.paused and app.ui.page=="dialogue","real keyboard Up reads the notice board in a modal")
	key(KEY_ESCAPE,true);await ticks(2);key(KEY_ESCAPE,false);await ticks(3)
	check(not app.paused,"closing the board returns to clean movement")
	key(KEY_UP,true);await ticks(3);key(KEY_UP,false);await ticks(2)
	check(app.paused and app.ui.page=="dialogue","first Up after closing a modal is not swallowed by stale held-key state")
	key(KEY_ESCAPE,true);await ticks(2);key(KEY_ESCAPE,false);await ticks(3)
	var before:=app.camera.position.y
	var bottom:=app.player.position.y
	var top:=bottom
	key(KEY_SPACE,true);await ticks(4);key(KEY_SPACE,false)
	for i: int in 40:
		await physics_frame;top=minf(top,app.player.position.y)
	check(bottom-top>30 and absf(app.camera.position.y-before)<(bottom-top)*.5,"short physical jump stays inside camera buffer instead of dragging the view")
	check(app.camera.get_parent()==app,"camera is independent from character transforms")
	var walk:=await visible_motion("P-R01","INTRO-P24-P01:P-R01",0)
	check(walk>=12 and walk<=36,"horizontal entry visibly walks approximately one body width after reveal")
	var hop:=await visible_motion("P-R06","room-link-139:P-R06",1)
	check(hop>12 and hop<180 and app.player.is_on_floor(),"upward entry is a visible small physical hop ending on support")
	check(app.player.position.distance_to(app.entry_anchor)<4,"short upward hop lands beside the shaft on the authored safe ledge")
	var drop:=await visible_motion("P-R08","room-link-139:P-R08",1)
	check(drop>40 and drop<160 and app.player.is_on_floor(),"downward entry visibly falls onto safe support")
	check(app.player.position.distance_to(app.entry_anchor)<8,"downward entry finishes at its authored solid standing point")
	app.load_room("P-R12","");await settle()
	var hp:=app.controller.actor_resources.health.current
	app.player.reset_at(app.room.physical_action("pickup_EQ_MAP_P01").position);await ticks(5)
	check(app.player.is_on_floor() and app.controller.actor_resources.health.current==hp and app.context_target().get("kind","")=="action","collectible stands on its actual supported reward ledge")
	app.load_room("P-R25","");await settle()
	for actor: EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
	app.player.reset_at(Vector2(1024,878));await ticks(40)
	check(app.controller.actor_resources.health.current<hp,"visible thorn strip submits actual environmental damage")
	var rid:=UnderworldUI.icon(&"coil").get_rid()
	var stable:=true
	for i: int in 100: stable=stable and UnderworldUI.icon(&"coil").get_rid()==rid
	check(stable,"drawn atlas texture stays alive and is reused across redraws")
	app.load_room("P-R01","");await settle()
	var camera_before:=app.camera.position
	app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(25);app.controller.router.clear("camera_fixture")
	check(app.camera.position.distance_to(camera_before)<150,"station camera follows ordinary movement without a discontinuous jump")
	app.load_room("P-R14","L02:P-R14");await settle()
	app.room.encounter.set_physics_process(false)
	app.player.reset_at(Vector2(1452,742));await ticks(180)
	var half:=root.get_visible_rect().size/(2*app.camera.zoom)
	check(app.room.arena_bounds.grow(1).encloses(Rect2(app.camera.position-half,half*2)),"Boss inner room supplies the visible camera envelope after a smooth handoff")
	key(KEY_SPACE,true)
	var lowest_floor_visibility:=INF
	for i: int in 24:
		await physics_frame
		lowest_floor_visibility=minf(lowest_floor_visibility,app.camera.position.y+half.y)
	key(KEY_SPACE,false)
	check(lowest_floor_visibility>=app.room.arena_bounds.end.y-8,"Boss jump keeps receiving floor visible without changing zoom")
	await ticks(120)
	key(KEY_SPACE,true)
	var actor_in_frame:=true
	for i: int in 90:
		await physics_frame
		if i==12:app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
		var screen_feet:=app.player.global_position.y-app.camera.get_screen_center_position().y+half.y
		actor_in_frame=actor_in_frame and screen_feet>=float(app.camera.settings.arena_headroom)-2 and screen_feet<=half.y*2-float(app.camera.settings.arena_footroom)+2
	key(KEY_SPACE,false)
	check(actor_in_frame,"rapid arena jump plus downward recoil keeps the whole actor in the actual camera frame")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	print("WORLD PRESENTATION: %d assertions, %d failures" % [checks,failures]);quit(failures)

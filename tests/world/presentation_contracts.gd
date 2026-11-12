extends SceneTree
## Placement fixtures isolate visible handoff/camera/hazard behavior; plains_intro drives the current six-room route.
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
	root.add_child(app);await app.review.begin("P-R23","","base");await settle()
	app.player.reset_at(FixedWorldProvider.point(app.room.signs[0].point)+Vector2(0,30));await ticks(3)
	check(app.context_target().get("kind","")=="sign","authored notice board is reachable from its supported approach")
	key(KEY_UP,true);await ticks(3);key(KEY_UP,false);await ticks(2)
	check(app.paused and app.ui.page=="dialogue","real keyboard Up reads the notice board in a modal")
	key(KEY_ESCAPE,true);await ticks(2);key(KEY_ESCAPE,false);await ticks(3)
	check(not app.paused,"closing the board returns to clean movement")
	key(KEY_UP,true);await ticks(3);key(KEY_UP,false);await ticks(2)
	check(app.paused and app.ui.page=="dialogue","first Up after closing a modal is not swallowed by stale held-key state")
	key(KEY_ESCAPE,true);await ticks(2);key(KEY_ESCAPE,false);await ticks(3)
	# Camera behavior is covered by camera_controller/zones/motion, not legacy fixtures.
	var walk:=await visible_motion("P-R21","INTRO-P03-P21:P-R21",0)
	check(walk>=12 and walk<=36,"horizontal entry visibly walks approximately one body width after reveal")
	var hop:=await visible_motion("P-R24","INTRO-P23-P24:P-R24",1)
	check(hop>12 and hop<180 and app.player.is_on_floor(),"upward entry is a visible small physical hop ending on support")
	check(app.player.position.distance_to(app.entry_anchor)<4,"upward hop ends on its authored safe ledge")
	var drop:=await visible_motion("P-R22","INTRO-P21-P22:P-R22",1)
	check(drop>40 and drop<160 and app.player.is_on_floor(),"downward entry visibly falls onto safe support")
	check(app.player.position.distance_to(app.entry_anchor)<8,"downward entry ends at its authored solid standing point")
	var rid:=UnderworldUI.icon(&"coil").get_rid()
	var stable:=true
	for i: int in 100: stable=stable and UnderworldUI.icon(&"coil").get_rid()==rid
	check(stable,"drawn atlas texture stays alive and is reused across redraws")
	preload("res://tests/world/authored_room_fixture.gd").install(app,"P-R14")
	app.load_room("P-R14","");await settle()
	app.player.reset_at(Vector2(1572,350));await ticks(5)
	check(app.ui.mini.modulate.a<.2,"minimap yields contrast when the actual projected actor passes behind it")
	app._pause_world();app.ui.show_pause();app._update_hud()
	check(app.ui.mini.modulate.a==1,"paused UI restores full contrast without moving its input targets")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	print("WORLD PRESENTATION: %d assertions, %d failures" % [checks,failures]);quit(failures)

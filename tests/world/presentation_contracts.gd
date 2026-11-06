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
	var walk:=await visible_motion("P-R01","START-P03-P01:P-R01",0)
	check(walk>=12 and walk<=36,"horizontal entry visibly walks approximately one body width after reveal")
	var hop:=await visible_motion("P-R06","room-link-139:P-R06",1)
	check(hop>12 and hop<100 and app.player.is_on_floor(),"upward entry is a visible small physical hop ending on support")
	check(app.player.position.x<756 and app.player.position.x>732,"short upward hop lands beside the shaft on the authored safe ledge")
	var drop:=await visible_motion("P-R08","room-link-139:P-R08",1)
	check(drop>20 and drop<60 and app.player.is_on_floor(),"downward entry visibly falls onto safe support")
	app.load_room("P-R06","room-link-139:P-R06");await settle()
	var enemy: EnemyActor=app.room.enemies["P-R06:charger:01"]
	enemy.damageable.receive_damage({"event_id":"hazard_isolation","amount":99,"source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":enemy.damageable.actor_id,"target_epoch":enemy.damageable.damage_epoch})
	await ticks(120)
	var hp:=app.controller.actor_resources.health.current
	app.player.reset_at(Vector2(1040,613));await ticks(65)
	check(app.player.is_on_floor() and app.controller.actor_resources.health.current==hp and app.context_target().get("kind","")=="pickup","collectible stands on a supported safe ledge outside the thorn damage zone")
	app.player.reset_at(Vector2(924,596));await ticks(40)
	check(app.controller.actor_resources.health.current<hp,"visible thorn strip submits actual environmental damage")
	app.queue_free();await ticks(5)
	print("WORLD PRESENTATION: %d assertions, %d failures" % [checks,failures]);quit(failures)

extends "res://tests/world/plains35_fixture.gd"
## Actual gate state, story skip, hook contact and moving-enemy support.
func run() -> void:
	exercise_story=true
	root.size=Vector2i(1280,720)
	app=load("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://plains_story_hooks.json";root.add_child(app);app.workbench.enabled=true
	await load_room("P-R01")
	await fixture(Vector2(400,1262));await ticks(3)
	check(app.story.active and app.paused,"station briefing starts on safe approach")
	app.story.finish();await ticks(3)
	check(not app.paused and app.state.has("station_briefed") and not app.state.has("clockheart_briefed"),"skip commits only this conversation")
	var north_id:=""
	for door:Dictionary in app.room.doors:
		if door.target_room=="P-R08":north_id=door.id
	check(not north_id.is_empty() and not app.room.door_open.get(north_id,true),"skip station leaves north gate closed")
	check(app.story.figure.position.distance_to(Vector2(2112,384))<1,"guard stands at closed north exit")
	await load_room("P-R33");await ticks(5)
	if not app.story.active:await fixture(Vector2(200,558));await ticks(3)
	check(app.story.active,"clockheart first approach starts explanation")
	app.story.finish();await ticks(3)
	check(app.state.has("clockheart_briefed") and not app.paused,"clockheart skip saves north-route permission")
	var snapshot:=app.state.value.duplicate(true)
	check(app.state.valid(snapshot),"story receipts are valid durable state")
	var storage:=WorldSaveService.new();storage.configure("user://story_roundtrip.json",false,"story_roundtrip");storage.content_version=app.content.data.content_version
	check(storage.commit(snapshot,1),"story snapshot written through real save service")
	var restored:=FixedWorldState.new();restored.content=app.content;restored.storage=storage
	check(restored.restore() and restored.has("clockheart_briefed"),"clockheart permission survives disk reload")
	await app.load_room("P-R01","");await ticks(5)
	for door:Dictionary in app.room.doors:
		if door.target_room=="P-R08":check(app.room.door_open.get(door.id,false),"return from clockheart opens north gate")
	check(not app.story.figure.visible,"guard no longer blocks after clockheart")
	await load_room("P-R14","h")
	await hook(Vector2(1984,558),Vector2(1840,408),"P14 first stop anchor outside terrain")
	await fixture(Vector2(2192,366));app.controller.router.request_action(&"grapple",(Vector2(2304,264)-app.player.position-Vector2(0,-6)).normalized())
	var bounced:=false;var hung:=false
	for frame:int in 80:
		await ticks(1)
		bounced=bounced or app.controller.traversal.state in [&"hook_contact_kick",&"hook_kick"]
		hung=hung or app.controller.traversal.state==&"hook_hang"
	check(bounced and not hung,"open spring anchor bounces and never holds")
	await load_room("P-R15","h")
	await hook(Vector2(976,3758),Vector2(1136,3840),"P15 first stop anchor reachable from bank")
	await fixture(Vector2(1952,3918));await ticks(3)
	var zoom_before:=app.camera.zoom
	app._commit_action("repair_P");await ticks(4)
	check(app.story.active and app.state.has("clock_P"),"repair performance starts only after committed clock")
	await ticks(360)
	check((GameAudio.for_origin(app) as GameAudio).played.get(&"mechanism_bell",0)>0,"repair bell plays while world is paused")
	check(app.story.dialogue_active and app.camera.zoom==zoom_before,"repair reaches dialogue at constant zoom")
	check((app.room.get_node("RegionalArt") as PlainsRoomArt).repair_blend>.95,"repair restores regional light and vegetation")
	app.story.finish();await ticks(3)
	check(not app.paused and app.controller.active,"repair returns player control")
	await load_room("P-R26")
	await fixture(Vector2(1800,1518));await ticks(45)
	check(app.room.camera_concealers.secret.visible,"P26 chest hidden from main passage")
	app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(90);app.controller.router.clear("hidden entrance")
	check(not app.room.camera_concealers.secret.visible,"P26 walking through plants reveals chamber")
	await fixture(Vector2(2240,1518));app._commit_action("open_P26_hidden_chest");await ticks(3)
	var receipt_count:int=app.state.value.receipts.size();app._commit_action("open_P26_hidden_chest");await ticks(3)
	check(app.state.value.receipts.size()==receipt_count,"P26 chest cannot be reopened for duplicate coins")
	await fixture(Vector2(144,1518))
	var carrier:=app.room.get_node("Carrier0") as WorldMovingPlatform
	var rider:EnemyMotor=app.room.enemies["P-R26:lift_rider"].get_parent()
	carrier.motion_running=true
	var offset:=rider.position.y-carrier.position.y
	var supported:=true
	for frame:int in 240:
		await ticks(1)
		supported=supported and absf(rider.position.y-carrier.position.y-offset)<3
	check(supported and carrier.position.y<1300,"P26 ground enemy rides ascent without hovering")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
	print("STORY HOOKS: ",failures," failures");quit(failures)

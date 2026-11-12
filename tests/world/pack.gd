extends SceneTree
var app: FixedWorldApp
var failed := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	print("CHECK ",ok," ",text)
	if not ok: failed += 1
func ticks(n: int) -> void:
	for i: int in n: await physics_frame
func run() -> void:
	check(not FileAccess.file_exists("res://docs/bible/world_regions.json") and not FileAccess.file_exists("res://config/world/world.json"),"isolated pack has no docs or manual world source")
	app = preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path = "user://world_pack_test.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app)
	check(app.content.data.rooms.size()==43 and not app.content.room("Z-R01").is_empty(),"35 plains, clockheart and seven regional threshold contract load from exported bundle")
	for id: String in app.content.data.rooms:
		var request := LevelRequest.new()
		request.room_id = id
		check(not app.content.resolve(request).has("error"),"packed room resolves: "+id)
	await ticks(3)
	check(app.start_new(),"new game accepted")
	await ticks(40)
	check(app.room != null,"room loaded: "+app.status)
	if app.room != null:
		check(app.room.room_id=="P-R03" and app.player.is_on_floor(),"normal start grounded")
		print("PLAYER ",app.player.position," HP ",app.controller.actor_resources.health.current)
	for id: String in app.content.data.rooms:
		app.load_room(id,"")
		for i: int in 240:
			await physics_frame
			if not app.busy:break
		check(app.room!=null and app.room.room_id==id and app.controller.active,"packed room instantiates with native assets: "+id)
	await WorldAudioLifecycle.drain_world(app)
	app.queue_free()
	await ticks(4)
	print("WORLD PACK failures=",failed)
	quit(failed)

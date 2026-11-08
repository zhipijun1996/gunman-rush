extends SceneTree
## Presentation fixture: named camera positions, not a traversal proof.
var app: FixedWorldApp
func _initialize() -> void: run.call_deferred()
func ticks(n: int) -> void:
	for i: int in n:await physics_frame
func settle() -> void:
	for i: int in 240:
		await physics_frame
		if not app.busy:return
func run() -> void:
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://plains_visual_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle()
	DirAccess.make_dir_recursive_absolute("res://build/plains_rework/captures")
	var arguments:=OS.get_cmdline_user_args()
	for id: String in app.content.data.rooms:
		if not arguments.is_empty() and id not in arguments[0].split(","):continue
		app.load_room(id,"");await settle()
		if app.room.room_id!=id:printerr("CAPTURE LOAD FAILED ",id," ",app.status);quit(1);return
		app.set_physics_process(false);app.controller.active=false
		for actor: EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
		if app.room.encounter!=null:app.room.encounter.set_physics_process(false)
		var at:=app.room.start_point
		if not app.room.interaction_hosts.is_empty():at=app.room.interaction_hosts[0].position
		if id=="P-R01":at=Vector2(720,622)
		var focal: Dictionary={"P-R09":Vector2(1200,622),"P-R08":Vector2(912,1332),"P-R10":Vector2(784,1326),"P-R14":Vector2(1452,742),"P-R18":Vector2(1664,878),"P-R24":Vector2(1328,478),"P-R26":Vector2(480,1262),"P-R29":Vector2(768,942),"P-R33":Vector2(1840,878),"P-R34":Vector2(1840,388),"P-R35":Vector2(1424,142)}
		if focal.has(id):at=focal[id]
		if arguments.size()>2:at=Vector2(float(arguments[1]),float(arguments[2]))
		app.player.reset_at(at)
		app._update_hud()
		await ticks(60)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/plains_rework/captures/"+id+".png")
		if "--light-pair" in arguments:
			var art:=app.room.get_node("RegionalArt") as PlainsRoomArt
			art.set_process(false)
			art.ambient.color=Color.WHITE
			for node: Node in art.get_children():
				if node is Light2D:(node as Light2D).enabled=false
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/plains_rework/captures/"+id+"-unlit.png")
		if "--wind" in arguments:await ticks(360)
		print("CAPTURE ",id)
		app.set_physics_process(true)
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5);quit()

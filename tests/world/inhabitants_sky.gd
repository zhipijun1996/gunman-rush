extends "res://tests/world/approved_draft_actions.gd"
## Formal animal mappings and actual GPU cloud motion; no change to service owners.
func screen()->Image:
	await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run()->void:
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
	await load_room("P-R01")
	var state:=app.state.value.duplicate(true);state.flags.append("station_rest_taught");app.state.commit(state,app.state.revision)
	if app.story.active:app.story.finish()
	await fixture(Vector2(1024,1262));await ticks(90)
	var catalog:Dictionary=WorldSpriteAnimation.catalog
	for id:String in ["NPC_P_REC","NPC_P_WEAVER","NPC_G_SMITH","NPC_F_RANGER","NPC_S_APOTHECARY","NPC_C_KEEPER","NPC_K_KNIGHT","NPC_R_ARCHIVIST","NPC_A_TECH","NPC_V_OBSERVER","NPC_M_FORAGER","NPC_Y_SAILMERCHANT","NPC_N_RAILBROKER","NPC_E_SALVAGER","NPC_TRAVELER_AQI"]:
		check(str(catalog[WorldNpc.visual_for(id)].get("species","")) in ["badger","hare","fox","boar","owl"],id+" uses an animal resident")
	check(app.story.figure.asset_id=="clockkeeper","story keeper uses the same owl identity")
	for key:String in catalog:
		var spec:Dictionary=catalog[key]
		if spec.get("kind","")!="npc":continue
		var image:Image=(load("res://"+str(spec.image)) as Texture2D).get_image()
		for frame:int in 6:
			var part:=image.get_region(Rect2i(frame*64,0,64,64)).get_used_rect()
			check(part.end.y==60 and part.position.y>=0,key+" native frame foot stays on shared baseline")
	var art:=app.room.get_node("RegionalArt") as PlainsRoomArt
	check(art.sky_layers.clouds.size()==2,"two independent cloud layers behind fixed terrain")
	var land:Image=art.sky.texture.get_image()
	check(land.get_pixel(land.get_width()/2,10).a==0,"landscape has real transparent sky")
	var phase:=art.clock
	paused=true;await process_frame;await process_frame
	check(art.clock==phase,"cloud clock freezes with pause")
	paused=false;await ticks(4);check(art.clock>phase,"cloud clock resumes")
	app.set_physics_process(false);app.camera.set_physics_process(false);art.set_process(false)
	var at:=art.sky.position
	art.sky_layers.update_clock(0);var first:=await screen()
	art.sky_layers.update_clock(12);var second:=await screen()
	var changed:=0
	for y:int in range(130,260,2):
		for x:int in range(320,960,2):
			if first.get_pixel(x,y)!=second.get_pixel(x,y):changed+=1
	check(changed>150,"actual sky pixels move over twelve seconds")
	check(art.sky.position==at and art.sky.material is CanvasItemMaterial,"cloud motion does not warp or move land/tower")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
	print("INHABITANTS AND SKY: ",failures," failures");quit(failures)

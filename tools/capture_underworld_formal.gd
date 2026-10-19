extends SceneTree
## Real DemoApp rendering. Positioning is explicitly separate from traversal.
var app: DemoApp
var output := "res://build/underworld_plains/captures"
var map_index := 1
var moving := false
var seed_value := "level-design-v2-baseline/08"
var captures: Array[Dictionary] = []
var motion: Array[Dictionary] = []
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--map="): map_index=int(arg.trim_prefix("--map="))
		if arg.begins_with("--seed="): seed_value=arg.trim_prefix("--seed=")
		if arg=="--motion":moving=true
	root.size=Vector2i(1280,720)
	run.call_deferred()
func freeze_physics(node: Node) -> void:
	# Leave collision objects registered in their physics space. Disabling a
	# CollisionObject's process_mode would detach it while ALWAYS child actors
	# can still execute; stop callbacks recursively instead.
	node.set_physics_process(false)
	for child: Node in node.get_children(): freeze_physics(child)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	assert(app.start_plains(seed_value))
	for tick: int in 8:await physics_frame
	if map_index==2:
		app.director.stage_index=2;app._load_stage()
		for tick: int in 8:await physics_frame
	assert(app.stage is PlainsRegionStage and app.stage.assembly_ok)
	for name: String in ["KeyboardMouseAdapter","GamepadAdapter"]:
		app.player.get_node(name).process_mode=Node.PROCESS_MODE_DISABLED
	var stage:=app.stage as PlainsRegionStage
	var manifest_hash:=str(stage.generated.manifest.manifest_hash)
	var evidence:= {"seed":seed_value,"map":map_index,"manifest_hash":manifest_hash,"source_scope":"actual DemoApp normal formal consumers with real UI/actors/physics","motion":moving,"positioned_fixture":not moving or map_index==2,"traversal_claim":false,"captures":captures,"motion_frames":motion}
	if moving:
		var start:=app.player.global_position
		var initial_epoch:=app.lifetime.actor_epoch
		var held:=0
		for tick: int in 480:
			await RenderingServer.frame_post_draw
			if not is_instance_valid(app.player):break
			# Submit fresh intent after the expensive rendered frame, never alter
			# Router TTL, retain an old request, or write Motor transforms.
			app.controller.router.set_move_axis(1.0 if tick>45 else 0.0)
			if tick>45 and app.player.is_on_floor() and held==0:
				app.controller.router.set_jump_held(&"underworld_movie",true);held=15
			elif held>0:
				held-=1
				if held==0:app.controller.router.set_jump_held(&"underworld_movie",false)
			if tick%110==65:app.controller.shoot_ability.try_fire(Vector2.RIGHT,true)
			motion.append({"frame":tick,"position":[app.player.position.x,app.player.position.y],"actor_epoch":app.lifetime.actor_epoch,"health":app.controller.actor_resources.health.current,"jump_held":held>0,"parallax":(app.get_node("PixelPlainsParallax") as PixelPlainsParallax).measured_nodes()})
			await physics_frame
		evidence.start=[start.x,start.y];evidence.initial_epoch=initial_epoch
	else:
		# Static inspection keeps actual world objects and UI, while stopping
		# damage and actors so sequential positioning cannot kill the probe.
		freeze_physics(app)
		var points:Array[Dictionary]=[{"id":"spawn","position":stage.spawn}]
		var seen:Dictionary={}
		for area:Dictionary in stage.generated.manifest.areas:
			var role:=str(area.get("role",""))
			if role in ["junction","merchant","creek","challenge"] and not seen.has(role):
				seen[role]=true;points.append({"id":role,"position":Vector2(area.position[0],area.position[1])-Vector2(0,18)})
		for enemy:EnemyMotor in stage.enemies:
			var actor:=enemy.get_node("Actor") as EnemyActor
			var id:="enemy_"+str(actor.definition.behavior_id)
			if not seen.has(id):seen[id]=true;points.append({"id":id,"position":enemy.position-Vector2(130,0)})
		for module:PlatformingModule in stage.assembler.modules:
			if not module.definition.surface_thorns.is_empty():
				var thorn:=module.definition.surface_thorns[0]
				var danger:=thorn.danger(module.definition.platforms)
				points.append({"id":"integrated_thorns","position":module.position+danger.get_center()-Vector2(100,70)})
				break
		points.append({"id":"boss","position":Vector2(stage.boss_arena.position.x+210,stage.boss_arena.end.y-18)})
		for point:Dictionary in points:
			if not is_instance_valid(app.controller):break
			app.controller.return_to_segment(point.position)
			# The fixture froze callback physics, including the camera spring.
			# Use its real cut/limit operation for this positioned still.
			app._run_camera.snap_to_target()
			app._run_camera.force_update_scroll()
			for tick:int in 9:await physics_frame;await process_frame
			await RenderingServer.frame_post_draw
			var file:=output+"/map%d_%s.png"%[map_index,point.id]
			var error:=root.get_texture().get_image().save_png(file)
			assert(error==OK)
			captures.append({"id":point.id,"path":file,"sha256":FileAccess.get_sha256(file),"positioned_fixture":true,"traversal_claim":false,"camera_center":[app._run_camera.get_screen_center_position().x,app._run_camera.get_screen_center_position().y],"parallax":(app.get_node("PixelPlainsParallax") as PixelPlainsParallax).measured_nodes()})
	FileAccess.open(output+"/map%d_%s.json"%[map_index,"motion" if moving else "captures"],FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
	app.abandon_run()
	await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	for tick:int in 5:await process_frame
	print("UNDERWORLD_CAPTURE map=%d captures=%d frames=%d failures=0"%[map_index,captures.size(),motion.size()])
	quit()

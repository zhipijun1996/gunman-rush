extends "res://tools/spatial_golden_preview.gd"
## Actual PlayerMotor/Combat/Run entry. Optional bounded input-only traversal is
## an experiment, not a claim of route or artistic admission.
var variant := 0
var capture_output := ""
var route_id := ""
var route_frames: Array = []
var route_result: Dictionary = {}
var capture_rows: Array = []
var rejected := false

func _initialize() -> void:
	auto_accept_quit = false
	root.close_requested.connect(close_review)
	review_seed = "world-rebuild-01"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):review_seed = arg.trim_prefix("--seed=")
		elif arg.begins_with("--variant="):variant = int(arg.trim_prefix("--variant="))
		elif arg.begins_with("--capture-output="):capture_output = arg.trim_prefix("--capture-output=")
		elif arg == "--route=main":route_id = "main"
		elif arg == "--smoke-close":smoke_close = true
		else:push_error("Unsupported world rebuild argument: " + arg);quit(2);return
	if not capture_output.is_empty() and DisplayServer.get_name() == "headless":
		push_error("Rendered evidence requires a display");quit(2);return
	if smoke_close and (not route_id.is_empty() or not capture_output.is_empty()):
		push_error("Choose smoke close or actual capture/route");quit(2);return
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.title = "失序之钟 · 连续世界重建实验（未艺术准入）"
	if not capture_output.is_empty():
		if DirAccess.dir_exists_absolute(capture_output) or DirAccess.make_dir_recursive_absolute(capture_output) != OK:
			push_error("Capture refuses existing or unavailable directory");quit(2);return
	app = DemoApp.new()
	app.set_meta("plains_world_rebuild_candidate",true)
	app.set_meta("plains_world_rebuild_variant",variant)
	app.avatar_selection_id = "p1_girl"
	app.meta_persistence_enabled = false
	root.add_child(app)
	if not app.start_plains(review_seed):
		push_error("World rebuild start rejected");rejected = true;await close_review();return
	for unused: int in 180:
		await physics_frame
		await process_frame
		if not app._stage_pending and is_instance_valid(app.stage) and app.stage.has_method("get_world_rebuild_snapshot"):
			var snapshot: Dictionary = app.stage.call("get_world_rebuild_snapshot")
			if not snapshot.get("ready",false):
				push_error("World rebuild assembly rejected");rejected = true;await close_review();return
			# Same existing gravity-aware following camera; no actor relocation.
			app._run_camera.viewing_zoom = 1.25
			app._run_camera.zoom = Vector2.ONE * 1.25
			app._run_camera.force_update_scroll()
			for settle: int in 12:await physics_frame
			print("PLAINS WORLD REBUILD READY: ",JSON.stringify({"seed":review_seed,"variant":variant,"actual_bodies":snapshot.actual_collisions.size(),"actual_enemies":snapshot.actual_enemies,"legacy_modules":snapshot.legacy_modules,"formal_pool":false}))
			if smoke_close:await close_review();return
			await save_frame("normal_start")
			if not route_id.is_empty():
				await run_main_route()
				await save_frame("normal_route_end")
				await save_receipt()
				await close_review()
			elif not capture_output.is_empty():
				await save_receipt()
				await close_review()
			return
	push_error("World rebuild startup timeout");rejected = true;await close_review()

func run_main_route() -> void:
	var snapshot: Dictionary = app.stage.call("get_world_rebuild_snapshot")
	var route: Dictionary = {}
	for row: Dictionary in snapshot.world_plan.routes:
		if row.id == "main":route = row;break
	if route.is_empty():
		rejected = true
		route_result = {"passed":false,"reason":"missing_main_route"}
		return
	var points: Array = route.points.duplicate(true)
	# Actual return through the same continuous world, not reset to entry.
	for index: int in range(points.size()-2,-1,-1):points.append(route.points[index])
	var target_index := 1
	var jump_held_ticks := 0
	var shots := 0
	var initial_session := app.controller.session_id
	var initial_hp := app.controller.actor_resources.health.current
	var min_hp: float = initial_hp
	var timeout_ticks := 4200
	for tick_index: int in timeout_ticks:
		if closing or not is_instance_valid(app) or not is_instance_valid(app.player):return
		var motor: PlayerMotor = app.player
		var controller: PlayerController = app.controller
		var router: InputRouter = controller.router
		if controller.session_id != initial_session:
			route_result = {"passed":false,"reason":"actual_respawn_or_stage_change","target_index":target_index}
			break
		var target := Vector2(float(points[target_index][0]),float(points[target_index][1]))
		var at := motor.global_position
		if absf(target.x-at.x)<24 and absf(target.y-at.y)<45 and motor.is_on_floor():
			await save_frame("normal_waypoint_%02d" % target_index)
			target_index += 1
			if target_index >= points.size():
				route_result = {"passed":true,"reason":"actual_forward_and_return","visited_points":target_index,"shots_submitted":shots,"minimum_hp":min_hp,"final_hp":controller.actor_resources.health.current,"ticks":tick_index}
				break
			target = Vector2(float(points[target_index][0]),float(points[target_index][1]))
		var axis := clampf((target.x-at.x)/18.0,-1.0,1.0)
		router.set_move_axis(axis)
		var actions: Array = []
		if jump_held_ticks>0:
			jump_held_ticks -= 1
			if jump_held_ticks==0:router.set_jump_held(&"world_rebuild_trace",false);actions.append("jump_release")
		if motor.is_on_floor() and jump_held_ticks==0 and absf(axis)>.2:
			var query := PhysicsRayQueryParameters2D.create(at+Vector2(axis*38,-4),at+Vector2(axis*38,54),1,[motor.get_rid()])
			var front_floor := motor.get_world_2d().direct_space_state.intersect_ray(query)
			if front_floor.is_empty() or (target.y<at.y-26 and absf(target.x-at.x)<130):
				router.set_jump_held(&"world_rebuild_trace",true)
				jump_held_ticks = 9
				actions.append("jump")
		# Shoot at the existing enemy through the normal release action; no HP
		# injection, resource grants, actor moves or terminal actor shortcuts.
		if tick_index%20==0:
			for enemy: EnemyMotor in (app.stage as GeneratedDemoStage).enemies:
				var actor := enemy.get_node("Actor") as EnemyActor
				var delta := enemy.global_position-at
				if not actor.health.terminal and delta.length()<380 and absf(delta.y)<90:
					router.request_action(&"shoot_release",delta.normalized());shots += 1;actions.append("shoot_release");break
		min_hp = minf(min_hp,controller.actor_resources.health.current)
		route_frames.append({"tick":tick_index,"target_index":target_index,"position":[at.x,at.y],"velocity":[motor.velocity.x,motor.velocity.y],"floor":motor.is_on_floor(),"axis":axis,"actions":actions,"hp":controller.actor_resources.health.current,"shot_charges":controller.action_resources.shot_charges})
		await physics_frame
	if route_result.is_empty():route_result = {"passed":false,"reason":"bounded_input_driver_timeout","target_index":target_index,"ticks":timeout_ticks}
	app.controller.router.clear("world_rebuild_trace_finished")
	if not route_result.get("passed",false):rejected = true;push_error("World rebuild actual route failed: "+JSON.stringify(route_result))
	print("PLAINS WORLD REBUILD ROUTE: ",JSON.stringify(route_result))

func save_frame(label: String) -> void:
	if capture_output.is_empty():return
	for unused: int in 2:await process_frame
	await RenderingServer.frame_post_draw
	var path := capture_output.path_join(label+".png")
	var error := root.get_texture().get_image().save_png(path)
	var camera := app._run_camera
	capture_rows.append({"label":label,"path":path,"sha256":FileAccess.get_sha256(path),"error":error,"player_position":[app.player.global_position.x,app.player.global_position.y],"camera_position":[camera.global_position.x,camera.global_position.y],"zoom":[camera.zoom.x,camera.zoom.y],"normal_follow_camera":true})
	if error!=OK:rejected = true;push_error("World rebuild PNG failed")

func save_receipt() -> void:
	if capture_output.is_empty():return
	var receipt := {"kind":"actual_godot_world_rebuild_candidate_not_art_approved","seed":review_seed,"variant":variant,"source_commit":OS.get_environment("REGIONAL_SOURCE_COMMIT"),"screenshots":capture_rows,"route":route_result,"input_trace":route_frames,"actual":app.stage.call("get_world_rebuild_snapshot"),"scope":"Normal following camera and real PlayerMotor, existing enemy combat, no teleport/save writes; no art/user/device admission"}
	var file := FileAccess.open(capture_output.path_join("receipt.json"),FileAccess.WRITE)
	if file==null:rejected = true;push_error("Cannot save world rebuild receipt");return
	file.store_string(JSON.stringify(receipt)+"\n")
	file.close()

func close_review() -> void:
	if closing:return
	closing = true
	paused = true
	var released := true
	if is_instance_valid(app):
		if is_instance_valid(app.controller):app.controller.router.clear("review_close")
		for child: Node in app.get_children():
			if child is GameAudio:
				released = await preload("res://tools/observed_audio_teardown.gd").drain_service(child) and released
		app.queue_free()
		app = null
		await process_frame
		await process_frame
	if not released:push_error("World rebuild audio release timeout")
	quit(0 if released and not rejected else 2)

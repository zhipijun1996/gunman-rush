extends SceneTree
## Actual full game composition only. Explicit staged poses are NOT traversal evidence.
const AUDIO := preload("res://tests/audio_teardown.gd")
var output := "res://build/region_bible_v2/golden-first"
var rows: Array[Dictionary] = []
var failures: Array[String] = []
var compare_plains := false
var near_scene := false
var guardian_scene := false
var ecology_scenes := false
var thorn_scenes := false
var thorn_only := false
var ecology_seen: Dictionary = {}
const ECOLOGY_TYPES := ["charger","forest_seed_sentry","forest_lantern","forest_thread_spider","forest_bark_beetle","forest_swing_pod","forest_crossbranch","forest_bible_weaver"]

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg == "--compare-plains": compare_plains = true
		elif arg == "--near-scene": near_scene = true
		elif arg == "--guardian-scene": guardian_scene = true
		elif arg == "--ecology-scenes": ecology_scenes = true
		elif arg == "--thorn-scenes": thorn_scenes = true
		elif arg == "--thorn-only": thorn_scenes = true; thorn_only = true
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(output)
	if compare_plains: await capture_plains_reference()
	for index: int in [1,2]:
		var app := DemoApp.new()
		app.meta_persistence_enabled = false
		root.add_child(app)
		if not app.start_debug_region(&"thorn_forest",index,"forest-depth-hollow-00",ThornForestRegionGenerator.DEPTH_VERSION,"forest-bible-world-v15"):
			failures.append("debug_entry_rejected"); app.free(); continue
		for unused: int in 12: await physics_frame
		if not app.stage is ThornForestRegionStage or not app.stage.assembly_ok:
			failures.append("actual_stage_missing"); await AUDIO.drain_world(app); app.free(); continue
		var stage := app.stage as ThornForestRegionStage
		if not is_instance_valid(stage.forest_terrain) or not stage.forest_terrain is UnderworldTerrain:
			failures.append("shared_terrain_missing")
		var shots: Array = ["camp","R","bible_web_lower","bible_backbranch_reward","prep"] if index == 1 else ["boss"]
		if thorn_only: shots.clear()
		if near_scene and index == 1: shots.append("near_tree")
		if guardian_scene and index == 1: shots.append("boss")
		if ecology_scenes:
			for enemy: Dictionary in stage.enemy_manifest:
				var kind := str(enemy.behavior_id)
				if kind in ECOLOGY_TYPES and not ecology_seen.has(kind):
					shots.append("ecology_"+str(enemy.id)); ecology_seen[kind] = true
		if thorn_scenes:
			shots.append_array(["thorn_hollow","thorn_mouth","thorn_retired"] if index == 1 else ["thorn_elbow"])
		if not app.player.get_node_or_null("PixelPlainsActor") is UnderworldPlayer:
			failures.append("shared_courier_missing")
		if app.player.get_node("CourierVisual").visible or app.player.get_node("PlayerFeedback").visible:
			failures.append("duplicate_legacy_courier")
		for id: String in shots:
			var point := stage.spawn
			var found := id == "camp"
			var ecology: Dictionary = {}
			if id.begins_with("thorn_"):
				var m: Dictionary = stage.generated.manifest
				if id == "thorn_retired":
					var old: Array = m.thorn_surface_contract.retired_prototype.source_global_dangers[0]
					point = Vector2(float(old[0])+float(old[2])*0.5,float(old[1])-80.0); found = true
				elif id == "thorn_mouth":
					for surface: Dictionary in m.thorn_surfaces:
						if surface.face != "left": continue
						var rect: Array = surface.hazard_rect
						point = Vector2(float(rect[0])-30.0,float(rect[1])-35.0); found = true; break
				else:
					var first: Array = m.dangers[0]
					point = Vector2(float(first[0])+float(first[2])*0.5+100.0,float(first[1])+90.0); found = true
			elif id.begins_with("ecology_"):
				for enemy_index: int in stage.enemy_manifest.size():
					var enemy: Dictionary = stage.enemy_manifest[enemy_index]
					if str(enemy.id) != id.trim_prefix("ecology_"): continue
					var actor := stage.enemies[enemy_index].get_node("Actor") as EnemyActor
					point = actor.motor.global_position+Vector2(90,-4); found = true
					ecology = {"id":enemy.id,"behavior":String(actor.definition.behavior_id),"position":[actor.motor.global_position.x,actor.motor.global_position.y],"brain_direction":actor.brain.direction,"collision_size":[actor.definition.collision_size.x,actor.definition.collision_size.y],"terminal":actor.health.terminal,"grounded":actor.motor.is_on_floor()}
					break
			elif id == "near_tree":
				if is_instance_valid(stage.near_scenery) and not stage.near_scenery.placements.is_empty():
					var placement: Dictionary = stage.near_scenery.placements[0]
					var bounds: Array = placement.bounds
					point = Vector2(float(bounds[0])+float(bounds[2])+160.0,float(placement.foot[1])-18.0)
					found = true
			else:
				for area: Dictionary in stage.generated.manifest.areas:
					if str(area.id) == id:
						point = Vector2(area.position[0],area.position[1]); found = true; break
			if not found:
				failures.append("missing_golden_area:"+id); continue
			paused = true
			app.controller.router.clear("explicit_composition_fixture")
			app.player.global_position = point
			app._run_camera.snap_to_target()
			app._run_camera.force_update_scroll()
			stage.queue_redraw()
			if is_instance_valid(stage.near_scenery): stage.near_scenery.queue_redraw()
			if is_instance_valid(stage.ambience): stage.ambience.queue_redraw()
			app._process(0.0)
			for unused: int in 3: await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var name := "map%s_%s.png" % [index,id]
			var result := image.save_png(output+"/"+name)
			if result != OK: failures.append("png_write_failed:"+name)
			var near_audit: Dictionary = stage.near_scenery.position_audit() if is_instance_valid(stage.near_scenery) else {}
			rows.append({"image":name,"region":"thorn_forest","area":id,"map_index":index,"manifest_hash":stage.generated.manifest.manifest_hash,"layout":stage.generated.manifest.layout_version,"staged_pose":[point.x,point.y],"camera":[app._run_camera.get_screen_center_position().x,app._run_camera.get_screen_center_position().y],"size":[image.get_width(),image.get_height()],"shared_family":{"terrain":"UnderworldTerrain","body":"UnderworldPlayer","tile_px":UnderworldTerrain.specification().tile_px,"world_tile_wu":UnderworldTerrain.specification().world_tile_wu},"near_scenery":near_audit,"ecology":ecology,"thorn_surfaces":stage.generated.manifest.get("thorn_surfaces",[]).duplicate(true),"thorn_retirement":stage.generated.manifest.get("thorn_surface_contract",{}).duplicate(true),"purpose":"static full game art review; explicit pose assignment, no Motor/GUI/device proof"})
		paused = false
		app.lifetime.end()
		if not await AUDIO.drain_world(app): failures.append("audio_release")
		app.free()
		for unused: int in 3: await process_frame
	if ecology_scenes:
		for kind: String in ECOLOGY_TYPES:
			if not ecology_seen.has(kind): failures.append("missing_actual_ecology:"+kind)
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"actual_v15_full_game_static_composition_staged_poses","rows":rows,"failures":failures},"\t"))
	print("FOREST BIBLE GOLDEN: %s images / %s failures" % [rows.size(),failures.size()])
	quit(0 if failures.is_empty() and rows.size()==(2 if compare_plains else 0)+(0 if thorn_only else 6)+(1 if near_scene else 0)+(1 if guardian_scene else 0)+(ECOLOGY_TYPES.size() if ecology_scenes else 0)+(4 if thorn_scenes else 0) else 1)

func capture_plains_reference() -> void:
	for index: int in [1,2]:
		var app := DemoApp.new()
		app.meta_persistence_enabled = false
		root.add_child(app)
		if not app.start_debug_region(&"plains",index,"forest-style-continuity-reference"):
			failures.append("plains_reference_entry_rejected"); app.free(); continue
		for unused: int in 12: await physics_frame
		if not app.stage is PlainsRegionStage or not app.stage.assembly_ok:
			failures.append("plains_reference_stage_missing"); await AUDIO.drain_world(app); app.free(); continue
		paused = true
		app.controller.router.clear("explicit_composition_fixture")
		app.player.global_position = app.stage.spawn
		app._run_camera.snap_to_target()
		app._run_camera.force_update_scroll()
		app._process(0.0)
		for unused: int in 3: await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		var file := "plains_map%s_reference.png" % index
		if shot.save_png(output+"/"+file) != OK: failures.append("png_write_failed:"+file)
		rows.append({"image":file,"region":"windchime_plains","map_index":index,"manifest_hash":app.stage.generated.manifest.manifest_hash,"layout":app.stage.generated.manifest.get("layout_version",""),"content_version":app.stage.generated.manifest.version,"purpose":"same-source actual formal Plains style reference; explicitly staged static composition"})
		paused = false
		app.lifetime.end()
		if not await AUDIO.drain_world(app): failures.append("audio_release")
		app.free()
		for unused: int in 3: await process_frame

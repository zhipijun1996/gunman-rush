extends SceneTree
## Actual formal controls at camera extremes; catches the former bottom-slot crop.
var checks := 0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL "+label)
func run() -> void:
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_debug_region(&"plains",2,"level-design-v2-baseline/08"),"actual formal map2 starts")
	for i: int in 8:await physics_frame
	app.set_physics_process(false);app.player.set_physics_process(false)
	app._run_camera.set_process(false);app._run_camera.set_physics_process(false)
	var bottom_seen:=false
	var view:=app.get_viewport_rect()
	for screen_point: Vector2 in [Vector2(80,65),Vector2(80,650),Vector2(1180,65),Vector2(640,-300),Vector2(-400,900)]:
		var offset: Vector2=(view.size*.5-screen_point)/app._run_camera.zoom
		app._run_camera.position=app.player.global_position+offset
		app._run_camera.force_update_scroll()
		app._layout_region_hud()
		print("HUD_DIAG offset=%s center=%s player_screen=%s panel=%s touch=%s"%[offset,app._run_camera.get_screen_center_position(),app.player.get_canvas_transform()*app.player.global_position,app._hud_frame.position,app.overlay.enabled])
		await process_frame
		bottom_seen=bottom_seen or app._hud_frame.position.y>view.size.y*.5
		check(view.encloses(app._hud_frame.get_global_rect()),"whole panel in viewport offset%s"%offset)
		for node: Control in [app._title,app._hud,app._resources_hud.health_label,app._resources_hud.stamina_label,app._resources_hud._shots_label,app._resources_hud.combat_label,app._resources_hud.focus_label]:
			if node.is_visible_in_tree():check(view.encloses(node.get_global_rect()),"actual visible label in viewport %s offset%s"%[node.name,offset])
	check(bottom_seen,"actual blocker scoring exercised bottom layout")
	DirAccess.make_dir_recursive_absolute("res://build/fine_space_05")
	FileAccess.open("res://build/fine_space_05/hud_bounds.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"bottom_seen":bottom_seen,"scope":"Actual formal controls and camera diagnostics, not input/traversal/device acceptance"},"  "))
	app.abandon_run();await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	await process_frame
	print("FINE_HUD_BOUNDS checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

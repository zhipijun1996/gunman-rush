extends SceneTree
## Actual menu callbacks into App; native fixture, browser GUI is a separate check.
var assertions := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	for map_index: int in [1,2]:
		var app := DemoApp.new()
		app.meta_persistence_enabled = false
		root.add_child(app)
		app.menu.show_debug_regions()
		var chosen: Button
		for node: Node in app.menu.find_children("*","Button",true,false):
			if (node as Button).text == "FOREST EXPLORATION / MAP %s" % map_index: chosen = node as Button
		check(chosen!=null,"actual visible exploration entry exists for each map")
		if chosen!=null: chosen.pressed.emit()
		for unused: int in 10: await physics_frame
		check(app.stage is ThornForestRegionStage and app.stage.assembly_ok,"menu callback assembles real forest stage")
		if app.stage is ThornForestRegionStage and app.stage.assembly_ok:
			var m: Dictionary = app.stage.generated.manifest
			check(m.layout_version=="forest-branching-expedition-v16" and int(m.map_index)==map_index,"explicit exploration menu consumes new layout and selected actual map")
			check(m.geometry_instances.any(func(row: Dictionary) -> bool: return str(row.module_id)==("backlook_fruit_cache" if map_index==1 else "borrow_pod_crossing")),"actual new geometry is present beyond menu identity")
			check(app.controller.traversal.hook_enabled and not app.controller.traversal.wall_enabled and not app.controller.traversal.double_enabled,"preview grants only legal forest H")
			check(app.campaign.debug_entry and app.campaign.completed_regions.is_empty(),"preview fabricates no campaign clear")
			check(app._requested_forest_layout.is_empty(),"one entry request does not leak to subsequent run")
		check(ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT=="forest-bible-world-v15","published save/default contract stays explicit during candidate development")
		if not await load("res://tests/audio_teardown.gd").drain_world(app): failures += 1
		app.free()
	print("FOREST EXPLORATION MENU: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)

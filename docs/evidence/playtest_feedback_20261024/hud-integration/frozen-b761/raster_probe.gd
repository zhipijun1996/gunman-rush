extends SceneTree
## Actual production HUD raster ablation, not route/input/device acceptance.
var out_dir := "res://build/verification/hud-review-independent/raster-final"
var app: DemoApp
var hud: DemoGameHud
var target: SubViewport
var viewport_container: SubViewportContainer
var observations: Array[Dictionary] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):out_dir=argument.trim_prefix("--output=")
	root.size = Vector2i(1280,720)
	run.call_deferred()

func rect_values(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func snapshot(label: String) -> void:
	for unused: int in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	var image := target.get_texture().get_image()
	var path := out_dir+"/"+label+".png"
	var error := image.save_png(path)
	var widgets: Array[Dictionary] = []
	for widget: Control in hud.status_draw_controls():
		var row := {"name":str(widget.name),"type":widget.get_class(),"bounds":rect_values(widget.get_global_rect()),"notice":widget==hud._notice}
		if widget is Label:
			row["text"] = (widget as Label).text
			row["font_size"] = widget.get_theme_font_size("font_size")
			row["outline_size"] = widget.get_theme_constant("outline_size")
			row["native_text_width"] = widget.get_theme_font("font").get_string_size((widget as Label).text,HORIZONTAL_ALIGNMENT_LEFT,-1,widget.get_theme_font_size("font_size")).x
			row["global_scale"] = [absf(widget.get_global_transform().get_scale().x),absf(widget.get_global_transform().get_scale().y)]
		widgets.append(row)
	observations.append({"label":label,"path":path,"save_error":error,"image_size":[image.get_width(),image.get_height()],"rows_bounds":rect_values(hud._rows.get_global_rect()),"vitals_bounds":rect_values(hud._vitals.get_global_rect()),"resonance_bounds":rect_values(hud.resonance.get_global_rect()),"widgets":widgets})
	print("HUD RASTER "+label+" saved="+str(error))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	app=DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	if not app.start_debug_region(&"plains",2,"level-design-v2-baseline/08"):
		printerr("Cannot start actual formal consumer")
		quit(1)
		return
	for unused: int in 120:
		await physics_frame
		await process_frame
		if is_instance_valid(app.player) and app.stage is PlainsRegionStage and not app._stage_pending:
			break
	if not (is_instance_valid(app.controller) and app.stage is PlainsRegionStage):
		printerr("Formal consumer not ready")
		quit(1)
		return
	hud=app._demo_hud
	app.process_mode=Node.PROCESS_MODE_DISABLED
	target=SubViewport.new()
	target.size=Vector2i(1280,720)
	target.world_2d=World2D.new()
	target.transparent_bg=false
	target.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport_container=SubViewportContainer.new()
	viewport_container.size=Vector2(1280,720)
	root.add_child(viewport_container)
	viewport_container.add_child(target)
	hud.reparent(target)
	hud.process_mode=Node.PROCESS_MODE_DISABLED
	hud.present_context("风铃平原 · 2/2",0,0,false)
	hud.show()
	hud._notice.hide()
	# Old layout uses the original source's two EXPAND_FILL flags only.
	hud._vitals.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud.resonance.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	await snapshot("before-quiet")
	hud._rows.hide()
	await snapshot("without-status")
	hud._rows.show()
	hud._vitals.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	hud.resonance.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	await snapshot("after-quiet")
	# Exercise the real production notification method, without claiming damage.
	hud._notify("受伤 -1",Color.WHITE)
	hud._notice.show()
	await snapshot("after-notice")
	hud._rows.hide()
	await snapshot("without-status-notice")
	var source_hashes := {}
	for path: String in ["res://scripts/demo/demo_app.gd","res://scripts/ui/demo_ui_01/game_hud.gd","res://tests/plains_redesign_scene_runner.gd","res://tests/underworld_plains/test_fine_hud_bounds.gd"]:
		source_hashes[path]=FileAccess.get_sha256(path)
	var report := {"scope":"Actual formal-bound production GameHud raster in isolated SubViewport. Runtime flags restore old EXPAND for before; no source replacement. This is HUD ink/bounds proof, not gameplay, route, player or physical-device acceptance.","engine":Engine.get_version_info().string,"rendering_method":RenderingServer.get_current_rendering_method(),"observations":observations,"sources":source_hashes,"actor_bound":hud.actor==app.controller,"actual_stage":app.stage.get_class()}
	var file:=FileAccess.open(out_dir+"/probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	hud.reparent(app._canvas)
	# Keep the world frozen; resume only audio owners so disabled parents do
	# not leave paused mixer voices unable to consume their queued release.
	for group: StringName in [&"game_audio",&"game_music"]:
		for service: Node in get_nodes_in_group(group):
			if app.is_ancestor_of(service):service.process_mode=Node.PROCESS_MODE_ALWAYS
	for voice: Node in app.find_children("*","AudioStreamPlayer2D",true,false):
		voice.process_mode=Node.PROCESS_MODE_ALWAYS
	await process_frame
	var released: bool = await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	viewport_container.queue_free()
	await process_frame
	print("HUD RASTER PROBE COMPLETE")
	quit(0 if released else 1)

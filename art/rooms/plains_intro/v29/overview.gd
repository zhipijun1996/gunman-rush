extends SceneTree
## One draw of the actual room in a native-size offscreen viewport. This works
## for tall rooms even when the monitor is shorter than the world bounds.
const WORLD := preload("res://rooms/world/world.tscn")

func _initialize() -> void:
	capture.call_deferred()

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["P01","P02","P03"]:
		printerr("Expected a room ID and output PNG path.")
		quit(1)
		return
	var id := args[0]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var surface := SubViewportContainer.new()
	root.add_child(surface)
	surface.add_child(viewport)
	var host: WorldGameHost = WORLD.instantiate()
	viewport.add_child(host)
	if is_instance_valid(host.active) and id != host.active.room.room_id:
		host.enter_room(id,"d001" if id == "P02" else "d002")
	if not is_instance_valid(host.active) or host.active.room.room_id != id or not host.last_error.is_empty():
		printerr("Failed to open ",id,": ",host.last_error)
		surface.free()
		quit(1)
		return
	var bounds := FixedWorldProvider.rect(host.active_doc.bounds)
	var planned := FixedWorldProvider.rect(host.catalog.lookup("rooms",id).row.authoring.construction.bounds_world)
	if not bounds.is_equal_approx(planned):
		printerr(id," runtime bounds ",bounds," differ from the locked construction ",planned)
		await host.active.audio_service.shutdown()
		surface.free()
		quit(1)
		return
	# Fractional lower edges occupy the last raster row at native resolution.
	var raster_size := Vector2i(bounds.size.ceil())
	viewport.size = raster_size
	for layer: CanvasLayer in host.find_children("*","CanvasLayer",true,false):
		layer.hide()
	var survey := Camera2D.new()
	host.active.add_child(survey)
	survey.position = bounds.position + Vector2(raster_size)*0.5
	survey.make_current()
	survey.force_update_scroll()
	for i in 6: await physics_frame
	await RenderingServer.frame_post_draw
	var actual := viewport.get_texture().get_image()
	var aligned := viewport.get_canvas_transform() * bounds.position
	var err := ERR_INVALID_DATA
	if aligned.is_zero_approx() and actual.get_size() == raster_size and survey.zoom == Vector2.ONE:
		err = actual.save_png(args[1])
	if err == OK:
		print("V29_OVERVIEW ",id," bounds=",bounds," pixels=",actual.get_size()," camera=",survey.zoom)
	else:
		printerr("Invalid room framing or PNG output: ",args[1]," origin=",aligned," code=",err)
	await host.active.audio_service.shutdown()
	surface.queue_free()
	await process_frame
	await process_frame
	quit(0 if err == OK else 1)

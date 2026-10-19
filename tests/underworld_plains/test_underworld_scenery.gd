extends SceneTree
var checks := 0
var failures := 0
var receipts: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func run() -> void:
	# A literal SubViewport avoids the project Window's KEEP_ASPECT stretch
	# turning a requested 720x1280 window into a letterboxed 720x405 render.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = false
	camera.limit_left = -2000
	camera.limit_right = 18000
	camera.limit_top = -4000
	camera.limit_bottom = 5000
	world.add_child(camera)
	camera.make_current()
	var sky := UnderworldParallax.new()
	sky.configure(camera)
	viewport.add_child(sky)
	await process_frame
	for viewport_size: Vector2i in [Vector2i(1280,720), Vector2i(720,1280), Vector2i(1920,1080)]:
		viewport.size = viewport_size
		await process_frame
		for target: Vector2 in [Vector2(-8000,-8000), Vector2(0,0), Vector2(8192,1200), Vector2(11000,0), Vector2(24000,8000)]:
			camera.position = target
			camera.force_update_scroll()
			await process_frame
			sky._update()
			var actual := camera.get_screen_center_position()
			var sample := sky.measured_nodes()
			check(sample.size()==3, "three real independent rendered planes")
			for i: int in sample.size():
				var plane: Dictionary = sample[i]
				var coefficient: Array = plane.camera_coefficient
				check(absf(float(plane.unwrapped_offset[0]) + (actual.x-sky.origin.x)*float(coefficient[0]))<.02, "drift uses actual clamped Camera2D center")
				var strips: Array = plane.strips
				var size := viewport.get_visible_rect().size
				check(size==Vector2(viewport_size), "actual logical viewport equals requested aspect and dimensions")
				check(float(strips[0].x)<=0 and float(strips[-1].right)>=size.x, "horizontal viewport coverage at camera extremes and portrait")
				for n: int in 2:
					check(float(strips[n].right)>=float(strips[n+1].x)-.01, "adjacent strips have no geometric sampling gap")
					if i==0:
						check(bool(strips[n].mirrored)!=bool(strips[n+1].mirrored), "opaque far source edge meets its mirrored copy")
					else:
						check(not bool(strips[n].mirrored) and not bool(strips[n+1].mirrored) and float(strips[n].right)>float(strips[n+1].x), "transparent planes overlap original orientation without paired mirror landmarks")
				if i==0:
					check(float(plane.screen_position[1])<=0 and float(plane.screen_position[1])+float(plane.display_size[1])>=size.y, "opaque far sky covers complete vertical viewport")
				if i>0:
					check(float(coefficient[0])>float(sample[i-1].camera_coefficient[0]), "depth coefficients strictly ordered")
			check(sample[0].texture_sha256!=sample[1].texture_sha256 and sample[1].texture_sha256!=sample[2].texture_sha256, "different original painting bytes")
			receipts.append({"viewport": [viewport_size.x,viewport_size.y], "actual_viewport": [viewport.get_visible_rect().size.x,viewport.get_visible_rect().size.y], "scope":"explicit_component_subviewport_not_device_acceptance", "target": [target.x,target.y], "actual_center": [actual.x,actual.y], "layers": sample})
			if "--capture-scenery-limits" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				var path := "res://build/underworld_plains/parallax_"+str(viewport_size.x)+"x"+str(viewport_size.y)+"_"+str(int(target.x))+".png"
				var pixels := viewport.get_texture().get_image()
				check(pixels.get_size()==viewport_size, "actual captured PNG has requested landscape or portrait pixel dimensions")
				check(pixels.save_png(path)==OK, "actual GPU layer-limit capture saved")
	# Grounding, broad-bank rhythm and whole-object keepout are tested on actual
	# placement consumers, including order/partition metamorphic counterexamples.
	var solids: Array[Rect2] = [Rect2(0,600,5000,180),Rect2(1300,400,400,32)]
	var blocked: Array[Rect2] = [Rect2(1200,200,650,450)]
	var decor := UnderworldScenery.new()
	world.add_child(decor)
	decor.configure_geometry(solids,blocked,"actual-runtime-test")
	check(not decor.placements.is_empty(), "sparse actual props exist on broad banks")
	var expected := decor.placements.duplicate(true)
	for item: Dictionary in decor.placements:
		var edge: Vector4 = item.support_edge
		check(float(item.root_span[0])>=edge.x and float(item.root_span[1])<=edge.z, "full visible root fan fits exposed solid top")
		check(is_equal_approx(item.position.y,edge.y), "root anchors rest on actual solid top")
		for keepout: Rect2 in blocked: check(not item.bounds.grow(8).intersects(keepout), "whole prop respects gameplay keepout")
	check(decor.find_children("*","CollisionObject2D",true,false).is_empty(), "decor creates zero physics or damage bodies")
	var reverse := solids.duplicate()
	reverse.reverse()
	decor.configure_geometry(reverse,blocked,"actual-runtime-test")
	check(decor.placements==expected, "decoration invariant under solid-array reorder")
	decor.configure_geometry([Rect2(0,600,2400,180),Rect2(2400,600,2600,180),Rect2(1300,400,400,32)],blocked,"actual-runtime-test")
	check(decor.placements==expected, "union-equivalent module partition preserves macro composition")
	decor.configure_geometry(solids,[Rect2(-10000,-10000,40000,40000)],"actual-runtime-test")
	check(decor.placements.is_empty(), "fully protected gameplay admits no decoration")
	decor.configure_geometry([],[],"actual-runtime-test")
	check(decor.placements.is_empty(), "no static ground cannot produce floating rooted props")
	var file := FileAccess.open("res://build/underworld_plains/scenery_runtime_receipts.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":"underworld-scenery-runtime-test-v1","checks":checks,"failures":failures,"camera_samples":receipts,"decor_sample":expected},"\t"))
	file.close()
	sky.free()
	world.free()
	viewport.free()
	print("Underworld scenery: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

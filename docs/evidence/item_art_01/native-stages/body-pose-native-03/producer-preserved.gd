extends SceneTree
## Actual world consumers; presentation state/positions are explicit fixtures.
## This does not claim naturally earned evolution or accepted trap placement.
var checks := 0
var failures := 0
var output := "res://build/item_art_01/body-pose-probe"
var evidence: Array[Dictionary] = []
var registry: Dictionary
var calibration: Dictionary = {}
var same_pose_centers: Array[Vector2] = []
var isolated_renders: Array[Dictionary] = []

class Guides extends Node2D:
	var boxes: Array[Rect2] = []
	func _draw() -> void:
		for box: Rect2 in boxes: draw_rect(box,Color(.3,.5,.6,.65),false,.5)
		for center: Vector2 in [Vector2(80.25,50.25),Vector2(160.25,50.25),Vector2(240.25,50.25)]:
			draw_line(center-Vector2(2,0),center+Vector2(2,0),Color(.9,.25,.2),.5)
			draw_line(center-Vector2(0,2),center+Vector2(0,2),Color(.9,.25,.2),.5)
		draw_line(Vector2(60,132.25),Vector2(100,132.25),Color(.85,.7,.35),.5)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ITEM BODY POSE FAILURE: "+label)

func body(kind: StringName, origin: StringName, point: Vector2, radius: float, state := 0) -> ItemV5Entity:
	var node := ItemV5Entity.new()
	node.kind = kind
	node.evolved = state
	node.radius = radius
	node.position = point
	node.set_meta("item_definition_id",origin)
	root.add_child(node)
	return node

func clip_bounds(clip: StringName, point: Vector2, actual_material: Material) -> Dictionary:
	var texture := ItemArtLibrary.frame_texture(clip,0)
	if texture == null: return {}
	var image := texture.get_image()
	var used := image.get_used_rect()
	var row: Dictionary = registry.clips[String(clip)]
	var canvas := Vector2(float(row.world_size[0]),float(row.world_size[1]))
	var pivot := Vector2(float(row.pivot[0]),float(row.pivot[1]))
	var scale := canvas/Vector2(image.get_size())
	var projected := Rect2(Vector2(used.position)*scale-canvas*pivot,Vector2(used.size)*scale)
	var half_min := image.get_size()
	var half_max := Vector2i(-1,-1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x,y).a>.5:
				half_min.x = mini(half_min.x,x)
				half_min.y = mini(half_min.y,y)
				half_max.x = maxi(half_max.x,x)
				half_max.y = maxi(half_max.y,y)
	var half := Rect2i(half_min,half_max-half_min+Vector2i.ONE)
	var half_projected := Rect2(Vector2(half.position)*scale-canvas*pivot,Vector2(half.size)*scale)
	var result := {"clip":String(clip),"world_canvas":[canvas.x,canvas.y],"pivot":[pivot.x,pivot.y],"full_alpha_source_bbox":[used.position.x,used.position.y,used.size.x,used.size.y],"full_alpha_projected_bbox":[projected.position.x,projected.position.y,projected.size.x,projected.size.y],"half_alpha_source_bbox_diagnostic_only":[half.position.x,half.position.y,half.size.x,half.size.y],"half_alpha_projected_bbox_diagnostic_only":[half_projected.position.x,half_projected.position.y,half_projected.size.x,half_projected.size.y],"no_alpha_threshold_applied_to_render":true,"node_position":[point.x,point.y],"world_shader":(actual_material as ShaderMaterial).shader.resource_path,"source_bounds_not_raster_footprint":true}
	if calibration.has(String(clip)):
		var feature: Array = calibration[String(clip)].feature_anchor_source
		var offset := Vector2(feature[0],feature[1])*scale-canvas*pivot
		result["independent_measured_feature_source"] = feature
		result["measured_feature_world_offset"] = [offset.x,offset.y]
	return result

func source_bounds(node: ItemV5Entity) -> Dictionary:
	var clip := ItemArtLibrary.entity_clip(node.kind,node.get_meta("item_definition_id"),node.evolved)
	var result := clip_bounds(clip,node.position,node.material)
	if result.is_empty(): return {}
	result["legacy_progress_dots"] = node.evolved
	return result

func optical_center(image: Image) -> Dictionary:
	var total := Vector2.ZERO
	var count := 0
	# Independent actual raster landmark near real core, excluding the pendant.
	for y: int in range(189,214):
		for x: int in range(629,654):
			var color := image.get_pixel(x,y)
			if color.g>.2 and color.b>.25 and color.r<color.g*.8:
				total += Vector2(x+.5,y+.5)
				count += 1
	return {"pixels":count,"center_screen":[total.x/count,total.y/count] if count>0 else [],"definition":"actual rendered cyan RGB in25screenpx aperture around expected opticalcore; no sprite alpha altered"}

func capture(stem: String, nodes: Array[ItemV5Entity]) -> void:
	for unused: int in 6: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.get_size() == Vector2i(1280,720),"actual pose framebuffer dimensions "+stem)
	if image == null: return
	check(image.save_png(ProjectSettings.globalize_path(output).path_join(stem+".png")) == OK,"save actual rendered pose "+stem)
	var rows: Array = []
	for node: ItemV5Entity in nodes: rows.append(source_bounds(node))
	var record := {"file":stem+".png","poses":rows}
	if stem.begins_with("g19-same-pose-state-"):
		var optical := optical_center(image)
		record["actual_optical_core"] = optical
		check(int(optical.pixels)>0,"actual raster opticalcore is visible "+stem)
		if int(optical.pixels)>0: same_pose_centers.append(Vector2(optical.center_screen[0],optical.center_screen[1]))
	evidence.append(record)

func rank_pixels(image: Image, position: Vector2, radius: float) -> int:
	var count := 0
	var color := Color("d4ac64")
	var at := (position*4).round()
	# Full old detached-dot foot band for evolved2; color+opaque-alpha excludes
	# the original faint PNG fringe. This is the real submitted old rank tint.
	for y: int in range(roundi(at.y+(radius+2)*4),roundi(at.y+(radius+6)*4)):
		for x: int in range(roundi(at.x-6*4),roundi(at.x+6*4)):
			if image.get_pixel(x,y).is_equal_approx(color): count += 1
	return count

func isolated_complete_body(state: int, fallback := false) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.canvas_transform = Transform2D(0,Vector2.ZERO).scaled(Vector2.ONE*4)
	var node := ItemV5Entity.new()
	node.kind = &"growth_drone"
	node.evolved = state
	node.radius = float(ItemV5Entity.read_tuning().visual.drone_radius_px)
	node.position = Vector2(32.25,24.25)
	node.set_meta("item_definition_id",&"explicit_unmapped_fallback_fixture" if fallback else &"G19")
	viewport.add_child(node)
	for unused: int in 6: await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var used := image.get_used_rect()
	var opaque_rank := rank_pixels(image,node.position,node.radius)
	var stem := "legacy-fallback-rank-control" if fallback else "g19-total-visual-state-"+str(state)
	check(image.save_png(ProjectSettings.globalize_path(output).path_join(stem+".png")) == OK,"save isolated actual complete body "+stem)
	if fallback:
		check(opaque_rank>0,"real unmapped legacy renderer retains visible old rank dots as positive control")
	else:
		check(opaque_rank == 0,"actual authored variant omits detached old rank pixels in foot band "+str(state))
		check(used.size.x<=37*4 and used.size.y<=24*4,"actual complete rendered G19 alpha footprint fits37x24, including every submitted primitive "+str(state))
	isolated_renders.append({"file":stem+".png","actual_complete_alpha_bbox":[used.position.x,used.position.y,used.size.x,used.size.y],"actual_world_width_height":[used.size.x/4.0,used.size.y/4.0],"actual_opaque_old_rank_pixels":opaque_rank,"fallback_control":fallback,"actual_material":(node.material as ShaderMaterial).shader.resource_path,"scope":"actual complete real Node render on transparent independent viewport, not source-only projected bounds; explicit state fixture"})
	viewport.free()
	await process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless":
		check(false,"pose probe refuses headless/dummy image evidence")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.canvas_transform = Transform2D(0,Vector2.ZERO).scaled(Vector2.ONE*4)
	registry = JSON.parse_string(FileAccess.get_file_as_string(ItemArtLibrary.CONFIG_PATH))
	var measured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/item_art_01/expansion-generation/body-calibration-candidate.json"))
	for value: Dictionary in measured.get("values",[]): calibration[String(value.key)] = value
	var tuning := ItemV5Entity.read_tuning()
	var defense: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/item_v5_defense.json"))
	var guides := Guides.new()
	guides.material = ItemArtLibrary.world_material()
	root.add_child(guides)
	var states: Array[ItemV5Entity] = []
	for state: int in 3:
		var node := body(&"growth_drone",&"G19",Vector2(80.25+state*80,50.25),float(tuning.visual.drone_radius_px),state)
		states.append(node)
		var bounds := source_bounds(node)
		check(not bounds.is_empty(),"actual G19 state resolves "+str(state))
		if not bounds.is_empty():
			var box: Array = bounds.full_alpha_projected_bbox
			check(float(box[2])<=37.0001 and float(box[3])<=24.0001,"actual full-alpha source projection respects37x24 body envelope "+str(state))
			guides.boxes.append(Rect2(node.position+Vector2(box[0],box[1]),Vector2(box[2],box[3])))
	var trap := body(&"trap",&"P25",Vector2(80.25,130.25),float(tuning.visual.trap_radius_px))
	var large := body(&"large_drone",&"G05",Vector2(80.25,90.25),float(tuning.visual.large_drone_radius_px))
	var temporary := body(&"temporary_drone",&"P15",Vector2(160.25,90.25),float(tuning.visual.drone_radius_px))
	var crystal := ItemDefenseEffects.CrystalGlyph.new()
	crystal.radius = float(defense.crystal_contact_radius_px)
	crystal.position = Vector2(160.25,130.25)
	root.add_child(crystal)
	var guard := ItemDefenseEffects.GuardGlyph.new()
	guard.radius = float(defense.orbit_intercept_radius_px)
	guard.position = Vector2(240.25,130.25)
	root.add_child(guard)
	var overview: Array[ItemV5Entity] = states.duplicate()
	overview.append_array([large,temporary,trap])
	await capture("g19-overview-trap-crystal-guard",overview)
	for state: int in 3:
		for other: int in 3:
			states[other].visible = other == state
			states[other].position = Vector2(160.25,50.25)
		await capture("g19-same-pose-state-"+str(state),[states[state]])
		check(states[state].position == Vector2(160.25,50.25),"actual shader never mutates same-position node transform "+str(state))
	if same_pose_centers.size() == 3:
		var spread := Vector2.ZERO
		for point: Vector2 in same_pose_centers:
			spread.x = maxf(spread.x,absf(point.x-same_pose_centers[0].x))
			spread.y = maxf(spread.y,absf(point.y-same_pose_centers[0].y))
		check(spread.x<=4.0001 and spread.y<=4.0001,"actual same-position opticalcores remain within one1wu samplingcell across tiers")
	guard.available = false
	guard.scale = Vector2.ONE*float(defense.morning_guard_visual_multiplier)
	guard.queue_redraw()
	await capture("guard-unavailable-existing-morning-scale",[trap])
	for state: int in 3: await isolated_complete_body(state)
	await isolated_complete_body(2,true)
	var row: Dictionary = registry.clips["p25.needle_trap"]
	var atlas := ItemArtLibrary.frame_texture(&"p25.needle_trap",0) as AtlasTexture
	var metal_foot := Vector2(168,277) # Independent measured feature, raw PNG unchanged.
	var foot_offset := (metal_foot/atlas.region.size-Vector2(row.pivot[0],row.pivot[1]))*Vector2(row.world_size[0],row.world_size[1])
	check(absf(foot_offset.x)<.0001 and absf(foot_offset.y-float(tuning.trap.surface_offset_px))<.0001,"declared measured metal foot reaches original real support offset, separate from faint raw fringe")
	var report := {"scope":"Actual ItemV5Entity and original defense Glyph render with production item shader. Positions, evolved state and guard status are presentation fixtures, not natural gameplay/earned growth/physical devices.","display_server":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"screen_pixels_per_world_unit":4,"shader":ItemArtLibrary.WORLD_SHADER_PATH,"shader_sha256":FileAccess.get_sha256(ItemArtLibrary.WORLD_SHADER_PATH),"canonical_sha256":FileAccess.get_sha256(ItemArtLibrary.WORLD_STYLE_SHADER_PATH),"registry_sha256":FileAccess.get_sha256(ItemArtLibrary.CONFIG_PATH),"checks":checks,"failures":failures,"trap_node":[trap.position.x,trap.position.y],"trap_measured_metal_foot_world_offset":[foot_offset.x,foot_offset.y],"original_support_offset":tuning.trap.surface_offset_px,"raw_fringe_may_extend_below_support":true,"resources":ItemArtLibrary.diagnostics(),"captures":evidence,"complete_body_isolation":isolated_renders,"G05":source_bounds(large),"P15":source_bounds(temporary),"P16":clip_bounds(&"p16.orbit_guard",guard.position,guard.material),"P16_actual_morning_scale":guard.scale.x,"P20":clip_bounds(&"p20.crystal",crystal.position,crystal.material)}
	var file := FileAccess.open(ProjectSettings.globalize_path(output).path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	for node: ItemV5Entity in states: node.free()
	trap.free()
	large.free()
	temporary.free()
	crystal.free()
	guard.free()
	guides.free()
	ItemArtLibrary.clear_cache()
	await process_frame
	print("ITEM BODY POSE: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)

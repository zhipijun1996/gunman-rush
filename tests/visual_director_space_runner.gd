extends SceneTree
var assertions := 0
var failures := 0
var output := ""
var mutation := ""
var report: Dictionary = {}
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--mutation="): mutation = arg.trim_prefix("--mutation=")
	run.call_deferred()
func check(value: bool, label: String) -> void:
	assertions += 1
	if not value: failures += 1; printerr("VISUAL SPACE FAIL: ", label)
func find_spaces(node: Node, result: Array[PlainsVisualSpace]) -> void:
	if node is PlainsVisualSpace: result.append(node)
	for child: Node in node.get_children(): find_spaces(child, result)
func forbidden_descendants(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is CollisionObject2D or child is CollisionShape2D or child is Camera2D: return true
		if forbidden_descendants(child): return true
	return false
func run() -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("level-design-v2-baseline"), "real formal baseline starts")
	for unused: int in 120:
		await physics_frame; await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage: break
	app.lifetime.stage_epoch += 1; app.lifetime.actor_epoch += 1
	app.director._enter_stage(2, &"boss"); app._stage_entered(DemoRunResult.new())
	for unused: int in 120:
		await physics_frame; await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.map_index == 2: break
	check(app.stage is PlainsRegionStage and app.stage.assembly_ok, "real map2 assembled")
	var before := JSON.stringify(app.stage.generated.manifest)
	var spaces: Array[PlainsVisualSpace] = []
	find_spaces(app.stage, spaces)
	check(spaces.size() == 1, "exactly one semantic creek space")
	if spaces.size() == 1:
		var space := spaces[0]
		check(space.omission_reason.is_empty(), "candidate has actual supported anchor")
		check(is_instance_valid(space.source_module) and space.source_module.definition.module_id == &"plains_bell_ferry_control", "real semantic ferry module")
		check(is_instance_valid(space.attachment) and space.attachment.get_parent() == space.source_module, "actual dock support body")
		check(not forbidden_descendants(space), "presentation subtree has no collision or camera authority")
		check(space.measured_nodes().size() == 2, "real sprite and real collider measured")
		check(space.actual_issues().is_empty(), "untouched actual wall anchor/scale/depth/source")
		if mutation == "detached_root": space.wall.position.y -= 120
		elif mutation == "channel_intrusion": space.wall.position.x += 500
		elif mutation == "far_detached_root": space.recess.global_position.y -= 120
		elif mutation == "far_clipped_boundary":
			var cropped := AtlasTexture.new(); cropped.atlas = space.recess.texture
			cropped.region = Rect2(0,0,768,1024); space.recess.texture = cropped
		elif mutation == "far_wrong_scale": space.recess.scale *= 1.5
		elif mutation == "far_wrong_depth": space.recess.z_index = 100
		elif mutation == "wrong_attachment": space.attachment = space.source_module.get_node("Platform1") as StaticBody2D
		elif mutation == "translated_parent":
			# Compare equal sampling instants, not an old pre-camera-ready frame.
			space._update_recess_parallax()
			var parent := Node2D.new(); parent.position = Vector2(240,-90); parent.z_index = -15
			app.stage.add_child(parent)
			var translated := PlainsVisualSpace.new(); translated.configure(app.stage); parent.add_child(translated)
			check(translated.actual_issues().is_empty(), "real translated parent keeps world anchored walls/recess")
			check(translated.actual_opaque_bounds().is_equal_approx(space.actual_opaque_bounds()), "translated parent actual opaque world bounds equal")
			check(translated.recess.global_position.is_equal_approx(space.recess.global_position), "translated parent actual far world placement equal")
			parent.free()
		elif not mutation.is_empty(): check(false, "unknown mutation")
		var issues := space.actual_issues()
		check(issues.is_empty(), "actual consumer invariant after requested mutation: " + str(issues))
		check(JSON.stringify(app.stage.generated.manifest) == before, "presentation keeps formal Manifest unchanged")
		report = {"mutation": mutation, "issues": issues, "nodes": space.measured_nodes(), "dock": PlainsVisualSpace.rect_values(space.dock), "manifest_hash": app.stage.generated.manifest.manifest_hash, "scope": "Real DemoApp/assembler and actual Sprite/Platform0 measures, no traversal or aesthetic/device claim"}
	check(PlainsVisualSpace.validated_output_path("res://build/../docs/escape.json").is_empty(), "observer rejects canonical relative path escape")
	check(PlainsVisualSpace.validated_output_path(ProjectSettings.globalize_path("res://build") + "/../../escape.json").is_empty(), "observer rejects canonical absolute path escape")
	check(not PlainsVisualSpace.validated_output_path("res://build/visual_director/observed.json").is_empty(), "observer permits only real build output")
	app.free(); await process_frame
	report["assertions"] = assertions; report["failures"] = failures
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report) + "\n"); file.close()
	print("VISUAL SPACE: %s assertions, %s failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)

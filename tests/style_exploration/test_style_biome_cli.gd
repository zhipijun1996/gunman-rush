extends SceneTree
## Launch the actual runtime with actual command-line arguments, including fallback.
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var expected_style := ""
	var expected_biome := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--expect-style="): expected_style = arg.trim_prefix("--expect-style=")
		if arg.begins_with("--expect-biome="): expected_biome = arg.trim_prefix("--expect-biome=")
	var lab := preload("res://experiments/terrain/entries/style_lab.tscn").instantiate() as StyleLab
	root.add_child(lab)
	var failures := 0
	if lab.style_id != expected_style or lab.biome_id != expected_biome or lab.scenery.get("biome_id") != expected_biome:
		failures += 1
		printerr("FAIL: actual CLI/scenery style=%s biome=%s expected=%s/%s" % [lab.style_id, lab.biome_id, expected_style, expected_biome])
	if lab.layout != StyleLayout.generate(0):
		failures += 1
		printerr("FAIL: CLI art environment replaced shared layout")
	print("STYLE_BIOME_CLI style=%s biome=%s failures=%d" % [lab.style_id, lab.biome_id, failures])
	lab.leave()
	lab.free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)

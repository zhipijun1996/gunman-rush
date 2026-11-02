extends SceneTree
func _initialize() -> void:
	var base := "/workspace/refactor-evidence/combat-perf-deploy-01/release-cache/"
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(base+"mini-pack-inputs.json"))
	var packer := PCKPacker.new()
	if packer.pck_start(base+"packed/cache-bench.pck") != OK:
		quit(1)
		return
	for row: Dictionary in rows:
		if packer.add_file(row.pack_path,row.source) != OK:
			quit(1)
			return
	if packer.flush() != OK:
		quit(1)
		return
	print("CACHE_BENCH_PACK_READY")
	quit()

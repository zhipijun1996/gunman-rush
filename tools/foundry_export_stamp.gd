extends SceneTree
## Exporting compiled scripts cannot recompute editor source hashes at runtime.
## Refuse to stamp a stale source tree; the cooked pack inherits this proven basis.
func _initialize() -> void:
	var batch := FoundryCatalog.batch()
	if batch.is_empty():
		push_error("Foundry source changed after validation; rebuild batch before export")
		quit(1)
		return
	var stamp := {"schema": 1, "basis": FoundryCatalog.basis(), "engine": Engine.get_version_info().string, "configs": {}}
	for path: String in ["res://config/player_tuning.json", "res://config/input_profile.json", "res://config/platforming_foundry.json", "res://config/foundry_capabilities.json"]:
		stamp.configs[path] = FileAccess.get_sha256(path)
	var file := FileAccess.open("res://resources/foundry/export_basis.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(stamp) + "\n")
	print("FOUNDRY EXPORT BASIS: ", stamp.basis)
	quit(0)

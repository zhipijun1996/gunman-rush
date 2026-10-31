extends SceneTree
func _initialize() -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ItemArtLibrary.CONFIG_PATH))
	print("SOURCE_VALIDATION: ",ItemArtLibrary.validate_sources(payload))
	var reply: Variant = ItemArtLibrary.reload()
	print("CLASS_RELOAD_RETURN: type=",typeof(reply)," value=",reply)
	print("ACTUAL_REGISTRY: ",ItemArtLibrary.diagnostics())
	ItemArtLibrary.clear_cache()
	quit()

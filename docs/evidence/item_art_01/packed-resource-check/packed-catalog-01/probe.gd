extends SceneTree
func _initialize() -> void:
	var items := ItemCatalogV5.all_items()
	var art := ItemArtLibrary.diagnostics()
	var ok := items.size() == 72 and bool(art.get("valid",false)) and str(art.get("last_error","")).is_empty()
	print("PACKED ITEM V5: items=",items.size()," art=",JSON.stringify(art)," passed=",ok)
	ItemArtLibrary.clear_cache()
	quit(0 if ok else 1)

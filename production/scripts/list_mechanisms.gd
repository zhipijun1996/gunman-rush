extends SceneTree
## Show the same library used to authorize placement and load room documents.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		printerr("用法：list_mechanisms.gd -- [region_id | --regions]")
		quit(1)
		return
	var region := "" if args.is_empty() else args[0]
	if region == "--regions":
		for id: String in WorldElementCatalog.catalog().mechanism_regions: print(id)
		quit()
		return
	var palette := WorldElementCatalog.mechanism_palette(region)
	if palette.has("error"):
		printerr(palette.error)
		quit(1)
		return
	print("公有机关")
	show_entries(palette.common)
	if not region.is_empty():
		print(region," 专属机关")
		if palette.regional.is_empty(): print("尚无登记项")
		show_entries(palette.regional)
	quit()

func show_entries(ids: Array) -> void:
	for id: String in ids:
		var definition: Dictionary = WorldElementCatalog.catalog().definitions[id]
		print(id,"  ",definition.name,"  ",definition.documentation)

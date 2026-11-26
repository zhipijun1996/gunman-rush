extends SceneTree
const Info := preload("res://addons/mechanism_library/catalog_info.gd")
## Show the same library used to authorize placement and load room documents.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--describe":
		var definition: Dictionary = WorldElementCatalog.catalog().definitions.get(args[1], {})
		if definition.get("library") != "mechanisms":
			printerr("未知机关：", args[1])
			quit(1)
			return
		print_definition(definition)
		quit()
		return
	if args.size() > 1:
		printerr("用法：list_mechanisms.gd -- [region_id | --regions | --describe definition_id]")
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

func print_definition(definition: Dictionary) -> void:
	print(definition.name, "  ", definition.id, "  v", definition.version)
	print("声明区域  ", JSON.stringify(definition.get("usable_regions", ["*"])))
	var fields := Info.fields(definition)
	for key: String in fields:
		var field: Dictionary = fields[key]
		var value: Variant = definition.get("defaults", {}).get(key, field.get("default"))
		var display := str(field.get("label", key)) + " (" + key + ")"
		var detail := str(field.type) + " " + str(field.get("unit", ""))
		if value != null: detail += "  默认 " + JSON.stringify(value)
		if field.has("choices"): detail += "  " + JSON.stringify(field.choices)
		if not str(field.hint).is_empty(): detail += "  " + str(field.hint)
		print(display, "  ", detail)
	for mode: String in definition.get("mode_defaults", {}):
		print(mode, "  ", JSON.stringify(definition.mode_defaults[mode]))
	print(definition.documentation)

extends "res://tests/item_v5_ui_input_runner.gd"
## Inherits every original functional assertion and only replaces optional capture.
## All72 ownership, levels, equipped state and scroll positions are display setup.
const DISCLOSURE := "72图标显示初始化，非自然满包"
var _fixture_icon_rows: Array[Dictionary] = []
var _capture_sources: Dictionary = {}
var _sources_before: Dictionary = {}
var _visible_by_size: Dictionary = {}
var _icon_config: Dictionary = {}
var _capture_watermark: CanvasLayer
var _watermark_label: Label
var _watermark_background: ColorRect

func _source_snapshot() -> Dictionary:
	var paths: Array[String] = [get_script().resource_path,"res://tests/item_v5_ui_input_runner.gd","res://scripts/ui/demo_menu.gd","res://scripts/ui/item_presentation.gd","res://scripts/items/v5/item_art_library.gd","res://scripts/items/v5/item_catalog_v5.gd","res://config/items_v5.json","res://config/item_v5_authoring.json","res://config/item_v5_art.json","res://assets/items/v5/manifest.json"]
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/item_v5_art.json"))
	for section: String in ["icons","clips"]:
		for key: String in registry.get(section,{}):
			var texture: String = registry[section][key].texture
			if texture not in paths: paths.append(texture)
	paths.sort()
	var result := {}
	for path: String in paths:
		check(FileAccess.file_exists(path),"actual UI source dependency exists: "+path)
		result[path] = FileAccess.get_sha256(path)
	return result

func _add_watermark() -> void:
	_capture_watermark = CanvasLayer.new()
	_capture_watermark.layer = 200
	root.add_child(_capture_watermark)
	_watermark_background = ColorRect.new()
	_watermark_background.color = Color(.025,.045,.055,.94)
	_watermark_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_watermark.add_child(_watermark_background)
	_watermark_label = Label.new()
	_watermark_label.text = DISCLOSURE
	_watermark_label.add_theme_font_override("font",DemoClockworkTheme.FONT)
	_watermark_label.add_theme_font_size_override("font_size",15)
	_watermark_label.add_theme_color_override("font_color",Color("e4c77f"))
	_watermark_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_watermark.add_child(_watermark_label)

func _place_watermark(dimensions: Vector2i) -> void:
	_watermark_background.position = Vector2(float(dimensions.x-440)/2.0,5)
	_watermark_background.size = Vector2(440,28)
	_watermark_label.position = _watermark_background.position+Vector2(12,3)

func _card_visibility(menu: DemoMenu) -> Dictionary:
	var visible: Array[String] = []
	var full_cards: Array[String] = []
	var full_icons: Array[String] = []
	var rectangles: Array[Dictionary] = []
	var screen := Rect2(Vector2.ZERO,Vector2(root.size))
	for node: Node in menu.find_children("*","Button",true,false):
		var tile := node as Button
		if not tile.has_meta(&"inventory_tile") or not tile.is_visible_in_tree(): continue
		var instance := str(tile.get_meta(&"instance_id",&""))
		var definition := instance.trim_prefix("all72/")
		var card := tile.get_global_rect()
		var clip := screen
		var parent: Node = tile.get_parent()
		while parent != null:
			if parent is ScrollContainer: clip = clip.intersection((parent as ScrollContainer).get_global_rect())
			parent = parent.get_parent()
		var intersection := card.intersection(clip)
		if intersection.get_area() <= 0: continue
		visible.append(definition)
		var card_fraction := intersection.get_area()/maxf(1,card.get_area())
		if card_fraction > .995: full_cards.append(definition)
		# Actual ItemPresentation Button uses52px centered icon_max_width.
		var icon := Rect2(card.get_center()-Vector2(26,26),Vector2(52,52))
		var icon_fraction := icon.intersection(clip).get_area()/icon.get_area()
		if icon_fraction > .995: full_icons.append(definition)
		rectangles.append({"id":definition,"instance":instance,"card_rect":[card.position.x,card.position.y,card.size.x,card.size.y],"clip_rect":[clip.position.x,clip.position.y,clip.size.x,clip.size.y],"card_visible_fraction":card_fraction,"center52_icon_visible_fraction":icon_fraction})
	return {"visible_item_ids":visible,"fully_visible_card_item_ids":full_cards,"fully_visible_icon_item_ids":full_icons,"actual_card_rectangles":rectangles}

func _detail_metadata(menu: DemoMenu) -> Dictionary:
	var selected := str(menu._selected_instance_id).trim_prefix("all72/")
	var item := ItemCatalogV5.get_item(StringName(selected))
	var image := menu.find_child("SelectedItemIcon",true,false) as TextureRect
	var title := menu.find_child("SelectedItemName",true,false) as Label
	var level := menu.find_child("SelectedItemLevel",true,false) as Label
	var result := {"definition_id":selected,"name":title.text if title != null else "","level_text":level.text if level != null else ""}
	if image == null or item == null: return result
	var texture := image.texture as AtlasTexture
	check(texture != null and texture.atlas != null and texture.filter_clip,"actual detail uses clipped ItemPresentation AtlasTexture for "+selected)
	if texture == null: return result
	var recipe: Dictionary = _icon_config[String(item.icon_key)]
	var declared: Array = recipe.region
	var expected := Rect2(declared[0],declared[1],declared[2],declared[3])
	check(texture.region == expected and texture.atlas.resource_path == recipe.texture,"actual detail resolves the exact declared source and ROI for "+selected)
	result.icon_key = str(item.icon_key)
	result.source = texture.atlas.resource_path
	result.source_sha256 = FileAccess.get_sha256(texture.atlas.resource_path)
	result.region = [texture.region.position.x,texture.region.position.y,texture.region.size.x,texture.region.size.y]
	result.filter_clip = texture.filter_clip
	result.actual_control_size = [image.size.x,image.size.y]
	result.actual_control_rect = [image.get_global_rect().position.x,image.get_global_rect().position.y,image.size.x,image.size.y]
	result.display_icon_height = 90
	result.level = item.max_level
	result.max_level = item.max_level
	result.effect_state_fixture = {"evolution":2} if selected == "G19" else {}
	return result

func capture_menu_png(menu: DemoMenu, directory: String, stem: String, dimensions: Vector2i, rows: Array) -> void:
	await super.capture_menu_png(menu,directory,stem,dimensions,rows)
	if rows.is_empty(): return
	var visibility := _card_visibility(menu)
	var row: Dictionary = rows[-1]
	row.merge(visibility)
	row.selected_detail = _detail_metadata(menu)
	row.image_sha256 = FileAccess.get_sha256(directory.path_join(stem+".png"))
	row.watermark = DISCLOSURE
	row.scroll_setup = "direct original ScrollContainer assignment for display coverage; not native touch-drag evidence"
	row.source_hashes = _capture_sources.duplicate(true)
	var size_key := "%sx%s" % [dimensions.x,dimensions.y]
	var covered: Dictionary = _visible_by_size.get(size_key,{})
	for id: String in visibility.fully_visible_icon_item_ids: covered[id] = true
	_visible_by_size[size_key] = covered

func capture_menu_views(menu: DemoMenu, destination: String) -> void:
	if DisplayServer.get_name() == "headless":
		check(false,"all72 menu evidence requires actual GL")
		return
	var directory := ProjectSettings.globalize_path(destination)
	check(not DirAccess.dir_exists_absolute(directory),"all72 capture uses a fresh output directory and retains old evidence")
	if DirAccess.dir_exists_absolute(directory): return
	check(DirAccess.make_dir_recursive_absolute(directory) == OK,"all72 output is writable")
	_sources_before = _source_snapshot()
	_capture_sources = _sources_before.duplicate(true)
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/item_v5_art.json"))
	_icon_config = registry.icons
	var items: Array[Dictionary] = []
	var worn: Array[StringName] = [&"P24",&"P14"]
	var definitions: Array[ItemDefinition] = ItemCatalogV5.all_items()
	check(definitions.size() == 72,"display fixture enumerates all72 current effective definitions")
	var instances := {}
	var used := 0
	for item: ItemDefinition in definitions:
		var id := item.stable_id
		var instance := StringName("all72/"+str(id))
		check(not instances.has(instance),"independent display instance for "+str(id))
		instances[instance] = true
		check(ItemArtLibrary.has_icon(item.icon_key),"current independent icon registered for "+str(id))
		var texture := ItemPresentation.icon(item.icon_key) as AtlasTexture
		check(texture != null and texture.atlas != null and texture.filter_clip,"actual common UI texture route for "+str(id))
		if texture != null:
			_fixture_icon_rows.append({"id":str(id),"instance_id":str(instance),"icon_key":str(item.icon_key),"source":texture.atlas.resource_path,"region":[texture.region.position.x,texture.region.position.y,texture.region.size.x,texture.region.size.y],"level":item.max_level,"max_level":item.max_level,"equipped":id in worn})
		if id in worn: used += item.gear_cost
		items.append({"instance_id":instance,"definition":item,"level":item.max_level,"max_level":item.max_level,"equipped":id in worn,"active_capable":&"active" in item.tags,"active_selected":id == &"P24","effect_state":{"evolution":2} if id == &"G19" else {}})
	check(used == 6,"display fixture keeps actual P24/P14 gear6/8")
	var snapshot := {"capacity":8,"used":used,"remaining":8-used,"revision":72,"session":19,"coins":90,"summary":DISCLOSURE,"items":items,"upgrade":{"available":false,"price":0,"capacity":8,"reason":"美术显示初始化"}}
	var evidence: Array = []
	var old_size := root.size
	var old_scale := root.content_scale_size
	_add_watermark()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		_place_watermark(dimensions)
		menu.show_build("")
		menu.set_equipment_view(snapshot)
		for unused: int in 8: await process_frame
		menu.call("_select_equipment",&"all72/G01")
		var scroll := menu.find_child("BackpackScroll",true,false) as ScrollContainer
		check(scroll != null and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,"actual all72 backlog overflows at "+str(dimensions))
		if scroll == null: continue
		# Sample actual row tops. Fractional-page offsets can clip every other
		#52px icon in an82px mobile viewport even when the UI itself is correct.
		var maximum := maxi(0,int(ceil(scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page)))
		var positions: Array[int] = [0]
		for node: Node in menu.find_children("*","Button",true,false):
			var tile := node as Button
			if not tile.has_meta(&"inventory_tile") or not scroll.is_ancestor_of(tile): continue
			var row_top := clampi(int(round(tile.get_global_rect().position.y-scroll.get_global_rect().position.y))+scroll.scroll_vertical,0,maximum)
			if row_top not in positions: positions.append(row_top)
		positions.sort()
		var page := 0
		for position: int in positions:
			scroll.scroll_vertical = position
			for settle: int in 4: await process_frame
			var stem := "all72-menu-%sx%s-page%02d" % [dimensions.x,dimensions.y,page]
			await capture_menu_png(menu,directory,stem,dimensions,evidence)
			page += 1
		var size_key := "%sx%s" % [dimensions.x,dimensions.y]
		var covered: Dictionary = _visible_by_size.get(size_key,{})
		check(covered.size() == 72,"actual clipped52px icon coverage includes all72 at "+size_key)
		for selected: StringName in [&"G01",&"P16",&"G19"]:
			menu.call("_select_equipment",StringName("all72/"+str(selected)))
			var detail := menu.find_child("DetailScroll",true,false) as ScrollContainer
			if detail != null: detail.scroll_vertical = 0
			for settle: int in 4: await process_frame
			await capture_menu_png(menu,directory,"all72-menu-%sx%s-detail-%s" % [dimensions.x,dimensions.y,selected],dimensions,evidence)
	menu.close_panel()
	_capture_watermark.free()
	root.size = old_size
	root.content_scale_size = old_scale
	var after := _source_snapshot()
	check(after == _sources_before,"all actual UI/config/art/texture source hashes remain stable during capture")
	var file := FileAccess.open(directory.path_join("capture-manifest.json"),FileAccess.WRITE)
	check(file != null,"all72 actual UI capture manifest can be written")
	if file != null:
		file.store_string(JSON.stringify({"schema":"item-art-all72-actual-menu-v1","scope":"Actual DemoMenu/ItemPresentation all72 independent-icon display fixture, correct max-level metadata, P24/P14 gear6/8. Original functional UI/input assertions remain inherited. Direct native ScrollContainer assignment only covers displayed pages; not natural ownership, native touch-drag, physical Android/gamepad or gameplay acceptance. G01/P16 detail checks resolve current exact one-pixel-adjusted ROI; G19 evolution2 is explicitly initialized.","watermark":DISCLOSURE,"display_server":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"icons":_fixture_icon_rows,"source_before":_sources_before,"source_after":after,"source_stable":after == _sources_before,"fully_visible_icons_by_viewport":_visible_by_size,"rows":evidence},"  "))
		file.close()
	# The inherited runner then frees real menus/adapters and prints its original
	# strict completion marker; do not retain static AtlasTexture caches at quit.
	ItemArtLibrary.clear_cache()

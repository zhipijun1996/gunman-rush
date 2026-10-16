class_name RegionProgressionModal
extends CanvasLayer
signal ability_selected(id: StringName)
signal region_selected(id: StringName)
signal finish_requested
var opened := false
var _root: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 35

func show_abilities(offers: Array[Dictionary], boundary: bool) -> void:
	var rows := _begin("CHOOSE A CORE ABILITY", "Run abilities last until this run ends. GOLD item and core ability are separate rewards.")
	for offer: Dictionary in offers:
		var button := _button(rows, str(offer.label))
		button.disabled = not offer.available
		var id := StringName(offer.id)
		button.pressed.connect(func() -> void: ability_selected.emit(id))
	if boundary:
		_label(rows,"FOREST COMPLETE / Stage 3 regions are not built. Choose your reward, then return home; no full-run victory is claimed.")

func show_regions() -> void:
	var rows := _begin("CHOOSE THE NEXT REGION", "H acquired / Keep health, coins and build. Forest uses H plus your current base weapon.")
	_button(rows,"ENTER / THORN FOREST / 2 RANDOM MAPS").pressed.connect(func() -> void: region_selected.emit(&"thorn_forest"))
	for text: String in ["CANYON / Locked: region not built; requires W", "SWAMP / Locked: region not built; requires U1"]:
		_button(rows,text).disabled = true

func show_boundary() -> void:
	var rows := _begin("THORN FOREST COMPLETE", "Core ability received. Next regions are in development. Returning home ends this run and clears run abilities, coins and items; banked notes remain.")
	_button(rows,"END THIS RUN / RETURN HOME").pressed.connect(func() -> void: finish_requested.emit())

func close() -> void:
	opened = false
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = null

func _begin(title: String, detail: String) -> VBoxContainer:
	close()
	opened = true
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.035,0.04,0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.theme = DemoMenu.create_theme()
	panel.custom_minimum_size = Vector2(660,340)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",18)
	margin.add_child(rows)
	_label(rows,title)
	_label(rows,detail)
	return rows

func _label(rows: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 610
	label.add_theme_color_override("font_color",Color("25372f"))
	rows.add_child(label)

func _button(rows: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 58
	rows.add_child(button)
	return button

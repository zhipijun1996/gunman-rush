class_name PlainsRegionMapModal
extends CanvasLayer
signal closed
var opened := false
var canvas: PlainsRegionMap
var _root: Control
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	layer=40
func show_map(stage: PlainsRegionStage) -> void:
	close()
	opened=true
	_root=Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade:=ColorRect.new()
	shade.color=Color(0.015,0.025,0.03,0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var rows:=VBoxContainer.new()
	rows.position=Vector2(60,48)
	rows.size=Vector2(1160,624)
	_root.add_child(rows)
	var label:=Label.new()
	label.text="PLAINS / MAP %s OF 2 / EXPLORATION MAP" % stage.map_index
	label.add_theme_font_size_override("font_size",24)
	rows.add_child(label)
	var help:=Label.new()
	help.text="Fog = not explored / drag to pan / wheel or pinch to zoom / M or Esc to close"
	rows.add_child(help)
	canvas=PlainsRegionMap.new()
	canvas.name="ExplorationCanvas"
	canvas.expanded=true
	canvas.stage=stage
	canvas.custom_minimum_size=Vector2(1160,480)
	canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL
	rows.add_child(canvas)
	var controls:=HBoxContainer.new()
	controls.alignment=BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation",20)
	rows.add_child(controls)
	for title: String in ["ZOOM -","ZOOM +","FIT MAP","FIND ME","CLOSE MAP"]:
		var button:=Button.new()
		button.text=title
		button.custom_minimum_size=Vector2(160,44)
		controls.add_child(button)
		if title=="ZOOM -": button.pressed.connect(func() -> void: canvas.zoom_at(1.0/1.3,canvas.player_anchor()))
		elif title=="ZOOM +": button.pressed.connect(func() -> void: canvas.zoom_at(1.3,canvas.player_anchor()))
		elif title=="FIT MAP": button.pressed.connect(func() -> void: canvas.reset_view())
		elif title=="FIND ME": button.pressed.connect(func() -> void: canvas.focus_player())
		else:
			button.pressed.connect(func() -> void: closed.emit())
			button.grab_focus()
func close() -> void:
	opened=false
	canvas=null
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root=null

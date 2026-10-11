class_name ItemAcquiredToast
extends CanvasLayer
var _root: PanelContainer
var _remaining:=0.0
func show_item(item: ItemDefinition) -> void:
	clear();layer=5
	_root=PanelContainer.new();_root.position=Vector2(300,615);_root.size=Vector2(670,85);_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new();style.bg_color=Color(.08,.15,.12,.95);style.set_corner_radius_all(8);style.set_content_margin_all(10);_root.add_theme_stylebox_override("panel",style);add_child(_root)
	var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;_root.add_child(row)
	var image:=TextureRect.new();image.mouse_filter=Control.MOUSE_FILTER_IGNORE;image.texture=ItemPresentation.icon(item.icon_key);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=Vector2(64,64);row.add_child(image)
	var label:=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.text="已获得 / ACQUIRED "+item.display_name+"\n"+ItemPresentation.effects(item);label.add_theme_font_override("font",preload("res://assets/fonts/windkeeper_ui.ttf"));label.add_theme_font_size_override("font_size",16);row.add_child(label);_remaining=3.5
func _process(delta: float) -> void:
	_remaining=maxf(0,_remaining-delta)
	if _remaining==0: clear()
func clear() -> void:
	if is_instance_valid(_root): remove_child(_root);_root.queue_free()
	_root=null

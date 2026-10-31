class_name PixelPlainsPreview
extends Control
signal home_requested
var input_values: Dictionary={}
var room: PixelPlainsRoom
var viewport: SubViewport
var container: SubViewportContainer
var _buttons: HBoxContainer
var _effects:=true
var _light:=true

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var letterbox:=ColorRect.new()
	letterbox.color=Color("111e2b")
	letterbox.mouse_filter=Control.MOUSE_FILTER_IGNORE
	letterbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(letterbox)
	container=SubViewportContainer.new()
	container.size=Vector2(640,360)
	container.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	viewport=SubViewport.new()
	viewport.size=Vector2i(640,360)
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.snap_2d_transforms_to_pixel=true
	viewport.snap_2d_vertices_to_pixel=true
	container.add_child(viewport)
	room=PixelPlainsRoom.new()
	room.input_values=input_values
	room.home_requested.connect(func() -> void:home_requested.emit())
	viewport.add_child(room)
	_buttons=HBoxContainer.new()
	_buttons.add_theme_constant_override("separation",5)
	add_child(_buttons)
	_button("Restart",room.restart)
	_button("47 tiles",room._toggle_catalog)
	_button("Light",func() -> void:_light=not _light;room.set_light(_light))
	_button("Wind",func() -> void:_effects=not _effects;room.set_effects(_effects))
	_button("Pause",room._toggle_pause)
	_button("Home",room.leave)
	resized.connect(_fit)
	_fit.call_deferred()

func _button(text: String,action: Callable) -> void:
	var b:=Button.new()
	b.text=text
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",13)
	b.add_theme_color_override("font_color",Color("ead39a"))
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(.065,.12,.17,.9)
	style.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal",style)
	b.pressed.connect(func() -> void:room.controller.router.clear("pixel_ui");action.call())
	_buttons.add_child(b)

func _fit() -> void:
	var screen:=get_viewport_rect().size
	var factor:=minf(screen.x/640,screen.y/360)
	container.scale=Vector2.ONE*factor
	container.position=(screen-Vector2(640,360)*factor)*.5
	_buttons.position=Vector2(18,screen.y-48)

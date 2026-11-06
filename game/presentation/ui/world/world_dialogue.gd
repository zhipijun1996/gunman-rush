class_name WorldDialogue
extends DemoUiModalShell
## Reuses modal focus/touch/scroll ownership; a readable, compact world conversation.
var conversation:=true
var _content_minimum:=Vector2.ZERO
static var _readable_font: FontFile
func _ready() -> void:
	if _readable_font==null:
		# Load the licensed CJK source independently of GameTypography's legacy aliases.
		_readable_font=ResourceLoader.load("res://assets/fonts/foundry_notes.otf","FontFile",ResourceLoader.CACHE_MODE_IGNORE) as FontFile
		_readable_font.antialiasing=TextServer.FONT_ANTIALIASING_GRAY
		_readable_font.hinting=TextServer.HINTING_NORMAL
	preferred_width=1000;preferred_height=240 if conversation else 520
	super._ready()
	(get_child(0) as ColorRect).color=Color(.02,.04,.05,.45)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_panel.add_theme_stylebox_override("panel",DemoClockworkTheme.plate(Color("15272e"),DemoClockworkTheme.BRASS,24))
	if conversation: _panel.reparent(self)
	_fit()
func heading(title: String,detail: String,_eyebrow: String="") -> void:
	text(title,26,DemoClockworkTheme.BRASS)
	text(detail,22,DemoClockworkTheme.PAPER)
func text(value: String,font_size: int=22,color: Color=DemoClockworkTheme.PAPER) -> Label:
	var label:=super.text(value,maxi(20,font_size),color)
	label.set_meta(&"world_reading_size",maxi(20,font_size))
	return label
func button(title: String,action: Callable) -> Button:
	var control:=super.button(title,action)
	control.set_meta(&"world_reading_size",20)
	return control
func _fit() -> void:
	if scroll==null: return
	super._fit()
	var scale:=METRICS.pixel_scale(get_viewport())
	for node: Node in rows.find_children("*","Control",true,false):
		if node is Label or node is BaseButton:
			(node as Control).add_theme_font_override("font",_readable_font)
			(node as Control).add_theme_font_size_override("font_size",ceili(float(node.get_meta(&"world_reading_size",20))/scale))
			(node as Control).add_theme_constant_override("shadow_offset_x",0)
			(node as Control).add_theme_constant_override("shadow_offset_y",0)
			if node is BaseButton: (node as Control).custom_minimum_size.y=52/scale
	if not conversation: return
	var safe:=METRICS.safe_rect(get_viewport())
	var margin:=24/scale
	var width:=minf(1040/scale,safe.size.x-2*margin)
	var padding:=_panel.get_theme_stylebox("panel").get_minimum_size()
	scroll.custom_minimum_size=Vector2(width-padding.x,minf(safe.size.y*.65,maxf(160/scale,rows.get_combined_minimum_size().y)))
	scroll.size=scroll.custom_minimum_size
	_panel.size=scroll.custom_minimum_size+padding
	_panel.position=Vector2(safe.get_center().x-_panel.size.x/2,safe.end.y-margin-_panel.size.y)

func _process(delta: float) -> void:
	super._process(delta)
	if not conversation or rows==null: return
	# Wrapped text is measured after Container layout; shrink short conversations then.
	var minimum:=rows.get_combined_minimum_size()
	if minimum!=_content_minimum:
		_content_minimum=minimum;_fit()

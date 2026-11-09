class_name WorldDialogue
extends DemoUiModalShell
## Reuses modal focus/touch/scroll ownership; a readable, compact world conversation.
var conversation:=true
var compact_actions:=false
var _content_minimum:=Vector2.ZERO
var _portrait_host: Control
func _ready() -> void:
	preferred_width=880;preferred_height=220 if conversation else 520
	super._ready()
	theme=UnderworldUI.create_theme()
	(get_child(0) as ColorRect).color=Color(.02,.04,.05,.45)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.add_theme_stylebox_override("panel",UnderworldUI.box(UnderworldUI.PANEL,UnderworldUI.BORDER,16))
	if conversation: _panel.reparent(self)
	_fit()
func heading(title: String,detail: String,_eyebrow: String="") -> void:
	var original_rows:=rows
	var heading_row:=HBoxContainer.new();heading_row.add_theme_constant_override("separation",18);rows.add_child(heading_row)
	_portrait_host=Control.new();_portrait_host.custom_minimum_size=Vector2(72,84);_portrait_host.mouse_filter=Control.MOUSE_FILTER_IGNORE;_portrait_host.hide();heading_row.add_child(_portrait_host)
	var copy:=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading_row.add_child(copy);rows=copy
	text(title,22,DemoClockworkTheme.BRASS)
	text(detail,18,DemoClockworkTheme.PAPER)
	rows=original_rows
func portrait(asset: String) -> void:
	_portrait_host.show()
	var actor:=WorldSpriteAnimation.new();actor.asset_id=asset;actor.position=Vector2(36,80);actor.scale=Vector2.ONE
	_portrait_host.add_child(actor);actor.process_mode=Node.PROCESS_MODE_ALWAYS;actor.play_event()
func text(value: String,font_size: int=18,color: Color=DemoClockworkTheme.PAPER) -> Label:
	var label:=super.text(value,maxi(16,font_size),color)
	label.set_meta(&"world_reading_size",maxi(16,font_size))
	return label
func button(title: String,action: Callable) -> Button:
	var control:=super.button(title,action)
	control.set_meta(&"world_reading_size",18)
	return control
func _fit() -> void:
	if scroll==null: return
	super._fit()
	var scale:=METRICS.ui_scale(get_viewport())
	if compact_actions:rows.add_theme_constant_override("separation",ceili(8/scale))
	for node: Node in rows.find_children("*","Control",true,false):
		if node is Label or node is BaseButton:
			(node as Control).add_theme_font_override("font",UnderworldUI.FONT)
			(node as Control).add_theme_font_size_override("font_size",ceili(float(node.get_meta(&"world_reading_size",18))/scale))
			(node as Control).add_theme_constant_override("shadow_offset_x",0)
			(node as Control).add_theme_constant_override("shadow_offset_y",0)
			if node is BaseButton: (node as Control).custom_minimum_size.y=(48 if compact_actions else 52)/scale
	# Content dragging remains the touch target; the scrollbar is a compact indicator.
	var bar:=scroll.get_v_scroll_bar()
	bar.custom_minimum_size=Vector2(12/scale,0)
	for part: String in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
		var style:=bar.get_theme_stylebox(part).duplicate() as StyleBoxFlat
		style.content_margin_left=3/scale;style.content_margin_right=3/scale
		style.shadow_size=0;bar.add_theme_stylebox_override(part,style)
	if not conversation: return
	var safe:=METRICS.safe_rect(get_viewport())
	var margin:=24/scale
	var width:=minf(880/scale,safe.size.x-2*margin)
	var padding:=_panel.get_theme_stylebox("panel").get_minimum_size()
	scroll.custom_minimum_size=Vector2(width-padding.x,minf(safe.size.y*.65,maxf(112/scale,rows.get_combined_minimum_size().y)))
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

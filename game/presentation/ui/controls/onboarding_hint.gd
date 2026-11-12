class_name OnboardingHint
extends PanelContainer
## One non-modal screen-space prompt; location selected against real UI/body.
var heading: Label
var instruction: Label
var lesson := ""
var desired := false
var reduced := false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	theme=UnderworldUI.create_theme()
	add_theme_stylebox_override("panel",UnderworldUI.box(Color(.08,.12,.12,.94),Color(.5,.55,.4,.65),10))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",5);add_child(column)
	heading=Label.new();heading.add_theme_color_override("font_color",UnderworldUI.BRASS);column.add_child(heading)
	instruction=Label.new();instruction.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(instruction)
	modulate.a=0
	hide()
func present(value: Dictionary, viewport: Viewport, avoid: Array[Rect2], touch: bool) -> void:
	desired=not value.is_empty()
	if not desired: lesson="";return
	lesson=str(value.lesson)
	heading.text=str(value.title)
	instruction.text=str(value.binding)+"  ·  "+str(value.detail)
	var scale:=DemoUiModalMetrics.pixel_scale(viewport)
	var safe:=DemoUiModalMetrics.safe_rect(viewport).grow(-12/scale)
	var width:=minf(520/scale,safe.size.x)
	custom_minimum_size=Vector2(width,64/scale)
	size=custom_minimum_size
	heading.add_theme_font_size_override("font_size",ceili(16/scale))
	instruction.add_theme_font_size_override("font_size",ceili(16/scale))
	var candidates: Array[Vector2] = [Vector2(safe.get_center().x-width*.5,safe.end.y-size.y-(150/scale if touch else 12/scale)),Vector2(safe.get_center().x-width*.5,safe.position.y+92/scale),Vector2(safe.get_center().x-width*.5,safe.get_center().y-size.y*.5)]
	var best:=candidates[0]
	var penalty:=INF
	for point: Vector2 in candidates:
		point=point.clamp(safe.position,(safe.end-size).max(safe.position))
		var score:=0.0
		for rect: Rect2 in avoid:
			var overlap:=Rect2(point,size).intersection(rect.grow(8/scale))
			score+=overlap.get_area()
		if score<penalty:penalty=score;best=point
	position=best
	show()
func _process(delta: float) -> void:
	modulate.a=move_toward(modulate.a,1.0 if desired else 0.0,delta/maxf(Engine.time_scale,.001)*(12 if reduced else 6))
	if not desired and modulate.a<=0:hide()

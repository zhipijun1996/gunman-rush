class_name PlainsRegionMap
extends Control
## Real connections and discovered places, no invented corridor artwork.
var stage: PlainsRegionStage
var frame := Rect2(8,26,224,108)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(240,156)
func _process(_delta: float) -> void: queue_redraw()
func project(p: Array) -> Vector2:
	var m: Dictionary=stage.generated.manifest
	var b: Array=m.world_bounds
	return frame.position+Vector2((float(p[0])-float(b[0]))/float(b[2]),(float(p[1])-float(b[1]))/float(b[3]))*frame.size
func _draw() -> void:
	if not is_instance_valid(stage) or not stage.assembly_ok: return
	draw_style_box(panel(),Rect2(Vector2.ZERO,Vector2(240,156)))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(10,17),"PLAINS / EXPLORE FREELY",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("dbd7ab"))
	var g:=PlainsRegionGenerator.new()
	var m: Dictionary=stage.generated.manifest
	for e: Dictionary in m.connections:
		var a:=project(g._area(m,e.a).position)
		var b:=project(g._area(m,e.b).position)
		var locked: bool=e.condition=="backside" and not stage.region_state.opened.has(e.id)
		draw_line(a,b,Color("ac7854") if locked else Color("789778"),1)
		if locked: draw_circle((a+b)/2,2,Color("dfbb76"))
	for a: Dictionary in m.areas:
		var p:=project(a.position)
		var color:=Color("d2d9ac") if stage.region_state.visited.has(a.id) else Color("65796a")
		if a.role=="boss": color=Color("e8b76c")
		if a.role=="merchant": color=Color("9fccdb")
		draw_circle(p,3,color)
		if a.role in ["merchant","boss","challenge_reward"]:
			draw_string(font,p+Vector2(4,-3),"B" if a.role=="boss" else "C" if a.role=="merchant" else "*",HORIZONTAL_ALIGNMENT_LEFT,-1,10,color)
	var player:=stage.global_player_position()
	if player.is_finite(): draw_circle(project([player.x,player.y]),3,Color("fff5ca"))
	draw_string(font,Vector2(10,147),"B Boss   C Camp   * Rare   o You",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("d0d0ae"))
func panel() -> StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=Color(0.08,0.14,0.10,0.86)
	box.set_corner_radius_all(8)
	return box

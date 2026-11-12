class_name PlainsRegionMap
extends MapViewport
## Legacy generated-region content; input/projection are shared with the fixed world.
var stage: PlainsRegionStage

func _world_rect() -> Rect2:
	var b: Array=stage.generated.manifest.world_bounds
	return Rect2(b[0],b[1],b[2],b[3])
func visible_areas() -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	if not is_instance_valid(stage): return found
	for a: Dictionary in stage.generated.manifest.areas:
		if PlainsMapExploration.revealed(stage.region_state,Vector2(a.position[0],a.position[1])): found.append(a)
	return found
func player_anchor() -> Vector2:
	var p:=project_point(stage.global_player_position())
	return p if frame().has_point(p) else frame().get_center()
func focus_player() -> void:
	zoom=2
	pan=-(stage.global_player_position()-_world_rect().get_center())*_fit_scale()*zoom
	_limit_pan()
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(stage) or not stage.assembly_ok: return
	draw_style_box(panel(),Rect2(Vector2.ZERO,size))
	var font:=UnderworldUI.FONT
	if region_chip and not expanded:
		var baseline := floorf((size.y + font.get_ascent(12) - font.get_descent(12)) * 0.5)
		draw_string(font,Vector2(12,baseline),"MAP %s/2  ·  EXPLORE" % stage.map_index,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UnderworldUI.TEXT)
		return
	if not expanded:
		draw_string(font,Vector2(10,18),"MAP %s/2 / CLICK TO EXPLORE" % stage.map_index,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UnderworldUI.TEXT)
		draw_string(font,Vector2(10,148),"Fog: unexplored   B Boss   C Camp",HORIZONTAL_ALIGNMENT_LEFT,-1,10,UnderworldUI.MUTED)
	var bounds:=_world_rect()
	# Only reveal tiles already visited physically; unknown land remains opaque.
	for key: String in stage.region_state.explored:
		var coords:=key.split(":")
		var world_cell:=Rect2(Vector2(float(coords[0]),float(coords[1]))*PlainsMapExploration.CELL,Vector2.ONE*PlainsMapExploration.CELL).intersection(bounds)
		if world_cell.has_area(): draw_rect(Rect2(project_point(world_cell.position),world_cell.size*_fit_scale()*zoom),Color("233329"))
	var g:=PlainsRegionGenerator.new()
	for e: Dictionary in stage.generated.manifest.connections:
		var path: Array=e.get("path",[g._area(stage.generated.manifest,e.a).position,g._area(stage.generated.manifest,e.b).position])
		var locked: bool=e.condition=="backside" and not stage.region_state.opened.has(e.id)
		for i: int in path.size()-1:
			var a:=Vector2(path[i][0],path[i][1]); var b:=Vector2(path[i+1][0],path[i+1][1])
			var steps:=maxi(1,ceili(a.distance_to(b)/(PlainsMapExploration.CELL/4)))
			for n: int in steps:
				var start:=a.lerp(b,float(n)/steps); var end:=a.lerp(b,float(n+1)/steps)
				if PlainsMapExploration.revealed(stage.region_state,start) and PlainsMapExploration.revealed(stage.region_state,end):
					draw_line(project_point(start),project_point(end),UnderworldUI.BRASS if locked else UnderworldUI.MOSS,2 if expanded else 1)
	for a: Dictionary in visible_areas():
		var p:=project(a.position)
		var color:=Color("d2d9ac") if stage.region_state.visited.has(a.id) else Color("8aab8f")
		if a.role=="boss": color=Color("e8b76c")
		if a.role=="merchant": color=UnderworldUI.COOL
		draw_circle(p,5 if expanded else 3,color)
		if a.role in ["merchant","boss","challenge_reward"]:
			draw_string(font,p+Vector2(7,-4),"B" if a.role=="boss" else "C" if a.role=="merchant" else "*",HORIZONTAL_ALIGNMENT_LEFT,-1,14 if expanded else 10,color)
		if expanded:
			draw_string(font,p+Vector2(8,18),stage.area_label(a),HORIZONTAL_ALIGNMENT_LEFT,180,11,color)
	var player:=stage.global_player_position()
	if player.is_finite(): draw_circle(project_point(player),5 if expanded else 3,Color("fff5ca"))

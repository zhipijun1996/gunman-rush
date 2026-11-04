class_name PlainsRegionMap
extends Control
## Both map sizes share the same run-local fog; no undiscovered graph or icons.
signal open_requested
var stage: PlainsRegionStage
var expanded := false
var region_chip := false
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var _touches: Dictionary = {}
var _pinch_distance := 0.0
var _terrain_cells:Dictionary={}
var _geometry_revision:=-1
var _view_signature:Array=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	focus_mode=Control.FOCUS_ALL
	if not expanded: size=Vector2(160,32) if region_chip else Vector2(240,156)
func _process(_delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(stage):return
	var signature:Array=[stage.global_player_position().floor(),stage.region_state.explored.size(),stage.region_state.visited.size(),stage.geometry_revision,size,expanded,region_chip,zoom,pan,has_focus(),Rect2(Vector2.ZERO,size).has_point(get_local_mouse_position())]
	if signature!=_view_signature:_view_signature=signature;queue_redraw()
func frame() -> Rect2:
	return Rect2(16,16,maxf(1,size.x-32),maxf(1,size.y-32)) if expanded else Rect2(8,30,224,100)
func _world_rect() -> Rect2:
	var b: Array=stage.generated.manifest.world_bounds
	return Rect2(b[0],b[1],b[2],b[3])
func _fit_scale() -> float:
	var bounds:=_world_rect()
	var fitted:=minf(frame().size.x/bounds.size.x,frame().size.y/bounds.size.y)
	return fitted if expanded else maxf(fitted,minf(frame().size.x/2200.0,frame().size.y/1100.0))
func project(p: Array) -> Vector2:
	return project_point(Vector2(p[0],p[1]))
func project_point(p: Vector2) -> Vector2:
	var center:=_world_rect().get_center() if expanded else stage.global_player_position()
	return frame().get_center()+(p-center)*_fit_scale()*zoom+pan
func visible_areas() -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	if not is_instance_valid(stage): return found
	for a: Dictionary in stage.generated.manifest.areas:
		if PlainsMapExploration.revealed(stage.region_state,Vector2(a.position[0],a.position[1])): found.append(a)
	return found
func zoom_at(factor: float, anchor: Vector2) -> void:
	if not expanded or not is_finite(factor) or factor<=0: return
	var next:=clampf(zoom*factor,1.0,6.0)
	var relative:=anchor-frame().get_center()
	pan=relative-(relative-pan)*(next/zoom)
	zoom=next
	_limit_pan()
	queue_redraw()
func drag_by(amount: Vector2) -> void:
	if not expanded or not amount.is_finite(): return
	pan+=amount
	_limit_pan()
	queue_redraw()
func _limit_pan() -> void:
	var limit:=frame().size*zoom*0.75
	pan=pan.clamp(-limit,limit)
func reset_view() -> void:
	zoom=1
	pan=Vector2.ZERO
	queue_redraw()
func player_anchor() -> Vector2:
	var p:=project_point(stage.global_player_position())
	return p if frame().has_point(p) else frame().get_center()
func focus_player() -> void:
	zoom=2
	pan=-(stage.global_player_position()-_world_rect().get_center())*_fit_scale()*zoom
	_limit_pan()
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if not expanded:
		if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("ui_accept"):
			open_requested.emit()
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: zoom_at(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.2,event.position)
	elif event is InputEventMouseMotion and dragging: drag_by(event.relative)
	elif event is InputEventMagnifyGesture: zoom_at(event.factor,event.position)
	elif event is InputEventScreenTouch:
		if event.pressed: _touches[event.index]=event.position
		else: _touches.erase(event.index)
		_pinch_distance=0
	elif event is InputEventScreenDrag:
		_touches[event.index]=event.position
		if _touches.size()==1: drag_by(event.relative)
		elif _touches.size()==2:
			var points:=_touches.values()
			var distance: float=points[0].distance_to(points[1])
			if _pinch_distance>1: zoom_at(distance/_pinch_distance,(points[0]+points[1])*0.5)
			_pinch_distance=distance
	accept_event()
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
		draw_string(font,Vector2(10,148),"B Boss   C Camp   * Cache",HORIZONTAL_ALIGNMENT_LEFT,-1,10,UnderworldUI.MUTED)
	var bounds:=_world_rect()
	# Only reveal tiles already visited physically; unknown land remains opaque.
	for key: String in stage.region_state.explored:
		var coords:=key.split(":")
		var world_cell:=Rect2(Vector2(float(coords[0]),float(coords[1]))*PlainsMapExploration.CELL,Vector2.ONE*PlainsMapExploration.CELL).intersection(bounds)
		if world_cell.has_area(): draw_rect(Rect2(project_point(world_cell.position),world_cell.size*_fit_scale()*zoom).intersection(frame()),Color("233329"))
	# Draw the actual assembled terrain. Unused Ports are already sealed in
	# each Definition, so openings are the same holes the player can traverse.
	_draw_terrain()
	for a: Dictionary in visible_areas():
		if a.role not in ["merchant","boss","challenge_reward"]: continue
		var p:=project(a.position)
		if not frame().has_point(p): continue
		var color:=UnderworldUI.COOL if a.role=="merchant" else UnderworldUI.BRASS
		draw_circle(p,4 if expanded else 3,color)
		draw_string(font,p+Vector2(7,-4),"B" if a.role=="boss" else "C" if a.role=="merchant" else "*",HORIZONTAL_ALIGNMENT_LEFT,-1,14 if expanded else 10,color)
	var player:=stage.global_player_position()
	if player.is_finite(): draw_circle(project_point(player),5 if expanded else 3,Color("fff5ca"))
func _cache_terrain() -> void:
	if _geometry_revision==stage.geometry_revision:return
	_terrain_cells.clear();_geometry_revision=stage.geometry_revision
	for live:PlatformingModule in stage.assembler.modules:
		var definition:=live.definition
		for index:int in definition.platforms.size():
			if index in live.inactive_platform_indices:continue
			var terrain:Rect2=definition.platforms[index];terrain.position+=live.position
			for y:int in range(floori(terrain.position.y/PlainsMapExploration.CELL),ceili(terrain.end.y/PlainsMapExploration.CELL)):
				for x:int in range(floori(terrain.position.x/PlainsMapExploration.CELL),ceili(terrain.end.x/PlainsMapExploration.CELL)):
					var cell:=Rect2(Vector2(x,y)*PlainsMapExploration.CELL,Vector2.ONE*PlainsMapExploration.CELL)
					var key:="%s:%s" % [x,y]
					if not _terrain_cells.has(key):_terrain_cells[key]=[]
					_terrain_cells[key].append({"rect":terrain.intersection(cell),"one_way":index in definition.one_way_platform_indices})

func _draw_terrain() -> void:
	if stage.level_plan==null:return
	_cache_terrain()
	var scale_factor:=_fit_scale()*zoom
	var center:=_world_rect().get_center() if expanded else stage.global_player_position()
	var origin:=frame().get_center()+pan-center*scale_factor
	for key:String in stage.region_state.explored:
		for piece:Dictionary in _terrain_cells.get(key,[]):
			var terrain:Rect2=piece.rect
			var screen:=Rect2(origin+terrain.position*scale_factor,terrain.size*scale_factor).intersection(frame())
			if not screen.has_area():continue
			if piece.one_way:draw_line(screen.position,Vector2(screen.end.x,screen.position.y),Color("c9be86"),2 if expanded else 1)
			else:screen.size.y=maxf(screen.size.y,1);draw_rect(screen,Color("91a68d"))

func panel() -> StyleBoxFlat:
	var material := preload("res://game/presentation/ui/demo_ui_01/clockwork_theme.gd")
	var highlighted := not expanded and (has_focus() or Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()))
	return material.plate(material.RAISED if highlighted else material.PANEL, material.BRASS if highlighted else material.EDGE, 4)

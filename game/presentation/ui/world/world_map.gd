class_name FixedWorldMap
extends PlainsRegionMap
## Same map gestures/theme as the existing UI; fixed room knowledge replaces Stage.
var world: FixedWorldState
var content: FixedWorldProvider
var current_room := ""
var local_player := Vector2.ZERO
var selected_room := ""
var touch_clip: Control
var survey_visible := false
var _drawing := false
var _draw_rows: Array = []
var _draw_bounds := Rect2()
func frame() -> Rect2:
	return Rect2(12,30,maxf(1,size.x-24),maxf(1,size.y-44))
func rows() -> Array:
	if _drawing:return _draw_rows
	var result: Array = []
	if world == null: return result
	var component := ""
	for row: Dictionary in content.data.get("map_rooms",[]):
		if row.id == current_room: component = str(row.get("map_component",""));break
	var nearby: Array[String]=[current_room]
	if not expanded:
		for door: Dictionary in content.room(current_room).get("doors",[]):nearby.append(str(door.target_room))
	for row: Dictionary in content.data.get("map_rooms",[]):
		if not component.is_empty() and str(row.get("map_component","")) != component: continue
		if (survey_visible or row.id in world.value.get("explored",[])) and (expanded or row.id in nearby): result.append(row)
	return result
func _world_rect() -> Rect2:
	if _drawing:return _draw_bounds
	var bounds := Rect2()
	for row: Dictionary in rows():
		for raw: Array in row.polygon:
			var p := FixedWorldProvider.point(raw)
			bounds = Rect2(p,Vector2.ONE) if bounds.size==Vector2.ZERO else bounds.expand(p)
	return bounds.grow(16) if bounds.has_area() else Rect2(0,0,100,100)
func player_anchor() -> Vector2:
	for row: Dictionary in rows():
		if row.id==current_room: return project_point(FixedWorldProvider.point(row.origin)+local_player)
	return frame().get_center()
func focus_player() -> void:
	zoom=2
	for row: Dictionary in rows():
		if row.id==current_room:
			pan=-(FixedWorldProvider.point(row.origin)+local_player-_world_rect().get_center())*_fit_scale()*zoom
	selected_room=current_room
	_limit_pan();queue_redraw()
func _draw() -> void:
	if world==null or world.value.is_empty(): return
	# Projection used to rescan all room polygons for every individual vertex.
	_draw_rows=rows()
	_draw_bounds=_world_rect()
	_drawing=true
	var text_size:=maxi(14,ceili(14.0/DemoUiModalMetrics.ui_scale(get_viewport()))) if expanded else 14
	draw_style_box(panel(),Rect2(Vector2.ZERO,size))
	draw_string(UnderworldUI.FONT,Vector2(12,20),WorldText.text("review.map_title") if survey_visible else WorldText.text("world_map.00") if expanded else WorldText.text("world_map.01"),HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,UnderworldUI.TEXT)
	var visible := rows()

	for row: Dictionary in visible:
		var polygon := PackedVector2Array()
		for p: Array in row.polygon: polygon.append(project(p))
		if polygon.size()<3: continue
		draw_colored_polygon(polygon,Color("607b6b") if row.id==current_room else Color("354b49"))
		polygon.append(polygon[0])
		draw_polyline(polygon,UnderworldUI.BRASS if row.id==current_room else UnderworldUI.MOSS,2)
		if expanded:
			var label_size:=UnderworldUI.FONT.get_string_size(row.name,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size)
			var chamber: Array=content.room(row.id).world_geometry.space_rects[0]
			var visual_width:=absf(project_point(Vector2(float(chamber[2]),0)).x-project_point(Vector2.ZERO).x)
			if visual_width>label_size.x+12 or row.id==selected_room:
				var label_at:=project(row.map_centre)-Vector2(label_size.x*.5,0)
				draw_style_box(panel(),Rect2(label_at-Vector2(5,text_size),label_size+Vector2(10,8)))
				draw_string(UnderworldUI.FONT,label_at,row.name,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,UnderworldUI.TEXT)
		var contract:=content.room(row.id)
		if bool(contract.get("rest",{}).get("enabled",false)):
			var at:=project(row.map_centre)
			draw_rect(Rect2(at-Vector2(4,4),Vector2(8,8)),UnderworldUI.BRASS,false,2)
			draw_line(at+Vector2(-6,5),at+Vector2(6,5),UnderworldUI.BRASS,2)

	# Openings are short marks on shared boundaries, drawn after room fills.
	for row: Dictionary in visible:
		for door: Dictionary in content.room(row.id).get("doors",[]):
			if (not survey_visible and door.target_room not in world.value.explored) or row.id > door.target_room or content.room(door.target_room).is_empty(): continue
			var at := FixedWorldProvider.point(row.origin)+FixedWorldProvider.point(door.position_candidate.local_world_units)
			if door.direction in ["left","right"]: at.y -= 48
			var tangent := Vector2(48,0) if door.direction in ["up","down"] else Vector2(0,36)
			draw_line(project_point(at-tangent),project_point(at+tangent),Color("cce1c3"),4)

	draw_circle(player_anchor(),5,Color("f5e3aa"))
	_drawing=false

func select_at(at: Vector2) -> void:
	selected_room=""
	for row: Dictionary in rows():
		var points:=PackedVector2Array()
		for raw: Array in row.polygon:points.append(project(raw))
		if Geometry2D.is_point_in_polygon(at,points):selected_room=str(row.id);break
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if expanded and (event is InputEventMouseMotion or (event is InputEventScreenTouch and event.pressed)):select_at(event.position)
	# Unused keys must reach modal cancel / gameplay commands, rather than being swallowed.
	if event is InputEventKey or event is InputEventJoypadButton:
		if expanded or not event.is_action_pressed("ui_accept"): return
	super._gui_input(event)

func _input(event: InputEvent) -> void:
	if not expanded or not is_visible_in_tree(): return
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag: return
	if not _touches.has(event.index) and touch_clip!=null:
		var clip_point: Vector2=touch_clip.get_global_transform_with_canvas().affine_inverse()*event.position
		if not Rect2(Vector2.ZERO,touch_clip.size).has_point(clip_point): return
	var local: Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
	if not Rect2(Vector2.ZERO,size).has_point(local) and not _touches.has(event.index): return
	var mapped:=event.duplicate() as InputEvent
	mapped.position=local
	_gui_input(mapped)
	get_viewport().set_input_as_handled()

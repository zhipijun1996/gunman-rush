class_name FixedWorldMap
extends PlainsRegionMap
## Same map gestures/theme as the existing UI; fixed room knowledge replaces Stage.
var world: FixedWorldState
var content: FixedWorldProvider
var current_room := ""
var local_player := Vector2.ZERO
func frame() -> Rect2:
	return Rect2(12,30,maxf(1,size.x-24),maxf(1,size.y-44))
func rows() -> Array:
	var result: Array = []
	if world == null: return result
	for row: Dictionary in content.data.get("map_rooms",[]):
		if row.id in world.value.get("explored",[]): result.append(row)
	return result
func _world_rect() -> Rect2:
	var bounds := Rect2()
	for row: Dictionary in rows():
		for raw: Array in row.polygon:
			var p := FixedWorldProvider.point(raw)
			bounds = Rect2(p,Vector2.ONE) if bounds.size==Vector2.ZERO else bounds.expand(p)
	return bounds.grow(16) if bounds.has_area() else Rect2(0,0,100,100)
func player_anchor() -> Vector2:
	for row: Dictionary in rows():
		if row.id==current_room: return project(row.map_centre)
	return frame().get_center()
func focus_player() -> void:
	zoom=1
	pan=Vector2.ZERO
func _draw() -> void:
	if world==null or world.value.is_empty(): return
	draw_style_box(panel(),Rect2(Vector2.ZERO,size))
	draw_string(UnderworldUI.FONT,Vector2(12,20),WorldText.text("world_map.00") if expanded else WorldText.text("world_map.01"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,UnderworldUI.TEXT)
	var visible := rows()
	for row: Dictionary in visible:
		var polygon := PackedVector2Array()
		for p: Array in row.polygon: polygon.append(project(p))
		if polygon.size()<3: continue
		draw_colored_polygon(polygon,Color("607b6b") if row.id==current_room else Color("354b49"))
		polygon.append(polygon[0])
		draw_polyline(polygon,UnderworldUI.BRASS if row.id==current_room else UnderworldUI.MOSS,2)
		if expanded: draw_string(UnderworldUI.FONT,project(row.map_centre)+Vector2(8,0),row.name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,UnderworldUI.TEXT)
	# Connections are shown only when both actual rooms have been visited.
	for row: Dictionary in visible:
		for door: Dictionary in content.room(row.id).get("doors",[]):
			if door.target_room not in world.value.explored: continue
			for target: Dictionary in visible:
				if target.id==door.target_room: draw_line(project(row.map_centre),project(target.map_centre),Color("8dbda4"),2)
	draw_circle(player_anchor(),5,Color("f5e3aa"))

func _input(event: InputEvent) -> void:
	if not expanded or not is_visible_in_tree(): return
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag: return
	var local: Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
	if not Rect2(Vector2.ZERO,size).has_point(local) and not _touches.has(event.index): return
	var mapped:=event.duplicate() as InputEvent
	mapped.position=local
	_gui_input(mapped)
	get_viewport().set_input_as_handled()

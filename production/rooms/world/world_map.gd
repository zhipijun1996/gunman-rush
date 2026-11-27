class_name WorldRouteMap
extends Control
## The folded map uses the locked world's outlines. A concealed passage is drawn
## only after its discovery event. The room host owns travel and progression.
signal closed

const FONT := preload("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
const INK := Color("#c4d2bc")
const GOLD := Color("#f3ce80")
const PAPER := Color("#18262b")

var host: Node
var rooms: Dictionary
var doors: Array
var focus_room := ""
var new_game: Button
var was_paused := false
var button_fingers := {}
var close_button := Button.new()
var canvas := RegionCanvas.new()
var station_by_room := {}
var floorplans := {}

# The original map's mouse and multi-touch gestures operate on a clipped
# viewport. Room names, controls, and the safe-area frame stay outside it.
class RegionCanvas extends MapViewport:
	var region: WorldRouteMap
	func _draw() -> void:
		if region != null: region.draw_region(self,frame())
	func clear_gesture() -> void:
		dragging = false
		_touches.clear()
		_pinch_distance = 0.0
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventKey or event is InputEventJoypadButton: return
		super._gui_input(event)


static func mount(owner_node: Node) -> WorldRouteMap:
	var layer := CanvasLayer.new()
	layer.layer = 8
	owner_node.add_child(layer)
	var map := WorldRouteMap.new()
	map.host = owner_node
	layer.add_child(map)
	return map

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.region = self
	canvas.expanded = true
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.offset_left = 52
	canvas.offset_top = 93
	canvas.offset_right = -52
	canvas.offset_bottom = -115
	close_button.name = "CloseMap"
	close_button.text = "关闭地图"
	close_button.theme = DemoClockworkTheme.create_theme()
	close_button.theme_type_variation = &"CompactButton"
	close_button.pressed.connect(close)
	add_child(close_button)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -218
	close_button.offset_right = -64
	close_button.offset_top = 39
	close_button.offset_bottom = 88
	var session: OrdinaryRoomSession = host.get("active")
	focus_room = session.room.room_id
	session.touch_controls.map_requested.connect(open)
	host.connect("room_changed", arrive)
	if host.reset_dialog != null:
		new_game = host.new_game_button()
		add_child(new_game)
		new_game.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		new_game.offset_left = -220
		new_game.offset_right = -65
		new_game.offset_top = -95
		new_game.offset_bottom = -47
	var catalog := session.content_catalog
	for station: Dictionary in catalog.object("transport").value.stations:
		station_by_room[station.room] = station.id
	for row: Dictionary in catalog.table("rooms").rows:
		if host.has_room(row.id):
			rooms[row.id] = row
	for door: Dictionary in catalog.table("doors").rows:
		if rooms.has(door.a) and rooms.has(door.b):
			doors.append(door)

func arrive(id: String) -> void:
	focus_room = id
	host.active.touch_controls.map_requested.connect(open)
	queue_redraw()

func open(from_paused := false) -> void:
	if visible or host.crossing or (get_tree().paused and not from_paused): return
	was_paused = get_tree().paused
	host.active.controller.router.clear("world_map")
	canvas.clear_gesture()
	canvas.reset_view()
	show()
	close_button.grab_focus()
	get_tree().paused = true
	queue_redraw()

func close() -> void:
	if not visible: return
	canvas.clear_gesture()
	button_fingers.clear()
	close_button.release_focus()
	hide()
	get_tree().paused = was_paused
	was_paused = false
	host.active.controller.router.clear("world_map_closed")
	closed.emit()

func _input(event: InputEvent) -> void:
	# Native touchscreen events are captured independently of mouse emulation.
	# Only contacts begun on the map belong to its drag/pinch gesture.
	if visible and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		if event is InputEventScreenTouch:
			if event.pressed:
				for button: Button in [close_button,new_game]:
					if button != null and button.get_global_rect().has_point(event.position):
						button_fingers[event.index] = button
						get_viewport().set_input_as_handled()
						return
			elif button_fingers.has(event.index):
				var button: Button = button_fingers[event.index]
				button_fingers.erase(event.index)
				get_viewport().set_input_as_handled()
				if not event.canceled and button.get_global_rect().has_point(event.position):
					button.pressed.emit()
				return
		if button_fingers.has(event.index):
			get_viewport().set_input_as_handled()
			return
		var local := canvas.get_global_transform_with_canvas().affine_inverse()*Vector2(event.position)
		if Rect2(Vector2.ZERO,canvas.size).has_point(local) or canvas._touches.has(event.index):
			var mapped := event.duplicate() as InputEvent
			mapped.position = local
			canvas._gui_input(mapped)
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if visible and event.physical_keycode in [KEY_M, KEY_ESCAPE]:
		close()
	elif event.physical_keycode == KEY_M and not get_tree().paused and not host.crossing:
		open()
	else: return
	get_viewport().set_input_as_handled()

func known_rooms() -> Dictionary:
	var session: OrdinaryRoomSession = host.get("active")
	var known := {}
	known[focus_room] = true
	for room_id: String in session.state.value.explored:
		if rooms.has(room_id):
			known[room_id] = true
	for door: Dictionary in doors:
		if door.has("discovery") and session.state.has(str(door.discovery.event)):
			known[door.b if door.a == door.discovery.source_room else door.a] = true
	return known

func _draw() -> void:
	var panel := Rect2(Vector2(30, 30), size - Vector2(60, 60))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.06, 0.07, 0.85))
	draw_rect(panel, PAPER)
	draw_rect(panel, Color("#718373"), false, 2)
	var catalog: WorldContentCatalog = host.active.content_catalog
	var region_name: String = catalog.lookup("regions",rooms[focus_room].region).row.name
	draw_string(FONT, panel.position + Vector2(28, 42), region_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, INK)
	var caption := focus_room + "　" + str(rooms[focus_room].name)
	if host.active_doc.get("reception",false): caption += " · 接收段"
	draw_string(FONT,panel.position+Vector2(28,panel.size.y-55),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,22,GOLD)
	draw_string(FONT,panel.position+Vector2(28,panel.size.y-23),"● 位置　▱ 歇脚处　◎ 已启用钟站",HORIZONTAL_ALIGNMENT_LEFT,-1,16,INK)

func floorplan(id: String) -> Dictionary:
	if floorplans.has(id): return floorplans[id]
	var doc: Dictionary = host.active_doc if id == focus_room else host.read_destination(id)
	if doc.has("error"): return {}
	var plan := {"bounds":FixedWorldProvider.rect(doc.bounds)}
	var root_props: Dictionary = doc.root.properties
	if root_props.has("rest_point"):
		var rest := FixedWorldProvider.point(root_props.rest_point)
		if not rest.is_zero_approx(): plan["rest"] = rest
	for entity: Dictionary in doc.entities.values():
		if entity.definition_id == "recovery.station":
			plan["rest"] = FixedWorldProvider.point(entity.properties.position)
	var stop: String = station_by_room.get(id,"")
	if not stop.is_empty() and doc.get("sites",{}).has(stop):
		plan["station"] = FixedWorldProvider.point(doc.sites[stop].at)
	floorplans[id] = plan
	return plan

func map_position(id: String, local: Vector2) -> Vector2:
	var bounds: Rect2 = floorplan(id).bounds
	var row: Dictionary = rooms[id]
	var outline := FixedWorldProvider.rect(row.rect)
	var point := outline.position + ((local-bounds.position)/bounds.size).clamp(Vector2.ZERO,Vector2.ONE)*outline.size
	var polygon := PackedVector2Array()
	for vertex: Array in row.navigation.polygon: polygon.append(FixedWorldProvider.point(vertex))
	if Geometry2D.is_point_in_polygon(point,polygon): return point
	# Some surveyed rooms have concave outlines. Keep a room-local marker
	# on its own polygon instead of showing it inside the neighboring room.
	var nearest := polygon[0]
	for i: int in polygon.size():
		var edge := Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])
		if point.distance_squared_to(edge)<point.distance_squared_to(nearest): nearest = edge
	return nearest

func known_markers(id: String) -> Dictionary:
	var state: Dictionary = host.active.state.value
	if id != focus_room and id not in state.explored: return {}
	var plan := floorplan(id)
	var markers := {}
	if plan.has("rest"): markers["rest"] = map_position(id,plan.rest)
	if plan.has("station") and state.receipts.has(station_by_room[id]):
		markers["station"] = map_position(id,plan.station)
	return markers

func draw_region(canvas: CanvasItem, box: Rect2, miniature := false) -> void:
	if not rooms.has(focus_room) or not box.has_area(): return
	var known := known_rooms()
	var area := FixedWorldProvider.rect(rooms[focus_room].rect)
	for id: String in known.keys():
		if rooms[id].region != rooms[focus_room].region or (rooms[id].get("map_layer") != rooms[focus_room].get("map_layer")):
			known.erase(id)
			continue
		area = area.merge(FixedWorldProvider.rect(rooms[id].rect))
	area = area.grow(1.0)
	var scale_factor := minf(box.size.x / area.size.x, box.size.y / area.size.y)
	if not miniature: scale_factor *= self.canvas.zoom
	var origin := box.get_center() - area.get_center() * scale_factor
	if not miniature: origin += self.canvas.pan
	for id: String in known:
		var row: Dictionary = rooms[id]
		var shape := PackedVector2Array()
		for vertex: Array in row.navigation.polygon:
			shape.append(origin + FixedWorldProvider.point(vertex) * scale_factor)
		var current := id == focus_room
		canvas.draw_colored_polygon(shape, Color("#51635a") if current else Color("#34464a"))
		shape.append(shape[0])
		canvas.draw_polyline(shape, GOLD if current else INK, 1 if miniature else 2, true)
	if miniature:
		canvas.draw_circle(origin + map_position(focus_room,host.active.player.position)*scale_factor,3.0,GOLD)
		return
	for door: Dictionary in doors:
		if door.has("discovery") and not host.active.state.has(str(door.discovery.event)): continue
		if door.connection_type == "interior":
			for id: String in [door.a,door.b]:
				if known.has(id):
					var pin := origin + FixedWorldProvider.point(door.entrances[id].anchor) * scale_factor
					canvas.draw_rect(Rect2(pin-Vector2(3,4),Vector2(6,8)),GOLD,false,2)
			continue
		if not known.has(door.a) or not known.has(door.b): continue
		var seam: Dictionary = door.door
		var a := Vector2(seam.fixed, seam.start)
		var b := Vector2(seam.fixed, seam.end)
		if seam.axis == "h":
			a = Vector2(seam.start, seam.fixed)
			b = Vector2(seam.end, seam.fixed)
		canvas.draw_line(origin + a * scale_factor, origin + b * scale_factor, GOLD, 5, true)
	for id: String in known:
		var row: Dictionary = rooms[id]
		var at := origin + FixedWorldProvider.point(row.navigation.label_anchor) * scale_factor
		canvas.draw_string(FONT, at + Vector2(-60, 6), id, HORIZONTAL_ALIGNMENT_CENTER, 120, 20, GOLD if id == focus_room else INK)
		var markers := known_markers(id)
		if markers.has("rest"):
			var bench: Vector2 = origin + markers.rest*scale_factor
			canvas.draw_line(bench+Vector2(-6,-2),bench+Vector2(6,-2),INK,3)
			canvas.draw_line(bench+Vector2(-4,-2),bench+Vector2(-4,4),INK,2)
			canvas.draw_line(bench+Vector2(4,-2),bench+Vector2(4,4),INK,2)
		if markers.has("station"):
			var stop: Vector2 = origin + markers.station*scale_factor
			canvas.draw_arc(stop,8,0,TAU,18,GOLD,2,true)
			canvas.draw_arc(stop,4,0,TAU,14,GOLD,2,true)
	var here := origin + map_position(focus_room,host.active.player.position)*scale_factor
	canvas.draw_circle(here,6.0,PAPER)
	canvas.draw_circle(here,4.0,Color("#fff4bd"))

class_name P02RouteMap
extends Control
## The folded map uses the locked world's outlines. A concealed passage is drawn
## only after its discovery event. The room host owns travel and progression.
const FONT := preload("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
const FIELD := "P02"
const INK := Color("#c4d2bc")
const GOLD := Color("#f3ce80")
const PAPER := Color("#18262b")

var host: Node
var rooms: Dictionary
var doors: Array
var area: Rect2
var focus_room := FIELD

static func mount(owner_node: Node) -> P02RouteMap:
	var layer := CanvasLayer.new()
	layer.layer = 8
	owner_node.add_child(layer)
	var map := P02RouteMap.new()
	map.host = owner_node
	layer.add_child(map)
	return map

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var session: OrdinaryRoomSession = host.get("active")
	focus_room = session.room.room_id
	host.connect("room_changed", arrive)
	doors = session.content_catalog.connections(FIELD).rows
	for door: Dictionary in doors:
		for id: String in [door.a, door.b]:
			if rooms.has(id):
				continue
			var row: Dictionary = session.content_catalog.lookup("rooms", id).row
			var bounds := FixedWorldProvider.rect(row.rect)
			area = bounds if rooms.is_empty() else area.merge(bounds)
			rooms[id] = row

func arrive(id: String) -> void:
	focus_room = id
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_M and (visible or not get_tree().paused):
		visible = not visible
	elif visible and event.physical_keycode == KEY_ESCAPE:
		hide()
	else:
		return
	get_tree().paused = visible
	get_viewport().set_input_as_handled()
	queue_redraw()

func known_rooms() -> Dictionary:
	var session: OrdinaryRoomSession = host.get("active")
	var known := {}
	known[focus_room] = true
	for room_id: String in session.state.value.explored:
		if rooms.has(room_id):
			known[room_id] = true
	for door: Dictionary in doors:
		if door.has("discovery") and session.state.has(str(door.discovery.event)):
			known[door.b if door.a == FIELD else door.a] = true
	return known

func _draw() -> void:
	var panel := Rect2(Vector2(30, 30), size - Vector2(60, 60))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.06, 0.07, 0.85))
	draw_rect(panel, PAPER)
	draw_rect(panel, Color("#718373"), false, 2)
	draw_string(FONT, panel.position + Vector2(28, 42), "风铃平原", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, INK)
	draw_string(FONT, Vector2(panel.end.x - 180, panel.position.y + 40), "M / Esc  收起", HORIZONTAL_ALIGNMENT_RIGHT, 150, 18, INK)
	var box := Rect2(panel.position + Vector2(58, 62), panel.size - Vector2(116, 136))
	var scale_factor := minf(box.size.x / area.size.x, box.size.y / area.size.y)
	var origin := box.get_center() - area.get_center() * scale_factor
	var known := known_rooms()
	for id: String in known:
		var row: Dictionary = rooms[id]
		var shape := PackedVector2Array()
		for vertex: Array in row.navigation.polygon:
			shape.append(origin + FixedWorldProvider.point(vertex) * scale_factor)
		var current := id == focus_room
		draw_colored_polygon(shape, Color("#51635a") if current else Color("#34464a"))
		shape.append(shape[0])
		draw_polyline(shape, GOLD if current else INK, 2, true)
	for door: Dictionary in doors:
		if not known.has(door.a) or not known.has(door.b):
			continue
		var seam: Dictionary = door.door
		var a := Vector2(seam.fixed, seam.start)
		var b := Vector2(seam.fixed, seam.end)
		if seam.axis == "h":
			a = Vector2(seam.start, seam.fixed)
			b = Vector2(seam.end, seam.fixed)
		draw_line(origin + a * scale_factor, origin + b * scale_factor, GOLD, 5, true)
	for id: String in known:
		var row: Dictionary = rooms[id]
		var at := origin + FixedWorldProvider.point(row.navigation.label_anchor) * scale_factor
		draw_string(FONT, at + Vector2(-60, 6), id, HORIZONTAL_ALIGNMENT_CENTER, 120, 20, GOLD if id == focus_room else INK)
	var caption := "当前位置　" + focus_room + "　" + str(rooms[focus_room].name)
	draw_string(FONT, Vector2(panel.position.x + 28, panel.end.y - 27), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GOLD)

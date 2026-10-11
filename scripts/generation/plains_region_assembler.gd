class_name PlainsRegionAssembler
extends RandomStageAssembler
## Explicit region assembler, leaves the eight-room regression assembler intact.
var region_state: PlainsRegionState
var shortcut_bodies: Dictionary = {}
var shortcut_shapes: Dictionary = {}

func build(recorded: Dictionary, tuning: PlayerTuning) -> Dictionary:
	if not is_inside_tree() or not modules.is_empty() or not PlainsRegionGenerator.new().validate(recorded, tuning):
		return {"ok": false, "error": "Invalid connected region manifest"}
	manifest = recorded.duplicate(true)
	var r: Array = manifest.world_bounds
	bounds = Rect2(r[0],r[1],r[2],r[3])
	for n: Dictionary in manifest.nodes:
		var module := PlatformingModule.new()
		module.name = str(n.id).replace("/", "_")
		module.definition = PlainsRegionGenerator.definition(n)
		module.position = Vector2(n.offset[0],n.offset[1])
		module.authoring_debug = false
		modules.append(module)
		if region_state != null: module.clock = float(region_state.clocks.get(n.id, 0.0))
		add_child(module)
	if not manifest.ground_supports.is_empty():
		ground_supports=PlainsGroundSupports.new()
		add_child(ground_supports)
		var columns: Array[Rect2]=[]
		for support: Array in manifest.ground_supports: columns.append(Rect2(support[0],support[1],support[2],support[3]))
		ground_supports.install(columns)
	for e: Dictionary in manifest.connections:
		if e.condition != "backside": continue
		var gate: Array = e.gate
		var body := StaticBody2D.new()
		body.position = Vector2(gate[0]+gate[2]/2.0,gate[1]+gate[3]/2.0)
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(gate[2],gate[3])
		shape.shape = rect
		shape.disabled = region_state != null and region_state.opened.has(e.id)
		body.add_child(shape)
		add_child(body)
		shortcut_bodies[e.id] = body
		shortcut_shapes[e.id] = shape
	return {"ok": true}

func open_shortcut(id: String, location: Vector2) -> bool:
	for e: Dictionary in manifest.connections:
		if e.id != id or e.condition != "backside" or region_state.opened.has(id): continue
		if location.distance_to(Vector2(e.control[0],e.control[1])) > 90: return false
		region_state.opened[id] = true
		(shortcut_shapes[id] as CollisionShape2D).set_deferred("disabled", true)
		queue_redraw()
		return true
	return false

func world_entry() -> Vector2:
	return Vector2(manifest.spawn[0],manifest.spawn[1])

func world_exits() -> Array[Dictionary]: return []

func world_anchors() -> Array[Vector2]:
	var result: Array[Vector2] = [world_entry()]
	for a: Dictionary in manifest.areas:
		if a.role == "boss": continue
		result.append(Vector2(a.position[0],a.position[1]))
	return result

func _draw() -> void:
	for id: String in shortcut_bodies:
		if region_state.opened.has(id): continue
		var body := shortcut_bodies[id] as StaticBody2D
		var shape := shortcut_shapes[id] as CollisionShape2D
		var rect := (shape.shape as RectangleShape2D).size
		draw_rect(Rect2(body.position-rect/2,rect),Color("ba9467"))

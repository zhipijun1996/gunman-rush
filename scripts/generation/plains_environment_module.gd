class_name PlainsEnvironmentModule
extends PlatformingModule
## Polygon-backed module: no rectangular collider or old terrain skin is installed.
var solids: Array[Dictionary] = []
var collision_nodes: Array[CollisionPolygon2D] = []
var presentation_ready := false
var presented_solid_ids: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = -200
	for solid: Dictionary in solids:
		var body := StaticBody2D.new()
		body.name = str(solid.id)
		body.collision_layer = 1
		var shape := CollisionPolygon2D.new()
		shape.name = "ActualPolygon"
		var points := PackedVector2Array()
		for p: Array in solid.points: points.append(Vector2(p[0],p[1]))
		shape.polygon = points
		body.add_child(shape)
		add_child(body)
		collision_nodes.append(shape)
	for data: ModuleSawDefinition in definition.saws:
		var hazard := ModuleSawHazard.new()
		hazard.name = str(data.source_id)
		hazard.definition = data
		hazard.module = self
		hazards.append(hazard)
		add_child(hazard)
	queue_redraw()

func _draw() -> void:
	if presentation_ready: return
	# Honest structural fallback, never counted as finished environment art.
	for solid: Dictionary in solids:
		if str(solid.id) in presented_solid_ids: continue
		var points := PackedVector2Array()
		for p: Array in solid.points: points.append(Vector2(p[0],p[1]))
		draw_colored_polygon(points,Color("807a64") if str(solid.material)=="timber" else Color("a2aa89"))

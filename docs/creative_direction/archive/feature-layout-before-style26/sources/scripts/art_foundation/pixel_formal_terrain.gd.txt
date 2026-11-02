class_name PixelFormalTerrain
extends Node2D
## Exact-boundary presentation adapter for authored non-grid rectangles.
## Pixel clusters are quantized; collision silhouettes and union boundaries are not.
## This is deliberately not a 16/47-mask TileMap or a physics conversion.
const MATERIAL := preload("res://shaders/pixel_formal_terrain.gdshader")
const INK := Color("111e2b")
const DEEP := Color("203b46")
const STONE := Color("365a59")
const MOSS := Color("6e9180")
const CREAM := Color("ead39a")
const BRASS := Color("a66d45")
const ROSE := Color("b47c64")
var union_edges := PackedVector4Array()
var union_pieces: Array[Rect2] = []

static func geometry_plan(solids: Array[Rect2]) -> Dictionary:
	var unique: Dictionary = {}
	for rect: Rect2 in solids:
		if not rect.has_area(): continue
		for face: Dictionary in PlainsTerrainBorders.plan(rect, solids).faces:
			var a: Vector2 = face.start
			var b: Vector2 = face.finish
			if face.side in ["bottom", "left"]:
				var swap := a; a = b; b = swap
			unique[Vector4(a.x, a.y, b.x, b.y)] = true
	var edges := PlainsTileComposer.merge_edges(PackedVector4Array(unique.keys()))
	return {"edges": edges, "pieces": PlainsTileComposer.pieces_from_edges(edges)}

static func build(solids: Array[Rect2]) -> PixelFormalTerrain:
	var node := PixelFormalTerrain.new()
	node.name = "PixelExactTerrain"
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var plan := geometry_plan(solids)
	node.union_edges = plan.edges
	node.union_pieces.assign(plan.pieces)
	var pending: Array[Rect2] = node.union_pieces.duplicate()
	while not pending.is_empty():
		var rect: Rect2 = pending.pop_back()
		var faces := _nearby_edges(rect, node.union_edges)
		if faces.size() > 64:
			# Subdivide only drawing quads. Never truncate union boundaries or solids.
			if maxf(rect.size.x, rect.size.y) <= .25:
				node.free(); return null
			var vertical := rect.size.x >= rect.size.y
			var size := Vector2(rect.size.x / 2.0, rect.size.y) if vertical else Vector2(rect.size.x, rect.size.y / 2.0)
			pending.append(Rect2(rect.position, size))
			pending.append(Rect2(rect.position + Vector2(size.x, 0) if vertical else rect.position + Vector2(0, size.y), size))
			continue
		var material := ShaderMaterial.new()
		material.shader = MATERIAL
		material.set_shader_parameter("shape_origin", rect.position)
		material.set_shader_parameter("face_count", faces.size())
		faces.resize(64)
		material.set_shader_parameter("faces", faces)
		var quad := ColorRect.new()
		quad.position = rect.position
		quad.size = rect.size
		quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quad.material = material
		quad.set_meta("exact_union_piece", rect)
		node.add_child(quad)
	return node

static func _nearby_edges(rect: Rect2, edges: PackedVector4Array) -> PackedVector4Array:
	var result := PackedVector4Array()
	for edge: Vector4 in edges:
		var a := Vector2(edge.x, edge.y)
		var b := Vector2(edge.z, edge.w)
		if rect.grow(12).intersects(Rect2(a.min(b), a.max(b) - a.min(b)).grow(.001)):
			result.append(edge)
	return result

static func _inside(node: CanvasItem, bounds: Rect2, part: Rect2, color: Color) -> void:
	var clipped := bounds.intersection(part)
	if clipped.has_area(): node.draw_rect(clipped, color)

static func draw_one_way(node: CanvasItem, rect: Rect2) -> void:
	# A thin reed/wood deck with visible open underside distinguishes pass-through.
	_inside(node, rect, Rect2(rect.position, Vector2(rect.size.x, 8)), STONE)
	_inside(node, rect, Rect2(rect.position, Vector2(rect.size.x, 2)), CREAM)
	for x: float in [rect.position.x + 4, rect.end.x - 6]:
		_inside(node, rect, Rect2(x, rect.position.y + 2, 2, 8), BRASS)
	for x: int in range(int(rect.position.x) + 22, int(rect.end.x) - 8, 30):
		_inside(node, rect, Rect2(x, rect.position.y + 3, 2, 3), MOSS)

static func build_moving(rect: Rect2) -> Node2D:
	var node := PixelMovingPaint.new()
	node.name = "PixelCopperCarrier"
	node.bounds = rect
	return node

class PixelMovingPaint extends Node2D:
	var bounds: Rect2
	func _draw() -> void:
		PixelFormalTerrain.draw_moving(self, bounds)

static func draw_moving(node: CanvasItem, rect: Rect2) -> void:
	node.draw_rect(rect, INK)
	_inside(node, rect, Rect2(rect.position + Vector2(0, 2), Vector2(rect.size.x, maxf(0, rect.size.y - 4))), BRASS)
	_inside(node, rect, Rect2(rect.position, Vector2(rect.size.x, 2)), CREAM)
	for x: float in [rect.position.x + 5, rect.end.x - 9]:
		_inside(node, rect, Rect2(x, rect.position.y + 5, 4, 4), CREAM)
	if rect.size.y >= 16:
		_inside(node, rect, Rect2(rect.position.x + 12, rect.end.y - 6, maxf(0, rect.size.x - 24), 2), DEEP)

static func draw_saw(node: CanvasItem, radius: float) -> void:
	# Rotates with the existing hazard node. Each square remains inside its circle;
	# no extra teeth exceed the swept-contact radius.
	for y: int in range(-ceili(radius), ceili(radius), 2):
		for x: int in range(-ceili(radius), ceili(radius), 2):
			var center := Vector2(x + 1, y + 1)
			var far := Vector2(maxf(absf(x), absf(x + 2)), maxf(absf(y), absf(y + 2)))
			if far.length() > radius: continue
			var distance := center.length()
			var angle := fposmod(center.angle() / TAU * 10, 1.0)
			var color := BRASS
			if distance > radius - 5: color = CREAM if angle < .5 else DEEP
			elif distance < radius * .4: color = INK
			elif distance < radius * .55: color = STONE
			node.draw_rect(Rect2(x, y, 2, 2), color)
	var hub := minf(2, radius / 3)
	node.draw_rect(Rect2(-hub, -hub, hub * 2, hub * 2), ROSE)

static func draw_gate(node: CanvasItem, rect: Rect2) -> void:
	# A continuous closed lattice with rivets clearly reads as a blocking gate.
	node.draw_rect(rect, INK)
	_inside(node, rect, Rect2(rect.position, Vector2(rect.size.x, 4)), BRASS)
	_inside(node, rect, Rect2(rect.position.x, rect.end.y - 4, rect.size.x, 4), BRASS)
	for x: int in range(int(rect.position.x) + 4, int(rect.end.x), 12):
		_inside(node, rect, Rect2(x, rect.position.y, 4, rect.size.y), STONE)
		_inside(node, rect, Rect2(x, rect.position.y + 4, 2, maxf(0, rect.size.y - 8)), MOSS)
	var lock_at := rect.get_center() - Vector2(5, 7)
	_inside(node, rect, Rect2(lock_at, Vector2(10, 14)), BRASS)
	_inside(node, rect, Rect2(rect.get_center() - Vector2(1, 3), Vector2(2, 6)), CREAM)

static func draw_thorns(node: CanvasItem, danger: Rect2, face: int = PlatformThornDefinition.Face.TOP) -> void:
	# Full connected root band remains visible: gaps between tips are not safe.
	var horizontal := face in [PlatformThornDefinition.Face.TOP, PlatformThornDefinition.Face.BOTTOM]
	var length := danger.size.x if horizontal else danger.size.y
	var depth := danger.size.y if horizontal else danger.size.x
	var count := maxi(1, int(ceil(length / 16.0)))
	for i: int in count:
		var a := length * i / count
		var b := length * (i + 1) / count
		# Stair-step pixel silhouettes rather than vector triangles.
		for step: int in 4:
			var inset := (b - a) * step / 8.0
			var near := a + inset
			var far := b - inset
			var h := depth / 4.0
			var local := Rect2(near, depth - (step + 1) * h, far - near, h)
			var at: Rect2
			if face == PlatformThornDefinition.Face.TOP: at = Rect2(danger.position + local.position, local.size)
			elif face == PlatformThornDefinition.Face.BOTTOM: at = Rect2(danger.position + Vector2(local.position.x, depth - local.end.y), local.size)
			elif face == PlatformThornDefinition.Face.LEFT: at = Rect2(danger.position + Vector2(local.position.y, local.position.x), Vector2(local.size.y, local.size.x))
			else: at = Rect2(danger.position + Vector2(depth - local.end.y, local.position.x), Vector2(local.size.y, local.size.x))
			node.draw_rect(at, ROSE if step < 3 else CREAM)

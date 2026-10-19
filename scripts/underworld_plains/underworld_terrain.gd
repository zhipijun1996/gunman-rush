class_name UnderworldTerrain
extends Node2D
## Source-native Underworld material; never owns bodies or alters collision.
## Aligned interiors are real TileMapLayer cells. Non-grid union edges use an
## explicit exact-boundary adapter sampling the very same publisher pixels.
const BUILD_PATH := "res://assets/underworld_plains/terrain/terrain_build.json"
const SHADER := preload("res://scripts/underworld_plains/underworld_terrain.gdshader")
var union_edges := PackedVector4Array()
var union_pieces: Array[Rect2] = []
var union_corners := PackedVector4Array()
var core_cells: Dictionary = {}
var boundary_pieces: Array[Rect2] = []
var core_layer: TileMapLayer

static func specification() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH))

static func geometry_plan(solids: Array[Rect2]) -> Dictionary:
	# Reuse the already verified union construction, not its obsolete paint.
	return PixelFormalTerrain.geometry_plan(solids)

static func _contains(pieces: Array[Rect2], point: Vector2) -> bool:
	for rect: Rect2 in pieces:
		if rect.has_point(point): return true
	return false

static func _corners(edges: PackedVector4Array, pieces: Array[Rect2]) -> PackedVector4Array:
	var vertices: Dictionary = {}
	for edge: Vector4 in edges:
		vertices[Vector2(edge.x, edge.y)] = true
		vertices[Vector2(edge.z, edge.w)] = true
	var result := PackedVector4Array()
	var directions := [Vector2(1,1), Vector2(-1,1), Vector2(1,-1), Vector2(-1,-1)]
	for vertex: Vector2 in vertices:
		var filled: Array[bool] = []
		for direction: Vector2 in directions: filled.append(PlainsTerrainBorders.occupied_side(vertex, direction, pieces))
		var count := filled.count(true)
		if count == 1:
			result.append(Vector4(vertex.x,vertex.y,filled.find(true),0))
		elif count == 3:
			# The solid quadrant opposite the empty quadrant carries the inner arc.
			result.append(Vector4(vertex.x,vertex.y,3-filled.find(false)+4,0))
	return result

static func build(solids: Array[Rect2]) -> UnderworldTerrain:
	var node := UnderworldTerrain.new()
	node.name = "UnderworldTerrain"
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var spec := specification()
	var cell := int(spec.world_tile_wu)
	var plan := geometry_plan(solids)
	node.union_edges = plan.edges
	node.union_pieces.assign(plan.pieces)
	node.union_corners = _corners(node.union_edges,node.union_pieces)
	# Sum disjoint canonical pieces: fully covered grid cells can enter TileMap.
	var areas: Dictionary = {}
	for rect: Rect2 in node.union_pieces:
		for y: int in range(floori(rect.position.y/cell),ceili(rect.end.y/cell)):
			for x: int in range(floori(rect.position.x/cell),ceili(rect.end.x/cell)):
				var key := Vector2i(x,y)
				var overlap := rect.intersection(Rect2(Vector2(key*cell),Vector2.ONE*cell))
				areas[key] = float(areas.get(key,0.0)) + overlap.get_area()
	var full: Dictionary = {}
	for key: Vector2i in areas:
		if is_equal_approx(areas[key],float(cell*cell)): full[key]=true
	for key: Vector2i in full:
		var safe := true
		for y: int in range(-1,2):
			for x: int in range(-1,2):
				var neighbour:=key+Vector2i(x,y)
				if areas.has(neighbour) and not full.has(neighbour): safe=false
		if safe: node.core_cells[key]=true
	node.core_layer=TileMapLayer.new()
	node.core_layer.name="Source47InteriorTileMap"
	node.core_layer.tile_set=load(spec.tileset) as TileSet
	node.core_layer.scale=Vector2.ONE*float(cell)/int(spec.tile_px)
	for key: Vector2i in node.core_cells:
		var mask:=Blob47Rules.mask_at(full,key)
		var atlas: Array = spec.mask_to_atlas[str(mask)]
		node.core_layer.set_cell(key,0,Vector2i(int(atlas[0]),int(atlas[1])))
	node.add_child(node.core_layer)
	# Subtract those exact full cells from the drawing only. Boundary strips are
	# canonical horizontal runs, so input splitting/order cannot change pixels.
	for rect: Rect2 in node.union_pieces:
		var ys: Array[float] = [rect.position.y,rect.end.y]
		for y: int in range(floori(rect.position.y/cell)+1,ceili(rect.end.y/cell)): ys.append(float(y*cell))
		ys.sort()
		for row: int in ys.size()-1:
			var run_start := rect.position.x
			var cursor := rect.position.x
			while cursor < rect.end.x:
				var x_end := minf(rect.end.x,float((floori(cursor/cell)+1)*cell))
				var key := Vector2i(floori(cursor/cell),floori(ys[row]/cell))
				if node.core_cells.has(key):
					if cursor>run_start: node.boundary_pieces.append(Rect2(run_start,ys[row],cursor-run_start,ys[row+1]-ys[row]))
					run_start=x_end
				cursor=x_end
			if cursor>run_start: node.boundary_pieces.append(Rect2(run_start,ys[row],cursor-run_start,ys[row+1]-ys[row]))
	var texture := load(spec.source_texture) as Texture2D
	var pending: Array[Rect2] = node.boundary_pieces.duplicate()
	while not pending.is_empty():
		var rect: Rect2 = pending.pop_back()
		var faces := PackedVector4Array()
		for edge: Vector4 in node.union_edges:
			var a:=Vector2(edge.x,edge.y);var b:=Vector2(edge.z,edge.w)
			if rect.grow(16.01).intersects(Rect2(a.min(b),a.max(b)-a.min(b)).grow(.001)): faces.append(edge)
		var corners := PackedVector4Array()
		for corner: Vector4 in node.union_corners:
			if rect.grow(16.01).has_point(Vector2(corner.x,corner.y)): corners.append(corner)
		if faces.size()>64 or corners.size()>64:
			if maxf(rect.size.x,rect.size.y)<.25: node.free();return null
			var half := rect.size
			if half.x>=half.y: half.x/=2.0
			else: half.y/=2.0
			pending.append(Rect2(rect.position,half))
			pending.append(Rect2(rect.position+Vector2(half.x,0) if rect.size.x>=rect.size.y else rect.position+Vector2(0,half.y),half))
			continue
		var material:=ShaderMaterial.new()
		material.shader=SHADER
		material.set_shader_parameter("source_pixels",texture)
		material.set_shader_parameter("source_size",Vector2(texture.get_size()))
		material.set_shader_parameter("shape_origin",rect.position)
		material.set_shader_parameter("face_count",faces.size())
		faces.resize(64);material.set_shader_parameter("faces",faces)
		material.set_shader_parameter("corner_count",corners.size())
		corners.resize(64);material.set_shader_parameter("corners",corners)
		var quad:=ColorRect.new()
		quad.position=rect.position;quad.size=rect.size
		quad.mouse_filter=Control.MOUSE_FILTER_IGNORE;quad.material=material
		quad.set_meta("exact_union_piece",rect)
		node.add_child(quad)
	return node

## Physics-semantic sibling interfaces: thin open decks and copper carriers.
## They never become solid tile cells or create new collider bodies.
static func draw_one_way(node: CanvasItem, rect: Rect2) -> void:
	var source := load(specification().source_texture) as Texture2D
	for x: int in range(0,ceili(rect.size.x),32):
		var width := minf(32.0,rect.size.x-x)
		node.draw_texture_rect_region(source,Rect2(rect.position+Vector2(x,0),Vector2(width,minf(6.0,rect.size.y))),Rect2(32,0,width/2.0,minf(3.0,rect.size.y/2.0)))
	for x: float in [rect.position.x+3,rect.end.x-5]:
		node.draw_rect(Rect2(x,rect.position.y+2,2,minf(8,rect.size.y-2)),Color("a69055"))

static func draw_moving(node: CanvasItem, rect: Rect2) -> void:
	node.draw_rect(rect,Color("19202a"))
	node.draw_rect(Rect2(rect.position,Vector2(rect.size.x,minf(3,rect.size.y))),Color("b49a58"))
	if rect.size.y>4: node.draw_rect(Rect2(rect.position+Vector2(2,4),Vector2(maxf(0,rect.size.x-4),minf(4,rect.size.y-4))),Color("796445"))
	for x: float in [rect.position.x+5,rect.end.x-7]:
		if rect.size.y>8: node.draw_rect(Rect2(x,rect.position.y+6,2,2),Color("d0bf7a"))

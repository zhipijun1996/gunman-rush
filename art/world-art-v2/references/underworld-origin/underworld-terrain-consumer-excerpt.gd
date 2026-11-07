class_name UnderworldTerrain
extends Node2D
## Selected native32px Underworld material; never owns bodies or alters collision.
## Aligned interiors are real TileMapLayer cells. Non-grid union edges use an
## explicit exact-boundary adapter sampling the very same selected source family.
## Legacy16 assets/spec/shader remain intact for historical reconstruction.
const BUILD_PATH := "res://assets/underworld_plains/terrain/fine_32/terrain_build.json"
const SHADER := preload("res://shaders/formal_fine_boundary.gdshader")
const CORE_SHADER := preload("res://shaders/formal_fine_lit.gdshader")
var union_edges := PackedVector4Array()
var union_pieces: Array[Rect2] = []
var union_corners := PackedVector4Array()
var core_cells: Dictionary = {}
var boundary_pieces: Array[Rect2] = []
var core_layer: TileMapLayer
static var _mechanism_spec: Dictionary = {}
static var _mechanism_textures: Dictionary = {}
static var _terrain_source: Texture2D

static func specification() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH))

static func source_texture() -> Texture2D:
	# Draw command buffers retain only a RID, so the source must outlive _draw.
	if _terrain_source==null:
		_terrain_source=load(specification().source_texture) as Texture2D
	return _terrain_source

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
	node.set_meta("art_pixel_world_units",float(cell)/int(spec.tile_px))
	var plan := geometry_plan(solids)
	node.union_edges = plan.edges
	node.union_pieces.assign(plan.pieces)
	node.union_corners = _corners(node.union_edges,node.union_pieces)
	# Sum disjoint canonical pieces: fully covered grid cells can enter TileMap.
	var areas: Dictionary = {}
	for rect: Rect2 in node.union_pieces:
		for y: int in range(floori(rect.position.y/cell),ceili(rect.end.y/cell)):

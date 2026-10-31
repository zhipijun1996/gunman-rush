class_name UnderworldHazardTiles
extends RefCounted
## Integrated hazardous platform material; the existing damage rectangles remain
## authoritative. This class owns rendering only, never colliders or emitters.
const SPEC_PATH := "res://assets/underworld_plains/hazards/hazard_fine_build.json"
const ROOT_DEPTH_EPSILON := 0.001
static var _spec: Dictionary = {}
static var _atlas: Texture2D

static func enabled(node: Node) -> bool:
	var cursor := node
	while cursor != null:
		if cursor.has_meta("underworld_formal_style"):
			return bool(cursor.get_meta("underworld_formal_style"))
		cursor = cursor.get_parent()
	return false

static func specification() -> Dictionary:
	if _spec.is_empty():
		var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
		if decoded is Dictionary:
			_spec = decoded
			var tile_set := load("res://" + str(_spec.atlas.tileset)) as TileSet
			var source := tile_set.get_source(int(_spec.atlas.source_id)) as TileSetAtlasSource
			_atlas = source.texture
	return _spec

static func surface_plan(danger: Rect2, face: int, host: Rect2) -> Array[Dictionary]:
	var spec := specification()
	var horizontal := face in [PlatformThornDefinition.Face.TOP, PlatformThornDefinition.Face.BOTTOM]
	var length := danger.size.x if horizontal else danger.size.y
	var depth := danger.size.y if horizontal else danger.size.x
	var root_depth := float(spec.world.embedded_root_depth)
	var width := float(spec.world.tile_width)
	var tile_px := Vector2(float(spec.atlas.tile_size_px[0]), float(spec.atlas.tile_size_px[1]))
	var external_px := float(spec.atlas.external_depth_px)
	var root_px := float(spec.atlas.embedded_root_px)
	var result: Array[Dictionary] = []
	var offset := 0.0
	while offset < length - ROOT_DEPTH_EPSILON:
		var segment := minf(width, length - offset)
		var column := 3 if length <= width else (0 if offset == 0 else (2 if offset + segment >= length else 1))
		var source_x := column * tile_px.x
		var external := Rect2(offset, -depth, segment, depth)
		var root := Rect2(offset, 0, segment, root_depth)
		result.append({"danger_local": external, "root_local": root,
			"danger_world": _oriented(external, danger, face),
			"root_world": _oriented(root, danger, face).intersection(host),
			"danger_source": Rect2(source_x, 0, segment / width * tile_px.x, external_px),
			"root_source": Rect2(source_x, external_px, segment / width * tile_px.x, root_px),
			"variant": str(spec.atlas.columns[column])})
		offset += segment
	return result

static func _origin(danger: Rect2, face: int) -> Vector2:
	if face == PlatformThornDefinition.Face.TOP: return Vector2(danger.position.x, danger.end.y)
	if face == PlatformThornDefinition.Face.BOTTOM: return danger.position
	if face == PlatformThornDefinition.Face.LEFT: return Vector2(danger.end.x, danger.position.y)
	return danger.position

static func _axes(face: int) -> Transform2D:
	if face == PlatformThornDefinition.Face.BOTTOM: return Transform2D(Vector2.RIGHT, Vector2.UP, Vector2.ZERO)
	if face == PlatformThornDefinition.Face.LEFT: return Transform2D(Vector2.DOWN, Vector2.RIGHT, Vector2.ZERO)
	if face == PlatformThornDefinition.Face.RIGHT: return Transform2D(Vector2.DOWN, Vector2.LEFT, Vector2.ZERO)
	return Transform2D.IDENTITY

static func _oriented(rect: Rect2, danger: Rect2, face: int) -> Rect2:
	var basis := _axes(face)
	var a := basis * rect.position + _origin(danger, face)
	var b := basis * rect.end + _origin(danger, face)
	return Rect2(a.min(b), a.max(b) - a.min(b))

static func draw_surface(node: CanvasItem, thorn: PlatformThornDefinition, platforms: Array[Rect2]) -> void:
	if not thorn.is_valid(platforms): return
	draw_band(node, thorn.danger(platforms), thorn.face, platforms[thorn.platform_index])

static func draw_band(node: CanvasItem, danger: Rect2, face: int, host: Rect2) -> void:
	var plan := surface_plan(danger, face, host)
	if _atlas == null: return
	var basis := _axes(face)
	basis.origin = _origin(danger, face)
	node.draw_set_transform_matrix(basis)
	for part: Dictionary in plan:
		node.draw_texture_rect_region(_atlas, part.danger_local, part.danger_source)
		# A shallow host may be thinner than the root tile; crop, never spill into air.
		var root_world: Rect2 = part.root_world
		if not root_world.has_area(): continue
		var root_local: Rect2 = part.root_local
		var wanted: Rect2 = _oriented(root_local, danger, face)
		var ratio := (root_world.size.y / wanted.size.y) if face in [PlatformThornDefinition.Face.TOP, PlatformThornDefinition.Face.BOTTOM] else (root_world.size.x / wanted.size.x)
		root_local.size.y *= ratio
		var root_source: Rect2 = part.root_source
		root_source.size.y *= ratio
		node.draw_texture_rect_region(_atlas, root_local, root_source)
	node.draw_set_transform_matrix(Transform2D.IDENTITY)

static func supported_legacy_face(danger: Rect2, solids: Array[Rect2]) -> Dictionary:
	# Do not paint floating thorn platforms over deep-drop sensors. Only a real
	# authored supporting surface may consume the integrated material family.
	for host: Rect2 in solids:
		if danger.position.x >= host.position.x and danger.end.x <= host.end.x and absf(danger.end.y - host.position.y) < ROOT_DEPTH_EPSILON:
			return {"host": host, "face": PlatformThornDefinition.Face.TOP}
	return {}

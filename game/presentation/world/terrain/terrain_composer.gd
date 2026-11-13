class_name TerrainComposer
extends Node2D
## Sole static-room material composition. Runtime builds once on room load.
var geometry: Dictionary = {}
var groups: Array[Dictionary] = []
var surface_bands: Array[Dictionary] = []
var seams: Array[Dictionary] = []
var seed := 0
var _source_groups: Array[Dictionary] = []
var _hazards: Array[Dictionary] = []
var _origin := Vector2.ZERO
var _layers: Dictionary = {}
var _signatures: Dictionary = {}
var _transition_signature := ""
var _transitions: TerrainTransitions


static func room_plan(room: FixedWorldRoom) -> Dictionary:
	var primary := room.region_preview if not room.region_preview.is_empty() else ("mill_masonry" if not room.interior_material().is_empty() else "windchime_plains")
	var solids: Array[Rect2] = WorldRoomSpace.exterior_fill(room.contract.world_geometry,room.doors)
	for index: int in room.platforms.size():
		if index not in room.one_way_indices and index not in room.illustrated_platform_indices: solids.append(room.platforms[index])
	var partitions: Array[Dictionary] = [{"material_id":primary,"solids":solids,"polygons":room.terrain_polygons.duplicate(true),"bare":false}]
	if room.interior_material().is_empty():
		# Polygon material identity is authored independently of its vertices.
		for group: Dictionary in partitions.duplicate():
			var keep: Array[Dictionary] = []
			var stone: Array[Dictionary] = []
			for polygon: Dictionary in group.polygons:
				if polygon.get("material", "ground") == "masonry": stone.append(polygon)
				else: keep.append(polygon)
			group.polygons = keep
			if not stone.is_empty(): partitions.append({"material_id":"mill_masonry","solids":[] as Array[Rect2],"polygons":stone,"bare":false})
		for index: int in room.masonry_platform_indices:
			if index not in room.one_way_indices and index not in room.illustrated_platform_indices:
				# Preserve the previous exterior ownership for authored masonry.
				for part: Rect2 in WorldRoomSpace.exposed_parts([room.platforms[index]],room.boundary_art_rock):
					TerrainGeometry.paint_rect(partitions,part,"mill_masonry")
		for placement: Dictionary in room.art_placements:
			if placement.has("masonry_region"): TerrainGeometry.paint_rect(partitions,FixedWorldProvider.rect(placement.masonry_region),"mill_masonry")
	return {"groups":partitions,"geometry":TerrainGeometry.plan(solids,room.terrain_polygons)}

static func build(room: FixedWorldRoom) -> TerrainComposer:
	return compose(room_plan(room),room.terrain_paint,room.spike_strips,FixedWorldProvider.point(room.contract.world_geometry.get("world_origin",[0,0])))

static func compose(initial: Dictionary, paint: Dictionary = {}, hazards: Array[Dictionary] = [], origin := Vector2.ZERO) -> TerrainComposer:
	if not TerrainPaint.validate(paint).is_empty(): return null
	var node := TerrainComposer.new()
	node.name = "TerrainComposer"
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.geometry = initial.geometry
	node._source_groups.assign(initial.groups.duplicate(true))
	node._hazards = hazards.duplicate(true)
	node._origin = origin
	node.replace_paint(paint)
	return node

## Geometry is immutable for the lifetime of a composition. Painting reuses the
## union and every unaffected material partition's actual nodes/resources.
## Geometry edits use compose() with the new authoritative source.
func replace_paint(paint: Dictionary) -> String:
	var error := TerrainPaint.validate(paint)
	if not error.is_empty(): return error
	seed = int(paint.get("seed",0))+floori(_origin.x/32.0)
	groups.assign(_source_groups.duplicate(true))
	for region: Dictionary in TerrainPaint.ordered(paint.get("regions",[])):
		TerrainGeometry.paint_rect(groups,FixedWorldProvider.rect(region.bounds),str(region.material_id))
	var requests := TerrainPaint.ordered(paint.get("surfaces",[]))
	requests.append_array(TerrainSurfaceResolver.hazard_requests(_hazards))
	surface_bands = TerrainSurfaceResolver.bands(geometry.edges,requests)
	TerrainSurfaceResolver.apply(groups,surface_bands)
	groups = compact(groups)
	var wanted: Dictionary = {}
	for group: Dictionary in groups:
		var key := str(group.material_id)+("/bare" if group.bare else "/edge")
		wanted[key] = true
		var signature := var_to_str(group)+":"+str(seed)
		if _signatures.get(key,"") == signature: continue
		if _layers.has(key):
			remove_child(_layers[key]);_layers[key].free();_layers.erase(key)
		var appearance := TerrainMaterialRegistry.appearance(str(group.material_id))
		appearance["seed"] = seed
		appearance["bare"] = bool(group.bare)
		var solids: Array[Rect2] = []; solids.assign(group.solids)
		var polygons: Array[Dictionary] = []; polygons.assign(group.polygons)
		var terrain := UnderworldTerrain.build_with_polygons(solids,polygons,geometry,appearance)
		terrain.set_meta("material_id",str(group.material_id))
		terrain.set_meta("terrain_composed",true)
		add_child(terrain)
		_install_overhang(terrain,group,geometry,appearance)
		_layers[key] = terrain
		_signatures[key] = signature
	for key: String in _layers.keys():
		if wanted.has(key): continue
		remove_child(_layers[key]);_layers[key].free();_layers.erase(key);_signatures.erase(key)
	var signature := var_to_str(groups)
	if signature != _transition_signature:
		seams = TerrainTransitionResolver.resolve(groups)
		if is_instance_valid(_transitions): remove_child(_transitions);_transitions.free()
		_transitions = TerrainTransitions.new()
		_transitions.name = "MaterialTransitions"
		_transitions.setup(seams,geometry)
		add_child(_transitions)
		_transition_signature = signature
	return ""

static func compact(partitions: Array[Dictionary]) -> Array[Dictionary]:
	var by_key: Dictionary = {}
	for group: Dictionary in partitions:
		if group.solids.is_empty() and group.polygons.is_empty(): continue
		var key := str(group.material_id)+("/bare" if group.bare else "/edge")
		if not by_key.has(key): by_key[key] = {"material_id":group.material_id,"bare":group.bare,"solids":[] as Array[Rect2],"polygons":[] as Array[Dictionary]}
		by_key[key].solids.append_array(group.solids)
		by_key[key].polygons.append_array(group.polygons)
	var result: Array[Dictionary] = []
	var keys := by_key.keys(); keys.sort()
	for key: String in keys: result.append(by_key[key])
	return result

static func _install_overhang(terrain: UnderworldTerrain, group: Dictionary, shared: Dictionary, appearance: Dictionary) -> void:
	var trim := float(appearance.surface_y)
	if trim <= 0 or group.bare: return
	var edges: PackedVector4Array = TerrainGeometry.plan(group.solids,group.polygons).edges
	for edge: Vector4 in edges:
		if edge.y != edge.w or edge.z <= edge.x: continue
		for outer: Vector4 in shared.edges:
			if outer.y != outer.w or outer.z <= outer.x or not is_equal_approx(outer.y,edge.y): continue
			var start := maxf(edge.x,outer.x)
			var end := minf(edge.z,outer.z)
			if end <= start: continue
			var points := UnderworldPolygonTerrain.rectangle_points(Rect2(start,edge.y-trim,end-start,trim))
			var before := terrain.get_child_count()
			UnderworldPolygonTerrain._piece(terrain,points,shared.edges,UnderworldTerrain.specification(),appearance.texture,UnderworldTerrain.SHADER,0,appearance)
			for index: int in range(before,terrain.get_child_count()):
				var child := terrain.get_child(index) as Polygon2D
				child.name = "SurfaceOverhang"
				var corners := PackedVector4Array()
				for corner: Vector4 in shared.corners:
					if Rect2(start-16,edge.y-16,end-start+32,32).has_point(Vector2(corner.x,corner.y)): corners.append(corner)
				var material := child.material as ShaderMaterial
				material.set_shader_parameter("corner_count", mini(64,corners.size()))
				corners.resize(64);material.set_shader_parameter("corners",corners)

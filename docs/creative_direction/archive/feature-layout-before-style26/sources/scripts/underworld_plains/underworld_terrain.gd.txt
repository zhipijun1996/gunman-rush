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
	var core_material:=ShaderMaterial.new()
	core_material.shader=CORE_SHADER
	node.core_layer.material=core_material
	for key: Vector2i in node.core_cells:
		var mask:=Blob47Rules.mask_at(full,key)
		var atlas: Array = spec.mask_to_atlas[str(mask)]
		var variant:=posmod(key.x,int(spec.variant_count))
		node.core_layer.set_cell(key,0,Vector2i(int(atlas[0])+variant*int(spec.variant_atlas_stride),int(atlas[1])))
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
	var texture := source_texture()
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
		material.set_shader_parameter("art_scale",float(spec.source_coordinate_scale))
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
	# Open decks need an actual readable wood/copper cross-section, not the
	# transparent first six rows of grass (which resemble background vines).
	# Every strip is native1wu. End caps stay independent of body repetition.
	var source:=mechanism_texture(&"carrier")
	var height:=minf(8.0,maxf(6.0,rect.size.y))
	var left:=minf(8.0,rect.size.x*.5)
	var right:=minf(8.0,rect.size.x-left)
	var widths: Array[float]=[left,rect.size.x-left-right,right]
	var source_x: Array[float]=[0.0,80.0,192.0-right]
	var source_width: Array[float]=[left,32.0,right]
	for row: Vector3 in [Vector3(0,2,0),Vector3(2,height-4,6),Vector3(height-2,2,20)]:
		var x:=rect.position.x
		for column: int in 3:
			var remaining:=widths[column]
			while remaining>0.0:
				var width:=minf(remaining,source_width[column])
				node.draw_texture_rect_region(source,Rect2(x,rect.position.y+row.x,width,row.y),Rect2(source_x[column],row.z,width,row.y))
				x+=width;remaining-=width
	for x: float in [rect.position.x+3,rect.end.x-5]:
		node.draw_rect(Rect2(x,rect.position.y+2,2,minf(8,rect.size.y-2)),Color("a69055"))

static func draw_moving(node: CanvasItem, rect: Rect2) -> void:
	var texture := mechanism_texture(&"carrier")
	for part: Dictionary in moving_patch_plan(rect):
		node.draw_texture_rect_region(texture,part.target,part.source)

static func mechanism_specification() -> Dictionary:
	if _mechanism_spec.is_empty():
		_mechanism_spec = JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/mechanisms/mechanisms_fine_build.json"))
	return _mechanism_spec

static func moving_patch_plan(rect: Rect2) -> Array[Dictionary]:
	var spec: Dictionary = mechanism_specification().carrier
	var scale_value := float(spec.pixel_world_scale)
	var native := Vector2(float(spec.size_px[0]),float(spec.size_px[1]))
	var left := minf(float(spec.left_px)*scale_value,rect.size.x*.5)
	var right := minf(float(spec.right_px)*scale_value,rect.size.x-left)
	var top := minf(float(spec.top_px)*scale_value,rect.size.y*.5)
	var bottom := minf(float(spec.bottom_px)*scale_value,rect.size.y-top)
	var widths: Array[float] = [left,maxf(0,rect.size.x-left-right),right]
	var heights: Array[float] = [top,maxf(0,rect.size.y-top-bottom),bottom]
	var sources_x: Array[Vector2] = [Vector2(0,left/scale_value),Vector2(float(spec.middle_x_px),float(spec.middle_width_px)),Vector2(native.x-right/scale_value,right/scale_value)]
	var sources_y: Array[Vector2] = [Vector2(0,top/scale_value),Vector2(float(spec.top_px),native.y-float(spec.top_px)-float(spec.bottom_px)),Vector2(native.y-bottom/scale_value,bottom/scale_value)]
	var result: Array[Dictionary] = []
	var y := rect.position.y
	for row: int in 3:
		var x := rect.position.x
		for column: int in 3:
			var source := Rect2(sources_x[column].x,sources_y[row].x,sources_x[column].y,sources_y[row].y)
			var target := Rect2(x,y,widths[column],heights[row])
			if target.has_area() and source.has_area():
				var cursor_y := target.position.y
				while cursor_y < target.end.y-.0001:
					var height := minf(source.size.y*scale_value,target.end.y-cursor_y)
					var cursor_x := target.position.x
					while cursor_x < target.end.x-.0001:
						var width := minf(source.size.x*scale_value,target.end.x-cursor_x)
						result.append({"target":Rect2(cursor_x,cursor_y,width,height),"source":Rect2(source.position,Vector2(width,height)/scale_value),"column":column,"row":row})
						cursor_x += width
					cursor_y += height
			x += widths[column]
		y += heights[row]
	return result

static func mechanism_bell_texture() -> Texture2D:
	return mechanism_texture(&"bell")

static func mechanism_texture(kind: StringName) -> Texture2D:
	# Canvas draw commands retain a RID, not an owning Resource reference. Keep
	# these source textures alive beyond the local _draw call or the submitted
	# material becomes a white rectangle when the temporary load is released.
	if not _mechanism_textures.has(kind):
		_mechanism_textures[kind] = load(str(mechanism_specification()[kind].texture)) as Texture2D
	return _mechanism_textures[kind]

static func mechanism_bell_size() -> Vector2:
	var source := mechanism_bell_texture().get_size()
	var bounds: Array = mechanism_specification().bell.visual_bound_wu
	return source * minf(float(bounds[0])/source.x,float(bounds[1])/source.y)

static func draw_mechanism_bell(node: CanvasItem, at: Vector2, open: bool, flash := false) -> void:
	var texture := mechanism_bell_texture()
	var size := mechanism_bell_size()
	node.draw_texture_rect(texture,Rect2(at-size*.5,size),false,Color(1.18,1.12,1.0) if open or flash else Color.WHITE)

static func draw_mechanism_beam(node: CanvasItem, rect: Rect2, opacity := 1.0) -> void:
	var texture := mechanism_texture(&"carrier")
	var vertical := rect.size.y > rect.size.x
	if vertical:
		node.draw_set_transform(rect.position+Vector2(rect.size.x,0),PI*.5)
		for part: Dictionary in moving_patch_plan(Rect2(Vector2.ZERO,Vector2(rect.size.y,rect.size.x))):
			node.draw_texture_rect_region(texture,part.target,part.source,Color(1,1,1,opacity))
		node.draw_set_transform(Vector2.ZERO)
	else:
		for part: Dictionary in moving_patch_plan(rect):
			node.draw_texture_rect_region(texture,part.target,part.source,Color(1,1,1,opacity))

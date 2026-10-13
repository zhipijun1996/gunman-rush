class_name PlainsTileComposer
extends RefCounted
## Approved plains tile art. Pure presentation; never edits collision or map RNG.
const CELL := 32
const OFFSETS := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]
const DIAGONALS := [[4,0,3],[5,0,1],[6,1,2],[7,2,3]]
const MATERIAL := preload("res://shaders/plains_tile_material.gdshader")
const BORDER := preload("res://assets/plains_v8/painted_limestone_border.png")
const PAINT := preload("res://assets/plains_v8/painted_limestone_material.png")

static func catalog()->Dictionary:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/art/plains_tile_catalog.json"))
	var result:Dictionary={}
	for tile:Dictionary in data.tiles:result[int(tile.mask)]=tile
	return result

static func mask_at(cells:Dictionary,cell:Vector2i)->int:
	var mask:=0
	for i:int in 8:
		if cells.has(cell+OFFSETS[i]):mask|=1<<i
	for rule:Array in DIAGONALS:
		if not (mask&(1<<rule[1]) and mask&(1<<rule[2])):mask&=~(1<<rule[0])
	return mask

static func build(cells:Dictionary,macro_size:Vector2i=Vector2i.ONE)->Node2D:
	assert(macro_size.x>0 and macro_size.y>0 and macro_size.x*macro_size.y<=16,"Macro footprint must fit the 16-cell shader budget")
	var node:=Node2D.new()
	var tiles:=catalog()
	var edges:=PackedVector4Array()
	var solids:Array[Rect2]=[]
	for cell:Vector2i in cells:solids.append(Rect2(Vector2(cell*CELL),Vector2.ONE*CELL))
	for rect:Rect2 in solids:
		for face:Dictionary in PlainsTerrainBorders.plan(rect,solids).faces:
			var a:Vector2=face.start;var b:Vector2=face.finish
			if face.side in ["bottom","left"]:var swap:=a;a=b;b=swap
			edges.append(Vector4(a.x,a.y,b.x,b.y))
	# Each draw receives nearby boundary segments. No fixed global shape limit.
	var remaining:=cells.duplicate()
	var ordered:Array=remaining.keys()
	ordered.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.y<b.y if a.y!=b.y else a.x<b.x)
	for cell:Vector2i in ordered:
		if not remaining.has(cell):continue
		var size:=macro_size
		for y:int in size.y:
			for x:int in size.x:
				if not remaining.has(cell+Vector2i(x,y)):size=Vector2i.ONE;break
			if size==Vector2i.ONE:break
		var rect:=Rect2(Vector2(cell*CELL),Vector2(size*CELL))
		var local_edges:=nearby_edges(rect,edges)
		if local_edges.size()>64:
			# Macro art is optional; preserve every solid cell with canonical fallback.
			size=Vector2i.ONE
			rect=Rect2(Vector2(cell*CELL),Vector2.ONE*CELL)
			local_edges=nearby_edges(rect,edges)
		assert(local_edges.size()<=64,"One-cell neighbourhood exceeded the grid boundary budget")
		var material:=ShaderMaterial.new();material.shader=MATERIAL
		material.set_shader_parameter("painted_material",PAINT)
		material.set_shader_parameter("painted_border",BORDER)
		material.set_shader_parameter("face_count",local_edges.size())
		local_edges.resize(64);material.set_shader_parameter("faces",local_edges)
		var polygon:=paint_quad(rect,material)
		var masks:Array[int]=[]
		for y:int in size.y:
			for x:int in size.x:
				var p:=cell+Vector2i(x,y);remaining.erase(p)
				var mask:=mask_at(cells,p);assert(tiles.has(mask),"Missing canonical tile");masks.append(mask)
		var packed_masks:=PackedInt32Array(masks);packed_masks.resize(16)
		material.set_shader_parameter("cell_masks",packed_masks)
		material.set_shader_parameter("block_bounds",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
		material.set_shader_parameter("block_width",size.x)
		polygon.set_meta("tile_masks",masks);polygon.set_meta("macro_size",size)
		node.add_child(polygon)
	return node

static func nearby_edges(rect:Rect2,edges:PackedVector4Array)->PackedVector4Array:
	var result:=PackedVector4Array()
	for edge:Vector4 in edges:
		var a:=Vector2(edge.x,edge.y);var b:=Vector2(edge.z,edge.w)
		if rect.grow(48).intersects(Rect2(a.min(b),a.max(b)-a.min(b)).grow(.01)):result.append(edge)
	return result

## Canonical horizontal bands are derived from union faces, not input pieces.
## This also makes GPU vertex interpolation independent of authoring partitions.
static func pieces_from_edges(edges:PackedVector4Array)->Array[Rect2]:
	var ys:Array[float]=[]
	for edge:Vector4 in edges:
		for y:float in [edge.y,edge.w]:
			if y not in ys:ys.append(y)
	ys.sort()
	var result:Array[Rect2]=[]
	for i:int in ys.size()-1:
		var y:float=(ys[i]+ys[i+1])/2
		var xs:Array[float]=[]
		for edge:Vector4 in edges:
			if edge.x==edge.z and y>minf(edge.y,edge.w) and y<maxf(edge.y,edge.w):xs.append(edge.x)
		xs.sort()
		assert(xs.size()%2==0,"Union scanline must have matched exterior crossings")
		for j:int in range(0,xs.size(),2):
			var rect:=Rect2(xs[j],ys[i],xs[j+1]-xs[j],ys[i+1]-ys[i])
			var merged:=false
			for prior:int in result.size():
				if result[prior].position.x==rect.position.x and result[prior].end.x==rect.end.x and result[prior].end.y==rect.position.y:
					result[prior].size.y=rect.end.y-result[prior].position.y;merged=true;break
			if not merged and rect.has_area():result.append(rect)
	return result

static func build_rectangles(solids:Array[Rect2])->Node2D:
	var node:=Node2D.new()
	var unique_edges:Dictionary={}
	var unique_corners:Dictionary={}
	for rect:Rect2 in solids:
		var boundary:=PlainsTerrainBorders.plan(rect,solids)
		for face:Dictionary in boundary.faces:
			var a:Vector2=face.start;var b:Vector2=face.finish
			if face.side in ["bottom","left"]:var swap:=a;a=b;b=swap
			unique_edges[Vector4(a.x,a.y,b.x,b.y)]=true
		for corner:Dictionary in boundary.corners:
			if corner.kind=="outer":
				var id:int=PlainsTerrainBorders.CORNERS.find(corner.direction)
				unique_corners[Vector3(corner.point.x,corner.point.y,id)]=true
	# Canonical continuous faces depend on the union, never authoring partitions.
	var edges:=merge_edges(PackedVector4Array(unique_edges.keys()))
	var corners:=PackedVector4Array()
	for corner:Vector3 in unique_corners:
		var point:=Vector2(corner.x,corner.y)
		var radius:=2.5
		for edge:Vector4 in edges:
			var a:=Vector2(edge.x,edge.y);var b:=Vector2(edge.z,edge.w)
			if point==a or point==b:radius=minf(radius,a.distance_to(b)/2)
		corners.append(Vector4(point.x,point.y,corner.z,radius))
	var pending:Array[Rect2]=pieces_from_edges(edges)
	while not pending.is_empty():
		var rect:Rect2=pending.pop_back()
		var local_edges:=nearby_edges(rect,edges)
		var local_corners:=PackedVector4Array()
		for corner:Vector4 in corners:
			if rect.grow(3).has_point(Vector2(corner.x,corner.y)):local_corners.append(corner)
		if local_edges.size()>64 or local_corners.size()>32:
			if maxf(rect.size.x,rect.size.y)<=1:
				# Preserve baseline on unsupported subpixel density; never truncate geometry.
				node.free();return null
			var size:=rect.size
			if size.x>=size.y:size.x/=2
			else:size.y/=2
			pending.append(Rect2(rect.position,size))
			pending.append(Rect2(rect.position+Vector2(size.x,0) if rect.size.x>=rect.size.y else rect.position+Vector2(0,size.y),size))
			continue
		var material:=ShaderMaterial.new();material.shader=MATERIAL
		material.set_shader_parameter("painted_material",PAINT)
		material.set_shader_parameter("painted_border",BORDER)
		material.set_shader_parameter("canonical_cells",false)
		material.set_shader_parameter("face_count",local_edges.size())
		local_edges.resize(64);material.set_shader_parameter("faces",local_edges)
		material.set_shader_parameter("corner_count",local_corners.size())
		local_corners.resize(32);material.set_shader_parameter("outer_corners",local_corners)
		var polygon:=paint_quad(rect,material)
		polygon.set_meta("authored_piece",rect)
		node.add_child(polygon)
	return node

static func merge_edges(edges:PackedVector4Array)->PackedVector4Array:
	var groups:Dictionary={}
	for edge:Vector4 in edges:
		var horizontal:=edge.y==edge.w
		var a:=edge.x if horizontal else edge.y
		var b:=edge.z if horizontal else edge.w
		var key:=Vector3(0 if horizontal else 1,edge.y if horizontal else edge.x,1 if b>a else -1)
		if not groups.has(key):groups[key]=[]
		groups[key].append(Vector2(minf(a,b),maxf(a,b)))
	var result:=PackedVector4Array()
	var keys:Array=groups.keys()
	keys.sort_custom(func(a:Vector3,b:Vector3)->bool:return a.x<b.x if a.x!=b.x else a.y<b.y if a.y!=b.y else a.z<b.z)
	for key:Vector3 in keys:
		var intervals:Array=groups[key]
		intervals.sort_custom(func(a:Vector2,b:Vector2)->bool:return a.x<b.x)
		var merged:Array[Vector2]=[]
		for interval:Vector2 in intervals:
			if not merged.is_empty() and interval.x<=merged[-1].y:
				merged[-1].y=maxf(merged[-1].y,interval.y)
			else:merged.append(interval)
		for interval:Vector2 in merged:
			var a:=interval.x if key.z>0 else interval.y
			var b:=interval.y if key.z>0 else interval.x
			result.append(Vector4(a,key.y,b,key.y) if key.x==0 else Vector4(key.y,a,key.y,b))
	return result

static func paint_quad(rect:Rect2,material:ShaderMaterial)->ColorRect:
	# Native canvas quad avoids per-Polygon2D index/vertex buffer churn when
	# gallery pages and actual region consumers are destroyed/recreated on WebGL.
	var quad:=ColorRect.new()
	quad.position=rect.position;quad.size=rect.size
	quad.mouse_filter=Control.MOUSE_FILTER_IGNORE
	material.set_shader_parameter("shape_origin",rect.position)
	quad.material=material
	return quad

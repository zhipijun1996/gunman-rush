class_name PlainsTileComposer
extends RefCounted
## Candidate tile art. Pure presentation; never edits collision or map RNG.
const CELL := 32
const OFFSETS := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]
const DIAGONALS := [[4,0,3],[5,0,1],[6,1,2],[7,2,3]]
const MATERIAL := preload("res://shaders/plains_tile_material.gdshader")
const PAINT := preload("res://assets/plains_v7/meadow_tile_material.png")

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
		material.set_shader_parameter("face_count",local_edges.size())
		local_edges.resize(64);material.set_shader_parameter("faces",local_edges)
		var polygon:=Polygon2D.new()
		polygon.polygon=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		polygon.material=material
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

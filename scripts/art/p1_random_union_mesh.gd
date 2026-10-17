class_name P1RandomUnionMesh
extends RefCounted
## Fallback for actual stepped/holed rooted unions. Columns are derived from
## exposed union edges, never from authoring-quad texture islands.
static func columns(group: Dictionary) -> Array[Dictionary]:
	var xs: Array[float]=[]
	for edge: Vector4 in group.faces:
		for x: float in [edge.x,edge.z]:
			if x not in xs:xs.append(x)
	xs.sort()
	var result: Array[Dictionary]=[]
	for i: int in xs.size()-1:
		var middle := (xs[i]+xs[i+1])*.5
		var intervals: Array[Vector2]=[]
		for part: Rect2 in group.parts:
			if middle>part.position.x and middle<part.end.x:intervals.append(Vector2(part.position.y,part.end.y))
		intervals.sort_custom(func(a: Vector2,b: Vector2)->bool:return a.x<b.x)
		var merged: Array[Vector2]=[]
		for interval: Vector2 in intervals:
			if not merged.is_empty() and interval.x<=merged[-1].y:merged[-1].y=maxf(merged[-1].y,interval.y)
			else:merged.append(interval)
		result.append({"left":xs[i],"right":xs[i+1],"intervals":merged})
	return result

static func build(group: Dictionary,catalog: Dictionary,family: Dictionary) -> Node2D:
	var node := Node2D.new()
	var slices := columns(group)
	var pages: Array[Dictionary]=[]
	var start := float(group.bounds.position.x)
	var finish := float(group.bounds.end.x)
	var index := 0
	var variants: Array=family.get("sections",[])
	if variants.is_empty() or family.get("status","")!="source_measured_candidate":node.free();return null
	while start<finish-.001:
		var spec: Dictionary=catalog.terrain.grammar.duplicate(true)
		for key: String in variants[index%variants.size()]:spec[key]=variants[index%variants.size()][key]
		if not ResourceLoader.exists(str(spec.texture)):node.free();return null
		var texture := load(str(spec.texture)) as Texture2D
		if texture==null:node.free();return null
		var ppu := float(spec.source_pixels_per_world_unit)
		var margin := float(family.get("source_margin",24))
		var end := minf(finish,start+(texture.get_width()-margin*2)/ppu)
		var overlap := minf(float(family.get("overlap_world",80)),(end-start)*.2)
		var helper := PaintedTerrainGrammar.new()
		helper.configure({"solid_polygons":[],"top_polylines":[]},spec)
		# Mesh helper is detached until complete; no old rendering is hidden here.
		var front := {"vertices":PackedVector2Array(),"uv":PackedVector2Array(),"indices":PackedInt32Array()}
		var back := {"vertices":PackedVector2Array(),"uv":PackedVector2Array(),"indices":PackedInt32Array()}
		var expected := 0.0
		for slice: Dictionary in slices:
			var left := maxf(start,float(slice.left));var right := minf(end,float(slice.right))
			if right<=left:continue
			for interval: Vector2 in slice.intervals:
				expected+=(right-left)*(interval.y-interval.x)
				var cuts: Array[float]=[interval.x,interval.y]
				for depth: float in [float(spec.lip_world_depth),float(spec.upper_side_world_depth)]:
					if interval.x+depth<interval.y:cuts.append(interval.x+depth)
				cuts.sort()
				var xcuts: Array[float]=[left,right]
				var grid := floorf(left/12.0)*12.0+12.0
				while grid<right:xcuts.append(grid);grid+=12.0
				for point: Array in spec.source_surface_profile:
					var x := start+(float(point[0])-margin)/ppu
					if x>left and x<right and x not in xcuts:xcuts.append(x)
				xcuts.sort()
				for row: int in cuts.size()-1:
					for column: int in xcuts.size()-1:_quad(front,xcuts[column],xcuts[column+1],cuts[row],cuts[row+1],interval,start,margin,ppu,texture,helper)
				var clearance := float(spec.back_world_depth)
				for above: Vector2 in slice.intervals:
					if above.y<=interval.x:clearance=minf(clearance,maxf(0,interval.x-above.y))
				if clearance>0:
					for column: int in xcuts.size()-1:_quad(back,xcuts[column],xcuts[column+1],interval.x-clearance,interval.x,interval,start,margin,ppu,texture,helper)
		var actual := _area(front)
		if absf(expected-actual)>maxf(.01,expected*.00001) or expected<=0:
			helper.free();node.free();return null
		var checks: Array[Dictionary]=[]
		for slice: Dictionary in slices:
			var left := maxf(start,float(slice.left));var right := minf(end,float(slice.right))
			if right<=left:continue
			var ys: Array[float]=[group.bounds.position.y-2,group.bounds.end.y+2]
			for interval: Vector2 in slice.intervals:ys.append(interval.x);ys.append(interval.y)
			ys.sort()
			for y: int in ys.size()-1:
				var point := Vector2((left+right)*.5,(ys[y]+ys[y+1])*.5)
				var occupied: bool=group.parts.any(func(rect: Rect2)->bool:return rect.has_point(point))
				var painted: bool=helper.call("_covered",front,point)
				checks.append({"point":[point.x,point.y],"actual_solid":occupied,"front_triangle":painted})
				if occupied!=painted:helper.free();node.free();return null
		helper.call("_install_mesh",front,texture,-2,"P1UnionContinuousFace")
		helper.call("_install_mesh",back,texture,-3,"P1UnionExposedTop")
		for mesh: MeshInstance2D in helper.get_children():
			var material := ShaderMaterial.new();material.shader=load("res://scripts/art/p1_random_page.gdshader") as Shader
			material.set_shader_parameter("fade_start",start);material.set_shader_parameter("fade_width",overlap if index>0 else 0.0)
			# Each occupied interval has its own actual ceiling/floor; a global
			# underside would paint across holes. Main source remains fully opaque.
			mesh.material=material
		node.add_child(helper)
		pages.append({"source":spec.texture,"source_sha256":FileAccess.get_sha256(str(spec.texture)),"x_span":[start,end],"source_span":[margin,margin+(end-start)*ppu],"overlap":overlap if index>0 else 0,"coverage":{"all_canonical_occupied_cells_exact":true,"all_samples_match_actual_solid":true,"samples":checks,"expected_area":expected,"triangle_area":actual,"holes_filled":false},"external_ends":"section clipped at true external faces; independent turn-socket adaptation pending"})
		if end>=finish-.001:break
		start=end-overlap;index+=1
		if index>128:node.free();return null
	node.set_meta("facts",{"ok":true,"bounds":[group.bounds.position.x,group.bounds.position.y,group.bounds.size.x,group.bounds.size.y],"reason":"","method":"union-exposed canonical columns, shared finite geological pages","pages":pages,"columns":slices.size(),"source_reuse_explicit":true,"body_alpha":"original opaque painted section; no transparent ceiling excavation","turn_faces":"finite clipped side; independent socket art unverified"})
	return node

static func _quad(data: Dictionary,left: float,right: float,top: float,bottom: float,interval: Vector2,page_start: float,margin: float,ppu: float,texture: Texture2D,helper: PaintedTerrainGrammar) -> void:
	var vertices := PackedVector2Array([Vector2(left,top),Vector2(right,top),Vector2(right,bottom),Vector2(left,bottom)])
	var base: int=data.vertices.size()
	for p: Vector2 in vertices:
		var source_x := margin+(p.x-page_start)*ppu
		var surface := float(helper.call("_source_surface",source_x))
		var source_y := float(helper.call("_end_source_y",p.y-interval.x,interval.y-interval.x,surface,float(texture.get_height())))
		data.vertices.append(p);data.uv.append(Vector2(source_x,source_y)/texture.get_size())
	for i: int in [0,1,2,0,2,3]:data.indices.append(base+i)

static func _area(data: Dictionary) -> float:
	var result := 0.0
	for i: int in range(0,data.indices.size(),3):
		var a: Vector2=data.vertices[data.indices[i]];var b: Vector2=data.vertices[data.indices[i+1]];var c: Vector2=data.vertices[data.indices[i+2]]
		result+=absf((b-a).cross(c-a))*.5
	return result

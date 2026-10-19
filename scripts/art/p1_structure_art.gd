class_name P1StructureArt
extends RefCounted
## Painted structural consumers, no bodies/shapes or gameplay state.
const CATALOG := "res://resources/visual_development/p1_unity_components.json"
static var _image: Image
static var _texture: Texture2D
static var _data: Dictionary

static func make(rect: Rect2,kind: String) -> Node2D:
	if _data.is_empty():
		_data=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
		_texture=load(str(_data.texture)) as Texture2D
		if _texture==null:return null
		_image=_texture.get_image()
		if _image.is_compressed():_image.decompress()
	if not _data.components.has(kind) or rect.size.x<=0 or rect.size.y<=0:return null
	var spec: Dictionary=_data.components[kind]
	var region := Rect2(spec.region[0],spec.region[1],spec.region[2],spec.region[3])
	var vertices := PackedVector2Array();var uv := PackedVector2Array();var indices := PackedInt32Array()
	var horizontal := kind=="bridge"
	var low := int(spec.get("body_left",30)) if horizontal else int(spec.get("body_top",16)) if kind=="column" else int(spec.standing_y)
	var high := int(spec.get("body_right",495)) if horizontal else int(spec.get("body_bottom",475))
	var samples: Array[int]=[low,high]
	for point: int in range(low+4,high,4):samples.append(point)
	samples.sort()
	for point: int in samples:
		var range_low := int(spec.standing_y) if horizontal else int(spec.get("body_left",55)) if kind=="column" else 0
		var range_high := int(spec.body_bottom) if horizontal else int(spec.get("body_right",132)) if kind=="column" else int(region.size.x)-1
		var first := -1;var last := -1
		for across: int in range(range_low,range_high+1):
			var pixel := region.position+(Vector2(point,across) if horizontal else Vector2(across,point))
			if _image.get_pixelv(Vector2i(pixel)).a>=128.0/255.0:
				if first<0:first=across
				last=across
		if first<0:return null
		var q := float(point-low)/maxf(1,high-low)
		if horizontal:
			var reference := rect.size.y/maxf(1,float(spec.body_bottom)-float(spec.standing_y))
			var a := float(spec.left_socket);var b := float(spec.right_socket)
			var left_width := minf((a-low)*reference,rect.size.x*.25)
			var right_width := minf((high-b)*reference,rect.size.x*.25)
			var x := rect.position.x+left_width*float(point-low)/maxf(1,a-low) if point<=a else rect.end.x-right_width+right_width*float(point-b)/maxf(1,high-b) if point>=b else rect.position.x+left_width+(rect.size.x-left_width-right_width)*float(point-a)/maxf(1,b-a)
			vertices.append(Vector2(x,rect.position.y));vertices.append(Vector2(x,rect.end.y))
			uv.append((region.position+Vector2(point,first+.25))/_texture.get_size());uv.append((region.position+Vector2(point,last-.25))/_texture.get_size())
		else:
			var y := rect.position.y+q*rect.size.y
			if kind=="column":
				var scale_value := rect.size.x/maxf(1,float(spec.body_right)-float(spec.body_left))
				var a := float(spec.top_socket);var b := float(spec.bottom_socket)
				var upper := minf((a-low)*scale_value,rect.size.y*.25);var lower := minf((high-b)*scale_value,rect.size.y*.25)
				y=rect.position.y+upper*float(point-low)/maxf(1,a-low) if point<=a else rect.end.y-lower+lower*float(point-b)/maxf(1,high-b) if point>=b else rect.position.y+upper+(rect.size.y-upper-lower)*float(point-a)/maxf(1,b-a)
			vertices.append(Vector2(rect.position.x,y));vertices.append(Vector2(rect.end.x,y))
			uv.append((region.position+Vector2(first+.25,point))/_texture.get_size());uv.append((region.position+Vector2(last-.25,point))/_texture.get_size())
	for i: int in samples.size()-1:
		for vertex: int in [0,1,2,1,3,2]:indices.append(i*2+vertex)
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	var node := Node2D.new();node.name="P1Structure_"+kind
	var paint := MeshInstance2D.new();paint.mesh=mesh;paint.texture=_texture;paint.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	paint.z_as_relative=false;paint.z_index=-1;node.add_child(paint)
	if kind=="bridge":
		# Preserve the painted terminal braces as one pair per actual object,
		# not per material section. Their top is clipped at the true standing
		# plane; short inward braces below it are cosmetic, never extra ledges.
		var cap_scale := rect.size.y/maxf(1,float(spec.body_bottom)-float(spec.standing_y))
		for side: String in ["left","right"]:
			var source_left := 13.0 if side=="left" else float(spec.right_socket)
			var source_right := float(spec.left_socket) if side=="left" else 509.0
			var width := (source_right-source_left)*cap_scale
			if width>rect.size.x*.45:continue
			var atlas := AtlasTexture.new();atlas.atlas=_texture;atlas.filter_clip=true
			atlas.region=Rect2(region.position+Vector2(source_left,float(spec.standing_y)),Vector2(source_right-source_left,120.0-float(spec.standing_y)))
			var cap := Sprite2D.new();cap.texture=atlas;cap.centered=false;cap.scale=Vector2.ONE*cap_scale
			cap.position=Vector2(rect.position.x if side=="left" else rect.end.x-width,rect.position.y)
			cap.z_as_relative=false;cap.z_index=0;node.add_child(cap)
	node.set_meta("p1_structure",{"kind":kind,"physical_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"source":_data.texture,"source_sha256":FileAccess.get_sha256(str(_data.texture)),"method":"source-alpha physical edge calibration, preserved cap sockets, painted core covers actual full body; no collision changes","mesh_pairs":samples.size()})
	return node

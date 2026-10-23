extends SceneTree
## Organize generated art into a real native 32px/32wu, 47-adjacency TileSet.
## CPU sampling only resizes/slices the generated material and builds edge data.
const OUT := "res://assets/high_density_terrain_study/"
var master: Image

func _initialize() -> void:
	master = Image.load_from_file(OUT+"master_original.png")
	assert(master != null)
	master.resize(256,256,Image.INTERPOLATE_NEAREST)
	assert(master.save_png(OUT+"master_256.png") == OK)
	var atlas := Image.create(256,192,false,Image.FORMAT_RGBA8)
	var field := Image.create(256,192,false,Image.FORMAT_RGBA8)
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/terrain/terrain_build.json"))
	var tres := '[gd_resource type="TileSet" format=3]\n\n[ext_resource type="Texture2D" path="'+OUT+'atlas_32.png" id="1"]\n\n[sub_resource type="TileSetAtlasSource" id="Atlas"]\ntexture = ExtResource("1")\ntexture_region_size = Vector2i(32, 32)\n'
	for mask_text: String in spec.mask_to_atlas:
		var mask := int(mask_text)
		var coord: Array = spec.mask_to_atlas[mask_text]
		for y: int in 32:
			for x: int in 32:
				var edge := edge_data(mask,x,y)
				var at := Vector2i(int(coord[0])*32+x,int(coord[1])*32+y)
				field.set_pixelv(at,Color(edge.x/255.0,edge.y/255.0,0,edge.z))
				atlas.set_pixelv(at,material_pixel(Vector2i(x,y),edge))
		tres += '%d:%d/0 = 0\n'%[coord[0],coord[1]]
	tres += '\n[resource]\ntile_size = Vector2i(32, 32)\nsources/0 = SubResource("Atlas")\n'
	assert(atlas.save_png(OUT+"atlas_32.png") == OK)
	assert(field.save_png(OUT+"edges_32.png") == OK)
	FileAccess.open(OUT+"terrain_32.tres",FileAccess.WRITE).store_string(tres)
	FileAccess.open(OUT+"standard.json",FileAccess.WRITE).store_string(JSON.stringify({"task":"HIGH-DENSITY-TERRAIN-03","status":"experimental_proposed","tile_pixels":32,"tile_world_units":32,"world_units_per_art_pixel":1,"base_viewport":[1280,720],"display_scaling":"integer scaling preferred; this Lab does not modify project settings","mask_family":"existing 47 native masks, same core cell coordinates","source":"AI edited master_original.png -> nearest-sampled 256 logical pixels; no retouch of original game sprites or background","rendering":"native32 TileSet plus world-continuous master sampler and exact-boundary adapter","scope":"solid terrain and one-way top strip; native hazard/moving family remains original, not a whole-game migration"},"  "))
	print("DENSE_TERRAIN_BUILD masks=%d tile_px=32 world_wu=32 density=1"%spec.mask_to_atlas.size())
	quit()

func edge_data(mask: int,x: int,y: int) -> Vector3:
	var best := 32.0
	var kind := 4.0
	for row: Vector3 in [Vector3(y,0,1),Vector3(31-x,1,4),Vector3(31-y,2,16),Vector3(x,3,64)]:
		if (mask & int(row.z)) == 0 and row.x < best:
			best = row.x; kind = row.y
	var alpha := 1.0
	# Small native-pixel rounding replaces the enlarged 2px staircase.
	for corner: Vector4 in [Vector4(x,y,1,64),Vector4(31-x,y,1,4),Vector4(x,31-y,16,64),Vector4(31-x,31-y,16,4)]:
		if (mask & int(corner.z)) == 0 and (mask & int(corner.w)) == 0 and corner.x<4 and corner.y<4:
			if Vector2(corner.x-3.5,corner.y-3.5).length()>4: alpha=0
	return Vector3(best,kind,alpha)

func material_pixel(p: Vector2i,edge: Vector3) -> Color:
	var color:=wrap_sample(p,false)
	color.r=lerpf(.025,color.r,.32);color.g=lerpf(.036,color.g,.32);color.b=lerpf(.075,color.b,.32)
	if edge.x<8 and edge.y==0:
		var grass:=wrap_sample(Vector2i(p.x,int(edge.x)),true)
		color=color.lerp(grass,.88*(1.0-smoothstep(5,8,edge.x)))
	elif edge.y!=4 and edge.y!=0:
		var factor:=.72+.28*smoothstep(0,5,edge.x)
		color.r*=factor;color.g*=factor;color.b*=factor
	color.a *= edge.z
	return color

func wrap_sample(p: Vector2i,grass: bool) -> Color:
	var u:=posmod(p.x,224)
	var v:=posmod(p.y,160)
	var y:=clampi(p.y*3,0,31) if grass else 80+v
	var color:=master.get_pixel(16+u,y)
	if u<16:color=master.get_pixel(240+u,y).lerp(color,smoothstep(0,16,u+.5))
	if not grass and v<16:
		var other:=master.get_pixel(16+u,240+v)
		if u<16:other=master.get_pixel(240+u,240+v).lerp(other,smoothstep(0,16,u+.5))
		color=other.lerp(color,smoothstep(0,16,v+.5))
	return color

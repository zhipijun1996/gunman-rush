extends SceneTree
## FINE-SPACE-05. Asset preparation only: preserve existing high-resolution art,
## crop/resample at the selected 1wu art grid; never upscale old coarse pixels.
const TERRAIN := "res://assets/underworld_plains/terrain/fine_32/"
const MECHANISMS := "res://assets/underworld_plains/mechanisms/"
const HAZARDS := "res://assets/underworld_plains/hazards/"
const FOREST := "res://assets/forest_bible_v2/native/fine_32/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TERRAIN)
	build_terrain()
	build_carrier()
	build_hazards()
	build_forest()
	print("FORMAL_FINE_BUILD terrain=32px/32wu forest=32px/32wu carrier=192x22@1wu hazard=32px/32wu source=raw_masters")
	quit()

func build_terrain() -> void:
	for pair: Array in [["source_fine.png","source.png"],["fine_atlas.png","terrain.png"]]:
		var bytes:=FileAccess.get_file_as_bytes("res://assets/authored_terrain_study/"+pair[0])
		FileAccess.open(TERRAIN+pair[1],FileAccess.WRITE).store_buffer(bytes)
	var tres:=FileAccess.get_file_as_string("res://assets/authored_terrain_study/fine.tres")
	tres=tres.replace("res://assets/authored_terrain_study/fine_atlas.png",TERRAIN+"terrain.png")
	FileAccess.open(TERRAIN+"terrain.tres",FileAccess.WRITE).store_string(tres)
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/terrain/terrain_build.json"))
	spec["schema"]="underworld-terrain-build-v2-fine32"
	spec["task_id"]="FINE-SPACE-05"
	spec["tile_px"]=32
	spec["source_texture"]=TERRAIN+"source.png"
	spec["source_sha256"]=FileAccess.get_sha256(spec.source_texture)
	spec["atlas"]=TERRAIN+"terrain.png"
	spec["atlas_sha256"]=FileAccess.get_sha256(spec.atlas)
	spec["tileset"]=TERRAIN+"terrain.tres"
	spec["source_coordinate_scale"]=2
	spec["variant_count"]=3
	spec["variant_atlas_stride"]=8
	spec["source_bank_width_px"]=352
	spec["builder"]="tools/build_formal_fine.gd"
	spec["operations"]=["byte-identical promotion of selected authored fine source/atlas","original source_regions and 47 mask coordinates retained","3 grass banks; 1 source pixel per world unit; exact-boundary source scale2"]
	spec["source_provenance"]="res://assets/authored_terrain_study/provenance.json"
	spec["selected_master_sha256"]=FileAccess.get_sha256("res://assets/authored_terrain_study/master_original.png")
	spec["selection"]="User explicitly chose fine density and requested all live rendering to match; previous16px assets/spec retained as historical sources"
	spec["formal_boundary_claim"]="Same exact-union geometry and source-region recipe; source sampling native32px/32wu. New visual acceptance separate from preserved collision/Manifest contracts."
	write_json(TERRAIN+"terrain_build.json",spec)

func build_carrier() -> void:
	var raw:=Image.load_from_file(MECHANISMS+"source_carrier.png")
	assert(raw!=null)
	var image:=raw.get_region(Rect2i(70,272,2035,232))
	image.resize(192,22,Image.INTERPOLATE_NEAREST)
	assert(image.save_png(MECHANISMS+"carrier_fine.png")==OK)
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MECHANISMS+"mechanisms_build.json"))
	spec["schema"]="underworld-mechanisms-v2-fine"
	spec["task_id"]="FINE-SPACE-05"
	spec.carrier.texture=MECHANISMS+"carrier_fine.png"
	spec.carrier.sha256=FileAccess.get_sha256(spec.carrier.texture)
	spec.carrier.size_px=[192,22]
	spec.carrier.pixel_world_scale=1
	for key: String in ["left_px","right_px","top_px","bottom_px","middle_x_px","middle_width_px"]:
		spec.carrier[key]=int(spec.carrier[key])*2
	spec.carrier.operation="Original2172x724 AI master, same measured RGBA crop[70,272,2105,504], direct nearest192x22 sample. Not an upscale of96x11. Physical cap/top/bottom dimensions unchanged."
	spec.carrier["builder"]="tools/build_formal_fine.gd"
	spec["legacy_build"]="assets/underworld_plains/mechanisms/mechanisms_build.json"
	write_json(MECHANISMS+"mechanisms_fine_build.json",spec)

func build_hazards() -> void:
	var raw:=Image.load_from_file(HAZARDS+"generated_reference.png")
	var substrate:=Image.load_from_file(TERRAIN+"source.png")
	assert(raw!=null and substrate!=null)
	var band:=raw.get_region(Rect2i(30,272,2114,178))
	band.resize(256,32,Image.INTERPOLATE_NEAREST)
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(HAZARDS+"hazard_build.json"))
	var palette: Array=spec.processing.palette_rgba
	var root_mask: Dictionary={}
	for y: int in 32:
		for x: int in 256:
			var c:=band.get_pixel(x,y)
			if y>=24 and c.a>=.5 and c.r>c.b*1.3 and c.r>20.0/255.0: root_mask[Vector2i(x,y)]=true
			if c.a<.5:
				band.set_pixel(x,y,Color.TRANSPARENT)
			else:
				var index:=mini(5,int((c.r*.299+c.g*.587+c.b*.114)*255.0/36.0))
				var p: Array=palette[index]
				band.set_pixel(x,y,Color(float(p[0])/255.0,float(p[1])/255.0,float(p[2])/255.0,1))
	var atlas:=Image.create(128,32,false,Image.FORMAT_RGBA8)
	for column: int in 4:
		var offset:=column*64
		atlas.blit_rect(substrate,Rect2i(64,32,32,8),Vector2i(column*32,24))
		atlas.blit_rect(band,Rect2i(offset,0,32,24),Vector2i(column*32,0))
		for y: int in range(24,32):
			for x: int in 32:
				if root_mask.has(Vector2i(offset+x,y)): atlas.set_pixel(column*32+x,y,band.get_pixel(offset+x,y))
	assert(atlas.save_png(HAZARDS+"hazard_surface_fine.png")==OK)
	var tres: String='[gd_resource type="TileSet" format=3]\n\n[ext_resource type="Texture2D" path="'+HAZARDS+'hazard_surface_fine.png" id="1"]\n\n[sub_resource type="TileSetAtlasSource" id="Atlas"]\ntexture = ExtResource("1")\ntexture_region_size = Vector2i(32,32)\n0:0/0 = 0\n1:0/0 = 0\n2:0/0 = 0\n3:0/0 = 0\n\n[resource]\ntile_size = Vector2i(32,32)\nsources/0 = SubResource("Atlas")\n'
	FileAccess.open(HAZARDS+"hazard_fine_tileset.tres",FileAccess.WRITE).store_string(tres)
	spec["schema_version"]=2
	spec["task_id"]="FINE-SPACE-05"
	spec.atlas.path="assets/underworld_plains/hazards/hazard_surface_fine.png"
	spec.atlas.sha256=FileAccess.get_sha256(HAZARDS+"hazard_surface_fine.png")
	spec.atlas.tileset="assets/underworld_plains/hazards/hazard_fine_tileset.tres"
	spec.atlas.tile_size_px=[32,32]
	spec.atlas.external_depth_px=24
	spec.atlas.embedded_root_px=8
	spec.processing.command="bash tools/godot.sh --headless --path . --script tools/build_formal_fine.gd"
	spec.processing["source_detail"]="Direct raw2172x724 generated reference to256x32 nearest, not enlarged16px atlas; same alpha128/palette6 rules. Fine32 terrain substrate32x8; real generated red roots only."
	spec.processing.variant_offsets_px=[0,64,128,192]
	spec.processing.substrate_source_region_px=[64,32,32,8]
	spec.processing["substrate_source"]=TERRAIN+"source.png"
	spec.processing["substrate_sha256"]=FileAccess.get_sha256(TERRAIN+"source.png")
	spec.processing.root_composite="Actual generated red-root pixels in y24..31 over selected fine terrain substrate; no invented root fill."
	spec["legacy_build"]="assets/underworld_plains/hazards/hazard_build.json"
	write_json(HAZARDS+"hazard_fine_build.json",spec)

func write_json(path: String,data: Dictionary) -> void:
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"  ")+"\n")

func build_forest() -> void:
	var raw:=Image.load_from_file(FOREST+"bark_master_original.png")
	assert(raw!=null and raw.get_size()==Vector2i(1774,887))
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/terrain/terrain_build.json"))
	var source:=Image.create(1056,288,false,Image.FORMAT_RGBA8)
	for variant: int in 3:
		var kit:=Image.create(352,288,false,Image.FORMAT_RGBA8)
		var outer:=raw.get_region(Rect2i(48,108,1114,672))
		outer.resize(96,96,Image.INTERPOLATE_NEAREST)
		kit.blit_rect(outer,Rect2i(0,0,96,96),Vector2i(32,0))
		var top_x: int=[220,500,780][variant]
		var top:=raw.get_region(Rect2i(top_x,108,380,224))
		top.resize(32,32,Image.INTERPOLATE_NEAREST)
		kit.blit_rect(top,Rect2i(0,0,32,32),Vector2i(64,0))
		for row: Dictionary in [
			{"raw":Rect2i(1590,560,96,96),"at":Vector2i(160,32)},
			{"raw":Rect2i(1260,560,96,96),"at":Vector2i(144,32)},
			{"raw":Rect2i(1590,274,96,96),"at":Vector2i(160,16)},
			{"raw":Rect2i(1260,274,96,96),"at":Vector2i(144,16)}]:
			var patch:=raw.get_region(row.raw)
			patch.resize(16,16,Image.INTERPOLATE_NEAREST)
			kit.blit_rect(patch,Rect2i(0,0,16,16),row.at)
		source.blit_rect(kit,Rect2i(0,0,352,288),Vector2i(variant*352,0))
	assert(source.save_png(FOREST+"bark_source.png")==OK)
	var atlas:=Image.create(768,192,false,Image.FORMAT_RGBA8)
	for variant: int in 3:
		for mask: String in spec.mask_to_atlas:
			var coord: Array=spec.mask_to_atlas[mask]
			var at:=Vector2i((int(coord[0])+variant*8)*32,int(coord[1])*32)
			for part: Dictionary in spec.source_regions[mask]:
				var region: Array=part.source
				var dest: Array=part.destination
				var rect:=Rect2i((int(region[0])+variant*176)*2,int(region[1])*2,(int(region[2])-int(region[0]))*2,(int(region[3])-int(region[1]))*2)
				atlas.blit_rect(source,rect,at+Vector2i(int(dest[0]),int(dest[1]))*2)
	assert(atlas.save_png(FOREST+"bark_atlas47.png")==OK)
	write_json(FOREST+"build.json",{"task":"FINE-SPACE-05","source":"bark_source.png","source_sha256":FileAccess.get_sha256(FOREST+"bark_source.png"),"atlas":"bark_atlas47.png","atlas_sha256":FileAccess.get_sha256(FOREST+"bark_atlas47.png"),"master":"bark_master_original.png","master_sha256":FileAccess.get_sha256(FOREST+"bark_master_original.png"),"tile_px":32,"world_tile_wu":32,"variants":3,"source_size":[1056,288],"atlas_size":[768,192],"original_recipe":"assets/underworld_plains/terrain/terrain_build.json source_regions unchanged; coordinates scaled2","outer_crop":[48,108,1114,672],"top_crops_x":[220,500,780],"top_crop_ywh":[108,380,224],"inner_crops":[[1590,560,96,96],[1260,560,96,96],[1590,274,96,96],[1260,274,96,96]],"processing":"nearest resample/crop organization only; new image_gen bark/moss material, no16px upscale or recolored stone","generation":"generation.json","status":"awaiting_actual_forest_review"})

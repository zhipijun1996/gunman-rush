extends SceneTree
## TERRAIN-DENSITY-04: organize authored outer/inner edges into actual 47 tiles.
## Art content comes only from image_gen master. This tool crops/resizes/assembles.
const OUT := "res://assets/authored_terrain_study/"
var master: Image

func _initialize() -> void:
	master=Image.load_from_file(OUT+"master_original.png")
	assert(master!=null and master.get_size()==Vector2i(1254,1254))
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/terrain/terrain_build.json"))
	var source:=Image.create(1056,288,false,Image.FORMAT_RGBA8)
	var cuts: Array[Dictionary]=[]
	for variant: int in 3:
		var kit:=Image.create(352,288,false,Image.FORMAT_RGBA8)
		var block:=cut(Rect2i(32,306,752,640),Vector2i(96,96))
		kit.blit_rect(block,Rect2i(Vector2i.ZERO,block.get_size()),Vector2i(32,0))
		var top_x: int=[170,290,450][variant]
		var top_rect:=Rect2i(top_x,306,256,214)
		var top:=cut(top_rect,Vector2i(32,32))
		kit.blit_rect(top,Rect2i(0,0,32,32),Vector2i(64,0))
		cuts.append({"role":"top_variant_%d"%variant,"raw":rect_array(top_rect),"target":[64,0,32,32]})
		# Real hole corners, sampled from the solid quadrant opposite the air.
		for row: Dictionary in [
			{"role":"iTL","raw":Rect2i(1118,742,64,64),"at":Vector2i(160,32)},
			{"role":"iTR","raw":Rect2i(848,742,64,64),"at":Vector2i(144,32)},
			{"role":"iBL","raw":Rect2i(1118,486,64,64),"at":Vector2i(160,16)},
			{"role":"iBR","raw":Rect2i(848,486,64,64),"at":Vector2i(144,16)}]:
			var patch:=cut(row.raw,Vector2i(16,16))
			kit.blit_rect(patch,Rect2i(0,0,16,16),row.at)
			if variant==0: cuts.append({"role":row.role,"raw":rect_array(row.raw),"target":[row.at.x,row.at.y,16,16]})
		source.blit_rect(kit,Rect2i(0,0,352,288),Vector2i(variant*352,0))
	assert(source.save_png(OUT+"source_fine.png")==OK)
	var coarse:=source.duplicate()
	coarse.resize(528,144,Image.INTERPOLATE_NEAREST)
	assert(coarse.save_png(OUT+"source_coarse.png")==OK)
	for density: int in [1,2]:
		var tile_px:=16*density
		var image:=source if density==2 else coarse
		var atlas:=Image.create(tile_px*24,tile_px*6,false,Image.FORMAT_RGBA8)
		var path:=OUT+("fine" if density==2 else "coarse")
		var tres: String='[gd_resource type="TileSet" format=3]\n\n[ext_resource type="Texture2D" path="'+path+'_atlas.png" id="1"]\n\n[sub_resource type="TileSetAtlasSource" id="Atlas"]\ntexture = ExtResource("1")\ntexture_region_size = Vector2i(%d, %d)\n'%[tile_px,tile_px]
		for variant: int in 3:
			for mask: String in spec.mask_to_atlas:
				var coord: Array=spec.mask_to_atlas[mask]
				var at:=Vector2i((int(coord[0])+variant*8)*tile_px,int(coord[1])*tile_px)
				for part: Dictionary in spec.source_regions[mask]:
					var region: Array=part.source
					var dest: Array=part.destination
					var rect:=Rect2i((int(region[0])+variant*176)*density,int(region[1])*density,(int(region[2])-int(region[0]))*density,(int(region[3])-int(region[1]))*density)
					atlas.blit_rect(image,rect,at+Vector2i(int(dest[0]),int(dest[1]))*density)
				tres += '%d:%d/0 = 0\n'%[int(coord[0])+variant*8,int(coord[1])]
		tres += '\n[resource]\ntile_size = Vector2i(%d, %d)\nsources/0 = SubResource("Atlas")\n'%[tile_px,tile_px]
		assert(atlas.save_png(path+"_atlas.png")==OK)
		FileAccess.open(path+".tres",FileAccess.WRITE).store_string(tres)
	FileAccess.open(OUT+"build.json",FileAccess.WRITE).store_string(JSON.stringify({"task":"TERRAIN-DENSITY-04","master":"master_original.png","outer_sample":[32,306,752,640],"outer_target":[32,0,96,96],"cuts":cuts,"variants":3,"mask_count":47,"tile_world_units":32,"fine_tile_pixels":32,"coarse_tile_pixels":16,"coarse_method":"same fine source -> nearest16, not a second generated style","filter":"nearest","layout":"original source_regions recipe; same native47 masks, 3 banks","scope":"experimental solid terrain and open-deck top only; original physical geometry and formal defaults preserved"},"  "))
	print("AUTHORED_TERRAIN_BUILD masks=47 variants=3 native_fine=32 native_coarse=16 same_master=true")
	quit()

func cut(rect: Rect2i,size: Vector2i) -> Image:
	var image:=master.get_region(rect)
	image.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
	return image

func rect_array(rect: Rect2i) -> Array[int]:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

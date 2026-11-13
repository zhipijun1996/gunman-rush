extends SceneTree
## Mechanical crop/nearest normalization of inspected generated atlases.
func _initialize() -> void:
	var recipes := {
		"forest_bramble":{"boxes":[Rect2i(20,230,526,365),Rect2i(546,230,526,365),Rect2i(1072,230,526,365),Rect2i(1640,230,504,365)],"size":Vector2i(128,32)},
		"metal_spikes":{"boxes":[Rect2i(8,144,538,400),Rect2i(546,144,538,400),Rect2i(1084,144,538,400),Rect2i(1640,144,524,400)],"size":Vector2i(128,32)},
		"stacked_materials":{"boxes":[Rect2i(4,4,504,504),Rect2i(516,4,504,504),Rect2i(1028,4,504,504),Rect2i(4,516,504,504),Rect2i(516,516,504,504),Rect2i(1028,516,504,504)],"size":Vector2i(96,64)}
	}
	var manifest := {"generator":"image_gen","prompt_record":"art/world-elements/prompts.md","model":"tool does not expose model ID","processing":"inspected crop, nearest32; preserve source; rigid spikes support four face transforms","references":["assets/underworld_plains/hazards/hazard_surface_fine.png","assets/underworld_plains/terrain/fine_32/source.png","assets/plains_v07/native/mill_masonry_source.png"],"assets":{}}
	for id: String in recipes:
		var recipe: Dictionary = recipes[id]
		var source_path := "art/world-elements/sources/"+id+".png"
		var native_path := "assets/world_elements/native/"+id+".png"
		var source := Image.load_from_file("res://"+source_path)
		source.convert(Image.FORMAT_RGBA8)
		var atlas := Image.create(recipe.size.x,recipe.size.y,false,Image.FORMAT_RGBA8)
		var boxes: Array = []
		for i: int in recipe.boxes.size():
			var box: Rect2i = recipe.boxes[i]
			var tile := source.get_region(box); tile.resize(32,32,Image.INTERPOLATE_NEAREST)
			atlas.blit_rect(tile,Rect2i(0,0,32,32),Vector2i((i%(recipe.size.x/32))*32,(i/(recipe.size.x/32))*32))
			boxes.append([box.position.x,box.position.y,box.size.x,box.size.y])
		atlas.save_png("res://"+native_path)
		manifest.assets[id] = {"source":source_path,"source_sha256":FileAccess.get_sha256("res://"+source_path),"native":native_path,"sha256":FileAccess.get_sha256("res://"+native_path),"crops":boxes}
	var file := FileAccess.open("res://art/world-elements/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  ")+"\n")
	quit()

extends SceneTree
## FINE-SPACE-05: organize the generated five-piece foreground art, no repaint.
const OUT := "res://assets/underworld_plains/foreground_fine_05/"

func _initialize() -> void:
	var master:=Image.load_from_file(OUT+"master_original.png")
	assert(master!=null and master.get_size()==Vector2i(1619,972))
	var assets: Array[Dictionary]=[]
	for piece: Dictionary in [
		{"id":"grass_a","cell":Rect2i(0,0,520,500),"height":100,"root":Vector2(199,443),"kind":"grass"},
		{"id":"grass_b","cell":Rect2i(520,0,560,500),"height":96,"root":Vector2(646,443),"kind":"grass"},
		{"id":"grass_c","cell":Rect2i(1080,0,539,500),"height":108,"root":Vector2(1277,443),"kind":"grass"},
		{"id":"branch_left","cell":Rect2i(0,500,800,472),"width":248,"root":Vector2(88,538),"kind":"branch"},
		{"id":"branch_right","cell":Rect2i(800,500,819,472),"width":248,"root":Vector2(1516,538),"kind":"branch"}]:
		var crop:=alpha_bounds(master,piece.cell)
		assert(crop.has_area())
		var image:=master.get_region(crop)
		var factor:=float(piece.height)/crop.size.y if piece.has("height") else float(piece.width)/crop.size.x
		var size:=Vector2i(maxi(1,roundi(crop.size.x*factor)),maxi(1,roundi(crop.size.y*factor)))
		image.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
		var path:=OUT+str(piece.id)+".png"
		assert(image.save_png(path)==OK)
		var attach: Vector2=(piece.root-Vector2(crop.position))*Vector2(size)/Vector2(crop.size)
		assets.append({"id":piece.id,"image":path,"kind":piece.kind,"raw_crop":[crop.position.x,crop.position.y,crop.size.x,crop.size.y],"size":[size.x,size.y],"attachment":[attach.x,attach.y],"pixel_world_units":1,"source_sha256":FileAccess.get_sha256(path)})
	var spec: Dictionary={"task":"FINE-SPACE-05","schema":"underworld-foreground-fine-v1","master":"master_original.png","master_sha256":FileAccess.get_sha256(OUT+"master_original.png"),"method":"alpha>=2 crop inside disjoint declared source cells, keep all cropped RGBA, nearest resize; no repaint/recolor/alpha replacement","assets":assets,"native_world_units_per_pixel":1,"max_visible_grass":2,"max_visible_branches":1,"collision":false,"standing_edge":false,"attachment_policy":"Every visible root/hanging point stays offscreen with12wu air margin; otherwise whole sprite hidden","protection_policy":"Actual complete sprite bounds plus3wu wind margin hard-hide on any functional/HUD intersection; more than64 visible protection rectangles hides all foreground"}
	FileAccess.open(OUT+"foreground_build.json",FileAccess.WRITE).store_string(JSON.stringify(spec,"  "))
	print("UNDERWORLD_FOREGROUND_BUILD assets=%d fine_grid=1wu max_grass=2 max_branch=1"%assets.size())
	quit()

func alpha_bounds(image: Image,cell: Rect2i) -> Rect2i:
	var low:=cell.end
	var high:=cell.position-Vector2i.ONE
	for y: int in range(cell.position.y,cell.end.y):
		for x: int in range(cell.position.x,cell.end.x):
			if image.get_pixel(x,y).a<2.0/255.0: continue
			low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
	return Rect2i(low,high-low+Vector2i.ONE) if high.x>=low.x else Rect2i()

extends SceneTree
## FINE-SPACE-05: measured source organization. Geometry and state cues unchanged.
const OUT := "res://assets/forest_bible_v2/native/fine_32/"

func _initialize() -> void:
	build_ecology()
	build_thorns()
	build_boss_beetle()
	build_branch_deck()
	print("FORMAL_FOREST_DETAIL_BUILD ecology=4 boss_beetle=3 fine_sources=true thorn_pixel_world_scale=1 preserved_alpha_ports=true branch_deck=8wu")
	quit()

func build_ecology() -> void:
	var raw:=Image.load_from_file(OUT+"ecology_master_original.png")
	assert(raw!=null and raw.get_size()==Vector2i(1312,1199))
	var rows: Array[Dictionary]=[
		{"id":"lantern","raw":Rect2i(144,91,469,406),"size":Vector2i(48,40),"target":Rect2i(2,2,44,36)},
		{"id":"swing_pod","raw":Rect2i(833,72,291,429),"size":Vector2i(36,44),"target":Rect2i(4,2,26,38)},
		{"id":"seed_sentry","raw":Rect2i(218,624,308,497),"size":Vector2i(44,52),"target":Rect2i(4,2,36,48)},
		{"id":"crossbranch","raw":Rect2i(771,629,427,486),"size":Vector2i(48,48),"target":Rect2i(0,2,44,44)}]
	var outputs: Array[Dictionary]=[]
	for row: Dictionary in rows:
		var cut:=raw.get_region(row.raw)
		cut.resize(row.target.size.x,row.target.size.y,Image.INTERPOLATE_NEAREST)
		# Hard pixel alpha only; retain RGB from image_gen, no painted replacement.
		for y: int in cut.get_height():
			for x: int in cut.get_width():
				var c:=cut.get_pixel(x,y)
				c.a=1.0 if c.a>=.5 else 0.0
				cut.set_pixel(x,y,c)
		var image:=Image.create(row.size.x,row.size.y,false,Image.FORMAT_RGBA8)
		image.blit_rect(cut,Rect2i(Vector2i.ZERO,cut.get_size()),row.target.position)
		var path:=OUT+str(row.id)+".png"
		assert(image.save_png(path)==OK)
		outputs.append({"id":row.id,"raw_crop":[row.raw.position.x,row.raw.position.y,row.raw.size.x,row.raw.size.y],"source_size":[row.size.x,row.size.y],"target_alpha_bounds":[row.target.position.x,row.target.position.y,row.target.size.x,row.target.size.y],"sha256":FileAccess.get_sha256(path)})
	write_json(OUT+"ecology_build.json",{"task":"FINE-SPACE-05","master":"ecology_master_original.png","master_sha256":FileAccess.get_sha256(OUT+"ecology_master_original.png"),"outputs":outputs,"process":"Actual fine image_gen sheet, measured alpha128 crops, nearest sample to2x old native dimensions; old normalized body bounds and anchors retained; no enlarged old sprite RGB","alpha_cutoff":128,"runtime_scale_world":.75,"world_sampling":1,"lantern_parts":"Fine48x40 source remapped to top12, wing band12..24, lower16px; same age14 frequency and 3/6/9wu wing timing","gameplay_change":false})

func build_thorns() -> void:
	var old:=Image.load_from_file("res://assets/forest_bible_v2/native/thorn_briar_atlas_v2.png")
	var raw:=Image.load_from_file("res://assets/forest_bible_v2/source/thorn_native_study_v1/imagegen-original.png")
	assert(old!=null and raw!=null)
	var fine:=Image.create(512,192,false,Image.FORMAT_RGBA8)
	for y: int in fine.get_height():
		for x: int in fine.get_width():
			var c:=old.get_pixel(x>>1,y>>1)
			if c.a==0.0: continue
			# Only real high-resolution reference fiber modulates the old pigment.
			# Old pale danger identity, alpha silhouette and all ports stay fixed.
			var detail:=raw.get_pixel(90+posmod(x*7,1240),292+posmod(y*3,130))
			var luma:=detail.r*.299+detail.g*.587+detail.b*.114
			var factor:=.82+.36*luma if detail.a>=.5 else 1.0
			c.r*=factor;c.g*=factor;c.b*=factor
			fine.set_pixel(x,y,c)
	assert(fine.save_png(OUT+"thorn_briar_atlas.png")==OK)
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/forest_bible_v2/native/thorn_briar_atlas_v2.json"))
	var regions: Dictionary={}
	for name: String in original.regions:
		var row: Dictionary=original.regions[name].duplicate(true)
		for key: String in ["atlas_rect","size","outer_rect","root_rect","port"]:
			for i: int in row[key].size(): row[key][i]=int(row[key][i])*2
		row.seam_native=int(row.seam_native)*2
		var anchors: Array[int]=[]
		for anchor: Variant in row.root_anchor_y_by_x:
			anchors.append(int(anchor)*2);anchors.append(int(anchor)*2)
		row.root_anchor_y_by_x=anchors
		row.safe_tail_columns=[]
		# Safe tail proof extends the actual old pale connected components into
		# 1wu space; no half-needle cuts at new odd native columns.
		if row.face in ["up","down"]:
			var pale: Dictionary={}
			var old_row: Dictionary=original.regions[name]
			var a: Array=old_row.atlas_rect
			var outer: Array=old_row.outer_rect
			for yy: int in range(int(outer[1]),int(outer[1])+int(outer[3])):
				for xx: int in int(old_row.size[0]):
					var c:=old.get_pixel(int(a[0])+xx,int(a[1])+yy)
					if c.a>.5 and c.r>128.0/255.0 and c.g>c.r: pale[Vector2i(xx,yy)]=true
			var components: Array[Vector2i]=[]
			while not pale.is_empty():
				var start: Vector2i=pale.keys()[0]
				pale.erase(start)
				var queue: Array[Vector2i]=[start]
				var low:=start.x;var high:=start.x
				while not queue.is_empty():
					var p: Vector2i=queue.pop_back()
					low=mini(low,p.x);high=maxi(high,p.x)
					for dy: int in range(-1,2):
						for dx: int in range(-1,2):
							var q:=p+Vector2i(dx,dy)
							if pale.has(q): pale.erase(q);queue.append(q)
				components.append(Vector2i(low*2,high*2+1))
			for column: int in range(1,int(row.size[0])+1):
				var safe:=true
				for component: Vector2i in components:
					if component.x<column and component.y>=column: safe=false;break
				if safe: row.safe_tail_columns.append(column)
		regions[name]=row
	write_json(OUT+"thorn_briar_atlas.json",{"task":"FINE-SPACE-05","native_scale_world":1,"atlas_size":[512,192],"atlas_sha256":FileAccess.get_sha256(OUT+"thorn_briar_atlas.png"),"regions":regions,"source_template":"assets/forest_bible_v2/native/thorn_briar_atlas_v2.png","template_sha256":FileAccess.get_sha256("res://assets/forest_bible_v2/native/thorn_briar_atlas_v2.png"),"fiber_source":"assets/forest_bible_v2/source/thorn_native_study_v1/imagegen-original.png","fiber_sha256":FileAccess.get_sha256("res://assets/forest_bible_v2/source/thorn_native_study_v1/imagegen-original.png"),"process":"Old alpha/port/pale pigment template retained; real highres wood fiber luma adds1wu detail(.82+.36*luma), no generated noise or new silhouette. Not a newly redrawn contour family.","root_anchor_world_invariant":true,"physics_change":false,"rejected_candidate":"thorn_refine_rejected.png (imagegen layout/direction drift; not consumed)"})

func write_json(path: String,value: Dictionary) -> void:
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(value,"  ")+"\n")

func build_boss_beetle() -> void:
	var raw:=Image.load_from_file(OUT+"boss_beetle_master_original.png")
	assert(raw!=null and raw.get_size()==Vector2i(2056,765))
	var rows: Array[Dictionary]=[
		{"id":"guardian","raw":Rect2i(231,62,455,647),"size":Vector2i(72,96),"target":Rect2i(6,2,58,92)},
		{"id":"queen","raw":Rect2i(845,159,514,546),"size":Vector2i(72,68),"target":Rect2i(2,2,68,64)},
		{"id":"beetle","raw":Rect2i(1551,505,319,200),"size":Vector2i(48,32),"target":Rect2i(4,2,38,28)}]
	var outputs: Array[Dictionary]=[]
	for row: Dictionary in rows:
		var cut:=raw.get_region(row.raw)
		cut.resize(row.target.size.x,row.target.size.y,Image.INTERPOLATE_NEAREST)
		for y: int in cut.get_height():
			for x: int in cut.get_width():
				var c:=cut.get_pixel(x,y)
				c.a=1.0 if c.a>=.5 else 0.0
				cut.set_pixel(x,y,c)
		var image:=Image.create(row.size.x,row.size.y,false,Image.FORMAT_RGBA8)
		image.blit_rect(cut,Rect2i(Vector2i.ZERO,cut.get_size()),row.target.position)
		var path:=OUT+str(row.id)+".png"
		assert(image.save_png(path)==OK)
		outputs.append({"id":row.id,"raw_crop":[row.raw.position.x,row.raw.position.y,row.raw.size.x,row.raw.size.y],"source_size":[row.size.x,row.size.y],"target_alpha_bounds":[row.target.position.x,row.target.position.y,row.target.size.x,row.target.size.y],"sha256":FileAccess.get_sha256(path)})
	write_json(OUT+"boss_beetle_build.json",{"task":"FINE-SPACE-05","outputs":outputs,"master":"boss_beetle_master_original.png","master_sha256":FileAccess.get_sha256(OUT+"boss_beetle_master_original.png"),"process":"Actual fine image_gen sheet, measured alpha128 crop, nearest sample, normalized old opaque bounds and foot/core regions retained. Guardian and Queen render1wu/pixel; Beetle.75wu/pixel before common1wu world sampling.","guardian_foot_native":[36,94],"guardian_foot_world":[0,48],"guardian_closed_heart_source":[30,36,16,10],"queen_collision_changed":false,"weaver32_source_unchanged":true,"gameplay_change":false})

func build_branch_deck() -> void:
	var raw:=Image.load_from_file(OUT+"bark_master_original.png")
	var image:=raw.get_region(Rect2i(48,630,1114,140))
	image.resize(192,16,Image.INTERPOLATE_NEAREST)
	assert(image.save_png(OUT+"bark_deck.png")==OK)
	write_json(OUT+"bark_deck_build.json",{"task":"FINE-SPACE-05","source":"bark_master_original.png","crop":[48,630,1114,140],"native_size":[192,16],"render":"8wu bark cross-section; native1wu cap/body patches; no grass-only strip, no collider mutation","sha256":FileAccess.get_sha256(OUT+"bark_deck.png")})

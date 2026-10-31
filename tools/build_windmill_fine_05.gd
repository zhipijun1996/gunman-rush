extends SceneTree
## Organize real AI art into native fine-grid components; never paint new art.
const OUT := "res://assets/underworld_plains/windmill_fine_05/"

func _initialize() -> void:
	var master:=Image.load_from_file(OUT+"master_original.png")
	assert(master!=null and master.get_size()==Vector2i(1774,887))
	var body:=master.get_region(Rect2i(88,140,480,725))
	body.resize(80,122,Image.INTERPOLATE_NEAREST)
	assert(body.save_png(OUT+"body.png")==OK)
	# The square is centered on the measured bronze axle, with real transparent
	# padding around every blade. Its opaque radial sweep fits within34wu.
	var rotor:=master.get_region(Rect2i(670,161,624,624))
	rotor.resize(66,66,Image.INTERPOLATE_NEAREST)
	var radius:=0.0
	for y: int in rotor.get_height():
		for x: int in rotor.get_width():
			if rotor.get_pixel(x,y).a<.5: continue
			radius=maxf(radius,(Vector2(x+.5,y+.5)-Vector2(33,33)).length())
	assert(radius<=34.0,"Rotor would exceed the declared full-angle display envelope")
	assert(rotor.save_png(OUT+"rotor.png")==OK)
	var cloth:=master.get_region(Rect2i(1453,396,262,168))
	cloth.resize(17,11,Image.INTERPOLATE_NEAREST)
	var flag:=Image.create(19,13,false,Image.FORMAT_RGBA8)
	flag.blit_rect(cloth,Rect2i(0,0,17,11),Vector2i.ONE)
	assert(flag.save_png(OUT+"flag.png")==OK)
	var spec: Dictionary={"task":"FINE-SPACE-05","family":"separated_static_tower_rotor_and_flag","master":"master_original.png","master_size":[1774,887],"native_frame":[80,152],"body":{"crop":[88,140,480,725],"native_size":[80,122],"position":[0,30]},"rotor":{"crop":[670,161,624,624],"native_size":[66,66],"hub":[42,37],"source_measured_hub":[982,473],"maximum_alpha_radius":radius,"allowed_radius":34},"flag":{"crop":[1453,396,262,168],"content_size":[17,11],"padded_size":[19,13],"position":[59,62],"fixed_pole_columns":4,"maximum_cloth_sway_wu":1},"foot":[40,152],"ground_inset_wu":7,"sampling":"nearest, native1wu grid; instance uniformly fits inside original source sprite bounds","physics":false,"constraints":"static body never rotates; rotor and flag remain within source display/root-span envelope"}
	FileAccess.open(OUT+"windmill_build.json",FileAccess.WRITE).store_string(JSON.stringify(spec,"  "))
	print("WINDMILL_FINE_BUILD body=80x122 rotor=66x66 flag=19x13 radius=%.3f max=34 root_inset=7"%radius)
	quit()

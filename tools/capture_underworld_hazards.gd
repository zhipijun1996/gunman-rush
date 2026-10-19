extends SceneTree
## GPU material catalog only; the independent runtime checker exercises contacts.
class MaterialCatalog extends Node2D:
	var hosts: Array[Rect2] = [Rect2(100,190,320,64),Rect2(100,380,320,64),Rect2(630,190,96,240),Rect2(930,190,96,240),Rect2(630,510,240,64)]
	var bands: Array[Dictionary] = []
	func _ready() -> void:
		var terrain := UnderworldTerrain.build(hosts)
		terrain.z_index = -1
		add_child(terrain)
		for spec: Array in [[0,0,64,160],[1,3,64,160],[2,1,32,144],[3,2,32,144],[4,0,176,64],[4,2,0,64]]:
			var thorn := PlatformThornDefinition.new()
			thorn.platform_index = int(spec[0])
			thorn.face = int(spec[1])
			thorn.start_offset = float(spec[2])
			thorn.length = float(spec[3])
			thorn.depth = 24
			bands.append({"thorn":thorn})
	func _draw() -> void:
		for row: Dictionary in bands: UnderworldHazardTiles.draw_surface(self,row.thorn,hosts)
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(80,65),"UNDERWORLD / INTEGRATED HAZARDOUS SURFACES",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("e8d7ad"))
		draw_string(font,Vector2(80,100),"Same rock / embedded roots / original contact rectangles",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("91a594"))
		for row: Array in [[Vector2(100,150),"TOP / safe ends retained"],[Vector2(100,340),"BOTTOM"],[Vector2(600,150),"LEFT"],[Vector2(900,150),"RIGHT"],[Vector2(630,480),"SHARED CORNER"]]:
			draw_string(font,row[0],row[1],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("baac8e"))
		draw_string(font,Vector2(80,640),"Material catalog, not route traversal or device acceptance.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("91a594"))

func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	root.add_child(MaterialCatalog.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://build/underworld_plains/hazards")
	var error := picture.save_png("res://build/underworld_plains/hazards/material_catalog.png")
	print("UNDERWORLD HAZARD GPU CATALOG: ", error)
	quit(0 if error==OK else 1)

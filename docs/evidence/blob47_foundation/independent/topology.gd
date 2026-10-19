extends SceneTree
var failures: Array[String] = []
var checks := 0
func _init() -> void: call_deferred("run")
func ck(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL ",message)
func run() -> void:
	var im := Blob47Terrain.ATLAS.get_image()
	var signatures: Dictionary = {}
	for variant: int in range(3):
		for mask: int in Blob47Rules.catalog_masks():
			var at := Blob47Rules.atlas_coords(mask,variant) * Blob47Rules.PITCH + Vector2i.ONE * Blob47Rules.GUTTER
			var crop := im.get_region(Rect2i(at,Vector2i(64,64)))
			var signature := hash(crop.get_data())
			ck(not signatures.has(signature),"unique mask/variant pixel crop "+str(mask)+"/"+str(variant))
			signatures[signature] = true
			for pair: Array in [[1,Vector2i(32,0)],[4,Vector2i(63,32)],[16,Vector2i(32,63)],[64,Vector2i(0,32)]]:
				var pixel := crop.get_pixelv(pair[1])
				ck(pixel.is_equal_approx(Color("c68e57")) if mask & pair[0] else not pixel.is_equal_approx(Color("c68e57")),"actual art cardinal "+str(mask)+"/"+str(pair[0]))
			ck(im.get_pixelv(at-Vector2i.ONE).a == 0,"transparent gutter")
	for seed_id: int in range(20):
		var data := Blob47Layout.generate("independent-union-%02d"%seed_id)
		var forward: Dictionary = {}
		var reverse: Dictionary = {}
		var modules: Array = data.modules.duplicate(true)
		for module: Dictionary in modules:
			for tile: Dictionary in module.tiles:
				for y: int in range(tile.rect.position.y,tile.rect.end.y):
					for x: int in range(tile.rect.position.x,tile.rect.end.x): forward[module.origin+Vector2i(x,y)] = tile.material
		modules.reverse()
		for module: Dictionary in modules:
			var tiles: Array = module.tiles.duplicate(true)
			tiles.reverse()
			for tile: Dictionary in tiles:
				for y: int in range(tile.rect.position.y,tile.rect.end.y):
					for x: int in range(tile.rect.position.x,tile.rect.end.x): reverse[module.origin+Vector2i(x,y)] = tile.material
		ck(forward == data.cells and reverse == data.cells,"module union exact and order independent")
		for seam_x: int in [19,39,59]:
			for y: int in range(20,25):
				ck(Blob47Rules.mask_at(forward,Vector2i(seam_x,y)) & 4 != 0,"no false E seam cap")
				ck(Blob47Rules.mask_at(reverse,Vector2i(seam_x+1,y)) & 64 != 0,"no false W seam cap")
	print("INDEPENDENT_TOPOLOGY checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

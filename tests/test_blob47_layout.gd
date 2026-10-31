extends SceneTree
## Grid/semantic generation tests. Does not claim player/Motor clearance proof.

const Layout = preload("res://game/presentation/world/art_foundation/blob47_layout.gd")
var failures: Array[String] = []
var checks: int = 0


func _init() -> void:
	var pool: Array[Dictionary] = Layout.module_catalog()
	_expect(pool.size() == 3, "three authored shape templates")
	for module: Dictionary in pool:
		_expect(Layout.validate_module(module).ok, "valid authored module: " + module.id)
	_expect(Layout.validate_chain(pool).ok, "all different templates join exactly")
	var signatures: Dictionary = {}
	for index: int in range(32):
		var seed_text := "blob-layout-case-%d" % index
		var result: Dictionary = Layout.generate(seed_text)
		_expect(result.ok, "generation succeeds: " + seed_text)
		if not result.ok:
			print(result.errors)
			continue
		var replay: Dictionary = Layout.generate(seed_text)
		_expect(result == replay, "same seed reconstructs all actual content")
		_expect(result.seed == seed_text and result.version == Layout.VERSION, "seed and version recorded")
		_expect(result.bounds == Rect2(0, 0, 2560, 800), "bounded 80 by 25 sample")
		_expect(result.modules.size() == 4, "four-module manifest")
		var module_ids: Array[String] = []
		var rebuilt: Dictionary = {}
		for module: Dictionary in result.modules:
			module_ids.append(module.id)
			_expect(module.version == result.version, "manifest pins actual module version")
			var authored: Dictionary = {}
			for candidate: Dictionary in pool:
				if candidate.id == module.id:
					authored = candidate
			for key: String in ["family_ids", "tile_size", "ports_and_halo", "density_profile", "background_profile", "visual_role", "exceptions"]:
				_expect(module[key] == authored[key], "manifest records actual module card: " + key)
			for tile: Dictionary in module.tiles:
				var rect: Rect2i = tile.rect
				for y: int in range(rect.position.y, rect.end.y):
					for x: int in range(rect.position.x, rect.end.x):
						rebuilt[module.origin + Vector2i(x, y)] = tile.material
		_expect(rebuilt == result.cells, "manifest reconstructs every collision source cell")
		_expect(module_ids.slice(0, 3).has("terraced_court") and module_ids.slice(0, 3).has("open_arch") and module_ids.slice(0, 3).has("sheltered_basin"), "bag contains all three actual shapes")
		signatures[str(module_ids)] = true
		for x: int in range(80):
			_expect(result.cells.get(Vector2i(x, 20)) == &"sandstone", "no gap in protected main floor")
		for cell: Vector2i in result.cells:
			_expect(Rect2i(0, 0, 80, 25).has_point(cell), "solid cell inside declared bounds")
		for hazard: Rect2 in result.hazards:
			_expect(hazard.end.y <= 18 * Layout.CELL, "hazards stay above main route")
		for platform: Dictionary in result.moving:
			var sweep: Rect2 = platform.rect.merge(Rect2(platform.rect.position + platform.travel, platform.rect.size))
			_expect(sweep.end.y <= 16 * Layout.CELL, "moving sweep stays in optional upper lane")
	_expect(signatures.size() >= 3, "seed changes actual module order")
	var bad: Dictionary = pool[0].duplicate(true)
	bad.size = Vector2(20.5, 25)
	_reject(bad, "fractional size")
	bad = pool[0].duplicate(true)
	bad.tiles[0].rect = Rect2(0.5, 20, 20, 5)
	_reject(bad, "fractional tile rectangle cannot be snapped")
	bad = pool[0].duplicate(true)
	bad.tiles[0].rect = Rect2i(0, 20, 21, 5)
	_reject(bad, "out-of-bounds tile")
	bad = pool[0].duplicate(true)
	bad.tiles[0].material = &"legacy_rock"
	_reject(bad, "unknown material")
	bad = pool[0].duplicate(true)
	bad.tiles[0].semantic = &"one_way"
	_reject(bad, "one-way cannot be misdeclared solid")
	bad = pool[0].duplicate(true)
	bad.tiles.append(bad.tiles[0].duplicate(true))
	_reject(bad, "overlapping solid tiles")
	bad = pool[0].duplicate(true)
	bad.entry = Vector2i(0, 19)
	_reject(bad, "unmatched port")
	bad = pool[0].duplicate(true)
	bad.hazards.append(Rect2i(15, 19, 1, 1))
	_reject(bad, "hazard in safe route")
	bad = pool[0].duplicate(true)
	bad.one_way.append(Rect2i(12, 14, 2, 1))
	_reject(bad, "one-way overlaps solid")
	bad = pool[0].duplicate(true)
	bad.moving[0].travel = Vector2(2.5, 0)
	_reject(bad, "fractional moving travel")
	bad = pool[0].duplicate(true)
	bad.moving[0].travel = Vector2i(0, 4)
	_reject(bad, "moving sweep intersects solid")
	bad = pool[0].duplicate(true)
	bad.moving[0].travel = Vector2i(100000000, 0)
	_reject(bad, "huge moving sweep fails before rasterization")
	bad = pool[0].duplicate(true)
	bad.moving[0].period = INF
	_reject(bad, "infinite moving period")
	bad = pool[0].duplicate(true)
	bad.moving[0].period = NAN
	_reject(bad, "nan moving period")
	bad = pool[2].duplicate(true)
	bad.one_way = [Rect2i(5, 17, 3, 1)]
	_reject(bad, "original basin low one-way catches main-route jump below high wall")
	bad = pool[1].duplicate(true)
	bad.one_way.append(Rect2i(5, 16, 2, 1))
	_reject(bad, "original arch low one-way catches main-route jump below high wall")
	bad = pool[2].duplicate(true)
	bad.tiles[1].rect = Rect2i(4, 19, 4, 1)
	_reject(bad, "original basin step terminates in a one-cell body pinch")
	bad = pool[0].duplicate(true)
	bad.family_ids = [&"legacy_rock"]
	_reject(bad, "unknown family card")
	bad = pool[0].duplicate(true)
	bad.tile_size = Layout.CELL * 2
	_reject(bad, "card tile size differs from rules")
	bad = pool[0].duplicate(true)
	bad.ports_and_halo.halo_cells = 0
	_reject(bad, "missing neighbor halo")
	bad = pool[0].duplicate(true)
	bad.ports_and_halo.owner = "local_module"
	_reject(bad, "halo owned by isolated local module")
	bad = pool[0].duplicate(true)
	bad.density_profile = "unknown"
	_reject(bad, "unknown density profile")
	bad = pool[0].duplicate(true)
	bad.background_profile = "unknown"
	_reject(bad, "unknown background profile")
	bad = pool[0].duplicate(true)
	bad.erase("visual_role")
	_reject(bad, "missing visual role")
	bad = pool[0].duplicate(true)
	bad.exceptions = ["ignore_collision"]
	_reject(bad, "unhandled exception")
	_expect(not Layout.validate_chain([pool[0], pool[1]], [Vector2i.ZERO, Vector2i(19, 0)]).ok, "overlapping module bounds and unmatched ports rejected")
	_expect(not Layout.validate_chain([pool[0], pool[1]], [Vector2i.ZERO, Vector2i(21, 0)]).ok, "one-cell seam gap rejected")
	_expect(not Layout.validate_chain([pool[0]], [Vector2(0.5, 0)]).ok, "fractional origin rejected")
	_expect(not Layout.validate_chain([pool[0], pool[1]], [Vector2i.ZERO]).ok, "missing origin rejected")
	_expect(not Layout.validate_chain([]).ok, "empty chain rejected")
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("BLOB47_LAYOUT checks=%d failures=%d; grid/semantic/port validation only; Motor traversal unverified" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _reject(module: Dictionary, label: String) -> void:
	_expect(not Layout.validate_module(module).ok, label + " rejected")

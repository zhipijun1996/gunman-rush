extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("TERRAIN COHESION: " + message)
func run() -> void:
	# A synthetic atlas exercises clipping independently of a particular image.
	var source := Rect2(30, 40, 900, 180)
	var scale_value := 0.2
	for width: float in [8, 24, 100, 320, 1800]:
		for depth: float in [12, 30, 40, 120]:
			var slab := Rect2(17, 100, width, depth)
			var target := Rect2(slab.position, Vector2(width, 36))
			var coverage := 0.0
			for piece: Dictionary in PlainsTerrainSkin.clipped_strip_pieces(target, slab, Vector2(287, 30), source, scale_value):
				check(slab.encloses(piece.destination), "root/soil paint stays inside existing slab; no void filling")
				check(source.encloses(piece.source), "source crop stays within original generated strip")
				check(piece.destination.size.is_equal_approx(piece.source.size * scale_value), "roots and soil keep fixed natural scale")
				check(is_equal_approx(piece.destination.size.y, minf(36, depth)), "thin floors clip transition instead of painting false deep sides")
				coverage += piece.destination.size.x
			check(is_equal_approx(coverage, width), "soil transition covers full authored surface width")
	for source_region: Rect2 in [PlainsTerrainSkin.SOIL_SOURCE, PlainsTerrainSkin.THORN_ROOT_SOURCE]:
		check(Rect2(Vector2.ZERO, PlainsTerrainSkin.ROOT_BANDS.get_size()).encloses(source_region), "actual runtime crop lies inside original root atlas")
		var real_slab := Rect2(0, 300, 320, 30)
		for piece: Dictionary in PlainsTerrainSkin.clipped_strip_pieces(Rect2(0, 300, 320, source_region.size.y * PlainsTerrainSkin.ROOT_SCALE), real_slab, Vector2(160, 0), source_region, PlainsTerrainSkin.ROOT_SCALE):
			check(source_region.encloses(piece.source) and real_slab.encloses(piece.destination), "actual atlas pieces cannot paint past thin solid slabs")
	var world_point := Vector2(420, 112)
	check(sample(Rect2(0, 100, 800, 36), Vector2.ZERO, source, world_point).is_equal_approx(sample(Rect2(0, 100, 350, 36), Vector2(300, 0), source, world_point)), "split modules sample the same soil pixel at shared world coordinate")
	var danger := Rect2(100, 70, 160, 30)
	var ground: Array[Rect2] = [Rect2(80, 100, 80, 40), Rect2(210, 100, 100, 40)]
	var clips := PlainsTerrainSkin.thorn_root_clips(danger, ground)
	check(clips.size() == 3, "thorn root bedding has existing hazard base plus two real ground fragments")
	var protected_gap := Rect2(160, 100, 50, 18)
	for clip: Rect2 in clips:
		check(not clip.intersects(protected_gap), "root bedding never joins across the protected gap")
		check(danger.encloses(clip) or ground.any(func(solid: Rect2) -> bool: return solid.encloses(clip)), "each root fragment lies inside hazard or real solid")
	var empty: Array[Rect2] = []
	check(PlainsTerrainSkin.thorn_root_clips(danger, empty) == [Rect2(100, 88, 160, 12)], "airborne pit hazard gets no fake soil/floor below its collision silhouette")
	check(PlainsTerrainSkin.thorn_root_clips(Rect2(), ground).is_empty(), "empty hazard adds no decorative collision-looking content")
	# Regression: this real preview manifest previously hit sub-ULP tile widths
	# during drawing and allocated dictionaries without bound until OOM.
	var tuning := PlayerTuning.load_default()
	var generated := RandomStageGenerator.new().generate("preview-contract-proof".hash(), tuning, 14, "plains_standard")
	check(generated.ok, "OOM regression uses the real preview-contract-proof manifest")
	if generated.ok:
		var assembler := RandomStageAssembler.new()
		root.add_child(assembler)
		check(assembler.build(generated.manifest, tuning).ok, "actual OOM seed assembles all presentation consumers")
		for module: PlatformingModule in assembler.modules:
			for index: int in module.definition.platforms.size():
				var slab: Rect2 = module.definition.platforms[index]
				if index in module.definition.one_way_platform_indices or index in module.floating_solid_indices: continue
				var region: Dictionary = module.ground_surface_regions.get(index, {})
				var edge: Rect2 = region.get("rect", slab)
				var edge_pieces := PlainsTerrainSkin.ground_edge_pieces(edge, module.position, bool(region.get("left", false)), bool(region.get("right", false)))
				bounded_coverage(edge_pieces, edge.size.x, "real preview grass edge")
				var soil := Rect2(edge.position - Vector2(0, (PlainsTerrainSkin.SOIL_ANCHOR - PlainsTerrainSkin.SOIL_SOURCE.position.y) * PlainsTerrainSkin.ROOT_SCALE), Vector2(edge.size.x, PlainsTerrainSkin.SOIL_SOURCE.size.y * PlainsTerrainSkin.ROOT_SCALE))
				bounded_coverage(PlainsTerrainSkin.clipped_strip_pieces(soil, edge, module.position, PlainsTerrainSkin.SOIL_SOURCE, PlainsTerrainSkin.ROOT_SCALE), edge.size.x, "real preview soil edge")
				var rock := PlainsTerrainSkin.rock_pieces(slab, module.position)
				check(rock.size() <= 100 and rock.all(func(piece: Dictionary) -> bool: return (piece.destination as Rect2).has_area()), "real preview rock skin is finite and nonempty")
			var solids: Array[Rect2] = []
			for index: int in module.definition.platforms.size():
				if index not in module.definition.one_way_platform_indices: solids.append(module.definition.platforms[index])
			for danger_rect: Rect2 in module.definition.danger_bounds:
				var target := Rect2(danger_rect.position.x, danger_rect.end.y - minf(12.0, danger_rect.size.y), danger_rect.size.x, PlainsTerrainSkin.THORN_ROOT_SOURCE.size.y * PlainsTerrainSkin.ROOT_SCALE)
				for clip: Rect2 in PlainsTerrainSkin.thorn_root_clips(danger_rect, solids):
					bounded_coverage(PlainsTerrainSkin.clipped_strip_pieces(target, clip, module.position, PlainsTerrainSkin.THORN_ROOT_SOURCE, PlainsTerrainSkin.ROOT_SCALE), target.intersection(clip).size.x, "real preview thorn bedding")
		# Exercise actual canvas _draw too, not only the pure crop plan.
		await process_frame
		await process_frame
		assembler.free()
	# Exact and near tile boundaries at negative and positive world offsets.
	for origin_x: float in [-10000.0, -582.76, -291.38, 0, 291.38, 582.76, 10000.0]:
		var box := Rect2(0, 100, 2200, 30)
		bounded_coverage(PlainsTerrainSkin.clipped_strip_pieces(box, box, Vector2(origin_x, 0), PlainsTerrainSkin.SOIL_SOURCE, PlainsTerrainSkin.ROOT_SCALE), box.size.x, "fractional tile boundary regression")
	if "--prove-failure" in OS.get_cmdline_user_args(): check(false, "intentional failure")
	print("PLAINS TERRAIN COHESION: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func sample(target: Rect2, origin: Vector2, source: Rect2, point: Vector2) -> Vector2:
	for piece: Dictionary in PlainsTerrainSkin.clipped_strip_pieces(target, target, origin, source, 0.2):
		var dst: Rect2 = piece.destination
		if dst.has_point(point - origin): return piece.source.position + (point - origin - dst.position) / 0.2
	return Vector2.INF

func bounded_coverage(pieces: Array[Dictionary], expected_width: float, context: String) -> void:
	check(pieces.size() <= 64, context + " has a geometry-bounded piece count")
	var width := 0.0
	for piece: Dictionary in pieces:
		var destination: Rect2 = piece.destination
		check(destination.has_area() and destination.size.x > 0, context + " never emits zero-width pieces")
		width += destination.size.x
	check(absf(width - expected_width) < 0.005, context + " covers complete width without a skipped final tile")

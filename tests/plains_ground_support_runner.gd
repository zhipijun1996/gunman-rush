extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("GROUND SUPPORT: " + message)
func fixture(platforms: Array[Rect2], offset := Vector2.ZERO) -> PlatformingModule:
	var module := PlatformingModule.new()
	module.definition = PlatformingModuleDefinition.new()
	module.definition.module_id = &"plains_fixture"
	module.definition.platforms = platforms
	module.definition.world_bounds = Rect2(0, 0, 300, 300)
	module.position = offset
	return module
func run() -> void:
	var base := fixture([Rect2(0, 100, 100, 40), Rect2(200, 100, 100, 40), Rect2(100, 20, 50, 24)])
	base.definition.one_way_platform_indices = [2]
	var modules: Array[PlatformingModule] = [base]
	var bounds := Rect2(0, 0, 300, 300)
	var columns := PlainsGroundSupports.plan(modules, bounds)
	check(columns.size() == 2, "solid ground joins earth; explicitly one-way sky platform stays floating")
	for column: Rect2 in columns:
		check(column.position.y == 140 and column.end.y == 492, "support continues exact slab underside through stage bottom")
		check(not column.intersects(Rect2(100, 140, 100, 350)), "gap remains open to falling, never bridged")
	base.definition.one_way_platform_indices = [0, 2]
	check(PlainsGroundSupports.plan(modules, bounds).size() == 1, "one-way solidity metadata takes priority over visual thickness")
	base.definition.one_way_platform_indices = [2]
	var lower := fixture([Rect2(0, 200, 100, 40)], Vector2(0, 200))
	modules.append(lower)
	columns = PlainsGroundSupports.plan(modules, Rect2(0, 0, 300, 700))
	check(not columns.has(Rect2(0, 140, 100, 752)), "whole lower room protected, including empty passage above its own floor")
	check(columns.size() == 1 and columns[0].position.y == 440, "only bottommost eligible ground supports overlapping rooms")
	lower.free()
	modules.remove_at(1)
	base.definition.danger_bounds = [Rect2(0, 200, 100, 20)]
	check(PlainsGroundSupports.plan(modules, bounds).size() == 1, "support cannot bury danger envelope")
	base.free()
	var left := fixture([Rect2(0, 100, 200, 30)])
	var right := fixture([Rect2(0, 100, 200, 30)], Vector2(160, 0))
	var seam_modules: Array[PlatformingModule] = [left, right]
	var seam_plan := PlainsGroundSupports.plan(seam_modules, bounds)
	check(seam_plan.size() == 1 and seam_plan[0] == Rect2(0, 130, 360, 362), "same-level 40-unit shared seam merges continuous thin solid ground without vertical slot")
	check(PlainsGroundSupports.floating_indices(left, seam_plan).is_empty() and PlainsGroundSupports.floating_indices(right, seam_plan).is_empty(), "grounded thin solids retain stone, not hanging wood")
	check(PlainsGroundSupports.floating_indices(left, []).has(0), "unattached solid is explicitly marked boxed timber, never false floating stone")
	PlainsTerrainSkin.configure_ground_edges(seam_modules)
	check(left.ground_surface_regions[0].right and right.ground_surface_regions[0].left, "neighboring ground omits internal painted endcaps")
	check(right.ground_surface_regions[0].rect.position.x == 40, "shared 40-unit seam grass is painted once, not two alpha layers")
	for piece: Dictionary in PlainsTerrainSkin.ground_edge_pieces(Rect2(0, 100, 360, 40), Vector2.ZERO, true, true):
		check(piece.destination.end.y <= 114 and piece.source.position.x >= 297 and piece.source.end.x <= 1873, "connected ground uses shallow blended middle grass instead of individual stone caps")
	left.free()
	right.free()
	var point := Vector2(391, 211)
	check(texture_sample(Rect2(0, 0, 700, 400), Vector2.ZERO, point).is_equal_approx(texture_sample(Rect2(0, 0, 240, 300), Vector2(300, 100), point)), "module slabs and foundation use same world-space rock pixel at shared location")
	var tuning := PlayerTuning.load_default()
	var generator := RandomStageGenerator.new()
	var total := 0
	for index: int in 12:
		var data := generator.generate(("ground-support-%d" % index).hash(), tuning, 14, "plains_standard")
		check(data.ok, "shared generic generated map succeeds")
		if not data.ok: continue
		var recorded: Dictionary = JSON.parse_string(JSON.stringify(data.manifest))
		recorded.ground_support_version = PlainsGroundSupports.VERSION
		recorded.ground_supports = PlainsGroundSupports.recorded_plan(recorded, generator)
		recorded.manifest_hash = generator._manifest_hash(recorded)
		check(generator.validate_manifest(recorded, tuning).ok, "JSON replay preserves exact support rectangles")
		var assembler := RandomStageAssembler.new()
		root.add_child(assembler)
		check(assembler.build(recorded, tuning).ok, "recorded support assembly succeeds")
		await physics_frame
		await physics_frame
		var layer := assembler.ground_supports
		total += layer.columns.size()
		check(layer.columns == PlainsGroundSupports.plan(assembler.modules, assembler.bounds), "runtime bodies match deterministic safe support plan")
		check(layer.get_child_count() == layer.columns.size(), "every visible earth column has exactly one real body")
		for column_index: int in layer.columns.size():
			var body := layer.get_child(column_index) as StaticBody2D
			var shape := body.get_child(0) as CollisionShape2D
			check(body.position == layer.columns[column_index].get_center() and (shape.shape as RectangleShape2D).size == layer.columns[column_index].size and not shape.one_way_collision, "art and solid collision share exact rectangle")
			var query := PhysicsPointQueryParameters2D.new()
			query.position = body.global_position
			query.collision_mask = 1
			var hit := root.world_2d.direct_space_state.intersect_point(query)
			check(hit.any(func(item: Dictionary) -> bool: return item.collider == body), "new earth is present in actual physics space")
		var forged := recorded.duplicate(true)
		forged.ground_supports.append([0, 0, 5000, 5000])
		forged.manifest_hash = generator._manifest_hash(forged)
		check(not generator.validate_manifest(forged, tuning).ok, "rehashed forged support rectangle still rejected")
		forged = recorded.duplicate(true)
		forged.erase("ground_support_version")
		forged.manifest_hash = generator._manifest_hash(forged)
		check(not generator.validate_manifest(forged, tuning).ok, "missing support version rejected instead of silently changing old collision")
		assembler.free()
	check(total >= 12, "generic sample receives actual grounded earth, not empty cosmetic feature")
	print("GROUND SUPPORT COVERAGE: %d solid columns / 12 shared generic samples" % total)
	if "--prove-failure" in OS.get_cmdline_user_args(): check(false, "intentional failure")
	print("PLAINS GROUND SUPPORT: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func texture_sample(rect: Rect2, origin: Vector2, world_point: Vector2) -> Vector2:
	for piece: Dictionary in PlainsTerrainSkin.rock_pieces(rect, origin):
		var dst: Rect2 = piece.destination
		var point := world_point - origin
		if not dst.has_point(point): continue
		var relative := point - dst.position
		if piece.flip.x < 0: relative.x = dst.size.x - relative.x
		if piece.flip.y < 0: relative.y = dst.size.y - relative.y
		return piece.source.position + relative / PlainsTerrainSkin.ROCK_SCALE
	return Vector2.INF

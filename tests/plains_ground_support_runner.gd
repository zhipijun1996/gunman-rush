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
	var modules: Array[PlatformingModule] = [base]
	var bounds := Rect2(0, 0, 300, 300)
	var columns := PlainsGroundSupports.plan(modules, bounds)
	check(columns.size() == 2, "thick ground joins earth; thin sky platform stays floating")
	for column: Rect2 in columns:
		check(column.position.y == 140 and column.end.y == 492, "support continues exact slab underside through stage bottom")
		check(not column.intersects(Rect2(100, 140, 100, 350)), "gap remains open to falling, never bridged")
	base.definition.one_way_platform_indices = [0]
	check(PlainsGroundSupports.plan(modules, bounds).size() == 1, "one-way solidity metadata takes priority over visual thickness")
	base.definition.one_way_platform_indices.clear()
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
	var tuning := PlayerTuning.load_default()
	var generator := RandomStageGenerator.new()
	var total := 0
	for index: int in 12:
		var data := PlainsStageGenerator.new().generate("ground-support-%d" % index, 1 + index % 7, &"combat", tuning)
		check(data.ok, "formal generated map succeeds")
		if not data.ok: continue
		var recorded: Dictionary = JSON.parse_string(JSON.stringify(data.manifest))
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
	check(total >= 12, "formal sample receives actual grounded earth, not empty cosmetic feature")
	print("GROUND SUPPORT COVERAGE: %d solid columns / 12 formal rooms" % total)
	if "--prove-failure" in OS.get_cmdline_user_args(): check(false, "intentional failure")
	print("PLAINS GROUND SUPPORT: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)

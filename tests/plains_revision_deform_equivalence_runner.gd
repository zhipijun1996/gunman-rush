extends SceneTree
## Exact numerical regression against the frozen 2ce4ffa6 test-only oracle.
## The fixture is excluded by the existing tests/* production export filter.
const Oracle = preload("res://tests/fixtures/plains_revision_deform_2ce4ffa6/skin.gd")
const GroundOracle = preload("res://tests/fixtures/plains_revision_deform_2ce4ffa6/ground.gd")
const FloraOracle = preload("res://tests/fixtures/plains_revision_deform_2ce4ffa6/flora.gd")
const KINDS: Array[StringName] = [&"patrol", &"charger", &"hopper", &"sentry", &"fan_sentry", &"root_bell"]
var assertions := 0
var failures := 0
var compared_vertices := 0

class ObservedSkin:
	extends PlainsRevisionSkin
	var observed := PackedVector2Array()
	var contexts: Dictionary = {}
	func _init(behavior: StringName) -> void:
		super(behavior)
	func deform_prepared(point: Vector2, uv: Vector2, pose: PlainsRevisionPose, weights: PlainsRevisionWeights) -> Vector2:
		contexts[pose.get_instance_id()] = true
		var result := super.deform_prepared(point, uv, pose, weights)
		observed.append(result)
		return result

class DrawCanvas:
	extends Node2D
	var rig: ObservedSkin
	var pose: Dictionary = {}
	var draws := 0
	func _draw() -> void:
		draws += 1
		if rig != null: rig.draw_pose(self, pose)

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("PLAINS DEFORM EQUIVALENCE: " + label)

func _base_pose() -> Dictionary:
	return {"clock":.731, "stride":1.17, "travel":.73, "load":.61, "strike":.39, "recovery":.28, "hurt":.41, "turn":-.73, "air":false, "vertical":-173.5, "dead":false, "death":0.0, "drive":-.67, "appendage_follow":.23, "aim":-.31, "landing":0.0, "death_clock":.11}

func _poses() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{}, _base_pose()]
	for airborne: bool in [false, true]:
		for progress: float in [-.1, 0.0, .001, .139999, .14, .159999, .16, .199999, .2, .72, .999, 1.0, 1.1]:
			var value := _base_pose()
			value.merge({"dead":true, "air":airborne, "death":progress, "landing":.23 if progress == .2 else 0.0}, true)
			result.append(value)
	var aged := _base_pose()
	aged.merge({"dead":true, "death":1.0, "death_clock":900.0, "clock":200.0, "stride":100.0}, true)
	result.append(aged)
	return result

func _boundary_poses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in ["clock", "stride", "travel", "load", "strike", "recovery", "hurt", "turn", "vertical", "drive", "appendage_follow", "aim", "landing", "death_clock"]:
		for value: float in [-2.0, 0.0, .5, 1.0, 2.0]:
			var pose := _base_pose()
			pose[key] = value
			# Exercise raw-load+raw-strike against clamped-load+clamped-strike.
			if key == "load": pose.strike = 1.5
			if key == "strike": pose.load = -.5
			if key in ["landing", "death_clock"]: pose.merge({"dead":true, "death":.1, "air":true}, true)
			result.append(pose)
		var missing := _base_pose()
		missing.erase(key)
		result.append(missing)
	return result

func _grid() -> PackedVector2Array:
	var result := PackedVector2Array()
	for y: int in 25:
		for x: int in 25: result.append(Vector2(float(x)/24, float(y)/24))
	return result

func _arbitrary_uvs() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-.2,.3), Vector2(1.2,-.1), Vector2(.391,.229), Vector2(.479,.469), Vector2(.501,.551), Vector2(.699,.319), Vector2(.811,.907), Vector2(394.0/453.0,218.0/376.0), Vector2.ZERO, Vector2.ONE])

func _compare_batch(rig: PlainsRevisionSkin, uvs: PackedVector2Array, pose: Dictionary, offset: Vector2, label: String, public_kernels := false) -> void:
	var oracle := Oracle.new()
	oracle.kind = rig.kind
	oracle.bounds = rig.bounds
	var prepared := PlainsRevisionPose.prepare(pose)
	var actual := PackedVector2Array()
	var direct := PackedVector2Array()
	var expected := PackedVector2Array()
	var standalone := PackedVector2Array()
	var standalone_expected := PackedVector2Array()
	for uv: Vector2 in uvs:
		var point := rig.bounds.position + uv*rig.bounds.size + offset
		actual.append(rig.deform(point, uv, pose))
		direct.append(rig.deform_prepared(point, uv, prepared, PlainsRevisionWeights.new(uv, rig.kind)))
		expected.append(oracle.deform(point, uv, pose))
		if public_kernels:
			if rig.kind in [&"patrol", &"charger", &"hopper"]:
				standalone.append(PlainsRevisionGround.deform(point, uv, rig.bounds.size, pose, rig.kind))
				standalone_expected.append(GroundOracle.deform(point, uv, rig.bounds.size, pose, rig.kind))
			else:
				standalone.append(PlainsRevisionFlora.deform(point, uv, rig.bounds.size, pose, rig.kind))
				standalone_expected.append(FloraOracle.deform(point, uv, rig.bounds.size, pose, rig.kind))
	compared_vertices += uvs.size()
	_check(actual.to_byte_array() == expected.to_byte_array(), label + " standalone Skin is bit-identical to frozen baseline")
	_check(direct.to_byte_array() == expected.to_byte_array(), label + " prepared core is bit-identical to frozen baseline")
	if public_kernels:
		_check(standalone.to_byte_array() == standalone_expected.to_byte_array(), label + " public Ground/Flora is bit-identical to frozen baseline")

func _standalone_cases() -> void:
	var grid := _grid()
	var arbitrary := _arbitrary_uvs()
	for kind: StringName in KINDS:
		var rig := PlainsRevisionSkin.new(kind)
		var original_bounds := rig.bounds
		for size: Vector2 in [original_bounds.size, Vector2(13.125,77.375), Vector2(.125,.375)]:
			rig.bounds = Rect2(Vector2(-size.x*.5,-size.y),size)
			for pose: Dictionary in _poses(): _compare_batch(rig, grid, pose, Vector2.ZERO, String(kind)+"/grid/"+str(size))
			for pose: Dictionary in _boundary_poses(): _compare_batch(rig, arbitrary, pose, Vector2(.127,-.219), String(kind)+"/boundary/"+str(size), true)
		# Invalid-size Flora guards are public API behavior, not mesh policy.
		if kind in [&"sentry", &"fan_sentry", &"root_bell"]:
			for size: Vector2 in [Vector2.ZERO, Vector2(-1,3), Vector2(2,-4), Vector2(INF,3)]:
				for pose: Dictionary in [{}, {"dead":true,"death":.1}]:
					var point := Vector2(1.25,-2.5)
					_check(PlainsRevisionFlora.deform(point,Vector2(.4,.6),size,pose,kind) == FloraOracle.deform(point,Vector2(.4,.6),size,pose,kind), String(kind)+" invalid-size guard")
	# Unknown kinds retain the previous no-anatomy/floor behavior.
	var unknown := PlainsRevisionSkin.new(&"unknown")
	_compare_batch(unknown, arbitrary, {}, Vector2.ZERO, "unknown live", true)
	_compare_batch(unknown, arbitrary, {"dead":true,"death":.1}, Vector2.ZERO, "unknown dead", true)

func _draw_case(canvas: DrawCanvas, pose: Dictionary, expected_count: int, label: String) -> void:
	canvas.rig.observed.clear()
	canvas.rig.contexts.clear()
	canvas.pose = pose
	var before := canvas.draws
	canvas.queue_redraw()
	for _frame: int in 3: await process_frame
	_check(canvas.draws == before+1, label+" invokes the actual draw exactly once")
	_check(canvas.rig.observed.size() == expected_count, label+" preserves all625 vertices or the existing settled cache hit")
	_check(canvas.rig.contexts.size() == (1 if expected_count else 0), label+" parses one pose per actual mesh update")
	if expected_count:
		var oracle := Oracle.new()
		oracle.kind = canvas.rig.kind
		oracle.bounds = canvas.rig.bounds
		var expected := PackedVector2Array()
		var points: PackedVector2Array = canvas.rig.get("_points")
		var units: PackedVector2Array = canvas.rig.get("_units")
		for i: int in points.size(): expected.append(oracle.deform(points[i],units[i],pose))
		compared_vertices += points.size()
		_check(canvas.rig.observed.to_byte_array() == expected.to_byte_array(), label+" actual draw is bit-identical to frozen baseline")

func _draw_cases() -> void:
	for kind: StringName in KINDS:
		var canvas := DrawCanvas.new()
		canvas.position = Vector2(64,96)
		canvas.rig = ObservedSkin.new(kind)
		canvas.pose = _base_pose()
		root.add_child(canvas)
		await _draw_case(canvas, canvas.pose, 625, String(kind)+" live cold draw")
		# Mutate the same Dictionary to rule out identity-based stale pose caches.
		canvas.pose.clock += .37
		canvas.pose.load = -.5
		canvas.pose.strike = 1.5
		await _draw_case(canvas, canvas.pose, 625, String(kind)+" same dictionary mutated")
		var rest := _base_pose()
		rest.merge({"dead":true,"death":1.0,"death_clock":2.0},true)
		await _draw_case(canvas, rest, 625, String(kind)+" rest cold draw")
		rest.death_clock = 90.0
		await _draw_case(canvas, rest, 0, String(kind)+" corpse age cache hit")
		var saved_bounds := canvas.rig.bounds
		canvas.rig.bounds = Rect2(saved_bounds.position+Vector2(.25,.5),saved_bounds.size+Vector2(.5,.25))
		await _draw_case(canvas, rest, 625, String(kind)+" mutable bounds")
		canvas.rig.texture = PlainsRevisionSkin.TEXTURES[&"charger" if kind != &"charger" else &"patrol"]
		await _draw_case(canvas, rest, 625, String(kind)+" mutable texture")
		canvas.rig.kind = &"fan_sentry" if kind != &"fan_sentry" else &"root_bell"
		await _draw_case(canvas, rest, 625, String(kind)+" mutable kind rebuilds UV weights")
		canvas.rig.kind = kind
		canvas.rig.bounds = saved_bounds
		canvas.rig.texture = PlainsRevisionSkin.TEXTURES[kind]
		await _draw_case(canvas, _base_pose(), 625, String(kind)+" restored original bindings")
		canvas.rig = null
		canvas.free()

func _run() -> void:
	_standalone_cases()
	await _draw_cases()
	print("PLAINS DEFORM EQUIVALENCE VERTICES: %d" % compared_vertices)
	print("PLAINS DEFORM EQUIVALENCE: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

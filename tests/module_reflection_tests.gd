extends RefCounted

func run(_tree: SceneTree, check: Callable) -> void:
	var resource_reader = load("res://scripts/generation/random_stage_generator.gd").new()
	for id: String in ["micro_board", "micro_step", "micro_drop", "spike_gap", "saw_gate", "macro_chain", "moving_transfer", "challenge_recoil_climb", "challenge_long_gap", "route_junction"]:
		var source := load("res://resources/generation/modules/%s.tres" % id) as PlatformingModuleDefinition
		check.call(source != null and source.is_valid(), id + " reflection starts from valid authored geometry")
		if source == null:
			continue
		var original := _content(source, resource_reader)
		var original_hash := original.sha256_text()
		var mirrored := ModuleReflection.reflected_definition(source)
		check.call(mirrored != source and mirrored.is_valid() and mirrored.mirrored_horizontal, id + " reflects into an independent valid resource with explicit orientation")
		check.call(_content(source, resource_reader) == original, id + " reflection leaves the complete source resource unchanged")
		var restored := ModuleReflection.reflected_definition(mirrored)
		check.call(_content(restored, resource_reader) == original and _content(restored, resource_reader).sha256_text() == original_hash, id + " double reflection restores exact serialized content and hash")
		check.call(not restored.mirrored_horizontal and restored != source, id + " double reflection restores orientation without sharing source state")
		var axis_sum := source.world_bounds.position.x + source.world_bounds.end.x
		check.call(mirrored.world_bounds == source.world_bounds, id + " reflection keeps authored bounds and gravity coordinates")
		check.call(mirrored.entry_port.direction.x == -source.entry_port.direction.x and mirrored.entry_port.direction.y == source.entry_port.direction.y, id + " entry direction reflects horizontally")
		check.call(mirrored.exit_port.direction.x == -source.exit_port.direction.x and mirrored.exit_port.direction.y == source.exit_port.direction.y, id + " exit direction reflects horizontally")
		for index: int in source.saws.size():
			var original_saw := source.saws[index]
			var reflected_saw := mirrored.saws[index]
			check.call(reflected_saw != original_saw and reflected_saw.radius == original_saw.radius and reflected_saw.period == original_saw.period and reflected_saw.initial_phase == original_saw.initial_phase, id + " saw radius, timing and phase are preserved independently")
			for elapsed: float in [0.0, 0.37, 1.5, 3.2, 8.0]:
				check.call(reflected_saw.at_time(elapsed).is_equal_approx(_point(original_saw.at_time(elapsed), axis_sum)), id + " reflected moving-saw path remains exact at clock %.2f" % elapsed)
		for index: int in source.ferries.size():
			var original_ferry := source.ferries[index]
			var reflected_ferry := mirrored.ferries[index]
			check.call(reflected_ferry != original_ferry and reflected_ferry.size == original_ferry.size and reflected_ferry.period() == original_ferry.period() and reflected_ferry.initial_phase == original_ferry.initial_phase, id + " moving-platform dimensions, timing and phase remain independent")
			for elapsed: float in [0.0, 0.37, 1.5, 3.2, 8.0]:
				check.call(reflected_ferry.at_time(elapsed).is_equal_approx(_point(original_ferry.at_time(elapsed), axis_sum)), id + " moving-platform reflected path remains exact at clock %.2f" % elapsed)
		mirrored.platforms[0].position.x += 1.0
		mirrored.entry_port.position.x += 1.0
		if not mirrored.saws.is_empty():
			mirrored.saws[0].radius += 1.0
		if not mirrored.ferries.is_empty():
			mirrored.ferries[0].size.x += 1.0
		check.call(_content(source, resource_reader).sha256_text() == original_hash and _content(restored, resource_reader).sha256_text() == original_hash, id + " mutating reflected geometry, ports and hazards cannot affect source or sibling")
	_alias_contract(check, resource_reader)
	check.call(ModuleReflection.reflected_definition(null) == null, "null reflection input returns null without constructing partial geometry")

func _alias_contract(check: Callable, resource_reader: RefCounted) -> void:
	var source := load("res://resources/generation/modules/micro_board.tres").duplicate(true) as PlatformingModuleDefinition
	# A nonzero axis catches accidental reflection about x=0 or width alone.
	source.world_bounds = Rect2(-70, -20, 240, 360)
	source.platforms.assign([Rect2(-70, 280, 240, 40)])
	source.anchors.assign([Vector2(-50, 262), Vector2(150, 262)])
	source.entry_port.position = Vector2(-50, 262)
	source.exit_port.position = Vector2(150, 262)
	source.entry_ports.assign([source.entry_port])
	source.exit_ports.assign([source.exit_port])
	check.call(source.is_valid(), "alias fixture supports nonzero bounds origin and active ports shared with arrays")
	var original := _content(source, resource_reader)
	var reflected := ModuleReflection.reflected_definition(source)
	check.call(reflected.is_valid() and reflected.entry_port.position == Vector2(150, 262) and reflected.exit_port.position == Vector2(-50, 262), "reflection uses the actual bounds centre rather than assuming origin zero")
	check.call(reflected.entry_port == reflected.entry_ports[0] and reflected.exit_port == reflected.exit_ports[0], "canonical ports retain their aliases in reflected alternative-port arrays")
	check.call(reflected.entry_ports[0] != source.entry_ports[0] and reflected.exit_ports[0] != source.exit_ports[0], "reflected canonical and alternate ports share no source Resource instances")
	check.call(_content(ModuleReflection.reflected_definition(reflected), resource_reader) == original, "shared active-port aliases reflect exactly once in each direction")
	reflected.entry_ports[0].min_air_shots = 3
	check.call(source.entry_port.min_air_shots == 0 and reflected.entry_port.min_air_shots == 3, "mutating a reflected port alias affects its canonical copy without altering source")

func _content(value: PlatformingModuleDefinition, resource_reader: RefCounted) -> String:
	return JSON.stringify(resource_reader._resource_data(value), "", true)

func _point(value: Vector2, axis_sum: float) -> Vector2:
	return Vector2(axis_sum - value.x, value.y)

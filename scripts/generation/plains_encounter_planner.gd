class_name PlainsEncounterPlanner
extends RefCounted
## Route-owned, replayable encounters; never changes map geometry or player tuning.
const VERSION := "plains-encounters-v1"
const PROFILE := "res://config/plains_encounter_profile.json"

static func plan(stage: GeneratedDemoStage) -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	var enemy_definition := load("res://resources/enemies/patrol_drone.tres") as EnemyDefinition
	var wanted := 0
	if stage.stage_type == &"combat":
		wanted = int(config.combat_counts[0 if stage.stage_index <= 2 else 1 if stage.stage_index <= 4 else 2])
	elif stage.stage_type == &"coin_reward": wanted = int(config.coin_count)
	elif stage.stage_type == &"item_reward": wanted = int(config.item_counts[0 if stage.stage_index <= 3 else 1])
	var seed_text := str(stage.generated.manifest.seed)
	var stream := RunRandomStream.new(seed_text, "encounters", "stage_%s" % stage.stage_index, VERSION)
	var result := {"version": VERSION, "config": config, "seed": seed_text, "stage_index": stage.stage_index, "stage_type": str(stage.stage_type), "requested_count": wanted, "enemies": [], "routes": [], "rejections": {}, "stream_position": 0, "enemy_profile": {"id": str(enemy_definition.stable_id), "version": enemy_definition.definition_version, "patrol_speed": enemy_definition.patrol_speed, "health": enemy_definition.health_definition.max_health, "collision_size": [enemy_definition.collision_size.x, enemy_definition.collision_size.y]}}
	if wanted == 0: return result
	var m: Dictionary = stage.generated.manifest
	var paths: Array = [m.get("common_path", []), m.get("terminal_paths", [[], []])[0], m.get("terminal_paths", [[], []])[1]]
	var quotas: Array = [wanted - 2, 1, 1] if wanted < 6 else [3, 2, wanted - 5]
	var occupied: Array[Rect2] = []
	for route: int in 3:
		var candidates: Array[Dictionary] = []
		for raw_index: Variant in paths[route]:
			var index := int(raw_index)
			var module := stage.assembler.modules[index]
			var route_slot: int = paths[route].find(raw_index)
			if route_slot + 1 < paths[route].size() and stage.assembler.modules[int(paths[route][route_slot + 1])].definition.module_id == &"plains_patrol_meadow":
				_reject(result, "observation_before_patrol")
				continue
			if index < 2 or module.definition.requires_burst or not module.definition.ferries.is_empty() or str(module.definition.module_id).contains("door") or str(module.definition.module_id).contains("fork"):
				_reject(result, "protected_module")
				continue
			for slab: Rect2 in module.definition.platforms:
				if slab.size.x < 180 or slab.size.x < slab.size.y:
					_reject(result, "narrow_platform")
					continue
				for fraction: float in [0.25, 0.5, 0.75]:
					var point := module.to_global(Vector2(slab.position.x + slab.size.x * fraction, slab.position.y - 18))
					var radius := minf(float(config.patrol_radius), slab.size.x * minf(fraction, 1.0 - fraction) - 24)
					if radius < 10: continue
					for aerial: bool in [false, true]:
						var position := point - Vector2(0, float(config.aerial_elevation) if aerial else 0.0)
						var bounds := envelope(position, radius)
						var reason := unsafe_reason(stage, bounds, point, aerial, config)
						if not reason.is_empty():
							_reject(result, reason)
							continue
						candidates.append({"module_index": index, "position": [position.x, position.y], "patrol_radius": radius, "aerial": aerial, "route": route})
		var requested := int(quotas[route])
		var placed := 0
		var module_counts: Dictionary = {}
		# Shuffle only this independent content stream; map/reward draws are untouched.
		while not candidates.is_empty() and placed < requested:
			var preferred: Array[int] = []
			if placed == 0:
				for slot: int in candidates.size():
					if stage.assembler.modules[int(candidates[slot].module_index)].definition.module_id == &"plains_patrol_meadow": preferred.append(slot)
			var chosen := preferred[stream.next_int(preferred.size())] if not preferred.is_empty() else stream.next_int(candidates.size())
			var data: Dictionary = candidates.pop_at(chosen)
			if int(module_counts.get(data.module_index, 0)) >= int(config.max_enemies_per_module): continue
			var bounds := envelope(Vector2(data.position[0], data.position[1]), data.patrol_radius)
			if occupied.any(func(other: Rect2): return other.grow(float(config.enemy_separation)).intersects(bounds)): continue
			data.id = "drone" if result.enemies.is_empty() else "drone_%s" % result.enemies.size()
			result.enemies.append(data)
			occupied.append(bounds)
			module_counts[data.module_index] = int(module_counts.get(data.module_index, 0)) + 1
			placed += 1
		result.routes.append({"route": route, "requested": requested, "placed": placed, "shortfall": requested - placed, "reason": "safe_candidates_exhausted" if placed < requested else ""})
	result.stream_position = stream.position()
	return result

static func envelope(point: Vector2, radius: float) -> Rect2:
	return Rect2(point - Vector2(radius + 20, 30), Vector2(radius * 2 + 40, 54))

static func unsafe_reason(stage: GeneratedDemoStage, volume: Rect2, floor_point: Vector2, aerial: bool, config: Dictionary) -> String:
	if floor_point.distance_to(stage.spawn) < float(config.spawn_clearance): return "spawn"
	for terminal: Dictionary in stage.generated.manifest.terminal_exits:
		var exit := Vector2(terminal.position[0], terminal.position[1])
		if floor_point.distance_to(exit) < float(config.exit_clearance): return "exit"
	if volume.grow(45).has_point(stage.supply_position): return "supply"
	for anchor: Vector2 in stage.anchors:
		if volume.grow(float(config.anchor_clearance)).has_point(anchor): return "anchor"
	for danger: Rect2 in stage.assembler.world_dangers():
		if volume.intersects(danger.grow(float(config.danger_margin))): return "danger"
	for module: PlatformingModule in stage.assembler.modules:
		for ferry: ModuleMovingPlatformDefinition in module.definition.ferries:
			var ferry_box := ferry.envelope()
			if volume.intersects(Rect2(module.to_global(ferry_box.position), ferry_box.size).grow(20)): return "ferry"
		for platform: Rect2 in module.definition.platforms:
			var solid := Rect2(module.to_global(platform.position), platform.size)
			# Ground actor envelope extends six pixels below its feet conservatively.
			var body := Rect2(volume.position, Vector2(volume.size.x, 44)) if not aerial else volume
			if body.intersects(solid): return "terrain"
	for column: Array in stage.generated.manifest.get("ground_supports", []):
		if volume.intersects(Rect2(column[0], column[1], column[2], column[3])): return "support"
	return ""

static func _reject(result: Dictionary, reason: String) -> void:
	result.rejections[reason] = int(result.rejections.get(reason, 0)) + 1

static func recorded_plan(manifest: Dictionary) -> Dictionary:
	# Detached data-only scene graph: no ready(), actors, rendering or physics.
	var stage := GeneratedDemoStage.new()
	stage.stage_index = int(manifest.stage_index)
	stage.stage_type = StringName(manifest.stage_type)
	stage.generated = {"manifest": manifest}
	stage.assembler = RandomStageAssembler.new()
	stage.add_child(stage.assembler)
	var generator := RandomStageGenerator.new()
	for data: Dictionary in manifest.nodes:
		var module := PlatformingModule.new()
		module.definition = generator.definition_for(data.module_id, data.mirrored, data.reverse_traversal)
		module.position = Vector2(data.offset[0], data.offset[1])
		stage.assembler.add_child(module)
		stage.assembler.modules.append(module)
	stage.spawn = stage.assembler.world_entry()
	stage.anchors = stage.assembler.world_anchors()
	stage.supply_position = stage.anchors[mini(1, stage.anchors.size() - 1)]
	var result := plan(stage)
	stage.free()
	return result

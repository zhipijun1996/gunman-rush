class_name PlainsEncounterPlanner
extends RefCounted
## Route-owned, replayable encounters; never changes map geometry or player tuning.
const VERSION := "plains-encounters-v5-grammar-recovery"
const PROFILE := "res://config/plains_encounter_profile.json"

static func plan(stage: GeneratedDemoStage) -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	var wanted := 0
	if stage.stage_type == &"combat":
		wanted = int(config.combat_counts[0 if stage.stage_index <= 2 else 1 if stage.stage_index <= 4 else 2])
	elif stage.stage_type == &"coin_reward": wanted = int(config.coin_count)
	elif stage.stage_type == &"item_reward": wanted = int(config.item_counts[0 if stage.stage_index <= 3 else 1])
	if stage.stage_index == 7: wanted = 0
	if stage.stage_index == 1: wanted = mini(wanted, 2)
	var seed_text := str(stage.generated.manifest.seed)
	var stream := RunRandomStream.new(seed_text, "encounters", "stage_%s" % stage.stage_index, VERSION)
	var result := {"version": VERSION, "config": config, "seed": seed_text, "stage_index": stage.stage_index, "stage_type": str(stage.stage_type), "requested_count": wanted, "enemies": [], "routes": [], "rejections": {}, "stream_position": 0, "enemy_profiles": behavior_profiles(), "dodge_contract": {"movement_envelope": stage.generated.manifest.get("movement_envelope", {}).duplicate(true), "player_half_size": [12, 18], "danger_margin": config.danger_margin}}
	if wanted == 0: return result
	var m: Dictionary = stage.generated.manifest
	var protected_nodes: Array = []
	for segment: Dictionary in m.get("room_grammar", {}).get("segments", []):
		for beat: Dictionary in segment.beats:
			if beat.role in ["observation", "recovery"]: protected_nodes.append(int(beat.node))
	var paths: Array = [m.get("common_path", []), m.get("terminal_paths", [[], []])[0], m.get("terminal_paths", [[], []])[1]]
	var quotas: Array = [wanted, 0, 0] if wanted <= 2 else [wanted - 2, 1, 1] if wanted < 6 else [3, 2, wanted - 5]
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
			if index in protected_nodes:
				_reject(result, "grammar_observation_or_recovery")
				continue
			if index < 2 or module.definition.requires_burst or not module.definition.ferries.is_empty() or str(module.definition.module_id).contains("door") or str(module.definition.module_id).contains("fork") or str(module.definition.module_id).begins_with("plains_windchime_"):
				_reject(result, "protected_module")
				continue
			for slab: Rect2 in module.definition.platforms:
				if slab.size.x < 180 or slab.size.x < slab.size.y:
					_reject(result, "narrow_platform")
					continue
				for fraction: float in [0.25, 0.5, 0.75]:
					var point := module.to_global(Vector2(slab.position.x + slab.size.x * fraction, slab.position.y - 18))
					for behavior_id: String in ["charger", "sentry", "diver"]:
						var aerial := behavior_id == "diver"
						var radius := float(config.charger_radius) if behavior_id == "charger" else float(config.patrol_radius) if aerial else 0.0
						if slab.size.x * minf(fraction, 1.0 - fraction) - 24 < radius:
							_reject(result, "attack_leash_width")
							continue
						var position := point - Vector2(0, float(config.aerial_elevation) if aerial else 0.0)
						var bounds := envelope(position, radius, aerial)
						var reason := unsafe_reason(stage, bounds, point, aerial, config)
						if not reason.is_empty():
							_reject(result, reason)
							continue
						candidates.append({"module_index": index, "position": [position.x, position.y], "patrol_radius": radius, "aerial": aerial, "route": route, "behavior_id": behavior_id})

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
			var bounds := envelope(Vector2(data.position[0], data.position[1]), data.patrol_radius, bool(data.aerial))
			if occupied.any(func(other: Rect2): return other.grow(float(config.enemy_separation)).intersects(bounds)): continue
			var attack_definition := definition_for_behavior(str(data.behavior_id))
			data.attack_limits = {"body_envelope": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "leash_radius": data.patrol_radius, "protected_radius": attack_definition.protected_radius, "projectile_range": attack_definition.projectile_speed * attack_definition.projectile_lifetime if data.behavior_id == "sentry" else 0}
			if not bool(data.aerial):
				var dodge := ground_dodge_envelope(stage, Vector2(data.position[0], data.position[1]), float(data.patrol_radius))
				data.attack_limits.dodge_envelope = [dodge.position.x, dodge.position.y, dodge.size.x, dodge.size.y]
			data.id = "drone" if result.enemies.is_empty() else "drone_%s" % result.enemies.size()
			result.enemies.append(data)
			occupied.append(bounds)
			module_counts[data.module_index] = int(module_counts.get(data.module_index, 0)) + 1
			placed += 1
		result.routes.append({"route": route, "requested": requested, "placed": placed, "shortfall": requested - placed, "reason": "safe_candidates_exhausted" if placed < requested else ""})
	result.stream_position = stream.position()
	return result

static func envelope(point: Vector2, radius: float, aerial: bool = false) -> Rect2:
	return Rect2(point - Vector2(radius + 20, 30), Vector2(radius * 2 + 40, 54 + definition_for_behavior("diver").dive_depth if aerial else 54))

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
	if not aerial:
		return ground_dodge_reason(stage, floor_point, maxf(0.0, (volume.size.x - 40.0) * 0.5), config)
	return ""

static func ground_dodge_envelope(stage: GeneratedDemoStage, point: Vector2, radius: float) -> Rect2:
	# Use the recorded capability, including for detached replay; never live/default tuning.
	# Player rectangle is 24x36 in scenes/player/player.tscn. Half a full jump
	# on each side reserves takeoff as well as crossing the enemy leash.
	var capability: Dictionary = stage.generated.manifest.get("movement_envelope", {})
	var half_width := radius + 12.0 + float(capability.get("held_jump_range", 0.0)) * 0.5
	var height := float(capability.get("held_jump_height", 0.0)) + 36.0
	return Rect2(point + Vector2(-half_width, 18.0 - height), Vector2(half_width * 2.0, height))

static func ground_dodge_reason(stage: GeneratedDemoStage, point: Vector2, radius: float, config: Dictionary) -> String:
	var capability: Dictionary = stage.generated.manifest.get("movement_envelope", {})
	if not capability.has("held_jump_height") or not capability.has("held_jump_range"):
		return "dodge_capability_missing"
	var dodge := ground_dodge_envelope(stage, point, radius)
	for danger: Rect2 in stage.assembler.world_dangers():
		if dodge.intersects(danger.grow(float(config.danger_margin))): return "dodge_hazard"
	for module: PlatformingModule in stage.assembler.modules:
		for platform: Rect2 in module.definition.platforms:
			# The supporting floor touches the rectangle bottom; touching is not overlap.
			if dodge.intersects(Rect2(module.to_global(platform.position), platform.size)): return "dodge_terrain"
		for ferry: ModuleMovingPlatformDefinition in module.definition.ferries:
			var bounds := ferry.envelope()
			if dodge.intersects(Rect2(module.to_global(bounds.position), bounds.size).grow(20)): return "dodge_ferry"
	for column: Array in stage.generated.manifest.get("ground_supports", []):
		if dodge.intersects(Rect2(column[0], column[1], column[2], column[3])): return "dodge_support"
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

static func definition_for_behavior(id: String) -> EnemyDefinition:
	if id not in ["charger", "diver", "sentry", "fan_sentry", "hopper", "root_bell"]: return null
	return load("res://resources/enemies/plains_%s.tres" % id) as EnemyDefinition

static func behavior_profiles() -> Dictionary:
	var result := {}
	for id: String in ["charger", "diver", "sentry"]:
		var definition := definition_for_behavior(id)
		result[id] = {"definition_version": definition.definition_version, "health": definition.health_definition.max_health, "collision_size": [definition.collision_size.x, definition.collision_size.y], "protected_radius": definition.protected_radius, "patrol_speed": definition.patrol_speed, "telegraph": definition.telegraph_duration, "attack_duration": definition.attack_duration, "attack_speed": definition.attack_speed, "recovery": definition.recovery_duration, "return_speed": definition.return_speed, "activation_range": definition.activation_range, "dive_depth": definition.dive_depth, "projectile_speed": definition.projectile_speed, "projectile_lifetime": definition.projectile_lifetime}
	return result

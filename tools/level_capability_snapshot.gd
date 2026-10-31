extends RefCounted
## Read-only audit sidecar. Does not change RunManifest or grant capabilities.
const SCHEMA_VERSION := 2

static func tuning_values(tuning: PlayerTuning) -> Dictionary:
	var keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
	var result: Dictionary = {}
	for key: String in keys:
		result[key] = tuning.get(key)
	return result

static func matches_tuning(actor: Node, requested: PlayerTuning) -> bool:
	return requested != null and is_instance_valid(actor) and FoundryCatalog.same(tuning_values(actor.motor.tuning), tuning_values(requested))

static func capture(actor: Node, build: RefCounted = null, scope: String = "runtime_observation") -> Dictionary:
	if not is_instance_valid(actor): return {}
	var weapon: Variant = actor.shoot_ability.weapon
	var runtime: Variant = actor.shoot_ability.runtime # Avoid behavior(): it lazily creates state.
	var granted: Array[String] = []
	if actor.jump_ability.enabled and actor.jump_ability.maximum_jumps() > 0: granted.append("jump")
	if actor.shoot_ability.enabled: granted.append("shot_recoil")
	if actor.traversal.double_enabled: granted.append("double_jump")
	if actor.traversal.wall_enabled: granted.append("wall_climb")
	if actor.traversal.hook_enabled: granted.append("grapple")
	var energy: Dictionary = {"enabled": actor.shot_energy != null, "current": actor.actor_resources.stamina.current, "capacity": actor.actor_resources.stamina.capacity}
	if actor.shot_energy != null:
		for key: String in ["shot_energy_cost", "hit_energy_recovery", "ground_energy_recovery", "shot_energy_delay", "_delay"]:
			energy[key] = actor.shot_energy.get(key)
	var energy_path: String = actor.shot_energy.definition.resource_path if actor.shot_energy != null else ""
	if actor.shot_energy != null:
		energy["definition_path"] = energy_path
		energy["definition_sha256"] = FileAccess.get_sha256(energy_path)
		energy["definition_version"] = actor.shot_energy.definition.definition_version
		energy["shooting_consumes_energy"] = actor.shot_energy.definition.shooting_consumes_energy
	var items: Array = []
	var sources: Dictionary = {}
	if build != null:
		items.assign(build.item_ids())
		for id: StringName in build._sources: sources[str(id)] = str(build._sources[id].stable_id)
	return {"schema_version": SCHEMA_VERSION, "scope": scope,
		"granted_actions": granted, "implemented_independent_actions": ["double_jump", "wall_climb", "grapple"],
		"available_weapons_scope": "equipped_only_no_unlock_inference",
		"equipped_weapon": {"id": str(weapon.id), "tier": weapon.tier, "branch": str(weapon.branch), "mode": weapon.mode, "rounds": weapon.rounds, "interval": weapon.interval, "burst_duration": weapon.burst_duration, "recoil_scale": weapon.recoil_scale, "skill_name": weapon.skill_name, "definition_path": weapon.resource_path, "definition_sha256": FileAccess.get_sha256(weapon.resource_path)},
		"equipment_capacity": {"status": "single_current_weapon", "inventory_capacity": "unimplemented"},
		"tuning": tuning_values(actor.motor.tuning), "effective_max_jumps": actor.jump_ability.maximum_jumps(),
		"used_jumps": actor.jump_ability.used_jumps, "air_shots": actor.action_resources.shot_charges,
		"air_shot_flight_cap": actor.action_resources._flight_cap, "hook_used": actor.traversal.hook_used,
		"wall_ready": actor.traversal.wall_ready, "traversal_state": str(actor.traversal.state),
		"shot_energy": energy, "combat_energy": {"current": actor.combat_energy.current, "capacity": actor.combat_energy.definition.capacity, "skill_cost": weapon.skill_cost if weapon.tier == 3 else 0.0},
		"shot_cooldown": actor.shoot_ability.cooldown_remaining,
		"skill_cooldown": runtime.skill_cooldown if runtime != null else 0.0,
		"weapon_phase": str(runtime.phase) if runtime != null else "uninitialized",
		"build": {"items": items, "sources": sources, "status": "captured" if build != null else "no_build_consumer"},
		"position": pair(actor.motor.global_position), "velocity": pair(actor.motor.velocity),
		"normal_velocity": pair(actor.motor.normal_velocity), "recoil_velocity": pair(actor.motor.recoil_velocity),
		"grounded": actor.motor.is_on_floor(), "active": actor.active, "session_id": actor.session_id,
		"physics_hz": Engine.physics_ticks_per_second,
		"config_hashes": {"player_tuning": FileAccess.get_sha256("res://config/player_tuning.json"), "input_profile": FileAccess.get_sha256("res://config/input_profile.json"), "shot_energy": FileAccess.get_sha256(energy_path) if not energy_path.is_empty() else "", "traversal": FileAccess.get_sha256("res://resources/player/traversal.tres"), "weapon_motion": FileAccess.get_sha256("res://resources/weapons/motion.tres")}}

static func pair(value: Vector2) -> Array:
	return [value.x, value.y]

extends RefCounted
## Read-only projection into the addon protocol; never grants an ability.
## The conformance profile is selected by the caller, not inferred from seed.
const MAX_EXACT_SEED: int = 9007199254740991

static func from_controller(controller: PlayerController, motor: PlayerMotor, seed: int, template: Dictionary, nominal_weapon_motion: bool = false) -> Dictionary:
	if seed < -MAX_EXACT_SEED or seed > MAX_EXACT_SEED:
		return _failure("seed must be an integer within +/- (2^53 - 1)")
	if not is_instance_valid(controller) or not is_instance_valid(motor) or controller.motor != motor:
		return _failure("controller and motor must be the same configured player")
	var tuning: PlayerTuning = motor.tuning
	var jump: JumpAbility = controller.jump_ability
	var shoot: ShootAbility = controller.shoot_ability
	var actions: ActionResources = controller.action_resources
	var recoil: RecoilAbility = controller.recoil_ability
	if tuning == null or jump == null or shoot == null or actions == null or recoil == null or controller.traversal == null:
		return _failure("player abilities/tuning are not configured")
	if jump.tuning != tuning or shoot.tuning != tuning or actions.tuning != tuning or shoot.resources != actions or shoot.recoil != recoil or recoil.motor != motor or shoot.controller != controller:
		return _failure("player ability bindings do not share the actual motor/tuning/resources")
	if controller.actor_resources == null or controller.actor_resources.health == null or controller.actor_resources.stamina == null:
		return _failure("player actor resources are not configured")
	var weapon: WeaponDefinition = shoot.weapon
	if weapon == null or not weapon.is_valid():
		return _failure("actual equipped weapon is missing or invalid")
	if controller.shot_energy != null and (controller.shot_energy.definition == null or controller.shot_energy.controller != controller):
		return _failure("shot energy policy is not bound to this player")
	if template.get("schema", "") != "mapgen/generation-request/v1" or not template.get("player") is Dictionary:
		return _failure("template must be a generation-request/v1 with a player object")
	var collision: Dictionary = _collision(motor)
	if not collision.ok:
		return _failure(str(collision.error))
	var maximum: int = jump.maximum_jumps()
	var abilities: Array[String] = []
	if jump.enabled and maximum > 0:
		abilities.append("jump")
		if maximum > 1:
			abilities.append("double_jump")
	# These primaries use RecoilAbility. Other weapons have different movement
	# (blink/beam/hold), which the addon's single recoil tag cannot describe.
	var recoil_primary: bool = weapon.mode in [WeaponDefinition.Mode.PULSE, WeaponDefinition.Mode.MACHINE, WeaponDefinition.Mode.BOMB, WeaponDefinition.Mode.MINE]
	var recoil_positive: bool = (tuning.recoil_mode == "shot_burst" and tuning.shot_burst_speed > 0.0 and tuning.shot_burst_duration > 0.0) or (tuning.recoil_mode == "legacy_impulse" and tuning.recoil_impulse > 0.0)
	var energy_ready: bool = controller.shot_energy == null or controller.shot_energy.can_fire()
	var energy_capacity: bool = controller.shot_energy == null or not controller.shot_energy.definition.shooting_consumes_energy or controller.actor_resources.stamina.capacity + 1.0e-9 >= controller.shot_energy.shot_energy_cost
	var reverse_blink := nominal_weapon_motion and weapon.mode==WeaponDefinition.Mode.SHURIKEN and motor.weapon_motion!=null and motor.weapon_motion.base_distance(tuning,false)>0
	var shot_recoil: bool = shoot.enabled and recoil.enabled and ((recoil_primary and recoil_positive) or reverse_blink) and tuning.max_air_shots > 0 and energy_capacity
	if shot_recoil:
		abilities.append("shot_recoil")
	if controller.traversal.hook_enabled:
		abilities.append("grapple")
	var gaps: Array[String] = ["Addon ability tags do not prove physical reachability or model weapon-specific distance/timing.", "Ability tags express nominal enabled capacity, not remaining actions/energy in this flight; current availability is separate in this snapshot.", "Cooldown, active packets, traversal state and current aim are recorded, not simulated."]
	if reverse_blink:
		gaps.append("Formal Plains projects the actual finite reverse blink into the SDK nominal recoil tag; geometry and every weapon route still need real movement validation.")
	elif not recoil_primary:
		gaps.append("This weapon's blink/beam/hold movement is not mapped to shot_recoil.")
	var equipment: Dictionary = {}
	var items: ItemRuntime = controller.item_runtime as ItemRuntime
	if items != null and items.build() != null and items.build().equipment != null:
		equipment = items.build().equipment.snapshot().duplicate(true)
		equipment["modifier_sources"] = items.build().manifest_item_sources().duplicate(true)
	else:
		gaps.append("No bound ItemRuntime/BuildState equipment snapshot is available; effective tuning is still read from the live motor.")
	var energy: Dictionary = {"policy_present": controller.shot_energy != null, "can_fire": energy_ready, "nominal_shot_capacity_sufficient": energy_capacity, "stamina_current": controller.actor_resources.stamina.current, "stamina_capacity": controller.actor_resources.stamina.capacity, "combat_energy": controller.combat_energy.current}
	if controller.shot_energy != null:
		energy.merge({"definition": _resource_values(controller.shot_energy.definition), "shot_energy_cost": controller.shot_energy.shot_energy_cost, "hit_energy_recovery": controller.shot_energy.hit_energy_recovery, "ground_energy_recovery": controller.shot_energy.ground_energy_recovery, "recovery_delay": controller.shot_energy.shot_energy_delay})
	var snapshot: Dictionary = {
		"profile": "live_controller", "seed": seed, "active": controller.active, "health_terminal": controller.actor_resources.health.terminal,
		"abilities": {"jump_enabled": jump.enabled, "maximum_jumps": maximum, "capacity_floor": jump.capacity_floor, "used_jumps": jump.used_jumps, "can_air_jump": jump.can_air_jump(), "shoot_enabled": shoot.enabled, "recoil_enabled": recoil.enabled, "hook_enabled": controller.traversal.hook_enabled, "double_grant": controller.traversal.double_enabled, "wall_enabled": controller.traversal.wall_enabled},
		"tuning": _resource_values(tuning), "weapon": _resource_values(weapon), "weapon_motion": _resource_values(motor.weapon_motion),
		"resources": {"shot_charges": actions.shot_charges, "pending_ground_shots": actions.pending_ground_shots, "energy": energy},
		"transient": {"cooldown_remaining": shoot.cooldown_remaining, "rounds_remaining": shoot.rounds_remaining, "traversal_state": String(controller.traversal.state), "hook_used": controller.traversal.hook_used},
		"traversal_definition": _resource_values(controller.traversal.definition), "collision": collision, "equipment": equipment, "request_abilities": abilities.duplicate(), "gaps": gaps
	}
	var request: Dictionary = template.duplicate(true)
	request.seed = seed
	request.player = {"abilities": abilities, "clearance_half_extents_pixels": collision.half_extents_pixels.duplicate()}
	return {"ok": true, "error": "", "request": request, "snapshot": snapshot}

static func _collision(motor: PlayerMotor) -> Dictionary:
	var collider: CollisionShape2D = null
	for child: Node in motor.get_children():
		if child is CollisionPolygon2D and not child.disabled:
			return {"ok": false, "error": "polygon collider cannot be projected as the player's rectangle"}
		if child is CollisionShape2D and not child.disabled:
			if collider != null:
				return {"ok": false, "error": "multiple enabled player shapes are ambiguous"}
			collider = child as CollisionShape2D
	if collider == null or not collider.shape is RectangleShape2D:
		return {"ok": false, "error": "one enabled RectangleShape2D is required"}
	var rectangle: RectangleShape2D = collider.shape as RectangleShape2D
	var basis: Transform2D = collider.global_transform
	var local_half: Vector2 = rectangle.size * 0.5
	var offset: Vector2 = basis.origin - motor.global_position
	# World-axis conservative half extents include scale, rotation and offset.
	var half: Vector2 = basis.x.abs() * local_half.x + basis.y.abs() * local_half.y + offset.abs()
	if not rectangle.size.is_finite() or rectangle.size.x <= 0.0 or rectangle.size.y <= 0.0 or not half.is_finite() or half.x <= 0.0 or half.y <= 0.0 or absf(basis.determinant()) <= 1.0e-12:
		return {"ok": false, "error": "player collision dimensions/transform are invalid"}
	return {"ok": true, "error": "", "shape_size": [rectangle.size.x, rectangle.size.y], "basis_x": [basis.x.x, basis.x.y], "basis_y": [basis.y.x, basis.y.y], "offset_pixels": [offset.x, offset.y], "half_extents_pixels": [half.x, half.y]}

static func _resource_values(source: Resource) -> Dictionary:
	var result: Dictionary = {}
	if source == null:
		return result
	# Introspect existing script properties rather than maintain parallel tuning.
	for property: Dictionary in source.get_property_list():
		var key: String = str(property.name)
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or key.begins_with("_"):
			continue
		var value: Variant = source.get(key)
		if value is Array or value is Dictionary:
			result[key] = value.duplicate(true)
		elif typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
			result[key] = String(value) if value is StringName else value
	return result

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "request": {}, "snapshot": {}}

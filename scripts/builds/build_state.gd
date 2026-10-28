class_name BuildState
extends RefCounted

signal changed
var controller: PlayerController
var inventory: RunInventory
var equipment: EquipmentService
var _base: Dictionary = {}
var _sources: Dictionary = {}
var _revision := 0
var _applying := false
var _applied_effect_signature := "[]"
const STATS: Array[StringName] = [&"max_jumps", &"max_air_shots", &"projectile_damage", &"shot_burst_speed", &"recoil_impulse", &"max_health", &"ground_recoil_multiplier", &"ground_deceleration", &"shot_cooldown", &"focus_stamina_drain", &"focus_stamina_recovery", &"focus_rearm_stamina", &"coyote_time"]
const ENERGY_STATS: Array[StringName] = [&"shot_energy_cost",&"hit_energy_recovery", &"ground_energy_recovery", &"shot_energy_delay"]

func configure(player: PlayerController, scope: DemoLifetime = null, run_namespace: StringName = &"") -> void:
	controller = player
	inventory = RunInventory.new(run_namespace)
	equipment = EquipmentService.new()
	equipment.configure(self,scope,inventory)
	_sources.clear()
	_applied_effect_signature = "[]"
	_base.clear()
	for stat: StringName in STATS:
		_base[stat] = controller.actor_resources.health.capacity if stat == &"max_health" else controller.motor.tuning.get(stat)
	if controller.shot_energy!=null and controller.shot_energy.definition.shooting_consumes_energy:
		for stat: StringName in ENERGY_STATS: _base[stat]=controller.shot_energy.get(stat)

# Compatibility facade for existing reward/catalog consumers. Ownership is held
# exclusively by RunInventory; obtaining an item never mutates actor attributes.
func owned_items() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for instance: RunItemInstance in inventory.instances(): result.append(instance.item)
	return result

func count_item(id: StringName) -> int:
	return inventory.count_item(id)

func inventory_items() -> Array[RunItemInstance]:
	return inventory.instances()

func item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var ids: Array = _sources.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids: result.append((_sources[id] as ItemDefinition).stable_id)
	return result

# Map-content reconstruction metadata only, not an inventory/ability save file.
# Preserve actual instance ordering: it breaks equal-priority override ties.
func manifest_item_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if inventory == null: return result
	var ids: Array = _sources.keys()
	ids.sort_custom(func(a: StringName,b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		var owned := inventory.get_instance(id)
		if owned == null: return []
		var item := owned.item
		result.append({"instance_id":String(id),"definition_id":String(item.stable_id),"definition_version":item.definition_version,"catalog_version":item.catalog_version,"fingerprint":item.fingerprint(),"level":owned.level,"broken":bool(owned.effect_state.get("broken",false)),"source_id":String(owned.source_id),"origin":String(owned.origin),"gear_cost":item.gear_cost})
	return result

func can_add(item: ItemDefinition) -> bool:
	return not _applying and is_instance_valid(controller) and controller.active and not controller.actor_resources.health.terminal and inventory.can_add(item)

func add_item(source_id: StringName, item: ItemDefinition, origin: StringName = &"pickup") -> bool:
	if _applying or not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal: return false
	var savepoint := inventory._transaction_snapshot()
	if not inventory.add_item(source_id,item,origin): return false
	if refresh_equipped(): return true
	inventory._restore_transaction(savepoint)
	return false

# Explicit transaction boundary for a successful owned upgrade or a changed
# broken flag. Inventory.changed remains presentation-only and deferred.
func refresh_equipped() -> bool:
	if _applying or not is_instance_valid(controller) or controller.actor_resources.health.terminal: return false
	var sources: Dictionary = {}
	for id: StringName in equipment.equipped_ids():
		var owned := inventory.get_instance(id)
		if owned == null: return false
		sources[id] = owned.item
	if _effect_signature(sources) == _applied_effect_signature: return true
	if not validate_sources(sources).is_empty() or not _commit(sources): return false
	equipment._owned_effects_changed()
	return true

# An old source ID can still identify a loadout member, but removal requires the
# same live editing session as every other equipment operation. Ownership remains.
func remove_source(source_id: StringName, token: DemoToken = null, session: int = -1, expected_revision: int = -1) -> bool:
	var instance := inventory.instance_for_source(source_id)
	var id := instance.instance_id if instance != null else source_id
	var ids := equipment.equipped_ids()
	if id not in ids: return false
	ids.erase(id)
	return equipment.submit(ids,token,session,expected_revision).accepted

func validate_sources(proposed: Dictionary) -> StringName:
	if _applying or not is_instance_valid(controller): return &"invalid_context"
	for source: StringName in proposed:
		var item: ItemDefinition = proposed[source]
		if item == null or not item.is_valid(): return &"invalid_item"
		for modifier: BuildModifier in _modifiers_for(source,item):
			if not _base.has(modifier.stat_id): return &"unsupported_effect"
	return &"" if _valid_values(_resolve(proposed)) else &"invalid_stats"

func _replace_equipped_sources(proposed: Dictionary) -> bool:
	return validate_sources(proposed).is_empty() and _commit(proposed)

func effect_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = _sources.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		var item: ItemDefinition = _sources[id]
		var owned := inventory.get_instance(id)
		if owned != null and bool(owned.effect_state.get("broken",false)): continue
		var level := owned.level if owned != null else 1
		var parameters := item.parameters_for_level(level)
		var modifiers: Array[BuildModifier] = _modifiers_for(id,item) if item.catalog_version >= 5 else item.duplicate(true).modifiers
		if not modifiers.is_empty():
			result.append({"source_id":StringName("%s/stats" % id),"instance_id":id,"definition_id":item.stable_id,"definition_version":item.definition_version,"effect_id":&"stats","channel":ItemEffectComponent.Channel.PASSIVE,"modifiers":modifiers,"level":level,"parameters":parameters.duplicate(true)})
		for component: ItemEffectComponent in item.effect_components:
			result.append({"source_id":StringName("%s/%s" % [id,component.effect_id]),"instance_id":id,"definition_id":item.stable_id,"definition_version":item.definition_version,"effect_id":component.effect_id,"channel":component.channel,"component":component.duplicate(true),"level":level,"parameters":parameters.duplicate(true),"effect_state":owned.effect_state.duplicate(true) if owned != null else {}})
	return result

func clear() -> bool:
	# HealthState emits synchronously during commit; cleanup must not partially
	# reset ownership while that commit still owns the actor transaction.
	if _applying: return false
	equipment.reset()
	inventory.clear()
	if is_instance_valid(controller) and controller.actor_resources.health.terminal:
		# RunEnd discards the terminal actor; do not mutate/revive its HealthState.
		_sources.clear()
		_applied_effect_signature = "[]"
		for stat: StringName in _base:
			if stat != &"max_health":
				if stat in ENERGY_STATS: controller.shot_energy.set(stat,_base[stat])
				else: controller.motor.tuning.set(stat, _base[stat])
		call_deferred("_emit_changed")
		return true
	return _commit({})

func _resolve(sources: Dictionary) -> Dictionary:
	var modifiers: Dictionary = {}
	for source: StringName in sources: modifiers[source] = _modifiers_for(source,sources[source])
	return resolve_modifier_sources(_base,modifiers)

# Shared deterministic arithmetic for the live actor and content Manifest.
static func resolve_modifier_sources(base: Dictionary, modifiers: Dictionary) -> Dictionary:
	var values := base.duplicate()
	var keys: Array = modifiers.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for stat: StringName in base:
		var best_priority := -2147483648
		var value: float = float(base[stat])
		# Stable source order: later lexical ID wins equal-priority override.
		for source: StringName in keys:
			for modifier: BuildModifier in modifiers[source]:
				if modifier.stat_id == stat and modifier.operation == BuildModifier.Operation.OVERRIDE and modifier.priority >= best_priority:
					best_priority = modifier.priority
					value = modifier.value
		for operation: int in [BuildModifier.Operation.ADD, BuildModifier.Operation.MULTIPLY]:
			for source: StringName in keys:
				for modifier: BuildModifier in modifiers[source]:
					if modifier.stat_id == stat and modifier.operation == operation:
						value = value + modifier.value if operation == BuildModifier.Operation.ADD else value * modifier.value
		values[stat] = value
	return values

func _valid_values(values: Dictionary) -> bool:
	for stat: StringName in _base:
		var value: float = values[stat]
		if stat==&"shot_energy_cost" and value>controller.actor_resources.stamina.capacity: return false
		if stat==&"focus_rearm_stamina" and value>controller.motor.tuning.focus_stamina_capacity: return false
		if not is_finite(value) or value < 0.0:
			return false
		if stat in [&"max_jumps", &"max_air_shots"] and value != floor(value):
			return false
		if stat not in [&"max_jumps", &"max_air_shots", &"focus_stamina_recovery", &"focus_rearm_stamina"] and value <= 0.0:
			return false
	return true

func _commit(proposed: Dictionary) -> bool:
	if _applying or not is_instance_valid(controller):
		return false
	var values := _resolve(proposed)
	if not _valid_values(values):
		return false
	var health := controller.actor_resources.health
	var first_contract: StringName = &""
	var contract_equipped := false
	for id: StringName in proposed:
		var owned := inventory.get_instance(id)
		var item: ItemDefinition = proposed[id]
		var parameters := item.parameters_for_level(owned.level if owned != null else 1)
		if item.catalog_version >= 5 and bool(parameters.get("first_equip_current_hp_ratio_convert",false)):
			contract_equipped = true
			if owned != null and not bool(owned.effect_state.get("first_equip_ratio_applied",false)): first_contract = id
	_applying = true
	var previous_heal_block := health.normal_healing_blocked
	health.normal_healing_blocked = contract_equipped
	if not is_equal_approx(health.capacity, values[&"max_health"]):
		if health.terminal:
			health.normal_healing_blocked = previous_heal_block
			_applying = false
			return false
		_revision += 1
		var request := ActorResourceRequest.new(StringName("build_max_%s_%s" % [get_instance_id(), _revision]), health.epoch, values[&"max_health"], health.get_instance_id())
		var result: ActorResourceResult = health.set_max_preserving_ratio(request) if not first_contract.is_empty() else health.set_max(request)
		if not result.accepted():
			health.normal_healing_blocked = previous_heal_block
			_applying = false
			return false
	if not first_contract.is_empty():
		# A single persistent receipt ties the exceptional proportional conversion
		# to the same instance; ordinary HP upgrades never use this operation.
		inventory.patch_effect_state(first_contract,{"locked":true,"first_equip_ratio_applied":true},&"p18_first_equip")
	for stat: StringName in _base:
		if stat != &"max_health":
			if stat in ENERGY_STATS: controller.shot_energy.set(stat,values[stat])
			else: controller.motor.tuning.set(stat, int(values[stat]) if stat in [&"max_jumps", &"max_air_shots"] else values[stat])
	# Do not grant newly added airborne capacity; the existing ability flight caps own it.
	controller.action_resources.reconcile_capacity()
	controller.jump_ability.reconcile_capacity()
	_sources = {}
	for id: StringName in proposed:
		_sources[id] = (proposed[id] as ItemDefinition).duplicate(true)
	_applied_effect_signature = _effect_signature(_sources)
	_applying = false
	call_deferred("_emit_changed")
	return true

func _emit_changed() -> void:
	changed.emit()

func _effect_signature(sources: Dictionary) -> String:
	var rows: Array = []
	var ids: Array = sources.keys()
	ids.sort_custom(func(a: StringName,b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		var owned := inventory.get_instance(id)
		rows.append([id,(sources[id] as ItemDefinition).fingerprint(),owned.level if owned != null else 1,bool(owned.effect_state.get("broken",false)) if owned != null else false])
	return JSON.stringify(rows)

func _modifiers_for(source: StringName, item: ItemDefinition) -> Array[BuildModifier]:
	var owned := inventory.get_instance(source) if inventory != null else null
	return resolve_item_modifiers(item,owned.level if owned != null else 1,bool(owned.effect_state.get("broken",false)) if owned != null else false)

static func resolve_item_modifiers(item: ItemDefinition, level: int = 1, broken: bool = false) -> Array[BuildModifier]:
	var modifiers: Array[BuildModifier] = []
	if item == null or broken or level < 1 or level > item.max_level: return modifiers
	modifiers.append_array(item.stat_modifiers())
	if item.catalog_version < 5: return modifiers
	var parameters := item.parameters_for_level(level)
	var mappings: Array = [
		["max_hp_add",&"max_health",BuildModifier.Operation.ADD],
		["max_hp_multiplier",&"max_health",BuildModifier.Operation.MULTIPLY],
		["ground_recoil_multiplier",&"ground_recoil_multiplier",BuildModifier.Operation.MULTIPLY],
		["coyote_time_add_s",&"coyote_time",BuildModifier.Operation.ADD],
		["focus_stamina_drain_multiplier",&"focus_stamina_drain",BuildModifier.Operation.MULTIPLY],
		["focus_stamina_recovery_multiplier",&"focus_stamina_recovery",BuildModifier.Operation.MULTIPLY]]
	for mapping: Array in mappings:
		if not parameters.has(mapping[0]): continue
		var modifier := BuildModifier.new()
		modifier.stat_id = mapping[1]
		modifier.operation = mapping[2]
		modifier.value = float(parameters[mapping[0]])
		modifiers.append(modifier)
	return modifiers

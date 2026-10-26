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
const STATS: Array[StringName] = [&"max_jumps", &"max_air_shots", &"projectile_damage", &"shot_burst_speed", &"recoil_impulse", &"max_health", &"ground_recoil_multiplier", &"ground_deceleration", &"shot_cooldown", &"focus_stamina_drain", &"focus_stamina_recovery", &"focus_rearm_stamina"]
const ENERGY_STATS: Array[StringName] = [&"shot_energy_cost",&"hit_energy_recovery", &"ground_energy_recovery", &"shot_energy_delay"]

func configure(player: PlayerController, scope: DemoLifetime = null, run_namespace: StringName = &"") -> void:
	controller = player
	inventory = RunInventory.new(run_namespace)
	equipment = EquipmentService.new()
	equipment.configure(self,scope,inventory)
	_sources.clear()
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
	ids.sort()
	for id: StringName in ids: result.append((_sources[id] as ItemDefinition).stable_id)
	return result

func can_add(item: ItemDefinition) -> bool:
	return not _applying and is_instance_valid(controller) and controller.active and not controller.actor_resources.health.terminal and inventory.can_add(item)

func add_item(source_id: StringName, item: ItemDefinition, origin: StringName = &"pickup") -> bool:
	if _applying or not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal: return false
	return inventory.add_item(source_id,item,origin)

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
	for item: ItemDefinition in proposed.values():
		if item == null or not item.is_valid(): return &"invalid_item"
		for modifier: BuildModifier in item.stat_modifiers():
			if not _base.has(modifier.stat_id): return &"unsupported_effect"
	return &"" if _valid_values(_resolve(proposed)) else &"invalid_stats"

func _replace_equipped_sources(proposed: Dictionary) -> bool:
	return validate_sources(proposed).is_empty() and _commit(proposed)

func effect_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = _sources.keys()
	ids.sort()
	for id: StringName in ids:
		var item: ItemDefinition = _sources[id]
		if not item.modifiers.is_empty():
			result.append({"source_id":StringName("%s/stats" % id),"instance_id":id,"definition_id":item.stable_id,"definition_version":item.definition_version,"effect_id":&"stats","channel":ItemEffectComponent.Channel.PASSIVE,"modifiers":item.duplicate(true).modifiers})
		for component: ItemEffectComponent in item.effect_components:
			result.append({"source_id":StringName("%s/%s" % [id,component.effect_id]),"instance_id":id,"definition_id":item.stable_id,"definition_version":item.definition_version,"effect_id":component.effect_id,"channel":component.channel,"component":component.duplicate(true)})
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
		for stat: StringName in _base:
			if stat != &"max_health":
				if stat in ENERGY_STATS: controller.shot_energy.set(stat,_base[stat])
				else: controller.motor.tuning.set(stat, _base[stat])
		call_deferred("_emit_changed")
		return true
	return _commit({})

func _resolve(sources: Dictionary) -> Dictionary:
	var values := _base.duplicate()
	var keys: Array = sources.keys()
	keys.sort()
	for stat: StringName in _base:
		var best_priority := -2147483648
		var value: float = float(_base[stat])
		# Stable source order: later lexical ID wins equal-priority override.
		for source: StringName in keys:
			for modifier: BuildModifier in (sources[source] as ItemDefinition).stat_modifiers():
				if modifier.stat_id == stat and modifier.operation == BuildModifier.Operation.OVERRIDE and modifier.priority >= best_priority:
					best_priority = modifier.priority
					value = modifier.value
		for operation: int in [BuildModifier.Operation.ADD, BuildModifier.Operation.MULTIPLY]:
			for source: StringName in keys:
				for modifier: BuildModifier in (sources[source] as ItemDefinition).stat_modifiers():
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
	_applying = true
	if not is_equal_approx(health.capacity, values[&"max_health"]):
		if health.terminal:
			_applying = false
			return false
		_revision += 1
		var request := ActorResourceRequest.new(StringName("build_max_%s_%s" % [get_instance_id(), _revision]), health.epoch, values[&"max_health"], health.get_instance_id())
		if not health.set_max(request).accepted():
			_applying = false
			return false
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
	_applying = false
	call_deferred("_emit_changed")
	return true

func _emit_changed() -> void:
	changed.emit()

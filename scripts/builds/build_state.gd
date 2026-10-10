class_name BuildState
extends RefCounted

signal changed
var controller: PlayerController
var _base: Dictionary = {}
var _sources: Dictionary = {}
var _revision := 0
var _applying := false
const STATS: Array[StringName] = [&"max_jumps", &"max_air_shots", &"projectile_damage", &"shot_burst_speed", &"recoil_impulse", &"max_health"]

func configure(player: PlayerController) -> void:
	controller = player
	_sources.clear()
	_base.clear()
	for stat: StringName in STATS:
		_base[stat] = controller.actor_resources.health.capacity if stat == &"max_health" else controller.motor.tuning.get(stat)

func count_item(id: StringName) -> int:
	var count := 0
	for item: ItemDefinition in _sources.values():
		if item.stable_id == id:
			count += 1
	return count

func item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item: ItemDefinition in _sources.values():
		result.append(item.stable_id)
	return result

func can_add(item: ItemDefinition) -> bool:
	if _applying or not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal or item == null or not item.is_valid():
		return false
	var count := count_item(item.stable_id)
	if count >= item.stack_limit or (count > 0 and item.duplicate_policy == ItemDefinition.DuplicatePolicy.REJECT):
		return false
	for existing: ItemDefinition in _sources.values():
		for tag: StringName in existing.tags:
			if tag in item.exclusive_tags:
				return false
		for tag: StringName in item.tags:
			if tag in existing.exclusive_tags:
				return false
	var proposed := _sources.duplicate()
	proposed[&"__preview"] = item
	return _valid_values(_resolve(proposed))

func add_item(source_id: StringName, item: ItemDefinition) -> bool:
	if source_id.is_empty():
		return false
	if _sources.has(source_id):
		return item != null and _sources[source_id].fingerprint() == item.fingerprint()
	if not can_add(item):
		return false
	var proposed := _sources.duplicate()
	proposed[source_id] = item.duplicate(true)
	return _commit(proposed)

func remove_source(source_id: StringName) -> bool:
	if not _sources.has(source_id):
		return false
	var proposed := _sources.duplicate()
	proposed.erase(source_id)
	return _commit(proposed)

func clear() -> bool:
	if is_instance_valid(controller) and controller.actor_resources.health.terminal:
		# RunEnd discards the terminal actor; do not mutate/revive its HealthState.
		_sources.clear()
		for stat: StringName in STATS:
			if stat != &"max_health":
				controller.motor.tuning.set(stat, _base[stat])
		call_deferred("_emit_changed")
		return true
	return _commit({})

func _resolve(sources: Dictionary) -> Dictionary:
	var values := _base.duplicate()
	var keys: Array = sources.keys()
	keys.sort()
	for stat: StringName in STATS:
		var best_priority := -2147483648
		var value: float = float(_base[stat])
		# Stable source order: later lexical ID wins equal-priority override.
		for source: StringName in keys:
			for modifier: BuildModifier in sources[source].modifiers:
				if modifier.stat_id == stat and modifier.operation == BuildModifier.Operation.OVERRIDE and modifier.priority >= best_priority:
					best_priority = modifier.priority
					value = modifier.value
		for operation: int in [BuildModifier.Operation.ADD, BuildModifier.Operation.MULTIPLY]:
			for source: StringName in keys:
				for modifier: BuildModifier in sources[source].modifiers:
					if modifier.stat_id == stat and modifier.operation == operation:
						value = value + modifier.value if operation == BuildModifier.Operation.ADD else value * modifier.value
		values[stat] = value
	return values

func _valid_values(values: Dictionary) -> bool:
	for stat: StringName in STATS:
		var value: float = values[stat]
		if not is_finite(value) or value < 0.0:
			return false
		if stat in [&"max_jumps", &"max_air_shots"] and value != floor(value):
			return false
		if stat not in [&"max_jumps", &"max_air_shots"] and value <= 0.0:
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
	for stat: StringName in STATS:
		if stat != &"max_health":
			controller.motor.tuning.set(stat, int(values[stat]) if stat in [&"max_jumps", &"max_air_shots"] else values[stat])
	# Do not grant newly added airborne capacity; the existing ability flight caps own it.
	controller.action_resources.shot_charges = mini(controller.action_resources.shot_charges, controller.motor.tuning.max_air_shots)
	_sources = proposed
	_applying = false
	call_deferred("_emit_changed")
	return true

func _emit_changed() -> void:
	changed.emit()

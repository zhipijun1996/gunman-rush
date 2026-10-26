class_name RunInventory
extends RefCounted
## Ownership only: no gear budget, exclusivity, actor mutation or effect application.
signal changed
var _instances: Dictionary = {}
var _sources: Dictionary = {}
var _run_id: StringName
var _namespace: StringName
var _generation := 0
var revision := 0

func _init(run_namespace: StringName = &"") -> void:
	# Formal runs supply the persisted Meta run-receipt prefix. Local fixtures use
	# an object namespace without inventing persistent or cross-run state.
	_namespace = run_namespace if not run_namespace.is_empty() else StringName("fixture_%s" % get_instance_id())
	_run_id = _namespace

func instances() -> Array[RunItemInstance]:
	var result: Array[RunItemInstance] = []
	var ids: Array = _instances.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		result.append((_instances[id] as RunItemInstance).copy())
	return result

func item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var ids: Array = _instances.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		result.append((_instances[id] as RunItemInstance).definition_id)
	return result

func get_instance(id: StringName) -> RunItemInstance:
	return (_instances[id] as RunItemInstance).copy() if _instances.has(id) else null

func instance_for_source(source: StringName) -> RunItemInstance:
	return get_instance(_sources[source]) if _sources.has(source) else null

func count_item(id: StringName) -> int:
	var count := 0
	for instance: RunItemInstance in _instances.values():
		if instance.definition_id == id: count += 1
	return count

func validation_reason(item: ItemDefinition) -> StringName:
	if item == null or item is ResourceRewardChoice or not item.is_valid(): return &"invalid_item"
	for instance: RunItemInstance in _instances.values():
		if instance.definition_id == item.stable_id and instance.item.fingerprint() != item.fingerprint(): return &"definition_conflict"
	var count := count_item(item.stable_id)
	if count >= item.stack_limit: return &"ownership_limit"
	if count > 0 and item.duplicate_policy == ItemDefinition.DuplicatePolicy.REJECT: return &"duplicate_owned"
	return &""

func can_add(item: ItemDefinition) -> bool:
	return validation_reason(item).is_empty()

func add_item(source: StringName, item: ItemDefinition, origin: StringName = &"pickup") -> bool:
	if source.is_empty() or origin.is_empty() or item == null or item is ResourceRewardChoice or not item.is_valid(): return false
	if _sources.has(source):
		var previous := instance_for_source(source)
		return previous.origin == origin and previous.item.fingerprint() == item.fingerprint()
	if not can_add(item): return false
	var instance := RunItemInstance.new()
	instance.instance_id = StringName("%s/%s" % [_run_id, source])
	instance.definition_id = item.stable_id
	instance.definition_version = item.definition_version
	instance.source_id = source
	instance.origin = origin
	instance.item = item.duplicate(true)
	_instances[instance.instance_id] = instance
	_sources[source] = instance.instance_id
	revision += 1
	call_deferred("_emit_changed")
	return true

func clear() -> void:
	_generation += 1
	_run_id = StringName("%s/reset_%s" % [_namespace,_generation])
	_instances.clear()
	_sources.clear()
	revision += 1
	call_deferred("_emit_changed")

func _emit_changed() -> void:
	changed.emit()

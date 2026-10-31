class_name RunInventory
extends RefCounted
## Ownership only: no gear budget, exclusivity, actor mutation or effect application.
signal changed
var _instances: Dictionary = {}
var _sources: Dictionary = {}
var _source_receipts: Dictionary = {}
var _state_receipts: Dictionary = {}
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

func instance_for_definition(id: StringName) -> RunItemInstance:
	var selected: RunItemInstance
	for instance: RunItemInstance in _instances.values():
		if instance.definition_id == id and (selected == null or String(instance.instance_id) < String(selected.instance_id)):
			selected = instance
	return selected.copy() if selected != null else null

func source_receipt(source: StringName) -> Dictionary:
	return (_source_receipts.get(source,{}) as Dictionary).duplicate(true)

func effect_state(instance_id: StringName) -> Dictionary:
	return (_instances[instance_id] as RunItemInstance).effect_state.duplicate(true) if _instances.has(instance_id) else {}

func patch_effect_state(instance_id: StringName, patch: Dictionary, receipt: StringName = &"") -> bool:
	if not _instances.has(instance_id) or not _valid_state(patch): return false
	var key := JSON.stringify([String(instance_id),String(receipt)])
	var fingerprint := _canonical_state(patch)
	if not receipt.is_empty() and _state_receipts.has(key):
		return _state_receipts[key] == fingerprint
	var owned: RunItemInstance = _instances[instance_id]
	var changed_state := false
	for name: Variant in patch:
		if not owned.effect_state.has(name) or owned.effect_state[name] != patch[name]:
			changed_state = true
		owned.effect_state[name] = _copy_state(patch[name])
	if not receipt.is_empty(): _state_receipts[key] = fingerprint
	if changed_state:
		revision += 1
		call_deferred("_emit_changed")
	return true

func validation_reason(item: ItemDefinition) -> StringName:
	if item == null or item is ResourceRewardChoice or not item.is_valid(): return &"invalid_item"
	for instance: RunItemInstance in _instances.values():
		if instance.definition_id == item.stable_id and instance.item.fingerprint() != item.fingerprint(): return &"definition_conflict"
	var count := count_item(item.stable_id)
	if count > 0 and item.catalog_version >= 5 and item.max_level > 1:
		var previous := instance_for_definition(item.stable_id)
		return &"" if count == 1 and previous.level < item.max_level else &"maximum_level"
	if count >= item.stack_limit: return &"ownership_limit"
	if count > 0 and item.duplicate_policy == ItemDefinition.DuplicatePolicy.REJECT: return &"duplicate_owned"
	return &""

func can_add(item: ItemDefinition) -> bool:
	return validation_reason(item).is_empty()

func add_item(source: StringName, item: ItemDefinition, origin: StringName = &"pickup") -> bool:
	if source.is_empty() or origin.is_empty() or item == null or item is ResourceRewardChoice or not item.is_valid(): return false
	if _sources.has(source):
		var receipt: Dictionary = _source_receipts[source]
		return receipt.origin == origin and receipt.fingerprint == item.fingerprint()
	if not can_add(item): return false
	var previous := instance_for_definition(item.stable_id)
	if previous != null and item.catalog_version >= 5 and item.max_level > 1:
		var owned: RunItemInstance = _instances[previous.instance_id]
		owned.level += 1
		_sources[source] = owned.instance_id
		_source_receipts[source] = {"instance_id":owned.instance_id,"definition_id":owned.definition_id,"definition_version":owned.definition_version,"origin":origin,"fingerprint":item.fingerprint(),"level":owned.level,"upgraded":true}
		revision += 1
		call_deferred("_emit_changed")
		return true
	var instance := RunItemInstance.new()
	instance.instance_id = StringName("%s/%s" % [_run_id, source])
	instance.definition_id = item.stable_id
	instance.definition_version = item.definition_version
	instance.source_id = source
	instance.origin = origin
	instance.item = item.duplicate(true)
	_instances[instance.instance_id] = instance
	_sources[source] = instance.instance_id
	_source_receipts[source] = {"instance_id":instance.instance_id,"definition_id":instance.definition_id,"definition_version":instance.definition_version,"origin":origin,"fingerprint":item.fingerprint(),"level":1,"upgraded":false}
	revision += 1
	call_deferred("_emit_changed")
	return true

func clear() -> void:
	_generation += 1
	_run_id = StringName("%s/reset_%s" % [_namespace,_generation])
	_instances.clear()
	_sources.clear()
	_source_receipts.clear()
	_state_receipts.clear()
	revision += 1
	call_deferred("_emit_changed")

func _emit_changed() -> void:
	changed.emit()

# Only inventory operations may create provisional ownership changes. The
# synchronous acceptance callback applies dependent actor effects or a coin
# grant; callers never receive or restore the inventory's internal rows.
func add_item_checked(source: StringName, item: ItemDefinition, origin: StringName, accept: Callable) -> bool:
	if not accept.is_valid(): return false
	var saved := _capture_owned_state()
	if not add_item(source, item, origin): return false
	return _accept_or_restore(saved, accept)

func patch_effect_state_checked(instance_id: StringName, patch: Dictionary, receipt: StringName, accept: Callable, after_restore: Callable = Callable()) -> bool:
	if not accept.is_valid(): return false
	var saved := _capture_owned_state()
	if not patch_effect_state(instance_id, patch, receipt): return false
	return _accept_or_restore(saved, accept, after_restore)

func _accept_or_restore(saved: Dictionary, accept: Callable, after_restore: Callable = Callable()) -> bool:
	if bool(accept.call()): return true
	_restore_owned_state(saved)
	if after_restore.is_valid(): after_restore.call()
	return false

func _capture_owned_state() -> Dictionary:
	var owned: Dictionary = {}
	for id: StringName in _instances: owned[id] = (_instances[id] as RunItemInstance).copy()
	return {"instances":owned,"sources":_sources.duplicate(),"source_receipts":_source_receipts.duplicate(true),"state_receipts":_state_receipts.duplicate(true),"revision":revision}

func _restore_owned_state(snapshot: Dictionary) -> void:
	_instances = snapshot.instances
	_sources = snapshot.sources
	_source_receipts = snapshot.source_receipts
	_state_receipts = snapshot.state_receipts
	revision = snapshot.revision

func _copy_state(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

func _valid_state(value: Variant, depth: int = 0) -> bool:
	if depth > 12: return false
	if value == null or value is bool or value is String or value is StringName or value is int: return true
	if value is float: return is_finite(value)
	if value is Array:
		for entry: Variant in value:
			if not _valid_state(entry,depth+1): return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if not (key is String or key is StringName) or String(key).is_empty() or not _valid_state(value[key],depth+1): return false
		return true
	return false

func _canonical_state(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant,b: Variant) -> bool: return String(a) < String(b))
		var parts: PackedStringArray = []
		for key: Variant in keys: parts.append(JSON.stringify(String(key))+":"+_canonical_state(value[key]))
		return "{"+",".join(parts)+"}"
	if value is Array:
		var parts: PackedStringArray = []
		for entry: Variant in value: parts.append(_canonical_state(entry))
		return "["+",".join(parts)+"]"
	return JSON.stringify(value)

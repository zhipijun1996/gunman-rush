class_name ItemV5Pool
extends RefCounted
## A generated offer is a frozen receipt, not a view that is rerolled when a
## menu reopens, a weapon changes, or inventory ownership advances meanwhile.
const VERSION := "item_v5_pool_v2"
var _build: BuildState
var _offers: Dictionary = {}

func configure(build_state: BuildState) -> void:
	if _build != build_state: _offers.clear()
	_build = build_state

func clear() -> void:
	_offers.clear()

func eligible_items(rarity := -1, in_shop := false) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	if _build == null or rarity < -1 or rarity > ItemDefinition.Rarity.GOLD: return result
	for item: ItemDefinition in ItemCatalogV5.all_items():
		if item.appearance_weight > 0 and (rarity == -1 or item.rarity == rarity) and ItemV5Eligibility.offer_reason(item, _build, in_shop).is_empty(): result.append(item)
	result.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool: return String(a.stable_id) < String(b.stable_id))
	return result

func generate(seed: String, offer_id: StringName, count := 2, rarity := -1, in_shop := false, stream_namespace: StringName = &"item_v5_reward", rarity_weights: Dictionary = {}, rng_context: StringName = &"") -> Dictionary:
	if _build == null or not is_instance_valid(_build.controller) or not _build.controller.active or _build.controller.actor_resources.health.terminal: return _failure(&"invalid_context")
	if seed.is_empty() or offer_id.is_empty() or stream_namespace.is_empty() or count < 1 or count > 16 or rarity < -1 or rarity > ItemDefinition.Rarity.GOLD: return _failure(&"invalid_request")
	var normalized_weights := _rarity_weights(rarity_weights)
	if not rarity_weights.is_empty() and normalized_weights.is_empty(): return _failure(&"invalid_rarity_weights")
	var context := offer_id if rng_context.is_empty() else rng_context
	var request := JSON.stringify([seed, String(offer_id), count, rarity, in_shop, String(stream_namespace), normalized_weights, String(context)], "", true)
	if _offers.has(offer_id):
		if _offers[offer_id].request != request: return _failure(&"offer_conflict")
		return _reply(_offers[offer_id])
	var eligible := eligible_items(rarity, in_shop)
	if eligible.size() < count: return _failure(&"insufficient_legal_candidates")
	var pool_records := _records(eligible)
	var stream := RunRandomStream.new(seed, String(stream_namespace), String(context), VERSION)
	var selected: Array[ItemDefinition] = []
	var draws: Array[Dictionary] = []
	for unused: int in count:
		var weights := _item_weights(eligible, normalized_weights)
		var total := 0.0
		for value: float in weights: total += value
		if not is_finite(total) or total <= 0: return _failure(&"insufficient_weighted_candidates")
		var before := stream.position()
		var roll := stream.next_int(1000000)
		var threshold := float(roll) / 1000000.0 * total
		var index := eligible.size() - 1
		for candidate: int in eligible.size():
			threshold -= weights[candidate]
			if threshold < 0:
				index = candidate
				break
		selected.append(eligible[index].duplicate(true))
		draws.append({"position_before": before, "position_after": stream.position(), "roll": roll, "selected_id": String(eligible[index].stable_id), "total_weight": total})
		eligible.remove_at(index)
	var manifest := {"version": VERSION, "catalog_version": 5, "offer_id": String(offer_id), "root_seed": seed, "namespace": String(stream_namespace), "requested_count": count, "request_fingerprint": request.sha256_text(), "in_shop": in_shop, "rarity": rarity, "rarity_weights": normalized_weights,
		"rng_context": String(context), "rng_algorithm": RunRandomStream.ALGORITHM, "stream_derivation_version": RunRandomStream.DERIVATION_VERSION, "rng_position_before": 0, "rng_position_after": stream.position(),
		"candidate_pool": pool_records, "candidate_pool_hash": JSON.stringify(pool_records, "", true).sha256_text(), "selected": _records(selected), "draws": draws}
	var record := {"request": request, "items": selected, "manifest": manifest}
	_offers[offer_id] = record
	return _reply(record)

func manifest_for(offer_id: StringName) -> Dictionary:
	return _offers[offer_id].manifest.duplicate(true) if _offers.has(offer_id) else {}

func _reply(record: Dictionary) -> Dictionary:
	var copies: Array[ItemDefinition] = []
	for item: ItemDefinition in record.items: copies.append(item.duplicate(true))
	return {"accepted": true, "reason": &"", "items": copies, "manifest": record.manifest.duplicate(true)}

func _failure(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "items": [], "manifest": {}}

func _records(items: Array[ItemDefinition]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: ItemDefinition in items:
		result.append({"id": String(item.stable_id), "definition_version": item.definition_version, "catalog_version": item.catalog_version, "rarity": item.rarity, "appearance_weight": item.appearance_weight, "fingerprint": item.fingerprint()})
	return result

func _rarity_weights(provided: Dictionary) -> Dictionary:
	if provided.is_empty(): return {}
	var result: Dictionary = {}
	var total := 0.0
	for rarity: int in 3:
		var name: String = ["BLUE", "PURPLE", "GOLD"][rarity]
		var value: Variant = provided.get(name, provided.get(name.to_lower(), provided.get(rarity, provided.get(str(rarity), 0))))
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0: return {}
		result[name] = float(value)
		total += float(value)
	return result if is_finite(total) and total > 0 else {}

func _item_weights(items: Array[ItemDefinition], rarity_weights: Dictionary) -> Array[float]:
	var result: Array[float] = []
	var group_totals := [0.0, 0.0, 0.0]
	for item: ItemDefinition in items: group_totals[item.rarity] += item.appearance_weight
	for item: ItemDefinition in items:
		var value := item.appearance_weight
		if not rarity_weights.is_empty():
			var name: String = ["BLUE", "PURPLE", "GOLD"][item.rarity]
			value = item.appearance_weight / float(group_totals[item.rarity]) * float(rarity_weights[name])
		result.append(value)
	return result

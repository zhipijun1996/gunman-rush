class_name DemoRewardCatalog
extends RefCounted

# Fixture balance only. The first quick room keeps its existing explicit pair.
const CONTENT_VERSION := "demo_reward_catalog_v1"
const DEFAULT_ITEMS: Array[ItemDefinition] = [
	preload("res://resources/items/jump_blue.tres"),
	preload("res://resources/items/shot_purple.tres"),
	preload("res://resources/items/damage_blue.tres"),
	preload("res://resources/items/recoil_purple.tres"),
	preload("res://resources/items/health_blue.tres"),
]
var last_error: StringName = &""
var _build: BuildState
var _pool: Array[ItemDefinition] = []

func configure(build: BuildState) -> void:
	_build = build
	set_pool(DEFAULT_ITEMS)

func set_pool(items: Array[ItemDefinition]) -> bool:
	var seen: Array[StringName] = []
	var copied: Array[ItemDefinition] = []
	for item: ItemDefinition in items:
		if item == null or not item.is_valid() or item.stable_id in seen:
			return false
		seen.append(item.stable_id)
		copied.append(item.duplicate(true))
	copied.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool: return String(a.stable_id) < String(b.stable_id))
	_pool = copied
	return true

func choose_candidates(seed: String, stable_stage: String) -> Array[ItemDefinition]:
	last_error = &""
	var eligible: Array[ItemDefinition] = []
	if _build == null or stable_stage.is_empty():
		last_error = &"invalid_context"
		return eligible
	for item: ItemDefinition in _pool:
		if item.appearance_weight > 0.0 and _build.can_add(item):
			eligible.append(item)
	if eligible.size() < 2:
		last_error = &"insufficient_legal_candidates"
		# Explicit content failure: never duplicate one item to fake a choice.
		return []
	var stream := RunRandomStream.new(seed, "reward", stable_stage, CONTENT_VERSION)
	var result: Array[ItemDefinition] = []
	for unused: int in 2:
		var total := 0.0
		for item: ItemDefinition in eligible:
			total += item.appearance_weight
		if not is_finite(total) or total <= 0.0:
			last_error = &"invalid_total_weight"
			return []
		var threshold := float(stream.next_int(1000000)) / 1000000.0 * total
		var selected := eligible.size() - 1
		for index: int in eligible.size():
			threshold -= eligible[index].appearance_weight
			if threshold < 0.0:
				selected = index
				break
		result.append(eligible[selected].duplicate(true))
		eligible.remove_at(selected)
	return result

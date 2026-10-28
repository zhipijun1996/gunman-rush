extends SceneTree
## Native catalog data-contract suite; root owns actual engine execution.
var checks := 0
var failures := 0
var _base: Dictionary
var _authoring: Dictionary
var _reference_policy: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ITEM V5 CATALOG FAILURE: ", label)

func _reference_item(id: StringName) -> ItemDefinition:
	for item: ItemDefinition in ItemCatalogV5.from_payload(_base,_reference_policy):
		if item.stable_id == id: return item
	return null

func _run() -> void:
	_base = JSON.parse_string(FileAccess.get_file_as_string(ItemCatalogV5.CONFIG_PATH))
	_authoring = JSON.parse_string(FileAccess.get_file_as_string(ItemCatalogV5.AUTHORING_PATH))
	_reference_policy = _authoring.duplicate(true)
	_reference_policy.overrides = {}
	_reference_policy.additions = []
	_reference_policy.disabled_ids = []
	# The original400 guards audit the frozen workbook, not a designer's later
	# supported tuning proposal. Current production is checked separately below.
	var items := ItemCatalogV5.from_payload(_base,_reference_policy)
	_check(items.size() == 72, "all72")
	var ids: Array[StringName] = []
	var levels := 0
	var rarity_counts := [0, 0, 0]
	for item: ItemDefinition in items:
		_check(item.is_valid(), "valid_" + String(item.stable_id))
		_check(item.stable_id not in ids, "unique_" + String(item.stable_id))
		ids.append(item.stable_id)
		rarity_counts[item.rarity] += 1
		_check(item.catalog_version == 5 and item.shop_price > 0 and item.gear_cost >= 1 and item.gear_cost <= 5, "metadata_" + String(item.stable_id))
		_check(not item.parameters_for_level(1).is_empty(), "parameters_" + String(item.stable_id))
		_check(item.parameters_for_level(0).is_empty() and item.parameters_for_level(item.max_level + 1).is_empty(), "bad_level_" + String(item.stable_id))
		if item.max_level == 3:
			levels += 1
			_check(not item.parameters_for_level(2).is_empty() and not item.parameters_for_level(3).is_empty(), "all_levels_" + String(item.stable_id))
	_check(levels == 16, "only16upgradeable")
	_check(rarity_counts == [29, 28, 15], "rarity_counts")
	var barrel := _reference_item(&"B03")
	_check(barrel.parameters_for_level(1).primary_damage_multiplier == 1.12, "level1_direct_value")
	_check(barrel.parameters_for_level(2).primary_damage_multiplier == 1.22, "level2_direct_value")
	_check(barrel.parameters_for_level(3).primary_damage_multiplier == 1.32, "level3_direct_value")
	var second := _reference_item(&"B03")
	barrel.effect_parameters.primary_damage_multiplier_by_level[0] = 900.0
	_check(second.parameters_for_level(1).primary_damage_multiplier == 1.12, "factory_snapshots_independent")
	_check(_reference_item(&"B03").parameters_for_level(1).primary_damage_multiplier == 1.12, "canonical_immutable")
	var bad := second.duplicate(true) as ItemDefinition
	bad.effect_parameters.primary_damage_multiplier_by_level = [1.12]
	_check(not bad.is_valid(), "incomplete_levels_rejected")
	bad = second.duplicate(true) as ItemDefinition
	bad.effect_parameters.primary_damage_multiplier_by_level[0] = NAN
	_check(not bad.is_valid(), "nan_rejected")
	bad = second.duplicate(true) as ItemDefinition
	bad.effect_parameters.primary_damage_multiplier_by_level[0] = "bad"
	_check(not bad.is_valid(), "wrong_scalar_type_rejected")
	bad = second.duplicate(true) as ItemDefinition
	bad.effect_parameters.primary_damage_multiplier = 1.5
	_check(not bad.is_valid(), "ambiguous_level_key_rejected")
	var ember := _reference_item(&"B24")
	bad = ember.duplicate(true) as ItemDefinition
	bad.effect_parameters.erase("dot_duration_s")
	_check(not bad.is_valid(), "required_runtime_key_rejected")
	bad = ember.duplicate(true) as ItemDefinition
	bad.effect_parameters.dot_duration_s = 0
	_check(not bad.is_valid(), "zero_divisor_duration_rejected")
	bad = ember.duplicate(true) as ItemDefinition
	bad.effect_parameters.dot_duration_s = 4.5
	_check(bad.is_valid(), "positive_tuning_change_allowed")
	bad = ember.duplicate(true) as ItemDefinition
	bad.effect_parameters.misspelled_duration_s = 3
	_check(not bad.is_valid(), "unknown_parameter_rejected")
	bad = _reference_item(&"G06")
	bad.effect_parameters.chain_targets = 1.5
	_check(not bad.is_valid(), "fractional_target_count_rejected")
	_check(_reference_item(&"P06").effect_parameters.world_time_scale_while_air_aiming == 0 and _reference_item(&"P06").is_valid(), "explicit_world_zero_scale_allowed")
	_check(_reference_item(&"P18").effect_parameters.normal_healing_multiplier == 0 and _reference_item(&"P18").is_valid(), "explicit_no_healing_zero_allowed")
	var empty := ItemEffectComponent.new()
	empty.effect_id = &"empty"
	_check(not empty.is_valid(), "empty_component_still_rejected")
	_check(_reference_item(&"B25") == null and _reference_item(&"missing") == null, "deleted_and_unknown_not_registered")
	_check(_reference_item(&"B26").gear_cost == 5 and _reference_item(&"B26").rarity == ItemDefinition.Rarity.BLUE, "blue_high_cost")
	_check(_reference_item(&"G01").gear_cost == 1 and _reference_item(&"G01").rarity == ItemDefinition.Rarity.GOLD, "gold_low_cost")
	_check((load("res://resources/items/damage_blue.tres") as ItemDefinition).is_valid(), "legacy_definition_preserved")
	_check_effective_catalog()
	print("ITEM V5 CATALOG: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _check_effective_catalog() -> void:
	# Derive expected editable values from the declared source/patch fields,
	# independently of the runtime composer. No fixed current count or balance.
	var declared: Dictionary = {}
	for row: Dictionary in _base.items: declared[String(row.stable_id)] = row
	for row: Dictionary in _authoring.additions: declared[String(row.stable_id)] = row
	var production := ItemCatalogV5.all_items()
	_check(production.size() == declared.size(),"effective_catalog_matches_declared_count")
	var seen: Array[StringName] = []
	for item: ItemDefinition in production:
		var id := String(item.stable_id)
		_check(item.is_valid() and item.stable_id not in seen and declared.has(id),"effective_valid_unique_"+id)
		seen.append(item.stable_id)
		if not declared.has(id): continue
		var row: Dictionary = declared[id]
		var patch: Dictionary = _authoring.overrides.get(id,{})
		var parameters: Dictionary = row.effect_parameters.duplicate(true)
		parameters.merge(patch.get("effect_parameters",{}),true)
		_check(item.effect_parameters == parameters,"effective_declared_parameters_"+id)
		for field: String in ["display_name","description","gear_cost","shop_price","max_level","definition_version"]:
			var fallback: Variant = row.get(field,5 if field == "definition_version" else null)
			_check(item.get(field) == patch.get(field,fallback),"effective_declared_"+field+"_"+id)
		var rarity: String = patch.get("rarity",row.rarity)
		_check(item.rarity == {"BLUE":ItemDefinition.Rarity.BLUE,"PURPLE":ItemDefinition.Rarity.PURPLE,"GOLD":ItemDefinition.Rarity.GOLD}[rarity],"effective_declared_rarity_"+id)
		var metadata: Dictionary = _authoring.metadata[id].duplicate(true) if _authoring.metadata.has(id) else row.runtime_metadata.duplicate(true)
		metadata.merge(patch.get("runtime_metadata",{}),true)
		var weight: float = 0.0 if id in _authoring.disabled_ids else float(metadata.appearance_weight)
		_check(item.appearance_weight == weight and String(item.icon_key) == metadata.icon_key,"effective_declared_weight_icon_"+id)
		for field: String in ["tags","required_tags","required_capabilities","exclusive_tags"]:
			_check(JSON.stringify(item.get(field)) == JSON.stringify(metadata[field]),"effective_declared_"+field+"_"+id)
		_check(String(item.required_weapon_id) == metadata.get("required_weapon_id",""),"effective_declared_required_weapon_"+id)
		var before := item.fingerprint()
		for key: Variant in item.effect_parameters:
			if item.effect_parameters[key] is Array:
				item.effect_parameters[key][0] = 9999
				break
		item.effect_parameters["isolated_probe"] = 9999
		var fresh := ItemCatalogV5.get_item(item.stable_id)
		_check(fresh != null and fresh.fingerprint() == before and not fresh.effect_parameters.has("isolated_probe"),"effective_snapshots_independent_"+id)

extends SceneTree
## Native catalog data-contract suite; root owns actual engine execution.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ITEM V5 CATALOG FAILURE: ", label)

func _run() -> void:
	var items := ItemCatalogV5.all_items()
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
	var barrel := ItemCatalogV5.get_item(&"B03")
	_check(barrel.parameters_for_level(1).primary_damage_multiplier == 1.12, "level1_direct_value")
	_check(barrel.parameters_for_level(2).primary_damage_multiplier == 1.22, "level2_direct_value")
	_check(barrel.parameters_for_level(3).primary_damage_multiplier == 1.32, "level3_direct_value")
	var second := ItemCatalogV5.get_item(&"B03")
	barrel.effect_parameters.primary_damage_multiplier_by_level[0] = 900.0
	_check(second.parameters_for_level(1).primary_damage_multiplier == 1.12, "factory_snapshots_independent")
	_check(ItemCatalogV5.get_item(&"B03").parameters_for_level(1).primary_damage_multiplier == 1.12, "canonical_immutable")
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
	var ember := ItemCatalogV5.get_item(&"B24")
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
	bad = ItemCatalogV5.get_item(&"G06")
	bad.effect_parameters.chain_targets = 1.5
	_check(not bad.is_valid(), "fractional_target_count_rejected")
	_check(ItemCatalogV5.get_item(&"P06").effect_parameters.world_time_scale_while_air_aiming == 0 and ItemCatalogV5.get_item(&"P06").is_valid(), "explicit_world_zero_scale_allowed")
	_check(ItemCatalogV5.get_item(&"P18").effect_parameters.normal_healing_multiplier == 0 and ItemCatalogV5.get_item(&"P18").is_valid(), "explicit_no_healing_zero_allowed")
	var empty := ItemEffectComponent.new()
	empty.effect_id = &"empty"
	_check(not empty.is_valid(), "empty_component_still_rejected")
	_check(ItemCatalogV5.get_item(&"B25") == null and ItemCatalogV5.get_item(&"missing") == null, "deleted_and_unknown_not_registered")
	_check(ItemCatalogV5.get_item(&"B26").gear_cost == 5 and ItemCatalogV5.get_item(&"B26").rarity == ItemDefinition.Rarity.BLUE, "blue_high_cost")
	_check(ItemCatalogV5.get_item(&"G01").gear_cost == 1 and ItemCatalogV5.get_item(&"G01").rarity == ItemDefinition.Rarity.GOLD, "gold_low_cost")
	_check((load("res://resources/items/damage_blue.tres") as ItemDefinition).is_valid(), "legacy_definition_preserved")
	print("ITEM V5 CATALOG: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)

extends SceneTree
## Actual actor/loadout/inventory predicates and seeded immutable offer receipts.
var checks := 0
var failures := 0
var fixture: Variant
var actor: PlayerController
var build: BuildState

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ITEM V5 POOL FAILURE: ", label)

func _fresh() -> void:
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80, 20))
	actor = fixture.controller
	build = BuildState.new()
	build.configure(actor, DemoLifetime.new(), &"item_v5_pool_fixture")

func _weapon(name: String) -> void:
	check(actor.shoot_ability.equip(load("res://resources/weapons/%s.tres" % name) as WeaponDefinition), "weapon_" + name)

func _reason(id: StringName) -> StringName:
	return ItemV5Eligibility.equip_reason(ItemCatalogV5.get_item(id), actor, {}, build.inventory)

func _ids(items: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for item: ItemDefinition in items: result.append(item.stable_id)
	return result

func _run() -> void:
	await _fresh()
	for name: String in ["pulse_gun", "shadow_shuriken", "recoil_bomb", "triple_machine_gun", "sustained_laser", "fan_shuriken", "remote_boomerang", "magnetic_mine", "collapse_singularity", "machine_storm", "laser_cannon", "blade_bloom", "moon_boomerang", "magnetic_storm", "star_collapse"]:
		_weapon(name)
		var weapon := actor.shoot_ability.weapon
		check(_reason(&"B29").is_empty() == (weapon.mode in [WeaponDefinition.Mode.PULSE, WeaponDefinition.Mode.MACHINE]), name + "_ordinary_bullet_range")
		check(_reason(&"P08").is_empty() == (weapon.mode in [WeaponDefinition.Mode.PULSE, WeaponDefinition.Mode.MACHINE]), name + "_pierce_actual_bullet")
		check(_reason(&"B22").is_empty() == (weapon.mode in [WeaponDefinition.Mode.BOMB, WeaponDefinition.Mode.MINE, WeaponDefinition.Mode.SINGULARITY]), name + "_three_bomb_families")
		check(_reason(&"P23").is_empty() == (weapon.mode == WeaponDefinition.Mode.SINGULARITY and weapon.tier >= 2), name + "_singularity")
		check(_reason(&"P33").is_empty() == (weapon.mode == WeaponDefinition.Mode.LASER and weapon.tier >= 2), name + "_laser")
		check(_reason(&"P34").is_empty() == (weapon.mode == WeaponDefinition.Mode.MACHINE and weapon.tier >= 2), name + "_third_burst_hit")
		check(_reason(&"P03").is_empty() == (weapon.tier == 3), name + "_actual_lv3_skill")
		check(_reason(&"P17").is_empty() == (weapon.tier == 3 and weapon.mode in [WeaponDefinition.Mode.MACHINE, WeaponDefinition.Mode.LASER]), name + "_actual_charge_phase")
		check(_reason(&"B33").is_empty() == (weapon.mode not in [WeaponDefinition.Mode.BOMB, WeaponDefinition.Mode.MINE, WeaponDefinition.Mode.SINGULARITY]), name + "_small_blast_not_bomb_pool")
	_weapon("pulse_gun")
	check(not _reason(&"B21").is_empty() and not _reason(&"P13").is_empty(), "missing_core_hook_rejected")
	check(_reason(&"P29").is_empty(), "universal_chain_does_not_grant_or_require_hook")
	check(not actor.traversal.has_capability(&"grapple"), "eligibility_does_not_unlock_core")
	check(not ItemV5Eligibility.offer_reason(ItemCatalogV5.get_item(&"G08"), build).is_empty(), "no_companion_mark_offer")
	check(build.add_item(&"companion", ItemCatalogV5.get_item(&"P14")) and build.add_item(&"echo_mark", ItemCatalogV5.get_item(&"G01")), "own_companion_and_different_mark")
	check(not ItemV5Eligibility.offer_reason(ItemCatalogV5.get_item(&"G08"), build).is_empty(), "echo_mark_cannot_replace_pursuit")
	check(build.add_item(&"pursuit", ItemCatalogV5.get_item(&"P13")), "own_pursuit")
	check(ItemV5Eligibility.offer_reason(ItemCatalogV5.get_item(&"G08"), build).is_empty(), "owned_companion_and_pursuit_offer")
	var companion_proposal := {&"a": ItemCatalogV5.get_item(&"P14"), &"b": ItemCatalogV5.get_item(&"P13")}
	check(ItemV5Eligibility.equip_reason(ItemCatalogV5.get_item(&"G08"), actor, companion_proposal, build.inventory).is_empty(), "equipped_companion_and_pursuit_required")
	check(not ItemV5Eligibility.equip_reason(ItemCatalogV5.get_item(&"G08"), actor, {}, build.inventory).is_empty(), "ownership_alone_does_not_meet_equipment_prerequisite")
	check(build.add_item(&"ground_trap", ItemCatalogV5.get_item(&"P25")), "own_ground_trap")
	check(not ItemV5Eligibility.offer_reason(ItemCatalogV5.get_item(&"G15"), build).is_empty(), "ground_trap_not_a_projectile_tool")
	check(build.add_item(&"wheel", ItemCatalogV5.get_item(&"P24")), "own_projectile_wheel")
	check(ItemV5Eligibility.offer_reason(ItemCatalogV5.get_item(&"G15"), build).is_empty(), "projectile_tool_offer")
	for id: StringName in [&"B16", &"G10", &"P39"]:
		check(ItemV5Eligibility.offer_reason(ItemCatalogV5.get_item(id), build).is_empty(), "reward_only_admitted_" + String(id))
		check(ItemV5Eligibility.offer_reason(ItemCatalogV5.get_item(id), build, true) == &"reward_only", "reward_only_shop_rejected_" + String(id))
	var barrel := ItemCatalogV5.get_item(&"B03")
	check(build.add_item(&"level1", barrel) and build.add_item(&"level2", barrel) and build.add_item(&"level3", barrel), "three_distinct_reward_receipts_upgrade")
	check(ItemV5Eligibility.offer_reason(barrel, build) == &"maximum_level", "max_level_removed")
	var pool := ItemV5Pool.new()
	pool.configure(build)
	var generated := pool.generate("pool-seed", &"map1/chest1")
	check(generated.accepted and generated.items.size() == 2, "two_actual_eligible_candidates")
	check(generated.items[0].stable_id != generated.items[1].stable_id, "without_replacement")
	check(generated.manifest.rng_position_after == 2 and generated.manifest.rng_position_before == 0, "exact_rng_draw_count")
	check(generated.manifest.candidate_pool_hash == JSON.stringify(generated.manifest.candidate_pool, "", true).sha256_text(), "candidate_pool_hash")
	var frozen_ids := _ids(generated.items)
	var frozen_manifest: Dictionary = generated.manifest.duplicate(true)
	generated.items[0].description = "caller mutation"
	generated.manifest.selected.clear()
	_weapon("recoil_bomb")
	var reopened := pool.generate("pool-seed", &"map1/chest1")
	check(reopened.accepted and _ids(reopened.items) == frozen_ids and reopened.manifest == frozen_manifest, "reopen_or_weapon_change_does_not_reroll")
	check(reopened.items[0].description != "caller mutation", "returned_definitions_cannot_mutate_cached_offer")
	check(not pool.generate("different-seed", &"map1/chest1").accepted, "same_id_different_seed_conflict")
	var another := ItemV5Pool.new()
	another.configure(build)
	var deterministic1 := pool.generate("same-seed", &"map1/chest2")
	var deterministic2 := another.generate("same-seed", &"map1/chest2")
	check(deterministic1.accepted and deterministic1.manifest == deterministic2.manifest, "same_source_seed_namespace_same_manifest")
	var gold := pool.generate("pool-seed", &"map1/boss", 1, ItemDefinition.Rarity.GOLD)
	check(gold.accepted and gold.items[0].rarity == ItemDefinition.Rarity.GOLD, "boss_gold_exact_class")
	var blue := pool.generate("pool-seed", &"map1/weighted", 2, -1, false, &"weighted", {"blue": 100, "purple": 0, "gold": 0})
	check(blue.accepted and blue.items[0].rarity == ItemDefinition.Rarity.BLUE and blue.items[1].rarity == ItemDefinition.Rarity.BLUE, "lowercase_rarity_policy")
	check(not pool.generate("pool-seed", &"invalid_weight", 2, -1, false, &"weighted", {"blue": -1}).accepted, "bad_weight_rejected")
	var legacy := DemoRewardCatalog.new()
	legacy.configure(build)
	check(legacy.current_version() == DemoRewardCatalog.CONTENT_VERSION, "legacy_default_version_retained")
	legacy.configure(build, &"plains", true)
	check(legacy.current_version() == ItemV5Pool.VERSION and legacy.choose_candidates("catalog-seed", "catalog-offer").size() == 2 and not legacy.last_manifest.is_empty(), "explicit_formal_v5_catalog")
	build.clear()
	fixture.world.free()
	await process_frame
	print("ITEM V5 POOL: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)

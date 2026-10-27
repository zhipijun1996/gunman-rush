class_name ItemV5Eligibility
extends RefCounted
## The same current-capability rules protect reward/shop generation and atomic
## loadout proposals. Ownership never grants a core capability or changes a weapon.
const ECONOMY_PATH := "res://config/item_v5_economy.json"
const BULLET_MODES := [WeaponDefinition.Mode.PULSE, WeaponDefinition.Mode.MACHINE]
const BOMB_MODES := [WeaponDefinition.Mode.BOMB, WeaponDefinition.Mode.MINE, WeaponDefinition.Mode.SINGULARITY]

static func equip_reason(item: ItemDefinition, actor: PlayerController, proposed: Dictionary, inventory: RunInventory) -> StringName:
	if item == null or not item.is_valid() or inventory == null: return &"invalid_item"
	if item.catalog_version < 5: return &""
	var reason := _mechanical_reason(item, actor)
	if not reason.is_empty(): return reason
	var supplied: Array[StringName] = []
	for definition: ItemDefinition in proposed.values():
		if definition != null: supplied.append(definition.stable_id)
	return _combination_reason(item, actor, supplied)

static func offer_reason(item: ItemDefinition, build: RefCounted, in_shop := false) -> StringName:
	if item == null or not item.is_valid(): return &"invalid_item"
	if build == null: return &"invalid_context"
	var inventory := build.get("inventory") as RunInventory
	var actor := build.get("controller") as PlayerController
	if inventory == null: return &"invalid_context"
	if not bool(build.call("can_add", item)):
		var inventory_reason := inventory.validation_reason(item)
		return inventory_reason if not inventory_reason.is_empty() else &"invalid_context"
	if item.catalog_version < 5: return &""
	var reason := _mechanical_reason(item, actor)
	if not reason.is_empty(): return reason
	var supplied := inventory.item_ids()
	reason = _combination_reason(item, actor, supplied)
	if not reason.is_empty(): return reason
	if in_shop:
		if not FileAccess.file_exists(ECONOMY_PATH): return &"invalid_economy_policy"
		var policy: Variant = JSON.parse_string(FileAccess.get_file_as_string(ECONOMY_PATH))
		if not policy is Dictionary or not policy.get("reward_only_item_ids") is Array: return &"invalid_economy_policy"
		if String(item.stable_id) in policy.reward_only_item_ids: return &"reward_only"
	return &""

static func _mechanical_reason(item: ItemDefinition, actor: PlayerController) -> StringName:
	if not is_instance_valid(actor) or actor.shoot_ability == null or actor.shoot_ability.weapon == null: return &"invalid_context"
	var weapon := actor.shoot_ability.weapon
	if not weapon.is_valid(): return &"weapon_required"
	var id := item.stable_id
	if id in [&"B29", &"P08"] and weapon.mode not in BULLET_MODES: return &"weapon_required"
	if id == &"B22" and weapon.mode not in BOMB_MODES: return &"weapon_required"
	if id == &"B33" and weapon.mode in BOMB_MODES: return &"weapon_excluded"
	if id == &"P23" and (weapon.mode != WeaponDefinition.Mode.SINGULARITY or weapon.tier < 2): return &"weapon_required"
	if id == &"P33" and (weapon.mode != WeaponDefinition.Mode.LASER or weapon.tier < 2): return &"weapon_required"
	if id == &"P34" and (weapon.mode != WeaponDefinition.Mode.MACHINE or weapon.tier < 2): return &"weapon_required"
	if id == &"P03" and not _has_weapon_skill(actor): return &"weapon_skill_required"
	# WeaponActionRuntime actually enters charge only for these two Lv3 modes;
	# a default skill_charge field on another definition is not an implemented windup.
	if id == &"P17" and (not _has_weapon_skill(actor) or weapon.mode not in [WeaponDefinition.Mode.MACHINE, WeaponDefinition.Mode.LASER] or weapon.skill_charge <= 0): return &"charge_skill_required"
	if id in [&"B19", &"B20", &"B21", &"P13"] and (actor.traversal == null or not actor.traversal.has_capability(&"grapple")): return &"capability_required"
	if id == &"N01" and actor.air_focus_ability == null: return &"capability_required"
	return &""

static func _combination_reason(item: ItemDefinition, actor: PlayerController, supplied: Array[StringName]) -> StringName:
	var id := item.stable_id
	if id == &"G08":
		if &"P13" not in supplied or not _has_any(supplied, ItemCatalogV5.COMPANION_IDS): return &"prerequisite"
	if id == &"G15" and not _has_any(supplied, ItemCatalogV5.PROJECTILE_ACTIVE_IDS): return &"prerequisite"
	if id in [&"P02", &"P10"] and not _has_weapon_skill(actor) and not _has_any(supplied, ItemCatalogV5.ACTIVE_IDS): return &"prerequisite"
	return &""

static func _has_weapon_skill(actor: PlayerController) -> bool:
	return is_instance_valid(actor) and actor.shoot_ability != null and actor.shoot_ability.weapon != null and actor.shoot_ability.weapon.tier == 3 and not actor.shoot_ability.weapon.skill_name.is_empty()

static func _has_any(values: Array[StringName], candidates: Array[StringName]) -> bool:
	for value: StringName in candidates:
		if value in values: return true
	return false

class_name EquipmentService
extends RefCounted
## Owns the selected loadout and gear capacity. A full proposal is validated before
## BuildState applies any effect; inventory ownership never depends on loadout legality.
signal changed
var lifetime: DemoLifetime
var inventory: RunInventory
var _build_ref: WeakRef
var _policy: GearCapacityPolicy
var _implicit_lifetime := false
var _equipped_ids: Array[StringName] = []
var _level := 0
var _revision := 0
var _session := 0
var _session_serial := 0
var _session_token: DemoToken
var _router_epoch := -1
var _applying := false

func configure(build: RefCounted, scope: DemoLifetime, owned: RunInventory) -> void:
	_build_ref = weakref(build)
	inventory = owned
	_implicit_lifetime = scope == null
	lifetime = scope if scope != null else DemoLifetime.new()
	_policy = GearCapacityPolicy.load_default()

func bind_lifetime(scope: DemoLifetime) -> bool:
	if scope == null: return false
	if lifetime == scope: return true
	if not _implicit_lifetime: return false
	close_session()
	lifetime = scope
	_implicit_lifetime = false
	return true

# The owner already references EquipmentService. Keep the WeakRef return typed
# to its native base so GDScript resources do not form a BuildState/Equipment
# dependency cycle. Only the two owner effect methods cross this local bridge.
func _build() -> RefCounted:
	return _build_ref.get_ref() as RefCounted if _build_ref != null else null

func _controller() -> PlayerController:
	var owner := _build()
	return owner.get("controller") as PlayerController if owner != null else null

func _alive(token: DemoToken) -> bool:
	var actor := _controller()
	return is_instance_valid(actor) and lifetime != null and lifetime.accepts(token) and actor.active and not actor.actor_resources.health.terminal and not actor.has_pending_damage() and actor.router.has_application_focus and actor.is_inside_tree() and actor.get_tree().paused

func open_session(token: DemoToken) -> int:
	close_session()
	if not _alive(token) or not _policy.valid: return 0
	_session_serial += 1
	_session = _session_serial
	_session_token = token.copy()
	_router_epoch = _controller().router.epoch
	return _session

func close_session() -> void:
	_session_serial += 1
	_session = 0
	_session_token = null
	_router_epoch = -1

func validate_session(token: DemoToken, session: int, expected_revision: int) -> StringName:
	if _applying: return &"busy"
	if not _alive(token):
		close_session()
		return &"stale_actor"
	if session <= 0 or session != _session or _session_token == null or token.key() != _session_token.key(): return &"stale_session"
	if _controller().router.epoch != _router_epoch:
		close_session()
		return &"stale_session"
	if expected_revision != _revision: return &"stale_revision"
	return &""

func capacity() -> int:
	if _policy == null or not _policy.valid: return 0
	return _policy.initial_capacity if _level == 0 else int(_policy.upgrades[_level-1].capacity)

func equipped_ids() -> Array[StringName]:
	return _equipped_ids.duplicate()

func snapshot() -> Dictionary:
	var used := 0
	for id: StringName in _equipped_ids:
		var instance := inventory.get_instance(id)
		if instance != null: used += instance.item.gear_cost
	return {"capacity":capacity(), "used":used, "remaining":capacity()-used, "revision":_revision, "session":_session, "equipped_ids":equipped_ids(), "level":_level}

func upgrade_quote() -> Dictionary:
	var available := _policy != null and _policy.valid and _level < _policy.upgrades.size()
	var next: Dictionary = _policy.upgrades[_level] if available else {}
	return {"available":available, "level":_level, "capacity":capacity(), "next_capacity":int(next.get("capacity",capacity())), "price":int(next.get("price",0)), "quote_version":_level+1}

func preview(ids: Array[StringName]) -> Dictionary:
	var state := _build()
	var actor := _controller()
	if state == null or not _policy.valid or not is_instance_valid(actor) or not actor.active or actor.actor_resources.health.terminal: return _result(false,&"invalid_context")
	for id: StringName in _equipped_ids:
		var worn := inventory.get_instance(id)
		if worn == null: return _result(false,&"not_owned")
		# The declaration itself protects the just-committed first equip; there is
		# no deferred window in which its persistent lock can be bypassed.
		var locked := bool(worn.effect_state.get("locked",false)) or bool(worn.item.parameters_for_level(worn.level).get("locked_until_run_end",false))
		if locked and id not in ids: return _result(false,&"locked_until_run_end")
	var sources: Dictionary = {}
	var definitions: Dictionary = {}
	var used := 0
	var all_tags: Array[StringName] = []
	for id: StringName in ids:
		if sources.has(id): return _result(false,&"duplicate_instance")
		var instance := inventory.get_instance(id)
		if instance == null: return _result(false,&"not_owned")
		var item := instance.item
		sources[id] = item
		used += item.gear_cost
		definitions[item.stable_id] = int(definitions.get(item.stable_id,0))+1
		if int(definitions[item.stable_id]) > item.maximum_equipped(): return _result(false,&"equip_limit")
		for tag: StringName in item.tags:
			if tag not in all_tags: all_tags.append(tag)
	if used > capacity(): return _result(false,&"capacity_exceeded")
	for id: StringName in sources:
		var item: ItemDefinition = sources[id]
		if item.catalog_version >= 5:
			var item_reason := ItemV5Eligibility.equip_reason(item,actor,sources,inventory)
			if not item_reason.is_empty(): return _result(false,item_reason)
		for other_id: StringName in sources:
			if id == other_id: continue
			var other: ItemDefinition = sources[other_id]
			for tag: StringName in other.tags:
				if tag in item.exclusive_tags: return _result(false,&"exclusive")
		for required: StringName in item.required_tags:
			if required not in all_tags: return _result(false,&"prerequisite")
		for required: StringName in item.required_capabilities:
			if not _has_core_capability(actor,required): return _result(false,&"capability_required")
		if not item.required_weapon_id.is_empty() and actor.shoot_ability.weapon.id != item.required_weapon_id: return _result(false,&"weapon_required")
	var reason: StringName = state.call("validate_sources",sources)
	if not reason.is_empty(): return _result(false,reason)
	return {"accepted":true, "reason":&"", "sources":sources, "used":used}

func submit(ids: Array[StringName], token: DemoToken, session: int, expected_revision: int) -> Dictionary:
	var requested_ids: Array[StringName] = ids.duplicate()
	var reason := validate_session(token,session,expected_revision)
	if not reason.is_empty(): return _result(false,reason)
	var proposal := preview(requested_ids)
	if not proposal.accepted: return _result(false,proposal.reason)
	_applying = true
	if not bool(_build().call("commit_equipment_sources",proposal.sources)):
		_applying = false
		return _result(false,&"effect_rejected")
	_equipped_ids = requested_ids
	_revision += 1
	_applying = false
	call_deferred("_emit_changed")
	return _result(true,&"")

# Called only by ShopService after its validated quote/debit. No yield or signal
# can interleave debit, capacity mutation and ledger commit.
func commit_capacity_upgrade(expected_level: int) -> bool:
	if _applying or expected_level != _level or not upgrade_quote().available: return false
	_level += 1
	_revision += 1
	call_deferred("_emit_changed")
	return true

func invalidate_owned_effects() -> void:
	_revision += 1
	call_deferred("_emit_changed")

func reset() -> void:
	close_session()
	_equipped_ids.clear()
	_level = 0
	_revision += 1
	call_deferred("_emit_changed")

func _has_core_capability(actor: PlayerController, id: StringName) -> bool:
	return actor.traversal != null and actor.traversal.has_capability(id)

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted":accepted,"reason":reason}

func _emit_changed() -> void:
	changed.emit()

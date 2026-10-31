class_name ItemRuntime
extends RefCounted
## Per-run adapter for explicit item effect families. Ownership, loadout and
## damage/resource transactions remain in their existing authoritative services.
signal active_changed
signal effect_cued(kind: StringName, point: Vector2, detail: Dictionary)
var _actor: WeakRef
var _build: WeakRef
var _world: WeakRef
var _wallet: RunWallet
var _lifetime: DemoLifetime
var _map: StringName
var _clock := 0.0
var _selected: StringName
var _active_ids: Array[StringName] = []
var _effects: Dictionary = {}
var _syncing := false
var _serial := 0
var _visual_serial := 0
var _authorized: Dictionary = {}
var _packets: Dictionary = {}
var _kills: Dictionary = {}
var _combat: RefCounted
var _defense: RefCounted
var _time: RefCounted
var _actives: RefCounted
var _companions: RefCounted
var _economy: RefCounted
var _base_damage_multiplier := 1.0
var _boss_counts_as_elite := false
var _synergies: Dictionary = {}
var _instance_lookup: Dictionary = {}
var _world_run_epoch := -1
var _world_stage_epoch := -1
var _actor_session := -1

func configure(player: PlayerController, state_owner: BuildState, scope: DemoLifetime, coins: RunWallet) -> void:
	_actor = weakref(player)
	_build = weakref(state_owner)
	_lifetime = scope
	_wallet = coins
	_base_damage_multiplier = player.motor.tuning.projectile_damage
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/item_v5_runtime.json"))
	for id: String in settings.active_item_ids: _active_ids.append(StringName(id))
	_boss_counts_as_elite = bool(settings.get("boss_counts_as_elite",false))
	var recipes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/item_v5_synergies.json"))
	if recipes is Dictionary: _synergies = recipes.get("synergies", {})
	_combat = ItemCombatEffects.new()
	_defense = ItemDefenseEffects.new()
	_time = ItemTimeEffects.new()
	_actives = ItemActiveEffects.new()
	_companions = ItemCompanionEffects.new()
	_economy = ItemEconomyEffects.new()
	player.item_runtime = self
	for module: RefCounted in _modules(): module.call("configure", self)
	state_owner.changed.connect(sync)
	player.combat_energy.spent.connect(_energy_spent)
	player.shoot_ability.shot_fired.connect(func(_direction: Vector2, _shot: int) -> void: mark_combat_activity())
	sync()

func _modules() -> Array[RefCounted]:
	return [_combat, _defense, _time, _actives, _companions, _economy]

func actor() -> PlayerController:
	return _actor.get_ref() as PlayerController if _actor != null else null

func build() -> BuildState:
	return _build.get_ref() as BuildState if _build != null else null

func wallet() -> RunWallet:
	return _wallet

func world_root() -> Node2D:
	return _world.get_ref() as Node2D if _world != null else null

func map_key() -> StringName:
	return _map

func now() -> float:
	return _clock

func is_live() -> bool:
	var player := actor()
	return is_instance_valid(player) and player.is_inside_tree() and player.active and not player.actor_resources.health.terminal and player.router.has_application_focus and not player.get_tree().paused and _lifetime != null and _lifetime.active and is_instance_valid(world_root()) and _lifetime.epoch == _world_run_epoch and _lifetime.stage_epoch == _world_stage_epoch

func effect(id: StringName) -> Dictionary:
	return (_effects[id] as Dictionary).duplicate(true) if _effects.has(id) else {}

func has(id: StringName) -> bool:
	return _effects.has(id)

func synergy(id: StringName) -> Dictionary:
	var recipe: Dictionary = _synergies.get(String(id), {})
	if not bool(recipe.get("enabled",false)): return {}
	for required: String in recipe.get("required_items", []):
		if not has(StringName(required)): return {}
	return (recipe.get("parameters", {}) as Dictionary).duplicate(true)

func instance(id: StringName) -> RunItemInstance:
	if build() == null: return null
	if _instance_lookup.has(id):
		var found := build().inventory.get_instance(_instance_lookup[id])
		if found != null: return found
	var owned := build().inventory.instance_for_definition(id)
	if owned != null: _instance_lookup[id] = owned.instance_id
	return owned

func state(id: StringName) -> Dictionary:
	if build() == null: return {}
	if not _instance_lookup.has(id) and instance(id) == null: return {}
	return build().inventory.effect_state(_instance_lookup[id])

func patch_state(id: StringName, patch: Dictionary, receipt: StringName = &"") -> bool:
	var owner := build()
	var owned := instance(id)
	if owner == null or owned == null: return false
	if not owner.inventory.patch_effect_state(owned.instance_id, patch, receipt): return false
	if patch.has("broken"):
		if not owner.refresh_equipped(): return false
		sync()
	return true

func sync() -> void:
	if _syncing or build() == null or not is_instance_valid(actor()): return
	_syncing = true
	_effects.clear()
	for id: StringName in build().equipment.equipped_ids():
		var owned := build().inventory.get_instance(id)
		if owned != null and owned.item.catalog_version == 5 and not bool(owned.effect_state.get("broken", false)):
			_effects[owned.definition_id] = owned.item.parameters_for_level(owned.level)
	# Re-equipping a source cannot revive receipts cancelled when it was removed.
	for receipt: Variant in _authorized.keys():
		if not has(StringName(_authorized[receipt].origin)): _authorized.erase(receipt)
	var vessel := effect(&"B26")
	actor().combat_energy.set_capacity_bonus(float(vessel.get("max_resonance_add", 0.0)))
	var available := equipped_active_ids()
	if _selected not in available:
		_selected = available[0] if not available.is_empty() else &""
		active_changed.emit()
	for module: RefCounted in _modules():
		if module != null: module.call("sync")
	_syncing = false

func bind_world(world: Node2D, key: StringName) -> void:
	before_stage_change()
	_world = weakref(world)
	_map = key
	_world_run_epoch = _lifetime.epoch
	_world_stage_epoch = _lifetime.stage_epoch
	_actor_session = actor().session_id
	_authorized.clear()
	_packets.clear()
	_kills.clear()
	sync()
	for module: RefCounted in _modules(): module.call("map_entered", key)

func before_stage_change() -> void:
	if _time != null: _time.call("release_world")
	if _defense != null: _defense.call("clear_world_entities")
	if _actives != null: _actives.call("clear")
	if _companions != null: _companions.call("clear")
	_world = null
	_world_run_epoch = -1
	_world_stage_epoch = -1

func advance(real_delta: float, world_delta: float) -> void:
	if not is_live():
		if _time != null: _time.call("release_world")
		return
	if not is_finite(real_delta) or real_delta <= 0.0: return
	if _actor_session != actor().session_id:
		_actor_session = actor().session_id
		sync()
	_clock += real_delta
	var step := 0.0 if world_is_frozen() else maxf(0.0, world_delta)
	# Called after the one real Motor step: path effects observe actual motion.
	for module: RefCounted in _modules(): module.call("advance", real_delta, step)
	if world_is_frozen(): _time.call("refresh_world_scope")

func clear() -> void:
	before_stage_change()
	_effects.clear()
	_instance_lookup.clear()
	_authorized.clear()
	_kills.clear()
	_selected = &""

func equipped_active_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _active_ids:
		if has(id): result.append(id)
	return result

func selected_active() -> StringName:
	return _selected

func select_active(id: StringName) -> bool:
	if id not in equipped_active_ids(): return false
	_selected = id
	active_changed.emit()
	return true

func active_capable(id: StringName) -> bool:
	return id in _active_ids

func activate_selected(direction: Vector2) -> Dictionary:
	if not is_live() or _selected.is_empty() or not has(_selected): return {"accepted":false,"reason":&"unavailable"}
	# A resource callback may change selection/loadout during the existing cast.
	# Preserve only its visual identity; cost, return and skill hooks stay owned
	# by the original activation path below.
	var activated_id := _selected
	var visual_context := _presentation_context()
	var cast_point := actor().motor.global_position
	var result: Dictionary
	if _selected == &"G05": result = _companions.call("activate", _selected, direction)
	elif _selected in [&"P26", &"P27", &"N02"]: result = _defense.call("activate", _selected, direction)
	else: result = _actives.call("activate", _selected, direction)
	if bool(result.get("accepted", false)):
		_serial += 1
		var visual_event := StringName("item_cast/%s" % _serial)
		on_skill_started(StringName("item_cast/%s" % _serial))
		var visual := visual_context.duplicate()
		visual["item"] = activated_id
		visual["event_id"] = visual_event
		cue(&"active",cast_point,visual)
	else: cue(&"rejected",cast_point,result)
	return result

func base_damage() -> float:
	return actor().shoot_ability.weapon.damage * _base_damage_multiplier if is_instance_valid(actor()) else 0.0

func skill_cost(amount: float) -> float:
	var params := effect(&"P02")
	if params.is_empty(): return amount
	var cost := amount * float(params.skill_combat_energy_cost_multiplier)
	var discount := synergy(&"S10")
	if not discount.is_empty():
		var maps: Dictionary = state(&"G07").get("synergy_s10_maps", {})
		if bool((maps.get(String(_map), {}) as Dictionary).get("armed",false)): cost -= float(discount.skill_cost_credit)
	return maxf(float(params.minimum_skill_cost), cost)

func spend_energy(amount: float, receipt: StringName, active_skill: bool = true) -> bool:
	return is_live() and actor().combat_energy.consume(String(receipt), skill_cost(amount) if active_skill else amount)

func grant_energy(amount: float, receipt: StringName) -> float:
	return actor().combat_energy.grant(String(receipt), amount) if is_live() else 0.0

func heal(amount: float, receipt: StringName, origin: StringName = &"", visual_proof: Variant = null) -> bool:
	if not is_live(): return false
	# null means an ordinary resource caller. An explicitly supplied activation
	# proof, even empty/stale, must never be replaced after its spend callbacks.
	var visual: Dictionary = presentation_receipt(origin,receipt) if visual_proof == null else visual_proof.duplicate(true) if visual_proof is Dictionary else {}
	var point := actor().motor.global_position
	var health := actor().actor_resources.health
	var result := health.heal(ActorResourceRequest.new(receipt, health.epoch, amount, health.get_instance_id()))
	var applied := result.status == ActorResourceResult.Status.APPLIED and result.amount_applied > 0.0
	if applied: present_committed(&"heal",point,visual,{"amount":result.amount_applied})
	return applied

# A bounded presentation identity around the existing commit. It never accepts
# a transaction, retains an actor, changes HP/cost or authorizes damage.
func presentation_receipt(origin: StringName, event_id: StringName) -> Dictionary:
	if origin.is_empty() or event_id.is_empty() or not is_live() or not has(origin) or not _source_current(origin): return {}
	var value := _presentation_context()
	value["definition_id"] = origin
	value["event_id"] = event_id
	return value

func _presentation_context() -> Dictionary:
	if not is_live(): return {}
	return {"session":actor().session_id,"run_epoch":_lifetime.epoch,"stage_epoch":_lifetime.stage_epoch,"actor_epoch":_lifetime.actor_epoch,"weapon_epoch":actor().shoot_ability.weapon_epoch,"equipment_revision":int(build().equipment.snapshot().revision),"map_key":_map,"world_id":world_root().get_instance_id()}

func present_committed(kind: StringName, point: Vector2, proof: Dictionary, detail: Dictionary = {}) -> bool:
	if kind not in [&"heal",&"barrier",&"item_guard_active",&"item_rescue_committed",&"item_break_bell_committed"] or proof.is_empty() or not point.is_finite(): return false
	var origin: Variant = proof.get("definition_id")
	var event: Variant = proof.get("event_id")
	if not (origin is String or origin is StringName) or not (event is String or event is StringName): return false
	if proof != presentation_receipt(StringName(origin),StringName(event)): return false
	var payload := proof.duplicate(true)
	payload.merge(detail,false)
	cue(kind,point,payload)
	return true

func presentation_mark(origin: StringName, receiver: Damageable) -> Dictionary:
	if _combat == null or not has(origin) or not _source_current(origin): return {}
	return _combat.call("presentation_mark",origin,receiver)

func barrier_grant(amount: int, receipt: StringName) -> int:
	return int(_defense.call("grant_barrier", amount, receipt))

func barrier_count() -> int:
	return int(_defense.call("barrier_count"))

func targets(point: Vector2, radius: float) -> Array[Dictionary]:
	if not is_live() or radius <= 0 or not is_finite(radius): return []
	var result := actor().shoot_ability.behavior().receivers(point, radius)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := point.distance_squared_to((a.node as Node2D).global_position)
		var db := point.distance_squared_to((b.node as Node2D).global_position)
		if da != db: return da < db
		var a_receiver := a.receiver as Damageable
		var b_receiver := b.receiver as Damageable
		var left_id := a_receiver.actor_id if a_receiver.actor_id != 0 else a_receiver.get_instance_id()
		var right_id := b_receiver.actor_id if b_receiver.actor_id != 0 else b_receiver.get_instance_id()
		var left := str((a.node as Node).get_meta("item_v5_enemy_id", "%020d" % left_id))
		var right := str((b.node as Node).get_meta("item_v5_enemy_id", "%020d" % right_id))
		return left < right)
	return result

func clear_line(a: Vector2, b: Vector2) -> bool:
	return is_live() and actor().shoot_ability.behavior().clear_line(a, b)

func deal(receiver: Damageable, amount: float, key: StringName, origin: StringName, after_commit: Callable = Callable()) -> bool:
	return _deal(receiver, amount, key, origin, &"", after_commit)

func deal_active(receiver: Damageable, amount: float, key: StringName, origin: StringName, packet: StringName) -> bool:
	return _deal(receiver, amount, key, origin, packet)

func _deal(receiver: Damageable, amount: float, key: StringName, origin: StringName, packet: StringName, after_commit: Callable = Callable()) -> bool:
	if not is_live() or not is_instance_valid(receiver) or not receiver.active or receiver.faction != &"enemy" or key.is_empty() or not has(origin) or not _source_current(origin) or not is_finite(amount) or amount <= 0: return false
	if not receiver.can_receive_effects(): return false
	var player := actor()
	var expected_session := player.session_id
	var expected_stage := _lifetime.stage_epoch
	var expected_weapon := player.shoot_ability.weapon_epoch
	# Presentation receipts carry the already-authenticated source identity.
	var visual_run := _lifetime.epoch
	var visual_actor := _lifetime.actor_epoch
	var visual_map := _map
	var visual_world := world_root().get_instance_id()
	var visual_equipment := int(build().equipment.snapshot().revision)
	var event := StringName("item/%s/%s/%s" % [_map, origin, key])
	if _authorized.has(event): return false
	var point := (receiver.get_parent() as Node2D).global_position
	var context := {"session_id":expected_session,"event_id":event,"source_actor_id":player.motor.get_instance_id(),"source_faction":&"player","target_actor_id":receiver.actor_id,"target_epoch":receiver.damage_epoch,"amount":amount,"damage_type":&"item_effect","skill_attack":true,"item_effect_damage":true,"item_origin":origin,"hit_point":point,"hit_direction":(point-player.motor.global_position).normalized()}
	var hit_direction: Vector2 = context.hit_direction
	_authorized[event] = {"receiver":receiver.damage_policy_owner().get_instance_id(),"epoch":receiver.damage_epoch,"amount":amount,"session":expected_session,"stage":expected_stage,"weapon":expected_weapon,"origin":origin,"equipment_revision":int(build().equipment.snapshot().revision)}
	var current_packet := 0
	if not packet.is_empty():
		if not _packets.has(packet):
			_serial += 1
			_packets[packet] = _serial
		current_packet = int(_packets[packet])
	context.on_committed = func() -> void:
		if not is_live() or player.session_id != expected_session or _lifetime.stage_epoch != expected_stage or player.shoot_ability.weapon_epoch != expected_weapon or not is_instance_valid(receiver): return
		mark_combat_activity()
		_record_kill(receiver, event)
		if after_commit.is_valid(): after_commit.call()
		if not packet.is_empty():
			on_hit({"session":expected_session,"packet":current_packet,"shot":current_packet,"airborne":not player.motor.is_on_floor(),"skill":true,"item_active":true,"primary":false,"receiver":receiver,"point":point,"direction":hit_direction,"amount":amount,"weapon_id":player.shoot_ability.weapon.id,"tier":player.shoot_ability.weapon.tier,"origin_id":origin,"weapon_epoch":expected_weapon})
		# Policy invokes on_committed only after positive HP loss and death priority.
		# Earlier callbacks may remove equipment or change maps, so recheck only
		# the visual source. A killed receiver need not be alive to show its hit.
		if is_live() and actor() == player and player.session_id == expected_session and _lifetime.epoch == visual_run and _lifetime.actor_epoch == visual_actor and _lifetime.stage_epoch == expected_stage and player.shoot_ability.weapon_epoch == expected_weapon and has(origin) and _source_current(origin) and int(build().equipment.snapshot().revision) == visual_equipment and _map == visual_map and world_root().get_instance_id() == visual_world and _authorized.has(event):
			cue(&"item_committed_impact",point,{"definition_id":origin,"event_id":event,"direction":hit_direction,"session":expected_session,"run_epoch":visual_run,"stage_epoch":expected_stage,"actor_epoch":visual_actor,"weapon_epoch":expected_weapon,"equipment_revision":visual_equipment,"map_key":visual_map,"world_id":visual_world})
	var accepted := receiver.receive_damage(context)
	if not accepted: _authorized.erase(event)
	return accepted

func authorizes_effect(context: Dictionary, receiver: Damageable) -> bool:
	var event := StringName(context.get("event_id", &""))
	if not is_live() or not is_instance_valid(receiver) or not _authorized.has(event): return false
	var proof: Dictionary = _authorized[event]
	if not _source_current(StringName(proof.origin)): return false
	# Equipment commits are synchronous; presentation/cache notifications are
	# deferred. Read the authoritative revision so immediate resume/resolve is
	# safe, including unload/reload before either notification is delivered.
	if int(proof.equipment_revision) != int(build().equipment.snapshot().revision): return false
	return has(StringName(proof.origin)) and proof.receiver == receiver.damage_policy_owner().get_instance_id() and proof.epoch == receiver.damage_epoch and is_equal_approx(float(proof.amount), float(context.get("amount", -1))) and proof.session == actor().session_id and proof.stage == _lifetime.stage_epoch and proof.weapon == actor().shoot_ability.weapon_epoch and proof.origin == StringName(context.get("item_origin", &""))

func _source_current(origin: StringName) -> bool:
	var owned := instance(origin)
	return owned != null and owned.instance_id in build().equipment.equipped_ids() and not bool(owned.effect_state.get("broken",false))

func burst(point: Vector2, radius: float, ratio: float, origin: StringName, receipt: StringName) -> int:
	var count := 0
	for row: Dictionary in targets(point, radius):
		if clear_line(point, row.node.global_position) and deal(row.receiver, base_damage()*ratio, StringName("%s/%s" % [receipt, row.receiver.actor_id]), origin): count += 1
	return count

func on_hit(event: Dictionary) -> void:
	if not is_live() or int(event.get("session", actor().session_id)) != actor().session_id: return
	if event.has("weapon_epoch") and int(event.weapon_epoch) != actor().shoot_ability.weapon_epoch: return
	var receiver := event.get("receiver") as Damageable
	if not is_instance_valid(receiver): return
	mark_combat_activity()
	_record_kill(receiver, StringName("weapon/%s/%s/%s" % [actor().session_id, event.get("packet",0), receiver.actor_id]))
	_combat.call("on_hit", event)
	_time.call("on_hit", event)
	_economy.call("on_hit", event)

func on_hook_hit(receiver: Damageable, packet: int) -> void:
	if not is_live() or not is_instance_valid(receiver) or receiver.faction != &"enemy": return
	var receipt := StringName("hook/%s/%s/%s" % [actor().session_id, packet, receiver.actor_id])
	_combat.call("on_hook_hit", receiver, receipt)
	var row := _enemy_event(receiver, receipt)
	_economy.call("on_hook", row)
	_record_kill(receiver, receipt)
	on_hit({"session":actor().session_id,"packet":packet,"shot":packet,"hook":true,"airborne":not actor().motor.is_on_floor(),"skill":false,"receiver":receiver,"point":row.point,"direction":actor().traversal.hook_direction,"amount":actor().traversal.definition.hook_damage,"weapon_id":actor().shoot_ability.weapon.id,"tier":actor().shoot_ability.weapon.tier})

func _enemy_event(receiver: Damageable, receipt: StringName) -> Dictionary:
	var body := receiver.get_parent() as Node2D
	var boss := body.get_node_or_null("Encounter") != null
	var enemy_id := StringName(str(body.get_meta("item_v5_enemy_id", receiver.actor_id if receiver.actor_id != 0 else receiver.get_instance_id())))
	return {"enemy_id":enemy_id,"id":enemy_id,"key":StringName("%s/%s" % [_map,enemy_id]),"receipt":receipt,"map":_map,"boss":boss,"elite":bool(body.get_meta("item_v5_elite",false)) or (boss and _boss_counts_as_elite),"point":body.global_position}

func _record_kill(receiver: Damageable, receipt: StringName) -> void:
	if receiver.active or _kills.has(receiver.actor_id): return
	var row := _enemy_event(receiver, receipt)
	_kills[receiver.actor_id] = row
	_economy.call("on_kill", row)
	_companions.call("on_kill", row)

func has_kill(receiver: Damageable) -> bool:
	return is_instance_valid(receiver) and _kills.has(receiver.actor_id)

func settle_kill_coins(amount: int, key: StringName) -> int:
	return int(_economy.call("settle_kill_coins", amount, key))

func can_magnet_pickup(pickup: Dictionary, position: Vector2, clock: float) -> bool:
	return bool(_economy.call("can_magnet_pickup", pickup, position, clock))

func on_damage(event: Dictionary) -> void:
	if not is_live(): return
	_defense.call("on_damage", event)
	_economy.call("on_damage", event)

func defend_request(request: DamageRequest, current_hp: float) -> Dictionary:
	return _defense.call("defend_request", request, current_hp)

func monster_iframe(base: float) -> float:
	return float(_defense.call("monster_iframe", base))

func _energy_spent(receipt: String, amount: float) -> void:
	if not is_live(): return
	_companions.call("on_energy_spent", amount, StringName(receipt))
	_economy.call("on_energy_spent", amount, StringName(receipt))

func mark_combat_activity() -> void:
	if _economy != null: _economy.call("mark_combat_activity")

func on_skill_started(receipt: StringName) -> void:
	mark_combat_activity()
	_combat.call("on_skill_started", receipt)
	if has(&"G07") and has(&"P02"):
		var maps: Dictionary = state(&"G07").get("synergy_s10_maps", {}).duplicate(true)
		var row: Dictionary = maps.get(String(_map), {}).duplicate(true)
		if bool(row.get("armed",false)):
			row.armed = false
			row.consumed = true
			maps[String(_map)] = row
			patch_state(&"G07", {"synergy_s10_maps":maps}, StringName("S10/consume/%s" % receipt))

func on_idle_recovery(amount: float) -> void:
	var params := synergy(&"S10")
	if amount <= 0 or params.is_empty(): return
	var maps: Dictionary = state(&"G07").get("synergy_s10_maps", {}).duplicate(true)
	var row: Dictionary = maps.get(String(_map), {}).duplicate(true)
	var was_armed := bool(row.get("armed",false))
	row.recovered = float(row.get("recovered",0.0)) + amount
	if float(row.recovered) >= float(params.recovery_threshold) and not bool(row.get("consumed",false)): row.armed = true
	maps[String(_map)] = row
	if patch_state(&"G07", {"synergy_s10_maps":maps}) and not was_armed and bool(row.get("armed",false)):
		cue(&"skill_credit_ready", actor().motor.global_position, {"origin":&"G07","amount":float(params.skill_cost_credit)})

func on_blink(start: Vector2, finish: Vector2) -> void:
	_combat.call("on_blink", start, finish)
	if _defense.has_method("on_blink"): _defense.call("on_blink", start, finish)

func world_is_frozen() -> bool:
	return _time != null and bool(_time.call("world_is_frozen"))

func is_marked(receiver: Damageable) -> bool:
	return bool(_combat.call("is_marked", receiver))

func mark_key(receiver: Damageable) -> StringName:
	return _combat.call("mark_key", receiver)

func is_dream_marked(receiver: Damageable) -> bool:
	return bool(_combat.call("is_dream_marked", receiver))

func dream_mark_key(receiver: Damageable) -> StringName:
	return _combat.call("dream_mark_key", receiver)

func modify_direct_damage(amount: float, receiver: Damageable, skill: bool, packet: int) -> float:
	return float(_combat.call("modify_direct_damage", amount, receiver, skill, packet))

func primary_packet_started(packet: int, direction: Vector2 = Vector2.ZERO) -> void:
	_combat.call("primary_packet_started", packet, direction)
	mark_combat_activity()

func primary_damage_multiplier(packet: int) -> float:
	return float(_combat.call("primary_damage_multiplier", packet))

func weapon_cooldown_multiplier() -> float:
	return float(_combat.call("weapon_cooldown_multiplier"))

func projectile_range_multiplier() -> float:
	return float(_combat.call("projectile_range_multiplier"))

func extra_pierce() -> Dictionary:
	return _combat.call("extra_pierce")

func bomb_radius_multiplier() -> float:
	return float(_combat.call("bomb_radius_multiplier"))

func laser_width_multiplier() -> float:
	return float(_combat.call("laser_width_multiplier"))

func singularity_hold_add() -> float:
	return float(_combat.call("singularity_hold_add"))

func singularity_damage_multiplier() -> float:
	return float(_combat.call("singularity_damage_multiplier"))

func enemy_stagger_multiplier() -> float:
	return float(_combat.call("enemy_stagger_multiplier"))

func charge_move_multiplier() -> float:
	return float(_combat.call("charge_move_multiplier"))

func cue(kind: StringName, point: Vector2, detail: Dictionary = {}) -> void:
	var payload := detail.duplicate(true)
	# Existing synchronous cast/state observers get a publication identity.
	# Never stamp HP/resource/rescue committed kinds: those require their actual
	# commit proof. Never refresh even a partial carried identity on re-delivery.
	if kind in [&"arc",&"item_arc",&"cloud",&"ring",&"mark",&"echo",&"item_blast",&"item_throw_burst",&"item_clock_pulse",&"item_active_cast",&"active",&"item_drone_fire",&"coin",&"item_guard_evolved",&"item_large_guard_summoned",&"synergy_bell",&"time_refund",&"skill_credit_ready",&"defense_active",&"projectile_intercept",&"item_echo_armed",&"item_motion_path"]:
		var carried := false
		for field: String in ["session","run_epoch","stage_epoch","actor_epoch","weapon_epoch","equipment_revision","map_key","world_id"]:
			if payload.has(field): carried = true
		if not carried:
			var identity := _presentation_context()
			if not identity.is_empty():
				_visual_serial += 1
				identity["event_id"] = StringName("visual/%s/%s/%s/%s" % [_lifetime.epoch,_lifetime.stage_epoch,actor().session_id,_visual_serial])
				payload.merge(identity,false)
	effect_cued.emit(kind, point, payload)
	var player := actor()
	if not is_instance_valid(player): return
	if kind == &"rejected": GameAudio.cue(player, &"denied")
	elif kind == &"synergy_bell": GameAudio.cue(player, &"bell")
	elif kind in [&"active", &"barrier", &"heal"]: GameAudio.cue(player, &"confirm")

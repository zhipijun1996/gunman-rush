class_name ItemEconomyEffects
extends RefCounted
## Explicit consumers of accepted death/hook/loot events. The app keeps ownership
## of pickup/Meta receipts and calls this policy before its original transaction.
var _host_ref: WeakRef
var _last_combat := 0.0
var _recovery_credit := 0.0
var _map: StringName

func configure(host: RefCounted) -> void:
	_host_ref = weakref(host)
	_last_combat = _now()

func _host() -> RefCounted:
	return _host_ref.get_ref() as RefCounted if _host_ref != null else null

func _effect(id: StringName) -> Dictionary:
	var host := _host()
	return host.call("effect", id) as Dictionary if host != null else {}

func _state(id: StringName) -> Dictionary:
	var host := _host()
	return host.call("state", id) as Dictionary if host != null else {}

func _patch(id: StringName, patch: Dictionary, receipt: StringName) -> bool:
	var host := _host()
	return host != null and bool(host.call("patch_state", id, patch, receipt))

func _now() -> float:
	var host := _host()
	return float(host.call("now")) if host != null else 0.0

func _map_key() -> StringName:
	var host := _host()
	return StringName(host.call("map_key")) if host != null else &""

func _live() -> bool:
	var host := _host()
	return host != null and bool(host.call("is_live"))

func _instance(id: StringName) -> RunItemInstance:
	var host := _host()
	return host.call("instance", id) as RunItemInstance if host != null else null

func _wallet() -> RunWallet:
	var host := _host()
	return host.call("wallet") as RunWallet if host != null else null

func _coin_patch(id: StringName, patch: Dictionary, amount: int, receipt: StringName) -> bool:
	var host := _host()
	var coins := _wallet()
	var state := host.call("build") as BuildState if host != null else null
	if coins == null or state == null or state.inventory == null or amount <= 0: return false
	var savepoint := state.inventory._transaction_snapshot()
	if not _patch(id, patch, StringName("%s/state" % receipt)): return false
	if coins.grant(amount, receipt): return true
	state.inventory._restore_transaction(savepoint)
	return false

func sync() -> void:
	# Equipping never resets a map's earning budget or the last combat time.
	if _effect(&"G07").is_empty(): _recovery_credit = 0.0

func map_entered(key: StringName) -> void:
	if key == _map: return
	_map = key
	_last_combat = _now()
	_recovery_credit = 0.0

func mark_combat_activity() -> void:
	_last_combat = _now()
	_recovery_credit = 0.0

func on_hit(_event: Dictionary) -> void:
	mark_combat_activity()

func on_damage(_event: Dictionary) -> void:
	mark_combat_activity()

func on_energy_spent(amount: float, _receipt: StringName) -> void:
	if amount > 0.0: mark_combat_activity()

func advance(real_delta: float, _world_delta: float) -> void:
	if not _live() or not is_finite(real_delta) or real_delta <= 0.0: return
	var parameters := _effect(&"G07")
	var map := _map_key()
	if parameters.is_empty() or map.is_empty():
		_recovery_credit = 0.0
		return
	var delay := float(parameters.get("idle_delay_s", 0.0))
	var rate := float(parameters.get("resonance_per_s", 0.0))
	var budget := float(parameters.get("max_recovery_per_map", 0.0))
	if not is_finite(delay) or not is_finite(rate) or not is_finite(budget) or delay < 0.0 or rate <= 0.0 or budget <= 0.0: return
	var elapsed := _now() - _last_combat
	if elapsed < delay: return
	# Include only the part of a boundary frame after the six-second idle gate.
	var eligible_delta := minf(real_delta, maxf(0.0, elapsed - delay))
	_recovery_credit += rate * eligible_delta
	if _recovery_credit <= 0.000001: return
	var instance := _instance(&"G07")
	if instance == null: return
	var owned := _state(&"G07")
	var maps: Dictionary = owned.get("recovery_maps", {}).duplicate(true)
	var row: Dictionary = maps.get(String(map), {}).duplicate(true)
	var recovered := float(row.get("recovered", 0.0))
	var amount := minf(_recovery_credit, maxf(0.0, budget - recovered))
	var actor := _host().call("actor") as PlayerController
	if actor == null or actor.combat_energy == null: return
	var energy: RefCounted = actor.combat_energy
	var capacity := float(energy.call("capacity")) if energy.has_method("capacity") else actor.combat_energy.definition.capacity
	amount = minf(amount, maxf(0.0, capacity - actor.combat_energy.current))
	if amount <= 0.000001:
		# A full bar or exhausted map cannot bank a later burst by unequipping.
		_recovery_credit = 0.0
		return
	var serial := int(row.get("serial", 0)) + 1
	var receipt := StringName("item/G07/%s/%s/recovery/%s" % [instance.instance_id, map, serial])
	var actual := float(_host().call("grant_energy", amount, receipt))
	if actual <= 0.0: return
	row.recovered = recovered + actual
	row.serial = serial
	maps[String(map)] = row
	var committed := _patch(&"G07", {"recovery_maps": maps}, StringName("%s/state" % receipt))
	var source := _host()
	if committed and source != null and source.has_method("on_idle_recovery"):
		source.call("on_idle_recovery", actual)
	_recovery_credit = maxf(0.0, _recovery_credit - actual)

func on_kill(event: Dictionary) -> Dictionary:
	if not _valid_event(event): return {"accepted": false, "coins": 0}
	mark_combat_activity()
	var amount := 0
	for id: StringName in [&"B16", &"G10"]:
		amount += _kill_bonus(id, event)
	return {"accepted": true, "coins": amount}

func _valid_event(event: Dictionary) -> bool:
	return _live() and not StringName(event.get("enemy_id", &"")).is_empty() and not StringName(event.get("receipt", &"")).is_empty() and StringName(event.get("map", _map_key())) == _map_key() and not _map_key().is_empty()

func _kill_bonus(id: StringName, event: Dictionary) -> int:
	var parameters := _effect(id)
	var instance := _instance(id)
	var coins := _wallet()
	if parameters.is_empty() or instance == null or coins == null: return 0
	var limit := int(parameters.get("max_bonus_kills_per_map", 0))
	var amount := int(parameters.get("bonus_coin_per_kill", 0))
	if limit <= 0 or amount <= 0: return 0
	var map := String(_map_key())
	var enemy := String(event.enemy_id)
	var owned := _state(id)
	var maps: Dictionary = owned.get("kill_maps", {}).duplicate(true)
	var row: Dictionary = maps.get(map, {}).duplicate(true)
	var rewarded: Dictionary = row.get("rewarded_enemies", {}).duplicate(true)
	if rewarded.has(enemy) or rewarded.size() >= limit: return 0
	rewarded[enemy] = amount
	row.rewarded_enemies = rewarded
	row.coins = int(row.get("coins", 0)) + amount
	maps[map] = row
	var receipt := StringName("item/%s/%s/%s/kill/%s" % [id, instance.instance_id, map, enemy])
	# Both operations are synchronous; patch signals are deferred. The grant key
	# binds the authoritative owned instance, map and enemy, so replay cannot mint.
	if not _coin_patch(id, {"kill_maps": maps}, amount, receipt): return 0
	_host().call("cue", &"coin", event.get("point", Vector2.ZERO), {"item": id, "amount": amount, "magnet_bonus": id == &"B16" and not _effect(&"B01").is_empty()})
	return amount

func on_hook(event: Dictionary) -> Dictionary:
	if not _valid_event(event) or bool(event.get("boss", false)): return {"accepted": false, "coins": 0}
	mark_combat_activity()
	var parameters := _effect(&"B20")
	var instance := _instance(&"B20")
	var coins := _wallet()
	if parameters.is_empty() or instance == null or coins == null: return {"accepted": false, "coins": 0}
	var map := String(_map_key())
	var enemy := String(event.enemy_id)
	var maps: Dictionary = _state(&"B20").get("hook_maps", {}).duplicate(true)
	var row: Dictionary = maps.get(map, {}).duplicate(true)
	var enemies: Dictionary = row.get("rewarded_enemies", {}).duplicate(true)
	var amount := mini(int(parameters.get("coin_per_enemy", 0)), maxi(0, int(parameters.get("map_coin_cap", 0)) - int(row.get("coins", 0))))
	if enemies.has(enemy) or amount <= 0: return {"accepted": false, "coins": 0}
	enemies[enemy] = amount
	row.rewarded_enemies = enemies
	row.coins = int(row.get("coins", 0)) + amount
	maps[map] = row
	var receipt := StringName("item/B20/%s/%s/hook/%s" % [instance.instance_id, map, enemy])
	if not _coin_patch(&"B20", {"hook_maps": maps}, amount, receipt): return {"accepted": false, "coins": 0}
	_host().call("cue", &"coin", event.get("point", Vector2.ZERO), {"item": &"B20", "amount": amount})
	return {"accepted": true, "coins": amount}

func settle_kill_coins(base_amount: int, kill_key: StringName) -> int:
	# Called only when creating the immutable enemy drop. This never touches
	# chest/room rewards, refunds, Meta notes or a later pickup receipt.
	if base_amount < 0 or kill_key.is_empty(): return base_amount
	var instance := _instance(&"P39")
	if instance == null: return base_amount
	var owned := _state(&"P39")
	var receipts: Dictionary = owned.get("kill_coin_receipts", {}).duplicate(true)
	var key := "%s/%s" % [_map_key(), kill_key]
	if receipts.has(key): return int(receipts[key].amount)
	var parameters := _effect(&"P39")
	if not _live() or parameters.is_empty(): return base_amount
	var multiplier := float(parameters.get("kill_coin_multiplier", 1.0))
	if not is_finite(multiplier) or multiplier < 1.0: return base_amount
	var bonus := float(base_amount) * (multiplier - 1.0) + float(owned.get("kill_coin_fraction", 0.0))
	var extra := int(floor(bonus + 0.00000001))
	var amount := base_amount + extra
	receipts[key] = {"base": base_amount, "amount": amount}
	if not _patch(&"P39", {"kill_coin_receipts": receipts, "kill_coin_fraction": maxf(0.0, bonus - extra)}, StringName("item/P39/%s/%s" % [instance.instance_id, key])): return base_amount
	return amount

func can_magnet_pickup(pickup: Dictionary, player_position: Vector2, clock: float) -> bool:
	var parameters := _effect(&"B01")
	if not _live() or parameters.is_empty() or not player_position.is_finite() or not is_finite(clock): return false
	if bool(pickup.get("claimed", false)) or bool(pickup.get("reward_object", false)) or bool(pickup.get("shop_stock", false)): return false
	var kind := String(pickup.get("kind", ""))
	var canonical := {"coin": "coin", "note": "meta_note", "meta_note": "meta_note", "heart": "health_pickup", "health_pickup": "health_pickup", "energy": "energy_pickup", "energy_pickup": "energy_pickup"}
	if not canonical.has(kind) or int(parameters.get("auto_collect_reward_objects", 0)) != 0: return false
	var mask := String(parameters.get("resource_pickup_mask", "")).split("|")
	if canonical[kind] not in mask or clock < float(pickup.get("ready_at", 0.0)): return false
	var position: Variant = pickup.get("position", Vector2.INF)
	var target := Vector2.INF
	if position is Vector2: target = position
	elif position is Array and position.size() == 2 and (position[0] is int or position[0] is float) and (position[1] is int or position[1] is float): target = Vector2(float(position[0]), float(position[1]))
	var radius := float(parameters.get("pickup_radius_px", 0.0))
	return target.is_finite() and is_finite(radius) and radius > 0.0 and player_position.distance_to(target) <= radius and bool(_host().call("clear_line", player_position, target))

func shop_rarity_weights(base_weights: Dictionary) -> Dictionary:
	return ShopService.adjusted_rarity_weights(base_weights, _effect(&"G12"))

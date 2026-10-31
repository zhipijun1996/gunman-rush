class_name ItemCompanionEffects
extends RefCounted
## Bounded mechanical companions. Their hits are derived: no resonance or procs.
## Lifetimes and attack cadence advance only with the game world's delta.
const ENTITY := preload("res://scripts/items/v5/item_v5_entity.gd")
var _host_ref: WeakRef
var _casts: ItemActiveCast
var _tuning: Dictionary = {}
var _drones: Array[Dictionary] = []
var _world_time := 0.0
var _serial := 0
var _casting := false
var _pending_marks: Dictionary = {}
var _pending_attacks: Dictionary = {}

func configure(host: RefCounted) -> void:
	clear()
	_host_ref = weakref(host)
	_casts = ItemActiveCast.new(host)
	_world_time = 0.0
	_serial = 0
	_tuning = ENTITY.read_tuning()

func _host() -> RefCounted:
	return _host_ref.get_ref() as RefCounted if _host_ref != null else null

func _actor() -> PlayerController:
	var host := _host()
	return host.call("actor") as PlayerController if host != null else null

func _effect(id: StringName) -> Dictionary:
	var host := _host()
	return host.call("effect", id) if host != null else {}

func clear() -> void:
	for drone: Dictionary in _drones: _dispose(drone)
	_drones.clear()
	_casting = false
	_pending_marks.clear()
	_pending_attacks.clear()

func map_entered(_key: StringName) -> void:
	# Per-owned state (progress, spend remainder, cooldown) is deliberately retained.
	clear()
	sync()

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for drone: Dictionary in _drones:
		var view := drone.visual as ItemV5Entity
		result.append({"id":drone.id, "kind":drone.kind, "slot":drone.slot, "age":maxf(0,_world_time-float(drone.born_at)), "position":view.global_position if is_instance_valid(view) else Vector2.INF, "next_attack_at":drone.next_attack_at, "expires_at":drone.expires_at, "target_lock_id":drone.get("target_lock_id",0), "target_mark_key":drone.get("target_mark_key",&"")})
	return result

func sync() -> void:
	for i: int in range(_drones.size()-1, -1, -1):
		if not _valid_drone(_drones[i]):
			_dispose(_drones[i])
			_drones.remove_at(i)
	var host := _host()
	var actor := _actor()
	var world := host.call("world_root") as Node2D if host != null else null
	if host == null or not is_instance_valid(actor) or not actor.active or actor.actor_resources.health.terminal or not is_instance_valid(world) or not world.is_inside_tree() or _tuning.is_empty(): return
	var small := _effect(&"P14")
	if not small.is_empty():
		for index: int in clampi(int(small.small_drone_count),0,3):
			var slot := StringName("permanent/%s" % index)
			if not _has_slot(&"P14", slot): _spawn(&"P14", &"small_drone", slot, float(small.attack_interval_s), float(small.attack_damage_ratio_D), -1.0)
	var growth := _effect(&"G19")
	if not growth.is_empty() and not _has_slot(&"G19", &"permanent"):
		_spawn(&"G19", &"growth_drone", &"permanent", float(growth.attack_interval_s), float(growth.base_damage_ratio_D), -1.0)
	if not _dream_synergy():
		for drone: Dictionary in _drones:
			if drone.id == &"P14": _clear_lock(drone)

func preview(id: StringName, direction: Vector2) -> Dictionary:
	var host := _host()
	var actor := _actor()
	if _casting: return _result(false, &"busy")
	if id != &"G05": return _result(false, &"not_companion_active")
	if host == null or not bool(host.call("is_live")) or not is_instance_valid(actor) or _tuning.is_empty(): return _result(false, &"stale_actor")
	var params := _effect(id)
	if params.is_empty(): return _result(false, &"not_equipped")
	var world := host.call("world_root") as Node2D
	if not is_instance_valid(world) or not world.is_inside_tree(): return _result(false, &"no_world")
	if not direction.is_finite() or direction.is_zero_approx(): return _result(false, &"invalid_direction")
	if _count(id) >= mini(1,int(params.max_large_drones)): return _result(false, &"entity_limit")
	var stored: Dictionary = host.call("state", id)
	if float(stored.get("cooldown_until", 0)) > float(host.call("now"))+1e-9: return _result(false, &"cooldown")
	var cost: float = host.call("skill_cost", float(params.combat_energy_cost))
	if not actor.combat_energy.can_consume(cost): return _result(false, &"combat_energy")
	return {"accepted":true, "reason":&"", "cost":cost}

func activate(id: StringName, direction: Vector2) -> Dictionary:
	sync()
	var quote := preview(id, direction)
	if not quote.accepted: return quote
	var host := _host()
	var params := _effect(id)
	var prepared := _casts.prepare(id)
	var receipt: StringName = prepared.receipt
	_casting = true
	if not _casts.commit(prepared, float(params.combat_energy_cost), float(params.skill_cooldown_s)):
		_casting = false
		return _result(false, &"combat_energy")
	_spawn(id, &"large_drone", receipt, float(params.attack_interval_s), float(params.attack_damage_ratio_D), float(params.lifetime_s))
	_casting = false
	host.call("cue", &"item_large_guard_summoned", _actor().motor.global_position, {"packet":receipt, "definition_id":id})
	return {"accepted":true, "reason":&"", "receipt":receipt, "cost":quote.cost}

func on_energy_spent(amount: float, receipt: StringName) -> void:
	var host := _host()
	var params := _effect(&"P15")
	if host == null or params.is_empty() or not bool(host.call("is_live")) or amount <= 0 or not is_finite(amount) or receipt.is_empty(): return
	var world := host.call("world_root") as Node2D
	if not is_instance_valid(world) or not world.is_inside_tree(): return
	var stored: Dictionary = host.call("state", &"P15")
	var spent_receipts: Dictionary = stored.get("spent_receipts", {}).duplicate(true)
	if spent_receipts.has(String(receipt)): return
	spent_receipts[String(receipt)] = true
	var accumulated := float(stored.get("spent_remainder", 0.0))+amount
	var threshold := float(params.combat_energy_spent_threshold)
	if threshold <= 0: return
	var earned := int(floor(accumulated/threshold))
	var remainder := accumulated-threshold*earned
	# Only an incomplete threshold is carried. A full field never banks a hidden
	# queue of drones to appear without a new paid spend after earlier ones expire.
	if not bool(host.call("patch_state", &"P15", {"spent_remainder":remainder, "spent_receipts":spent_receipts}, StringName("P15/spend/%s" % receipt))): return
	for index: int in mini(earned, maxi(0, mini(2,int(params.max_temp_drones))-_count(&"P15"))):
		_spawn(&"P15", &"temporary_drone", StringName("%s/%s" % [receipt,index]), float(_tuning.companion.temporary_attack_interval_s), float(params.temp_drone_damage_ratio_D), float(params.temp_drone_lifetime_s))

func on_kill(event: Dictionary) -> void:
	var host := _host()
	var params := _effect(&"G19")
	if host == null or params.is_empty() or not bool(host.call("is_live")) or not bool(event.get("elite", false)): return
	if event.has("map") and StringName(str(event.map)) != StringName(str(host.call("map_key"))): return
	var key := str(event.get("key", event.get("id", "")))
	if key.is_empty(): return
	var stored: Dictionary = host.call("state", &"G19")
	var kills: Dictionary = stored.get("evolution_receipts", {}).duplicate(true)
	if kills.has(key): return
	var level := int(stored.get("evolution", 0))
	if level >= int(params.evolution_levels): return
	kills[key] = true
	host.call("patch_state", &"G19", {"evolution":level+1, "evolution_receipts":kills}, StringName("G19/evolution/%s" % key))
	host.call("cue", &"item_guard_evolved", _actor().motor.global_position, {"definition_id":&"G19", "evolution":level+1, "kill":key})

func advance(_real_delta: float, world_delta: float) -> void:
	var host := _host()
	if host == null: clear(); return
	if not bool(host.call("is_live")): return
	sync()
	# The original damage policy resolves accepted requests before the next
	# controller tick. An uncommitted request must not consume a mark forever.
	_pending_marks.clear()
	_pending_attacks.clear()
	if not is_finite(world_delta) or world_delta <= 0: return
	_world_time += world_delta
	for i: int in range(_drones.size()-1, -1, -1):
		var drone: Dictionary = _drones[i]
		if float(drone.expires_at) >= 0 and _world_time >= float(drone.expires_at):
			_dispose(drone)
			_drones.remove_at(i)
			continue
		var view := drone.visual as ItemV5Entity
		_update_position(drone, world_delta)
		view.step_visual(world_delta)
	var assign_patrol := false
	for drone: Dictionary in _drones:
		if drone.id == &"P14" and _world_time+1e-9 >= float(drone.next_attack_at): assign_patrol = true
	if assign_patrol and _dream_synergy(): _assign_patrol_locks()
	for drone: Dictionary in _drones:
		var view := drone.visual as ItemV5Entity
		if _world_time+1e-9 >= float(drone.next_attack_at):
			var target := _locked_target(drone) if drone.id == &"P14" and _dream_synergy() else _target(view.global_position)
			if not target.is_empty():
				_fire(drone, target)
				drone.next_attack_at = _world_time+float(drone.interval)
				_remember_attack_wait(drone)

func _spawn(id: StringName, kind: StringName, slot: StringName, interval: float, ratio: float, lifetime: float) -> void:
	var host := _host()
	var actor := _actor()
	var world := host.call("world_root") as Node2D
	var view := ENTITY.new() as ItemV5Entity
	view.kind = kind
	view.radius = float(_tuning.visual.large_drone_radius_px if kind == &"large_drone" else _tuning.visual.drone_radius_px)
	view.set_meta("item_definition_id", id)
	world.add_child(view)
	view.global_position = actor.motor.global_position
	_serial += 1
	var stored: Dictionary = host.call("state", id)
	var waits: Dictionary = stored.get("companion_attack_deadlines", {})
	var next_attack := maxf(_world_time+interval, float(waits.get(String(slot), 0.0)))
	var drone := {"id":id, "kind":kind, "slot":slot, "serial":_serial, "visual":view, "born_at":_world_time, "expires_at":_world_time+lifetime if lifetime >= 0 else -1.0, "interval":interval, "ratio":ratio, "next_attack_at":next_attack, "attack_sequence":0, "map":host.call("map_key"), "session":actor.session_id, "weapon_epoch":actor.shoot_ability.weapon_epoch, "world_id":world.get_instance_id()}
	_drones.append(drone)
	_remember_attack_wait(drone)
	_update_position(drone, 0.0)

func _valid_drone(drone: Dictionary) -> bool:
	var host := _host()
	var actor := _actor()
	var world := host.call("world_root") as Node2D if host != null else null
	return host != null and is_instance_valid(actor) and is_instance_valid(world) and is_instance_valid(drone.visual) and bool(host.call("has", drone.id)) and drone.map == host.call("map_key") and int(drone.session) == actor.session_id and int(drone.weapon_epoch) == actor.shoot_ability.weapon_epoch and int(drone.world_id) == world.get_instance_id()

func _has_slot(id: StringName, slot: StringName) -> bool:
	for drone: Dictionary in _drones:
		if drone.id == id and drone.slot == slot and _valid_drone(drone): return true
	return false

func _count(id: StringName) -> int:
	var count := 0
	for drone: Dictionary in _drones:
		if drone.id == id and _valid_drone(drone): count += 1
	return count

func _update_position(drone: Dictionary, delta: float) -> void:
	var actor := _actor()
	var view := drone.visual as ItemV5Entity
	var center := actor.motor.global_position
	var settings: Dictionary = _tuning.companion
	var radius := float(settings.large_orbit_radius_px if drone.kind == &"large_drone" else settings.orbit_radius_px)
	var angle := _world_time*float(settings.orbit_speed_rad_s)+float(int(drone.serial)%8)*TAU/8.0
	var desired := center+Vector2(cos(angle)*radius, float(settings.orbit_height_px)+sin(angle)*radius*0.35)
	var ray := PhysicsRayQueryParameters2D.create(center, desired, 1, [actor.motor.get_rid()])
	var hit := actor.motor.get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): desired = hit.position+hit.normal*3.0
	view.global_position = desired if delta <= 0 else view.global_position.lerp(desired, clampf(delta*float(settings.follow_speed),0,1))
	# A moving wall or a new player position must never strand a firing origin on
	# the far side of solid terrain while the purely visual follower catches up.
	var host := _host()
	if not bool(host.call("clear_line", center, view.global_position)): view.global_position = center
	if drone.id == &"G19":
		var stored: Dictionary = host.call("state", &"G19")
		view.evolved = int(stored.get("evolution", 0))

func _target(point: Vector2) -> Dictionary:
	var host := _host()
	var candidates: Array = host.call("targets", point, float(_tuning.companion.acquire_radius_px))
	var ordinary: Dictionary = {}
	var prioritise := not _effect(&"G08").is_empty()
	for value: Dictionary in candidates:
		var receiver := value.receiver as Damageable
		if not is_instance_valid(receiver) or not receiver.can_receive_effects(): continue
		if not bool(host.call("clear_line", point, (value.node as Node2D).global_position)): continue
		if ordinary.is_empty(): ordinary = value
		if prioritise and bool(host.call("is_marked", value.receiver)): return value
	return ordinary

func _dream_synergy() -> bool:
	return not _effect(&"P14").is_empty() and not _effect(&"B19").is_empty()

func _assign_patrol_locks() -> void:
	# S02 concerns the three P14 patrol devices. Other companion families retain
	# their own targeting contract. Stable serial order resolves an overfull old
	# lock, and a per-device receipt survives until that target stops being legal.
	var patrols: Array[Dictionary] = []
	for drone: Dictionary in _drones:
		if drone.id == &"P14" and _valid_drone(drone): patrols.append(drone)
	patrols.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.serial) < int(b.serial))
	var counts: Dictionary = {}
	var choices: Dictionary = {}
	var unassigned: Array[Dictionary] = []
	for drone: Dictionary in patrols:
		var candidates := _patrol_candidates(drone)
		choices[int(drone.serial)] = candidates
		var existing: Dictionary = {}
		for candidate: Dictionary in candidates:
			var receiver := candidate.receiver as Damageable
			if int(drone.get("target_lock_id",0)) == receiver.get_instance_id() and int(drone.get("target_lock_epoch",-1)) == receiver.damage_epoch and int(candidate.rank) == int(candidates[0].rank):
				existing = candidate
				break
		if not existing.is_empty() and int(counts.get((existing.receiver as Damageable).get_instance_id(),0)) < 2:
			_set_lock(drone, existing)
			var id := (existing.receiver as Damageable).get_instance_id()
			counts[id] = int(counts.get(id,0))+1
		else:
			_clear_lock(drone)
			unassigned.append(drone)
	for drone: Dictionary in unassigned:
		for candidate: Dictionary in choices[int(drone.serial)]:
			var id := (candidate.receiver as Damageable).get_instance_id()
			if int(counts.get(id,0)) >= 2: continue
			_set_lock(drone, candidate)
			counts[id] = int(counts.get(id,0))+1
			break

func _patrol_candidates(drone: Dictionary) -> Array[Dictionary]:
	var host := _host()
	var point := (drone.visual as ItemV5Entity).global_position
	var candidates: Array = host.call("targets", point, float(_tuning.companion.acquire_radius_px))
	var result: Array[Dictionary] = []
	var seek_pursuit := not _effect(&"G08").is_empty()
	for value: Dictionary in candidates:
		var receiver := value.receiver as Damageable
		if not is_instance_valid(receiver) or not receiver.can_receive_effects(): continue
		var node := value.node as Node2D
		if not bool(host.call("clear_line", point, node.global_position)): continue
		var pursuit := seek_pursuit and bool(host.call("is_marked", receiver))
		var dream := bool(host.call("is_dream_marked", receiver))
		var candidate: Dictionary = value.duplicate()
		candidate["rank"] = 0 if pursuit else 1 if dream else 2
		candidate["mark_key"] = host.call("mark_key", receiver) if pursuit else host.call("dream_mark_key", receiver) if dream else &""
		result.append(candidate)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if int(a.rank) != int(b.rank): return int(a.rank) < int(b.rank)
		var a_distance := point.distance_squared_to((a.node as Node2D).global_position)
		var b_distance := point.distance_squared_to((b.node as Node2D).global_position)
		return (a.receiver as Damageable).get_instance_id() < (b.receiver as Damageable).get_instance_id() if is_equal_approx(a_distance,b_distance) else a_distance < b_distance)
	return result

func _set_lock(drone: Dictionary, candidate: Dictionary) -> void:
	var receiver := candidate.receiver as Damageable
	if not is_instance_valid(receiver) or not receiver.can_receive_effects():
		_clear_lock(drone)
		return
	drone["target_lock"] = weakref(receiver)
	drone["target_lock_id"] = receiver.get_instance_id()
	drone["target_lock_epoch"] = receiver.damage_epoch
	drone["target_mark_key"] = candidate.mark_key

func _clear_lock(drone: Dictionary) -> void:
	drone.erase("target_lock")
	drone["target_lock_id"] = 0
	drone["target_lock_epoch"] = -1
	drone["target_mark_key"] = &""

func _locked_target(drone: Dictionary) -> Dictionary:
	if not drone.get("target_lock") is WeakRef: return {}
	var receiver := (drone.target_lock as WeakRef).get_ref() as Damageable
	if not is_instance_valid(receiver) or not receiver.can_receive_effects() or receiver.damage_epoch != int(drone.target_lock_epoch):
		_clear_lock(drone)
		return {}
	var node := receiver.get_parent() as Node2D
	if not is_instance_valid(node): return {}
	var host := _host()
	var point := (drone.visual as ItemV5Entity).global_position
	if point.distance_to(node.global_position) > float(_tuning.companion.acquire_radius_px) or not bool(host.call("clear_line",point,node.global_position)): return {}
	return {"node":node,"receiver":receiver}

func _fire(drone: Dictionary, target: Dictionary) -> void:
	var host := _host()
	var receiver := target.receiver as Damageable
	# Cached targets must still be eligible before sequence/mark reservations.
	if not is_instance_valid(receiver) or not receiver.can_receive_effects(): return
	var view := drone.visual as ItemV5Entity
	var ratio := float(drone.ratio)
	if drone.id == &"G19":
		var params := _effect(&"G19")
		var stored: Dictionary = host.call("state", &"G19")
		ratio *= 1.0+float(stored.get("evolution",0))*float(params.damage_bonus_per_level_pct)/100.0
	var mark := StringName(str(host.call("mark_key", receiver)))
	var mark_params := _effect(&"G08")
	var marks_used: Dictionary = {}
	var use_mark := false
	if not mark_params.is_empty() and not mark.is_empty():
		var stored: Dictionary = host.call("state", &"G08")
		marks_used = stored.get("used_mark_keys", {}).duplicate(true)
		use_mark = not marks_used.has(String(mark)) and not _pending_marks.has(mark)
		if use_mark: ratio *= float(mark_params.marked_companion_first_hit_multiplier)
	drone.attack_sequence = int(drone.attack_sequence)+1
	var receipt := StringName("%s/companion/%s/%s/%s/%s" % [drone.map, drone.session, drone.id, drone.serial, drone.attack_sequence])
	var committed := Callable()
	if use_mark:
		_pending_marks[mark] = receipt
		_pending_attacks[receipt] = {"map":drone.map, "session":drone.session, "weapon_epoch":drone.weapon_epoch}
		committed = _mark_committed.bind(mark,receipt)
	if bool(host.call("deal", receiver, float(host.call("base_damage"))*ratio, receipt, drone.id, committed)):
		view.beam_end = (target.node as Node2D).global_position
		view.beam_remaining = float(_tuning.companion.beam_visible_s)
		view.marked = not mark.is_empty()
		host.call("cue", &"item_drone_fire", view.global_position, {"end":view.beam_end, "definition_id":drone.id, "receipt":receipt, "marked":view.marked})
	elif use_mark:
		_pending_attacks.erase(receipt)
		if _pending_marks.get(mark) == receipt: _pending_marks.erase(mark)

func _mark_committed(mark: StringName, receipt: StringName) -> void:
	if not _pending_attacks.has(receipt): return
	var pending: Dictionary = _pending_attacks[receipt]
	_pending_attacks.erase(receipt)
	if _pending_marks.get(mark) == receipt: _pending_marks.erase(mark)
	var host := _host()
	var actor := _actor()
	if host == null or not is_instance_valid(actor) or pending.map != host.call("map_key") or int(pending.session) != actor.session_id or int(pending.weapon_epoch) != actor.shoot_ability.weapon_epoch: return
	var stored: Dictionary = host.call("state", &"G08")
	var marks_used: Dictionary = stored.get("used_mark_keys", {}).duplicate(true)
	if marks_used.has(String(mark)): return
	marks_used[String(mark)] = true
	host.call("patch_state", &"G08", {"used_mark_keys":marks_used}, StringName("G08/first/%s" % mark))

func _remember_attack_wait(drone: Dictionary) -> void:
	# Only permanent slots need a persistent deadline; transient slots already
	# have a unique paid birth and cannot be recreated by sync after unloading.
	if drone.id not in [&"P14", &"G19"]: return
	var host := _host()
	var stored: Dictionary = host.call("state", drone.id)
	var waits: Dictionary = stored.get("companion_attack_deadlines", {}).duplicate(true)
	waits[String(drone.slot)] = float(drone.next_attack_at)
	host.call("patch_state", drone.id, {"companion_attack_deadlines":waits})

func _dispose(drone: Dictionary) -> void:
	var view := drone.get("visual") as ItemV5Entity
	if is_instance_valid(view) and not view.is_queued_for_deletion(): view.queue_free()

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted":accepted, "reason":reason}

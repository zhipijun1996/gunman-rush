class_name ItemActiveEffects
extends RefCounted
## Item actives use their own input slot. They never call weapon LV3 or Motor.
## Cooldowns use real active time; travelling entities and pulses use world time.
const ENTITY := preload("res://scripts/items/v5/item_v5_entity.gd")
const IDS: Array[StringName] = [&"B33", &"P24", &"P25", &"G14", &"G16"]
var _host_ref: WeakRef
var _tuning: Dictionary = {}
var _entities: Array[Dictionary] = []
var _casting := false

func configure(host: RefCounted) -> void:
	clear()
	_host_ref = weakref(host)
	_tuning = ENTITY.read_tuning()

func _host() -> RefCounted:
	return _host_ref.get_ref() as RefCounted if _host_ref != null else null

func _actor() -> PlayerController:
	var host := _host()
	return host.call("actor") as PlayerController if host != null else null

func _effect(id: StringName) -> Dictionary:
	var host := _host()
	return host.call("effect", id) if host != null else {}

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entities:
		var view := entry.visual as ItemV5Entity
		result.append({"id":entry.id, "kind":entry.kind, "cast":entry.cast, "phase":entry.get("phase", &""), "direction":entry.direction, "position":view.global_position if is_instance_valid(view) else Vector2.INF, "age":entry.age})
	return result

func clear() -> void:
	for entry: Dictionary in _entities:
		_dispose(entry)
	_entities.clear()
	_casting = false

func map_entered(_key: StringName) -> void:
	clear()

func sync() -> void:
	for i: int in range(_entities.size()-1, -1, -1):
		if not _valid_entry(_entities[i]):
			_dispose(_entities[i])
			_entities.remove_at(i)

func preview(id: StringName, direction: Vector2) -> Dictionary:
	var host := _host()
	var actor := _actor()
	if _casting: return _result(false, &"busy")
	if id not in IDS: return _result(false, &"not_item_active")
	if host == null or not bool(host.call("is_live")) or not is_instance_valid(actor) or _tuning.is_empty(): return _result(false, &"stale_actor")
	var params := _effect(id)
	if params.is_empty(): return _result(false, &"not_equipped")
	var world := host.call("world_root") as Node2D
	if not is_instance_valid(world) or not world.is_inside_tree(): return _result(false, &"no_world")
	if not direction.is_finite() or direction.is_zero_approx(): return _result(false, &"invalid_direction")
	var stored: Dictionary = host.call("state", id)
	if float(stored.get("cooldown_until", 0)) > float(host.call("now"))+1e-9: return _result(false, &"cooldown")
	if not params.has("combat_energy_cost") or _cooldown(params) <= 0: return _result(false, &"invalid_parameters")
	var cost: float = host.call("skill_cost", float(params.combat_energy_cost))
	if not actor.combat_energy.can_consume(cost): return _result(false, &"combat_energy")
	var placement: Dictionary = {}
	if id == &"P25":
		if _count(id) >= int(params.max_active_traps): return _result(false, &"entity_limit")
		placement = _ground_placement()
		if placement.is_empty(): return _result(false, &"reliable_ground_required")
	elif id == &"P24" and _count(id) > 0:
		return _result(false, &"entity_limit")
	return {"accepted":true, "reason":&"", "cost":cost, "placement":placement, "direction":direction.normalized()}

func activate(id: StringName, direction: Vector2) -> Dictionary:
	sync()
	var quote := preview(id, direction)
	if not quote.accepted: return quote
	var host := _host()
	var actor := _actor()
	var params := _effect(id)
	var stored: Dictionary = host.call("state", id)
	var sequence := int(stored.get("cast_sequence", 0))+1
	var cast := StringName("%s/item/%s/%s/%s" % [host.call("map_key"), actor.session_id, id, sequence])
	_casting = true
	# No yield, external placement or target selection may fail after this debit.
	# All physical preconditions were resolved by preview in the same tick.
	if not bool(host.call("spend_energy", float(params.combat_energy_cost), cast)):
		_casting = false
		return _result(false, &"combat_energy")
	host.call("patch_state", id, {"cast_sequence":sequence, "cooldown_until":float(host.call("now"))+_cooldown(params)}, StringName("%s/state" % cast))
	var point := actor.motor.global_position
	var unit: Vector2 = quote.direction
	match id:
		&"B33":
			_active_burst(point, float(params.radius_px), float(params.damage_ratio_D), id, cast, &"blast")
		&"P24", &"G14":
			var split := _effect(&"G15")
			var count := clampi(int(split.get("projectile_count_multiplier", 1)),1,2)
			var budget := float(split.get("total_damage_budget_multiplier", 1.0))
			for i: int in count:
				var half_angle: float = _tuning.projection.split_half_angle_rad
				# S13 is a bidirectional flywheel, not two overlapping forward
				# copies. Other thrown projectiles keep their own split geometry.
				var aim := unit if count == 1 or id == &"P24" else unit.rotated(lerpf(-half_angle, half_angle, float(i)/float(count-1)))
				if id == &"P24" and i == 1: aim = -unit
				var entry := _spawn(id, &"flywheel" if id == &"P24" else &"throw", point, aim, cast, params)
				entry["projectile_index"] = i
				entry["budget_multiplier"] = budget/float(count)
		&"P25":
			var entry := _spawn(id, &"trap", quote.placement.point, unit, cast, params)
			entry["support"] = weakref(quote.placement.collider)
			entry["attachment"] = (quote.placement.collider as Node2D).to_local(quote.placement.point)
		&"G16":
			var entry := _spawn(id, &"pulses", point, unit, cast, params)
			entry["pulse_index"] = 0
			entry["next_pulse"] = 0.0
			_step_pulses(entry, 0.0)
	_casting = false
	host.call("cue", &"item_active_cast", point, {"definition_id":id, "packet":cast, "direction":unit})
	return {"accepted":true, "reason":&"", "receipt":cast, "cost":quote.cost}

func advance(_real_delta: float, world_delta: float) -> void:
	var host := _host()
	if host == null: clear(); return
	# Pause/focus suspends; it does not erase paid entities or restart cooldowns.
	if not bool(host.call("is_live")): return
	sync()
	if not is_finite(world_delta) or world_delta <= 0: return
	for i: int in range(_entities.size()-1, -1, -1):
		var entry: Dictionary = _entities[i]
		entry.age = float(entry.age)+world_delta
		var view := entry.visual as ItemV5Entity
		view.step_visual(world_delta)
		match entry.kind:
			&"flywheel": _step_flywheel(entry, world_delta)
			&"throw": _step_throw(entry, world_delta)
			&"trap": _step_trap(entry)
			&"pulses": _step_pulses(entry, world_delta)
		if bool(entry.get("spent", false)):
			_dispose(entry)
			_entities.remove_at(i)

func _spawn(id: StringName, kind: StringName, point: Vector2, unit: Vector2, cast: StringName, params: Dictionary) -> Dictionary:
	var host := _host()
	var actor := _actor()
	var view := ENTITY.new() as ItemV5Entity
	view.kind = &"pulse" if kind == &"pulses" else kind
	view.direction = unit
	view.radius = float(_tuning.visual.flywheel_radius_px if kind == &"flywheel" else _tuning.visual.throw_radius_px if kind == &"throw" else _tuning.visual.trap_radius_px if kind == &"trap" else params.get("range_px", 0))
	view.cone_half_angle = float(_tuning.pulse.half_angle_rad)
	view.set_meta("item_definition_id", id)
	var world := host.call("world_root") as Node2D
	world.add_child(view)
	view.global_position = point
	var entry := {"id":id, "kind":kind, "cast":cast, "params":params.duplicate(true), "visual":view, "age":0.0, "phase":&"outbound", "travelled":0.0, "direction":unit, "ignored":[], "hits":{}, "target_hits":{}, "spent":false, "map":host.call("map_key"), "session":actor.session_id, "weapon_epoch":actor.shoot_ability.weapon_epoch, "world_id":world.get_instance_id(), "damage_D":float(host.call("base_damage"))}
	_entities.append(entry)
	return entry

func _valid_entry(entry: Dictionary) -> bool:
	var host := _host()
	var actor := _actor()
	var world := host.call("world_root") as Node2D if host != null else null
	return host != null and is_instance_valid(actor) and is_instance_valid(world) and is_instance_valid(entry.visual) and not bool(entry.get("spent", false)) and bool(host.call("has", entry.id)) and entry.map == host.call("map_key") and int(entry.session) == actor.session_id and int(entry.weapon_epoch) == actor.shoot_ability.weapon_epoch and int(entry.world_id) == world.get_instance_id()

func _count(id: StringName) -> int:
	var count := 0
	for entry: Dictionary in _entities:
		if entry.id == id and _valid_entry(entry): count += 1
	return count

func _cooldown(params: Dictionary) -> float:
	return float(params.get("cooldown_s", params.get("skill_cooldown_s", 0.0)))

func _step_flywheel(entry: Dictionary, delta: float) -> void:
	if bool(entry.get("spent", false)): return
	if float(entry.age) >= float(_tuning.projection.flywheel_lifetime_s): entry.spent = true; return
	var view := entry.visual as ItemV5Entity
	var actor := _actor()
	var outbound: bool = entry.phase == &"outbound"
	var remaining := maxf(0.0, float(entry.params.range_px)-float(entry.travelled)) if outbound else view.global_position.distance_to(actor.motor.global_position)
	if not outbound and remaining <= float(_tuning.projection.collision_radius_px)*2.0:
		entry.spent = true
		return
	var unit: Vector2 = entry.direction if outbound else (actor.motor.global_position-view.global_position).normalized()
	var travel := minf(remaining, float(_tuning.projection.speed)*delta)
	var finish := view.global_position+unit*travel
	var exclusions: Array[RID] = []
	exclusions.assign(entry.ignored)
	for _attempt: int in 32:
		var contact := _contact(view.global_position, finish, exclusions)
		if contact.is_empty(): break
		var receiver := contact.get("receiver") as Damageable
		if receiver != null: receiver.physical_impact(contact.point)
		# An ineligible physical receiver is still solid armour. Do not add its
		# RID to the pass-through exclusions or spend a legal target's hit budget.
		if receiver == null or not receiver.can_receive_effects():
			view.global_position = contact.point+contact.normal*float(_tuning.projection.collision_radius_px)
			if outbound:
				entry.phase = &"returning"
				entry.ignored = []
			else: entry.spent = true
			return
		var target_key := "%s/%s" % [receiver.get_instance_id(), receiver.damage_epoch]
		var hit_key := "%s/%s" % [entry.phase, target_key]
		if not entry.hits.has(hit_key) and int(entry.target_hits.get(target_key,0)) < int(entry.params.max_target_hits):
			var ratio := float(entry.params.total_damage_ratio_D)*float(entry.budget_multiplier)/float(entry.params.max_target_hits)
			if _deal_active(receiver, float(entry.damage_D)*ratio, StringName("%s/%s/%s" % [entry.cast, entry.projectile_index, hit_key]), entry.id, entry.cast):
				entry.hits[hit_key] = true
				entry.target_hits[target_key] = int(entry.target_hits.get(target_key,0))+1
		exclusions.append(contact.rid)
		entry.ignored.append(contact.rid)
	view.global_position = finish
	entry.travelled = float(entry.travelled)+travel if outbound else float(entry.travelled)
	if outbound and travel >= remaining-0.001:
		entry.phase = &"returning"
		entry.ignored = []

func _step_throw(entry: Dictionary, delta: float) -> void:
	if bool(entry.get("spent", false)): return
	var view := entry.visual as ItemV5Entity
	var remaining := maxf(0.0, float(_tuning.projection.throw_range_px)-float(entry.travelled))
	var travel := minf(remaining, float(_tuning.projection.speed)*delta)
	var finish: Vector2 = view.global_position+entry.direction*travel
	var contact := _contact(view.global_position, finish, [])
	if not contact.is_empty():
		var receiver := contact.get("receiver") as Damageable
		if receiver != null: receiver.physical_impact(contact.point)
		view.global_position = contact.point+contact.normal*0.5
		_explode_throw(entry, receiver)
		return
	view.global_position = finish
	entry.travelled = float(entry.travelled)+travel
	if travel >= remaining-0.001 or float(entry.age) >= float(_tuning.projection.throw_lifetime_s): _explode_throw(entry, null)

func _explode_throw(entry: Dictionary, collision_target: Damageable) -> void:
	if bool(entry.spent): return
	entry.spent = true
	var host := _host()
	var view := entry.visual as ItemV5Entity
	var point := view.global_position
	# A chassis hit still terminates the physical throw. Only an eligible
	# receiver within the explosion's real acquire radius may become primary.
	var primary := collision_target if _eligible(collision_target) else null
	if primary == null:
		var nearby: Array = host.call("targets", point, float(_tuning.projection.throw_main_acquire_radius_px))
		for value: Dictionary in nearby:
			var receiver := value.receiver as Damageable
			if not _eligible(receiver): continue
			if bool(host.call("clear_line", point, (value.node as Node2D).global_position)):
				primary = receiver
				break
	var hit: Dictionary = {}
	if primary == null or not _deal_active(primary, float(entry.damage_D)*float(entry.params.throw_damage_ratio_D)*float(entry.budget_multiplier), StringName("%s/%s/impact/%s" % [entry.cast, entry.projectile_index, primary.get_instance_id()]), entry.id, entry.cast):
		host.call("cue", &"item_throw_burst", view.global_position, {"definition_id":entry.id, "packet":entry.cast})
		return
	hit[primary.get_instance_id()] = true
	var target_node := primary.get_parent() as Node2D
	if target_node != null: point = target_node.global_position
	var chain_count := 0
	for _i: int in int(entry.params.chain_targets):
		var chosen: Dictionary = {}
		var nearby: Array = host.call("targets", point, float(_tuning.projection.throw_chain_radius_px))
		for candidate: Dictionary in nearby:
			var receiver := candidate.receiver as Damageable
			if not _eligible(receiver) or hit.has(receiver.get_instance_id()): continue
			if not bool(host.call("clear_line", point, (candidate.node as Node2D).global_position)): continue
			# A refused candidate never consumes a chain hop. Ownership and
			# receipts still belong to the actual equipped G14 instance.
			if bool(host.call("deal", receiver, float(entry.damage_D)*float(entry.params.chain_damage_ratio_D)*float(entry.budget_multiplier), StringName("%s/%s/chain/%s" % [entry.cast, entry.projectile_index, chain_count]), &"G14")):
				chosen = candidate
				break
		if chosen.is_empty(): break
		var receiver := chosen.receiver as Damageable
		hit[receiver.get_instance_id()] = true
		var next := (chosen.node as Node2D).global_position
		host.call("cue", &"item_arc", point, {"end":next, "definition_id":entry.id, "packet":entry.cast})
		point = next
		chain_count += 1
	host.call("cue", &"item_throw_burst", view.global_position, {"definition_id":entry.id, "packet":entry.cast})

func _step_trap(entry: Dictionary) -> void:
	var support := (entry.support as WeakRef).get_ref() as Node2D
	if not is_instance_valid(support) or not support.is_inside_tree(): entry.spent = true; return
	var view := entry.visual as ItemV5Entity
	view.global_position = support.to_global(entry.attachment)
	if float(entry.age) >= float(entry.params.trap_lifetime_s): entry.spent = true; return
	var host := _host()
	var nearby: Array = host.call("targets", view.global_position, float(entry.params.radius_px))
	var found := false
	for value: Dictionary in nearby:
		if not _eligible(value.receiver as Damageable): continue
		if bool(host.call("clear_line", view.global_position, (value.node as Node2D).global_position)):
			found = true
			break
	if found:
		entry.spent = true
		_active_burst(view.global_position, float(entry.params.radius_px), float(entry.params.trap_damage_ratio_D), entry.id, entry.cast, &"trap", float(entry.damage_D))

func _step_pulses(entry: Dictionary, _delta: float) -> void:
	var host := _host()
	var view := entry.visual as ItemV5Entity
	var gap: float = _tuning.pulse.interval_s
	var duration: float = _tuning.pulse.visual_duration_s
	while int(entry.pulse_index) < int(entry.params.pulse_count) and float(entry.age)+1e-9 >= float(entry.next_pulse):
		var index := int(entry.pulse_index)
		var targets: Array = host.call("targets", view.global_position, float(entry.params.range_px))
		for value: Dictionary in targets:
			if not _eligible(value.receiver as Damageable): continue
			var offset := (value.node as Node2D).global_position-view.global_position
			var facing: Vector2 = entry.direction
			if absf(facing.angle_to(offset)) > float(_tuning.pulse.half_angle_rad): continue
			if not bool(host.call("clear_line", view.global_position, (value.node as Node2D).global_position)): continue
			var receiver := value.receiver as Damageable
			_deal_active(receiver, float(entry.damage_D)*float(entry.params.damage_ratio_D_each), StringName("%s/pulse/%s/%s" % [entry.cast, index, receiver.get_instance_id()]), entry.id, entry.cast)
		host.call("cue", &"item_clock_pulse", view.global_position, {"direction":entry.direction, "range":entry.params.range_px, "index":index, "packet":entry.cast})
		entry.pulse_index = index+1
		entry.next_pulse = float(entry.next_pulse)+gap
	view.progress = clampf((float(entry.age)-maxf(0, float(entry.next_pulse)-gap))/duration, 0, 1)
	if int(entry.pulse_index) >= int(entry.params.pulse_count) and float(entry.age) >= float(entry.next_pulse)-gap+duration: entry.spent = true

func _active_burst(point: Vector2, radius: float, ratio: float, id: StringName, cast: StringName, stage: StringName, damage_D := -1.0) -> void:
	var host := _host()
	var base := float(host.call("base_damage")) if damage_D < 0 else damage_D
	var targets: Array = host.call("targets", point, radius)
	for value: Dictionary in targets:
		if not _eligible(value.receiver as Damageable): continue
		if not bool(host.call("clear_line", point, (value.node as Node2D).global_position)): continue
		var receiver := value.receiver as Damageable
		_deal_active(receiver, base*ratio, StringName("%s/%s/%s" % [cast, stage, receiver.get_instance_id()]), id, cast)
	host.call("cue", &"item_blast", point, {"radius":radius, "definition_id":id, "packet":cast})

func _eligible(receiver: Damageable) -> bool:
	return is_instance_valid(receiver) and receiver.can_receive_effects()

func _deal_active(receiver: Damageable, amount: float, key: StringName, origin: StringName, packet: StringName) -> bool:
	if not _eligible(receiver): return false
	return bool(_host().call("deal_active", receiver, amount, key, origin, packet))

func _ground_placement() -> Dictionary:
	var actor := _actor()
	if not actor.motor.is_on_floor(): return {}
	var settings: Dictionary = _tuning.trap
	var center := actor.motor.global_position
	var space := actor.motor.get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(center, center+Vector2.DOWN*float(settings.ground_probe_px), 1, [actor.motor.get_rid()])
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or not hit.collider is Node2D or (hit.normal as Vector2).dot(Vector2.UP) < float(settings.floor_normal_min_up_dot): return {}
	for side: int in [-1,1]:
		var offset := Vector2(float(side)*float(settings.half_base_width_px), 0)
		var sample := space.intersect_ray(PhysicsRayQueryParameters2D.create(center+offset, center+offset+Vector2.DOWN*float(settings.ground_probe_px), 1, [actor.motor.get_rid()]))
		if sample.is_empty() or sample.rid != hit.rid or absf(float(sample.position.y)-float(hit.position.y)) > float(settings.ground_tolerance_px): return {}
	return {"point":hit.position+hit.normal*float(settings.surface_offset_px), "collider":hit.collider}

func _contact(start: Vector2, finish: Vector2, ignored: Array[RID]) -> Dictionary:
	if start.is_equal_approx(finish): return {}
	var actor := _actor()
	var space := actor.motor.get_world_2d().direct_space_state
	var best: Dictionary = {}
	var normal := (finish-start).normalized().orthogonal()*float(_tuning.projection.collision_radius_px)
	for offset: Vector2 in [Vector2.ZERO, normal, -normal]:
		var excluded: Array[RID] = [actor.motor.get_rid()]
		excluded.append_array(ignored)
		for _attempt: int in 32:
			var ray := PhysicsRayQueryParameters2D.create(start+offset, finish+offset, 0xFFFFFFFF, excluded)
			ray.collide_with_areas = true
			var hit := space.intersect_ray(ray)
			if hit.is_empty(): break
			var collider := hit.collider as Node2D
			var receiver := collider.get_node_or_null("Damageable") as Damageable if collider != null else null
			if receiver != null and receiver.active and receiver.faction == &"enemy":
				var distance := start.distance_squared_to(hit.position-offset)
				if best.is_empty() or distance < float(best.distance): best = {"receiver":receiver, "point":hit.position-offset, "normal":hit.normal, "rid":hit.rid, "distance":distance}
				break
			if receiver == null and collider is PhysicsBody2D:
				var distance := start.distance_squared_to(hit.position-offset)
				if best.is_empty() or distance < float(best.distance): best = {"receiver":null, "point":hit.position-offset, "normal":hit.normal, "rid":hit.rid, "distance":distance}
				break
			excluded.append(hit.rid)
	return best

func _dispose(entry: Dictionary) -> void:
	entry.spent = true
	var view := entry.get("visual") as ItemV5Entity
	if is_instance_valid(view) and not view.is_queued_for_deletion(): view.queue_free()

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted":accepted, "reason":reason}

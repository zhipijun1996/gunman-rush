class_name ItemCombatEffects
extends RefCounted
## Consumes only accepted weapon/grapple receipts. Derived damage never re-enters
## this component; the host submits it through the original frame damage policy.
var _host_ref: WeakRef
var _session := -1
var _world_time := 0.0
var _map: StringName
var _seen: Dictionary = {}
var _packets: Dictionary = {}
var _boosted_packets: Array[StringName] = []
var _hook_marks: Dictionary = {}
var _dream_marks: Dictionary = {}
var _echo_marks: Dictionary = {}
var _dots: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _pending_recoil_hits: Array[Dictionary] = []
var _last_position := Vector2.ZERO
var _moving_recoil := false
var _recoil_had_motion := false
var _recoil_serial := 0
var _recoil_targets: Dictionary = {}

func configure(host: RefCounted) -> void:
	_host_ref = weakref(host)
	_session = _actor().session_id
	_last_position = _actor().motor.global_position

func _host() -> RefCounted:
	return _host_ref.get_ref() as RefCounted if _host_ref != null else null

func _actor() -> PlayerController:
	return _host().call("actor") as PlayerController

func _effect(id: StringName) -> Dictionary:
	return _host().call("effect", id) as Dictionary

func _has(id: StringName) -> bool:
	return bool(_host().call("has", id))

func _state(id: StringName) -> Dictionary:
	return _host().call("state", id) as Dictionary

func _patch(id: StringName, patch: Dictionary) -> void:
	_host().call("patch_state", id, patch)

func _now() -> float:
	return float(_host().call("now"))

func _d() -> float:
	return float(_host().call("base_damage"))

func _target_key(receiver: Damageable) -> StringName:
	return StringName("%s/%s/%s" % [_map, receiver.get_instance_id(), receiver.damage_epoch])

func _packet_key(packet: int) -> StringName:
	return StringName("%s/%s" % [_actor().session_id, packet])

func _eligible(receiver: Damageable) -> bool:
	return is_instance_valid(receiver) and receiver.faction == &"enemy"

func _cooldown(id: StringName, seconds: float, key: StringName = &"global") -> bool:
	var cooldowns: Dictionary = _state(id).get("combat_cooldowns", {}).duplicate(true)
	if _now() + 0.0000001 < float(cooldowns.get(String(key), 0.0)): return false
	cooldowns[String(key)] = _now() + maxf(0.0, seconds)
	_patch(id, {"combat_cooldowns": cooldowns})
	return true

func _receipt(id: StringName, event: Dictionary, target: StringName = &"") -> StringName:
	var kind := "weapon"
	if bool(event.get("hook",false)): kind = "hook"
	elif bool(event.get("item_active",false)): kind = "item/%s" % event.get("origin_id", &"")
	return StringName("%s/%s/%s/%s/%s/%s" % [_map,id,kind,event.get("session",_session),event.get("packet",-1),target])

func _once(id: StringName, event: Dictionary, target: StringName = &"") -> bool:
	var key := _receipt(id, event, target)
	if _seen.has(key): return false
	_seen[key] = true
	return true

func map_entered(key: StringName) -> void:
	_map = key
	_seen.clear()
	_packets.clear()
	_boosted_packets.clear()
	_hook_marks.clear()
	_dream_marks.clear()
	_echo_marks.clear()
	_dots.clear()
	_clouds.clear()
	_rings.clear()
	_pending_recoil_hits.clear()
	_recoil_targets.clear()
	_moving_recoil = false
	_recoil_had_motion = false
	_last_position = _actor().motor.global_position

func sync() -> void:
	if not _has(&"P04"):
		for packet: StringName in _boosted_packets:
			if _packets.has(packet): (_packets[packet] as Dictionary).multiplier = 1.0
		_boosted_packets.clear()
		if float(_state(&"P04").get("buff_until", -1.0)) >= 0.0: _patch(&"P04", {"buff_until":-1.0})
	if not _has(&"P13"): _hook_marks.clear()
	if not _has(&"B19"): _dream_marks.clear()
	if not _has(&"G01"): _echo_marks.clear()
	for i: int in range(_dots.size()-1, -1, -1):
		if not _has(_dots[i].origin): _dots.remove_at(i)
	for i: int in range(_clouds.size()-1, -1, -1):
		if not _has(&"P10"): _clouds.remove_at(i)
	if not _has(&"B23"): _rings.clear()
	if not _has(&"P31"): _pending_recoil_hits.clear()

func primary_packet_started(packet: int, direction: Vector2 = Vector2.ZERO) -> void:
	if not _has(&"P04") and not _has(&"P31"): return
	var key := _packet_key(packet)
	if _packets.has(key): return
	var multiplier := 1.0
	if _has(&"P04"):
		var state := _state(&"P04")
		if float(state.get("buff_until", -1.0)) >= _now():
			multiplier = float(_effect(&"P04").get("next_primary_multiplier", 1.0))
			_patch(&"P04", {"buff_until": -1.0, "consumed_packet": String(key)})
	_packets[key] = {"multiplier":multiplier, "start":_actor().motor.global_position, "direction":direction, "recoiled":false}
	if not is_equal_approx(multiplier,1.0): _boosted_packets.append(key)

func primary_damage_multiplier(packet: int) -> float:
	var multiplier := float(_effect(&"B03").get("primary_damage_multiplier", 1.0))
	multiplier *= float(_effect(&"B17").get("primary_damage_multiplier", 1.0))
	var low := _effect(&"P05")
	var health := _actor().actor_resources.health
	if not low.is_empty() and health.capacity > 0.0 and health.current / health.capacity <= float(low.hp_ratio_threshold) + 0.0000001:
		multiplier *= float(low.primary_damage_multiplier)
	var packet_state: Dictionary = _packets.get(_packet_key(packet), {})
	return multiplier * (float(packet_state.get("multiplier", 1.0)) if _has(&"P04") else 1.0)

func modify_direct_damage(amount: float, receiver: Damageable, skill: bool, packet: int) -> float:
	if not is_finite(amount) or amount <= 0.0: return 0.0
	if skill:
		return amount * (float(_effect(&"P03").get("lv3_skill_damage_multiplier", 1.0)) if _actor().shoot_ability.weapon.tier == 3 else 1.0)
	var multiplier := primary_damage_multiplier(packet)
	if is_marked(receiver): multiplier *= float(_effect(&"P13").get("marked_primary_damage_multiplier", 1.0))
	return amount * multiplier

func weapon_cooldown_multiplier() -> float:
	var effect := _effect(&"B05")
	return maxf(float(effect.minimum_total_cooldown_multiplier),float(effect.primary_cooldown_multiplier)) if not effect.is_empty() else 1.0

func projectile_range_multiplier() -> float:
	return float(_effect(&"B29").get("projectile_range_multiplier", 1.0))

func extra_pierce() -> Dictionary:
	var effect := _effect(&"P08")
	return {"count":int(effect.get("max_extra_pierce", 0)), "damage_ratio":float(effect.get("pierced_damage_ratio_D", 1.0))}

func bomb_radius_multiplier() -> float:
	return float(_effect(&"B22").get("bomb_explosion_radius_multiplier", 1.0))

func laser_width_multiplier() -> float:
	return float(_effect(&"P33").get("laser_hit_width_multiplier", 1.0))

func singularity_hold_add() -> float:
	return float(_effect(&"P23").get("singularity_pull_duration_add_s", 0.0))

func singularity_damage_multiplier() -> float:
	return float(_effect(&"P23").get("singularity_explosion_damage_multiplier", 1.0))

func enemy_stagger_multiplier() -> float:
	return float(_effect(&"B31").get("enemy_stagger_multiplier", 1.0))

func charge_move_multiplier() -> float:
	# The existing charge movement baseline remains full speed until the user
	# resolves P17's conflicting movement rule. Its equipped values stay data-led.
	return float(_effect(&"P17").get("charge_move_speed_multiplier", 1.0))

func on_hook_hit(receiver: Damageable, receipt: StringName = &"") -> void:
	if (not _has(&"P13") and not _has(&"B19")) or not _eligible(receiver): return
	var key := _target_key(receiver)
	var dedupe := StringName("hook/%s/%s" % [key, receipt])
	if not receipt.is_empty() and _seen.has(dedupe): return
	_seen[dedupe] = true
	if _has(&"P13"):
		var sequence := int(_state(&"P13").get("mark_sequence", 0)) + 1
		_patch(&"P13", {"mark_sequence":sequence})
		_hook_marks[key] = {"until":_world_time+float(_effect(&"P13").mark_duration_s), "receipt":StringName("%s/hook/%s" % [key, sequence])}
		_host().call("cue", &"mark", (receiver.get_parent() as Node2D).global_position, {"origin":&"P13"})
	if _has(&"B19"):
		var sequence := int(_state(&"B19").get("dream_mark_sequence", 0)) + 1
		_patch(&"B19", {"dream_mark_sequence":sequence})
		_dream_marks[key] = {"until":_world_time+float(_effect(&"B19").mark_duration_s), "receipt":StringName("%s/dream/%s" % [key, sequence])}
		_host().call("cue", &"mark", (receiver.get_parent() as Node2D).global_position, {"origin":&"B19"})

func is_marked(receiver: Damageable) -> bool:
	return not mark_key(receiver).is_empty()

func mark_key(receiver: Damageable) -> StringName:
	if not _has(&"P13") or not _eligible(receiver): return &""
	var mark: Dictionary = _hook_marks.get(_target_key(receiver), {})
	return mark.get("receipt", &"") if not mark.is_empty() and float(mark.until) > _world_time else &""

func is_dream_marked(receiver: Damageable) -> bool:
	return not dream_mark_key(receiver).is_empty()

func dream_mark_key(receiver: Damageable) -> StringName:
	if not _has(&"B19") or not _eligible(receiver): return &""
	var mark: Dictionary = _dream_marks.get(_target_key(receiver), {})
	return mark.get("receipt", &"") if not mark.is_empty() and float(mark.until) > _world_time else &""

func on_hit(event: Dictionary) -> void:
	var receiver := event.get("receiver") as Damageable
	if not _eligible(receiver) or int(event.get("session", -1)) != _actor().session_id or not bool(_host().call("is_live")): return
	var skill := bool(event.get("skill", false))
	var hook := bool(event.get("hook", false))
	var primary := not skill and not hook and not bool(event.get("item_active", false))
	var target := _target_key(receiver)
	var point: Vector2 = event.get("point", (receiver.get_parent() as Node2D).global_position)
	if _has(&"P29") and _once(&"P29", event) and _cooldown(&"P29", float(_effect(&"P29").cooldown_s)):
		var chain := _effect(&"P29")
		_chain(receiver, point, int(chain.chain_targets), float(chain.chain_radius_px), float(chain.chain_damage_ratio_D), &"P29", event)
	if not primary: return
	if _has(&"G06") and _once(&"G06", event) and _cooldown(&"G06", float(_effect(&"G06").cooldown_s)):
		var chain := _effect(&"G06")
		_chain(receiver, point, int(chain.chain_targets), float(chain.chain_radius_px), float(chain.chain_damage_ratio_D), &"G06", event)
	if _has(&"P34") and int(event.get("weapon_mode", -1)) == WeaponDefinition.Mode.MACHINE and int(event.get("shot_index", 0)) == 3 and _once(&"P34", event):
		var third := _effect(&"P34")
		_host().call("burst", point, float(third.blast_radius_px), float(third.third_hit_bonus_damage_ratio_D), &"P34", _receipt(&"P34", event))
	if _has(&"P09") and _once(&"P09", event) and _cooldown(&"P09", float(_effect(&"P09").cooldown_s)):
		var blast := _effect(&"P09")
		_host().call("burst", point, float(blast.radius_px), float(blast.explosion_damage_ratio_D), &"P09", _receipt(&"P09", event))
	if _has(&"B24") and _once(&"B24", event) and _cooldown(&"B24", float(_effect(&"B24").cooldown_s)):
		var burn := _effect(&"B24")
		# Refresh this source on a target, never stack the same burn.
		for i: int in range(_dots.size()-1, -1, -1):
			if _dots[i].target == target and _dots[i].origin == &"B24": _dots.remove_at(i)
		_dots.append({"origin":&"B24", "target":target, "receiver":weakref(receiver), "remaining":float(burn.dot_duration_s), "damage_left":_d()*float(burn.total_dot_damage_ratio_D), "tick":0, "receipt":_receipt(&"B24", event, target)})
	if _has(&"P10") and float(_state(&"P10").get("primed_until", -1.0)) >= _now() and _once(&"P10", event):
		_patch(&"P10", {"primed_until":-1.0})
		var cloud := _effect(&"P10")
		_clouds.append({"point":point, "remaining":float(cloud.cloud_duration_s), "radius":float(cloud.cloud_radius_px), "damage_per_s":float(cloud.dot_damage_per_second_ratio_D), "tick":0, "receipt":_receipt(&"P10", event)})
		_host().call("cue", &"cloud", point, {"radius":float(cloud.cloud_radius_px), "duration":float(cloud.cloud_duration_s), "origin":&"P10"})
	if _has(&"G01") and _once(&"G01", event, target): _echo(receiver, point, event, target)
	if bool(event.get("airborne", false)):
		if _has(&"P31") and _once(&"P31", event): _pending_recoil_hits.append(event.duplicate())
		if _has(&"P04") and _once(&"P04", event):
			var state := _state(&"P04")
			# A boosted packet cannot re-arm its own next-shot benefit.
			if str(state.get("consumed_packet", "")) != String(_packet_key(int(event.packet))) and float(state.get("buff_until", -1.0)) < _now():
				_patch(&"P04", {"buff_until":_now()+float(_effect(&"P04").buff_window_s)})

func on_skill_started(_receipt: StringName) -> void:
	var key := StringName("skill/%s" % _receipt)
	if _seen.has(key): return
	_seen[key] = true
	if _has(&"P10"): _patch(&"P10", {"primed_until":_now()+float(_effect(&"P10").primed_window_s)})

func _echo(receiver: Damageable, point: Vector2, event: Dictionary, target: StringName) -> void:
	var mark: Dictionary = _echo_marks.get(target, {})
	if not mark.is_empty() and float(mark.until) <= _world_time:
		_echo_marks.erase(target)
		mark = {}
	if not mark.is_empty() and float(mark.until) > _world_time and str(mark.packet) != String(_packet_key(int(event.packet))):
		_detonate_echo(receiver,point,event,target)
	elif bool(event.get("airborne", false)) and mark.is_empty():
		var cooldowns: Dictionary = _state(&"G01").get("combat_cooldowns", {})
		if _now() >= float(cooldowns.get(String(target), 0.0)):
			_echo_marks[target] = {"packet":_packet_key(int(event.packet)), "until":_world_time+float(_effect(&"G01").mark_duration_s)}

func _detonate_echo(receiver: Damageable, point: Vector2, event: Dictionary, target: StringName) -> bool:
	if not _has(&"G01"): return false
	var mark: Dictionary = _echo_marks.get(target,{})
	if mark.is_empty() or float(mark.until) <= _world_time or str(mark.packet) == String(_packet_key(int(event.packet))): return false
	var echo := _effect(&"G01")
	if not _cooldown(&"G01",float(echo.target_cooldown_s),target): return false
	_echo_marks.erase(target)
	_host().call("deal",receiver,_d()*float(echo.detonation_damage_ratio_D),_receipt(&"G01",event,target),&"G01")
	_host().call("cue",&"echo",point,{"origin":&"G01"})
	return true

func _chain(receiver: Damageable, point: Vector2, count: int, radius: float, ratio: float, origin: StringName, event: Dictionary) -> void:
	var excluded: Dictionary = {receiver.get_instance_id():true}
	var start := point
	for i: int in count:
		var chosen: Dictionary = {}
		var candidates: Array = _host().call("targets", start, radius)
		for value: Dictionary in candidates:
			var target := value.receiver as Damageable
			if excluded.has(target.get_instance_id()) or not bool(_host().call("clear_line", start, (value.node as Node2D).global_position)): continue
			chosen = value
			break
		if chosen.is_empty(): break
		var target := chosen.receiver as Damageable
		var finish := (chosen.node as Node2D).global_position
		excluded[target.get_instance_id()] = true
		_host().call("deal", target, _d()*ratio, _receipt(origin, event, StringName("%s/%s" % [target.get_instance_id(),i])), origin)
		_host().call("cue", &"arc", start, {"finish":finish, "origin":origin})
		start = finish

func advance(_real_delta: float, world_delta: float) -> void:
	if _host() == null or not is_instance_valid(_actor()): return
	if _session != _actor().session_id:
		_session = _actor().session_id
		map_entered(_map)
	sync()
	_world_time += maxf(0.0, world_delta)
	for key: StringName in _hook_marks.keys():
		if float(_hook_marks[key].until) <= _world_time: _hook_marks.erase(key)
	for key: StringName in _dream_marks.keys():
		if float(_dream_marks[key].until) <= _world_time: _dream_marks.erase(key)
	for key: StringName in _echo_marks.keys():
		if float(_echo_marks[key].until) <= _world_time: _echo_marks.erase(key)
	_advance_recoil()
	if world_delta <= 0.0: return
	for i: int in range(_dots.size()-1, -1, -1):
		var dot := _dots[i]
		var receiver := (dot.receiver as WeakRef).get_ref() as Damageable
		if not is_instance_valid(receiver) or not receiver.active or _target_key(receiver) != dot.target:
			_dots.remove_at(i)
			continue
		var step := minf(world_delta, float(dot.remaining))
		var amount := float(dot.damage_left) * step / float(dot.remaining)
		dot.remaining = maxf(0.0, float(dot.remaining)-step)
		dot.damage_left = maxf(0.0, float(dot.damage_left)-amount)
		dot.tick = int(dot.tick)+1
		_host().call("deal", receiver, amount, StringName("%s/tick/%s" % [dot.receipt,dot.tick]), dot.origin)
		if float(dot.remaining) <= 0.0000001: _dots.remove_at(i)
	for i: int in range(_clouds.size()-1, -1, -1):
		var cloud := _clouds[i]
		var step := minf(world_delta, float(cloud.remaining))
		cloud.tick = int(cloud.tick)+1
		_host().call("burst", cloud.point, float(cloud.radius), float(cloud.damage_per_s)*step, &"P10", StringName("%s/tick/%s" % [cloud.receipt,cloud.tick]))
		cloud.remaining = maxf(0.0, float(cloud.remaining)-step)
		if float(cloud.remaining) <= 0.0000001: _clouds.remove_at(i)
	for i: int in range(_rings.size()-1, -1, -1):
		var ring := _rings[i]
		var candidates: Array = _host().call("targets", ring.point, float(ring.radius))
		for value: Dictionary in candidates:
			var receiver := value.receiver as Damageable
			if ring.targets.has(receiver.get_instance_id()) or not bool(_host().call("clear_line", ring.point, (value.node as Node2D).global_position)): continue
			ring.targets[receiver.get_instance_id()] = true
			_host().call("deal", receiver, _d()*float(ring.ratio), StringName("%s/%s" % [ring.receipt,receiver.get_instance_id()]), &"B23")
		ring.remaining = maxf(0.0, float(ring.remaining)-world_delta)
		if float(ring.remaining) <= 0.0000001: _rings.remove_at(i)

func _advance_recoil() -> void:
	var actor := _actor()
	var position := actor.motor.global_position
	var moved := position.distance_squared_to(_last_position) > 0.01
	var recoil := actor.motor.recoil_burst_remaining > 0.0 or (actor.shoot_ability.behavior().phase == &"beam" and not actor.motor.recoil_velocity.is_zero_approx())
	var interrupted := actor.motor.damage_remaining > 0.0 or actor.traversal.busy()
	if recoil and not _moving_recoil:
		_recoil_serial += 1
		_recoil_targets.clear()
		_recoil_had_motion = false
	if moved and not interrupted and (recoil or _moving_recoil):
		_recoil_had_motion = true
		var packet_state: Dictionary = _packets.get(_packet_key(actor.shoot_ability.packet_id), {})
		if not packet_state.is_empty():
			var direction: Vector2 = packet_state.direction
			if direction.is_zero_approx() or absf((position-_last_position).dot(direction)) > 0.01: packet_state.recoiled = true
		_observe_path(_last_position, position)
	if not recoil and _moving_recoil and _recoil_had_motion: _end_recoil(_last_position if interrupted else position)
	for i: int in range(_pending_recoil_hits.size()-1,-1,-1):
		var event := _pending_recoil_hits[i]
		var packet: Dictionary = _packets.get(_packet_key(int(event.packet)),{})
		if bool(packet.get("recoiled",false)):
			var raw: Variant = event.get("receiver")
			var receiver: Damageable = raw as Damageable if is_instance_valid(raw) else null
			if is_instance_valid(receiver) and receiver.active and _cooldown(&"P31",float(_effect(&"P31").cooldown_s)):
				_host().call("deal",receiver,_d()*float(_effect(&"P31").air_recoil_hit_extra_damage_ratio_D),_receipt(&"P31",event,_target_key(receiver)),&"P31")
			_pending_recoil_hits.remove_at(i)
		elif not recoil: _pending_recoil_hits.remove_at(i)
	_moving_recoil = recoil
	_last_position = position

func _observe_path(start: Vector2, finish: Vector2) -> void:
	if not _has(&"P12"): return
	var path := _effect(&"P12")
	var width := float(path.contact_width_px)
	var length := start.distance_to(finish)
	if length <= 0.000001: return
	var shape := CapsuleShape2D.new()
	shape.radius = width*0.5
	shape.height = length+width
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D((finish-start).angle()+PI*0.5,(start+finish)*0.5)
	query.collide_with_areas = true
	query.exclude = [_actor().motor.get_rid()]
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	for hit: Dictionary in _actor().motor.get_world_2d().direct_space_state.intersect_shape(query,64):
		var node := hit.collider as Node2D
		var receiver := node.get_node_or_null("Damageable") as Damageable if node != null else null
		if not _eligible(receiver) or not receiver.active or seen.has(receiver.get_instance_id()): continue
		seen[receiver.get_instance_id()] = true
		candidates.append({"receiver":receiver,"node":node})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return (a.receiver as Damageable).get_instance_id()<(b.receiver as Damageable).get_instance_id())
	for value: Dictionary in candidates:
		var receiver := value.receiver as Damageable
		var key := _target_key(receiver)
		var target_point := (value.node as Node2D).global_position
		var closest := Geometry2D.get_closest_point_to_segment(target_point,start,finish)
		if _recoil_targets.has(key) or not bool(_host().call("clear_line", closest,target_point)): continue
		if not bool(_host().call("clear_line", start,target_point)) and not bool(_host().call("clear_line", finish,target_point)): continue
		if not _cooldown(&"P12", float(path.target_cooldown_s), key): continue
		_recoil_targets[key] = true
		var receipt := StringName("%s/P12/%s/%s" % [_map,_recoil_serial,key])
		var committed := _path_committed.bind(receiver,target_point,_actor().shoot_ability.packet_id,_actor().session_id,key)
		_host().call("deal",receiver,_d()*float(path.path_contact_damage_ratio_D),receipt,&"P12",committed)

func _path_committed(receiver: Damageable, point: Vector2, packet: int, expected_session: int, target: StringName) -> void:
	# S06 is an explicit, bounded recipe consuming an existing G01 mark. It does
	# not dispatch a generic primary hit, create marks, or trigger other chains.
	if not _has(&"P12") or not _eligible(receiver) or _actor().session_id != expected_session or _target_key(receiver) != target or not bool(_host().call("is_live")): return
	_detonate_echo(receiver,point,{"session":expected_session,"packet":packet},target)

func _end_recoil(position: Vector2) -> void:
	if not _has(&"B23"): return
	var ring := _effect(&"B23")
	if _cooldown(&"B23",float(ring.cooldown_s)):
		_rings.append({"point":position,"radius":float(ring.radius_px),"ratio":float(ring.damage_ratio_D),"remaining":float(ring.effect_duration_s),"targets":{},"receipt":StringName("%s/B23/%s" % [_map,_recoil_serial])})
		_host().call("cue",&"ring",position,{"radius":float(ring.radius_px),"duration":float(ring.effect_duration_s),"origin":&"B23"})

func on_blink(start: Vector2, finish: Vector2) -> void:
	if start.distance_squared_to(finish) <= 0.01: return
	# Motor emits only after its actual swept blink, so walls and truncation are
	# already resolved. Process the same path observer without requesting motion.
	_last_position = start
	var packet: Dictionary = _packets.get(_packet_key(_actor().shoot_ability.packet_id), {})
	if not packet.is_empty(): packet.recoiled = true
	_recoil_serial += 1
	_recoil_targets.clear()
	_observe_path(start, finish)
	_end_recoil(finish)
	_last_position = finish

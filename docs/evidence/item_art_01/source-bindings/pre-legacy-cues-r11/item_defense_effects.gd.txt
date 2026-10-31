class_name ItemDefenseEffects
extends RefCounted
## Player defenses consume the selected FrameDamagePolicy request, never raw
## contact callbacks. Persistent counts live on the owned item, not the menu.
const BARRIER_ITEMS: Array[StringName] = [&"B13", &"B32", &"G02", &"N02"]
const BREAKABLE_ITEMS: Array[StringName] = [&"B16", &"B30", &"B17"]
var _host: WeakRef
var _tuning: Dictionary = {}
var _synergies: Dictionary = {}
var _shared_cap := 0
var _damage_seen: Dictionary = {}
var _defense_receipts: Dictionary = {}
var _maps_seen: Dictionary = {}
var _pending_entry: StringName
var _pending_entry_items: Array[StringName] = []
var _crystals: Array[Dictionary] = []
var _glyph: GuardGlyph
var _orbit_age := 0.0
var _previous_guard := Vector2.INF
var _projectile_positions: Dictionary = {}
var _rescue_policy: WeakRef
var _rescue_visual_tickets: Dictionary = {}
const MAX_RESCUE_VISUAL_TICKETS := 8

class CrystalGlyph extends Node2D:
	var radius := 0.0
	var visual_age := 0.0
	func _ready() -> void:
		material = ItemArtLibrary.world_material()
	func _draw() -> void:
		var clip := ItemArtLibrary.entity_clip(&"crystal",&"P20")
		if not clip.is_empty() and ItemArtLibrary.draw_recipe(self,clip,visual_age,Vector2.ZERO,Vector2.RIGHT,Vector2.ZERO,radius,Vector2.ZERO,Color(1,1,1,.5)): return
		var points := PackedVector2Array([Vector2(0,-radius), Vector2(radius*.65,0), Vector2(0,radius), Vector2(-radius*.65,0)])
		draw_colored_polygon(points, Color(.18,.55,.65,.5))
		draw_polyline(points + PackedVector2Array([points[0]]), Color(.65,.94,.95,.9), 2.0)
		draw_line(Vector2(0,-radius*.6), Vector2(0,radius*.6), Color(.88,.97,1), 1.0)

class GuardGlyph extends Node2D:
	var radius := 0.0
	var available := true
	var visual_age := 0.0
	func _ready() -> void:
		material = ItemArtLibrary.world_material()
	func _draw() -> void:
		var clip := ItemArtLibrary.entity_clip(&"orbit_guard",&"P16")
		var artist_tint := Color(1,1,1,.9) if available else Color(.35,.45,.48,.4)
		if not clip.is_empty() and ItemArtLibrary.draw_recipe(self,clip,visual_age,Vector2.ZERO,Vector2.RIGHT,Vector2.ZERO,radius,Vector2.ZERO,artist_tint): return
		var color := Color(.55,.88,.92,.9) if available else Color(.35,.45,.48,.4)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 20, color, 2.0)
		draw_line(Vector2(-radius*.6,0),Vector2(radius*.6,0),color,2)
		draw_line(Vector2(0,-radius*.6),Vector2(0,radius*.6),color,2)

func configure(host: RefCounted) -> void:
	_host = weakref(host)
	_tuning = _read_json("res://config/item_v5_defense.json")
	_synergies = _read_json("res://config/item_v5_synergies.json").get("synergies",{})
	var common := _read_json("res://config/item_v5_runtime.json")
	_shared_cap = int(common.get("shared_barrier_cap", 0))
	sync()

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _owner() -> RefCounted:
	return _host.get_ref() as RefCounted if _host != null else null

func _actor() -> PlayerController:
	var owner := _owner()
	return owner.call("actor") as PlayerController if owner != null else null

func _params(id: StringName) -> Dictionary:
	var owner := _owner()
	return owner.call("effect", id) if owner != null else {}

func _state(id: StringName) -> Dictionary:
	var owner := _owner()
	return owner.call("state", id) if owner != null else {}

func _patch(id: StringName, patch: Dictionary, receipt: StringName = &"") -> bool:
	var owner := _owner()
	return bool(owner.call("patch_state", id, patch, receipt)) if owner != null else false

func _now() -> float:
	var owner := _owner()
	return float(owner.call("now")) if owner != null else 0.0

func _map() -> String:
	var owner := _owner()
	return String(owner.call("map_key")) if owner != null else ""

func _live() -> bool:
	var owner := _owner()
	return owner != null and bool(owner.call("is_live"))

func sync() -> void:
	var owner := _owner()
	var actor := _actor()
	if owner == null or actor == null: return
	actor.actor_resources.health.normal_healing_blocked = not _params(&"P18").is_empty()
	for id: StringName in BARRIER_ITEMS:
		if _params(id).is_empty() and float(_state(id).get("barrier_remaining",0.0)) > 0.0:
			_patch(id,{"barrier_remaining":0.0})
	if _params(&"P26").is_empty() and float(_state(&"P26").get("invulnerable_until",0.0)) > 0.0:
		_patch(&"P26",{"invulnerable_until":0.0})
	if _params(&"P20").is_empty():
		for row: Dictionary in _crystals:
			if is_instance_valid(row.node): (row.node as Node).queue_free()
		_crystals.clear()
	if _params(&"P16").is_empty(): _clear_glyph()
	if _params(&"G04").is_empty(): _clear_rescue_observer()

func barrier_amount() -> float:
	var total := 0.0
	for id: StringName in BARRIER_ITEMS:
		if not _params(id).is_empty(): total += maxf(0.0,float(_state(id).get("barrier_remaining",0.0)))
	return minf(float(_shared_cap),total)

func barrier_count() -> int:
	return ceili(barrier_amount())

func grant_barrier(amount: int, receipt: StringName, origin: StringName = &"") -> int:
	if not _live() or amount <= 0 or receipt.is_empty() or _shared_cap <= 0: return 0
	if origin.is_empty(): origin = StringName(String(receipt).get_slice("/",0))
	if origin not in BARRIER_ITEMS or _params(origin).is_empty(): return 0
	var state := _state(origin)
	var receipts: Dictionary = (state.get("barrier_receipts",{}) as Dictionary).duplicate()
	if receipts.has(String(receipt)): return 0
	var applied := mini(amount, maxi(0,floori(float(_shared_cap)-barrier_amount())))
	receipts[String(receipt)] = applied
	var owner := _owner()
	var visual: Dictionary = owner.call("presentation_receipt",origin,receipt)
	var point := _actor().motor.global_position
	if not _patch(origin,{"barrier_remaining":float(state.get("barrier_remaining",0.0))+applied,"barrier_receipts":receipts},receipt): return 0
	if applied > 0: owner.call("present_committed",&"barrier",point,visual,{"amount":applied})
	return applied

func _absorb(amount: float, receipt: StringName) -> float:
	var left := amount
	for id: StringName in BARRIER_ITEMS:
		if _params(id).is_empty() or left <= 0.0: continue
		var available := maxf(0.0,float(_state(id).get("barrier_remaining",0.0)))
		var spent := minf(available,left)
		if spent > 0.0 and _patch(id,{"barrier_remaining":available-spent},StringName("%s/%s" % [receipt,id])): left -= spent
	return amount-left

func monster_iframe(base: float) -> float:
	var params := _params(&"B27")
	if params.is_empty(): return base
	return minf(maxf(base,float(_tuning.get("max_monster_invulnerability_s",base))),base+float(params.get("invulnerable_add_s",0.0)))

func defend_request(request: DamageRequest, current_hp: float) -> Dictionary:
	var result := {"amount":request.amount,"barrier_absorbed":0.0,"blocked":false,"rescued":false}
	if not _live() or request.fall or request.forced_failure: return result
	var key := "%s/%s/%s" % [_map(),request.actor_epoch,request.event_id]
	if _defense_receipts.has(key): return (_defense_receipts[key] as Dictionary).duplicate()
	var curtain := _params(&"P26")
	if not curtain.is_empty() and _now() < float(_state(&"P26").get("invulnerable_until",0.0)):
		result.amount = 0.0
		result.blocked = true
	else:
		result.barrier_absorbed = _absorb(request.amount,StringName("barrier/%s" % key))
		result.amount = maxf(0.0,request.amount-float(result.barrier_absorbed))
		result.blocked = float(result.amount) <= 0.0
		var rescue := _params(&"G04")
		if request.kind == DamageRequest.Kind.MONSTER and float(result.amount) >= current_hp and not rescue.is_empty():
			var state := _state(&"G04")
			var uses: Dictionary = (state.get("map_uses",{}) as Dictionary).duplicate()
			if int(uses.get(_map(),0)) < int(rescue.get("uses_per_map",0)):
				var owner := _owner()
				var visual: Dictionary = owner.call("presentation_receipt",&"G04",StringName("G04/rescue/%s" % key))
				var policy := _current_rescue_policy()
				var point := _actor().motor.global_position
				if bool(owner.call("spend_energy",float(rescue.get("combat_energy_cost",0.0)),StringName("G04/rescue/%s" % key),false)):
					uses[_map()] = int(uses.get(_map(),0))+1
					var prepared := _patch(&"G04",{"map_uses":uses},StringName("G04/use/%s" % key))
					if prepared: _prepare_rescue_visual(request,policy,visual,point)
					result.amount = maxf(0.0,current_hp-float(rescue.get("set_remaining_hp",1.0)))
					result.rescued = true
					result.blocked = float(result.amount) <= 0.0
	_defense_receipts[key] = result.duplicate()
	return result

func map_entered(key: StringName) -> void:
	clear_world_entities()
	if key.is_empty() or _maps_seen.has(String(key)): return
	_maps_seen[String(key)] = true
	_pending_entry = key
	_pending_entry_items.clear()
	for id: StringName in [&"B13",&"B32",&"G03"]:
		if not _params(id).is_empty(): _pending_entry_items.append(id)
	_commit_entry()

func _commit_entry() -> void:
	# A scene may finish loading while the app has lost focus. Freeze which
	# sources were present at entry, then defer grants until gameplay resumes.
	# Equipping another item in that intervening menu cannot add it to the set.
	if _pending_entry.is_empty() or not _live() or String(_pending_entry) != _map(): return
	var key := _pending_entry
	var items := _pending_entry_items.duplicate()
	_pending_entry = &""
	_pending_entry_items.clear()
	for id: StringName in items:
		var params := _params(id)
		var state := _state(id)
		var maps: Dictionary = (state.get("entry_maps",{}) as Dictionary).duplicate()
		if maps.has(String(key)): continue
		maps[String(key)] = true
		var receipt := StringName("%s/%s/entry" % [id,key])
		if not _patch(id,{"entry_maps":maps},receipt): continue
		if params.is_empty(): continue
		if id == &"G03": _owner().call("heal",float(params.get("heal_hp_on_new_map",0.0)),StringName("%s/heal" % receipt),id)
		else: grant_barrier(int(params.get("map_start_barrier",0)),StringName("%s/barrier" % receipt),id)

func on_damage(event: Dictionary) -> void:
	if not _live() or bool(event.get("lethal",false)) or float(event.get("hp_lost",0.0)) <= 0.0: return
	var key := "%s/%s" % [_map(),event.get("event_id","")]
	if key.ends_with("/") or _damage_seen.has(key): return
	_damage_seen[key] = true
	var owner := _owner()
	var actor := _actor()
	var broken_changed := false
	for id: StringName in BREAKABLE_ITEMS:
		var params := _params(id)
		if params.is_empty(): continue
		var hits := int(_state(id).get("damage_hits",0))+1
		var broken := hits >= int(params.get("break_on_hits",2147483647))
		var patch := {"damage_hits":hits,"broken":broken}
		var first_break := id == &"B17" and broken and not bool(_state(id).get("first_break_resolved",false))
		if first_break: patch["first_break_resolved"] = true
		var bell := first_break and not _params(&"B14").is_empty()
		if bell: patch["first_break_bell_emitted"] = true
		var bell_proof: Dictionary = owner.call("presentation_receipt",&"B14",StringName("S15/%s" % key)) if bell else {}
		var changed := _patch(id,patch,StringName("%s/hit/%s" % [id,key]))
		if bell:
			if changed: owner.call("present_committed",&"item_break_bell_committed",actor.motor.global_position,bell_proof,{"synergy":&"S15","item":id})
			owner.call("cue",&"synergy_bell",actor.motor.global_position,{"synergy":&"S15","item":id,"receipt":key})
		broken_changed = broken_changed or broken
	var pain := _params(&"B14")
	if not pain.is_empty(): owner.call("grant_energy",float(pain.get("combat_energy_gain_on_damage",0.0)),StringName("B14/%s" % key))
	var worry := _params(&"G02")
	if not worry.is_empty():
		var hits := int(_state(&"G02").get("hp_hits",0))+1
		_patch(&"G02",{"hp_hits":hits},StringName("G02/hit/%s" % key))
		var threshold := int(worry.get("hits_for_one_barrier",0))
		if threshold > 0 and hits % threshold == 0: grant_barrier(int(worry.get("shield_per_trigger",0)),StringName("G02/%s/shield" % key),&"G02")
	var thorns := _params(&"B15")
	if not thorns.is_empty() and _now() >= float(_state(&"B15").get("ready_at",0.0)):
		_patch(&"B15",{"ready_at":_now()+float(thorns.get("cooldown_s",0.0))},StringName("B15/cooldown/%s" % key))
		owner.call("burst",actor.motor.global_position,float(thorns.get("radius_px",0.0)),float(thorns.get("damage_ratio_D",0.0)),&"B15",StringName("B15/%s" % key))
	var crystal := _params(&"P20")
	if not crystal.is_empty() and _now() >= float(_state(&"P20").get("ready_at",0.0)):
		_patch(&"P20",{"ready_at":_now()+float(crystal.get("cooldown_s",0.0))},StringName("P20/cooldown/%s" % key))
		_spawn_crystal(crystal,actor.motor.global_position,StringName("P20/%s" % key))
	if broken_changed:
		var build := owner.call("build") as BuildState
		if build != null: build.refresh_equipped()
		owner.call("sync")

func activate(id: StringName, _direction: Vector2) -> Dictionary:
	if id not in [&"P26",&"P27",&"N02"]: return _result(false,&"not_defense_active")
	var params := _params(id)
	if not _live() or params.is_empty(): return _result(false,&"not_equipped")
	var actor := _actor()
	var owner := _owner()
	var state := _state(id)
	if _now() < float(state.get("ready_at",0.0)): return _result(false,&"cooldown")
	var uses: Dictionary = (state.get("map_uses",{}) as Dictionary).duplicate()
	var used := int(uses.get(_map(),0))
	if id == &"P27":
		if actor.actor_resources.health.normal_healing_blocked: return _result(false,&"healing_blocked")
		if actor.actor_resources.health.current >= actor.actor_resources.health.capacity: return _result(false,&"health_full")
		if used >= int(params.get("max_uses_per_map",0)): return _result(false,&"map_use_limit")
	if id == &"N02":
		if used >= int(params.get("max_uses_per_map",0)): return _result(false,&"map_use_limit")
		if barrier_amount() >= float(_shared_cap): return _result(false,&"barrier_full")
	var receipt := StringName("%s/%s/use/%s/%s" % [id,_map(),used,_now()])
	if not bool(owner.call("spend_energy",float(params.get("combat_energy_cost",0.0)),receipt)): return _result(false,&"combat_energy")
	if id == &"P26":
		var visual: Dictionary = owner.call("presentation_receipt",id,receipt)
		var point := actor.motor.global_position
		var committed := _patch(id,{"ready_at":_now()+float(params.get("cooldown_s",0.0)),"invulnerable_until":_now()+float(params.get("invulnerable_duration_real_active_s",0.0))},StringName("%s/state" % receipt))
		if committed: owner.call("present_committed",&"item_guard_active",point,visual)
	elif id == &"P27":
		owner.call("heal",float(params.get("heal_hp",0.0)),StringName("%s/heal" % receipt),id)
		uses[_map()] = used+1
		_patch(id,{"map_uses":uses},StringName("%s/state" % receipt))
	else:
		grant_barrier(int(params.get("barrier_grant",0)),StringName("%s/barrier" % receipt),id)
		uses[_map()] = used+1
		_patch(id,{"map_uses":uses},StringName("%s/state" % receipt))
	owner.call("cue",&"defense_active",actor.motor.global_position,{"item":id})
	return _result(true,&"")

func _spawn_crystal(params: Dictionary, point: Vector2, receipt: StringName) -> void:
	var owner := _owner()
	var world := owner.call("world_root") as Node2D
	if not is_instance_valid(world): return
	var marker := CrystalGlyph.new()
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.radius = float(_tuning.get("crystal_contact_radius_px",0.0))
	if marker.radius <= 0.0: return
	marker.set_meta(&"item_v5_world_entity",true)
	world.add_child(marker)
	marker.global_position = point
	_crystals.append({"node":marker,"remaining":float(params.get("crystal_lifetime_s",0.0)),"ratio":float(params.get("contact_damage_ratio_D",0.0)),"radius":marker.radius,"receipt":receipt,"targets":{}})

func advance(_real_delta: float, world_delta: float) -> void:
	if not _live(): return
	_commit_entry()
	var owner := _owner()
	for row: Dictionary in _crystals.duplicate():
		var marker := row.node as Node2D
		if not is_instance_valid(marker):
			_crystals.erase(row)
			continue
		if world_delta <= 0.0: continue
		(marker as CrystalGlyph).visual_age += world_delta
		marker.queue_redraw()
		row.remaining = float(row.remaining)-world_delta
		if row.remaining <= 0.0 or _params(&"P20").is_empty():
			marker.queue_free()
			_crystals.erase(row)
			continue
		for target: Dictionary in owner.call("targets",marker.global_position,float(row.radius)):
			var receiver := target.receiver as Damageable
			var target_id := receiver.get_instance_id()
			if (row.targets as Dictionary).has(target_id) or not bool(owner.call("clear_line",marker.global_position,(target.node as Node2D).global_position)): continue
			(row.targets as Dictionary)[target_id] = true
			owner.call("deal",receiver,float(owner.call("base_damage"))*float(row.ratio),StringName("%s/%s" % [row.receipt,target_id]),&"P20")
	_advance_guard(world_delta)

func _advance_guard(world_delta: float) -> void:
	var params := _params(&"P16")
	if params.is_empty():
		_clear_glyph()
		return
	var actor := _actor()
	var owner := _owner()
	if not is_instance_valid(_glyph):
		_glyph = GuardGlyph.new()
		_glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_glyph.radius = float(_tuning.get("orbit_intercept_radius_px",0.0))
		actor.motor.add_child(_glyph)
	_glyph.visual_age += maxf(0.0,world_delta)
	_orbit_age += maxf(0.0,world_delta)*float(_tuning.get("orbit_angular_speed_rad_s",0.0))
	_glyph.position = Vector2.from_angle(_orbit_age)*float(params.get("orbit_radius_px",0.0))
	var morning := not _params(&"B13").is_empty() and barrier_amount() > 0.0
	_glyph.scale = Vector2.ONE * (float(_tuning.get("morning_guard_visual_multiplier",1.0)) if morning else 1.0)
	_glyph.available = _now() >= float(_state(&"P16").get("ready_at",0.0))
	_glyph.queue_redraw()
	var world := owner.call("world_root") as Node
	var nodes: Array[Node] = []
	if is_instance_valid(world): _collect_projectiles(world,nodes)
	var parent := actor.motor.get_parent()
	if is_instance_valid(parent):
		for child: Node in parent.get_children():
			if child != world and child != actor.motor: _collect_projectiles(child,nodes)
	var next_positions: Dictionary = {}
	for node: Node in nodes:
		var projectile := node as Node2D
		var id := projectile.get_instance_id()
		next_positions[id] = projectile.global_position
		if not _glyph.available or bool(projectile.get_meta(&"unblockable",false)) or not bool(projectile.get_meta(&"interceptable",true)): continue
		if (projectile is EnemyAttackProjectile and (projectile as EnemyAttackProjectile).spent) or (projectile is BossProjectile and (projectile as BossProjectile).spent): continue
		# Existing windblade/pier proxies are Boss attack geometry, not a visible
		# flying bullet; destroying the proxy must not cancel that authored move.
		if projectile is BossProjectile and not (projectile as BossProjectile)._visible_attack(): continue
		if (projectile is ForestSeedProjectile and (projectile as ForestSeedProjectile).landed) or (projectile is ThornSeedProjectile and (projectile as ThornSeedProjectile).landed): continue
		var start: Vector2 = _projectile_positions.get(id,projectile.global_position)
		var guard_start := _previous_guard if _previous_guard.is_finite() else _glyph.global_position
		var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,start-guard_start,projectile.global_position-_glyph.global_position)
		var radius := float(projectile.get("radius"))+_glyph.radius
		if closest.length_squared() > radius*radius or not bool(owner.call("clear_line",_glyph.global_position,projectile.global_position)): continue
		var receipt := StringName("P16/%s/%s" % [_map(),id])
		var multiplier := 1.0
		if morning:
			var synergy: Dictionary = _synergies.get("S09",{})
			var values: Dictionary = synergy.get("parameters",{})
			multiplier = clampf(float(values.get("intercept_cooldown_multiplier",1.0)),0.01,1.0)
		_patch(&"P16",{"ready_at":_now()+float(params.get("cooldown_s",0.0))*multiplier},receipt)
		projectile.call("dispose")
		_glyph.available = false
		owner.call("cue",&"projectile_intercept",_glyph.global_position,{"item":&"P16"})
	_projectile_positions = next_positions
	_previous_guard = _glyph.global_position

# The existing policy signal is the only rescue presentation commit bridge.
# Preparing a defense, spending energy, or setting map uses is not an outcome.
func _current_rescue_policy() -> FrameDamagePolicy:
	var actor := _actor()
	if not is_instance_valid(actor): return null
	var reference: Variant = actor.get_meta(&"frame_damage_policy",null)
	return reference.get_ref() as FrameDamagePolicy if reference is WeakRef else null

func _prepare_rescue_visual(request: DamageRequest, policy: FrameDamagePolicy, proof: Dictionary, point: Vector2) -> void:
	if proof.is_empty() or not is_instance_valid(policy) or policy != _current_rescue_policy() or request.token == null: return
	var previous := _rescue_policy.get_ref() as FrameDamagePolicy if _rescue_policy != null else null
	if previous != policy:
		_clear_rescue_observer()
		_rescue_policy = weakref(policy)
		policy.batch_resolved.connect(_on_rescue_batch)
	if _rescue_visual_tickets.size()>=MAX_RESCUE_VISUAL_TICKETS: _rescue_visual_tickets.erase(_rescue_visual_tickets.keys()[0])
	_rescue_visual_tickets[request.get_instance_id()] = {"request":weakref(request),"proof":proof.duplicate(true),"point":point,"token":request.token.key(),"actor_epoch":request.actor_epoch,"health_epoch":request.health_epoch,"health_id":_actor().actor_resources.health.get_instance_id()}

func _on_rescue_batch(results: Array[DamageResult]) -> void:
	var policy := _rescue_policy.get_ref() as FrameDamagePolicy if _rescue_policy != null else null
	var tickets := _rescue_visual_tickets.duplicate()
	_rescue_visual_tickets.clear()
	if not _live() or not is_instance_valid(policy) or policy.lifetime == null or policy != _current_rescue_policy(): return
	for result: DamageResult in results:
		if result == null or not result.rescued or result.lethal or result.request == null or result.health == null or result.health.terminal: continue
		var request := result.request
		var row: Dictionary = tickets.get(request.get_instance_id(),{})
		if row.is_empty() or (row.request as WeakRef).get_ref() != request or request.token == null or not policy.lifetime.accepts(request.token): continue
		if request.token.key() != row.token or request.actor_epoch != row.actor_epoch or request.health_epoch != row.health_epoch: continue
		var health := _actor().actor_resources.health
		if health.get_instance_id() != row.health_id or health.epoch != row.health_epoch or health.terminal: continue
		_owner().call("present_committed",&"item_rescue_committed",row.point,row.proof,{"remaining_hp":result.health.current,"hp_lost":result.hp_lost})

func _clear_rescue_observer() -> void:
	var policy := _rescue_policy.get_ref() as FrameDamagePolicy if _rescue_policy != null else null
	if is_instance_valid(policy) and policy.batch_resolved.is_connected(_on_rescue_batch): policy.batch_resolved.disconnect(_on_rescue_batch)
	_rescue_policy = null
	_rescue_visual_tickets.clear()

func _collect_projectiles(node: Node, output: Array[Node]) -> void:
	if node is EnemyAttackProjectile or node is BossProjectile:
		if node not in output: output.append(node)
		return
	for child: Node in node.get_children(): _collect_projectiles(child,output)

func _clear_glyph() -> void:
	if is_instance_valid(_glyph): _glyph.queue_free()
	_glyph = null
	_previous_guard = Vector2.INF
	_projectile_positions.clear()

func clear_world_entities() -> void:
	_clear_rescue_observer()
	for row: Dictionary in _crystals:
		if is_instance_valid(row.node): (row.node as Node).queue_free()
	_crystals.clear()
	_clear_glyph()

func snapshot() -> Dictionary:
	return {"barrier":barrier_amount(),"barrier_cap":_shared_cap,"crystals":_crystals.size(),"curtain_remaining":maxf(0.0,float(_state(&"P26").get("invulnerable_until",0.0))-_now()) if not _params(&"P26").is_empty() else 0.0}

func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted":accepted,"reason":reason}

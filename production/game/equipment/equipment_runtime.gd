class_name EquipmentRuntime
extends RefCounted
## One player's permanent build and transient equipment clocks.
var session: OrdinaryRoomSession
var actor: PlayerController
var services: WorldServices
var fx: Dictionary
var packets := {}
var proof := {}
var serial := 0
var grounded_frames := 0
var base_hp: float
var freeze := WorldFreezeScope.new()
var scene: EquipmentField

func bind(host: OrdinaryRoomSession) -> void:
	session = host
	actor = host.controller
	services = host.services
	base_hp = actor.actor_resources.health_definition.max_health
	fx = services.ledger().effects.duplicate(true)
	var defaults := {"cooldowns":{}, "marks":{}, "dots":{}, "time":{}, "shields":[], "hurt_count":0,
		"rescued":false,"drone_progress":0.0,"gold_fraction":0.0,"enchanted":false,"target":{},
		"armed":false,"in_air":false,"epoch":0,"refund":0.0,"air_hits":0,"companions":{},"guard_hp":0.0}
	defaults.merge(fx, true)
	fx = defaults
	actor.item_runtime = self
	actor.air_focus_ability.air_time_used = fx.get("aim_seconds",0.0)
	if fx.has("stamina"): actor.actor_resources.stamina.restore_value(fx.stamina)
	actor.air_focus_ability.world_scale_resolver = world_scale
	freeze.bind(host.room,actor.motor)
	actor.air_focus_ability.world_freeze_callback = freeze.set_frozen
	actor.combat_energy.spent.connect(_spent)
	scene = EquipmentField.new()
	scene.runtime = self
	host.add_child(scene)
	scene.restore_field(fx.get("field",{}))
	sync_resources(true)

func has(id: String) -> bool: return services.active(id)

func p(id: String, key: String, fallback: float = 0) -> float:
	return EquipmentCatalog.parameter(id,services.level(id),key,fallback)

func sync_resources(restore: bool = false) -> void:
	var health := actor.actor_resources.health
	var maximum := (base_hp + p("B11","capacity")) * p("P18","capacity_scale",1)
	if maximum != health.capacity:
		health.set_max(ActorResourceRequest.new(StringName("equip_max:%s" % services.state.revision),health.epoch,maximum,health.get_instance_id()))
	health.normal_healing_blocked = has("P18")
	actor.combat_energy.set_capacity_bonus(p("B26","capacity"))
	if restore:
		health.restore_value(services.state.value.hp)
		actor.combat_energy.current = minf(services.state.value.combat_energy,actor.combat_energy.capacity())
	var base: Dictionary = session.heal_base
	session.focus_heal.settings.cost = p("143","cost",base.cost)
	session.focus_heal.settings.heal = p("143","heal",base.heal)
	session.focus_heal.settings.charge_seconds = p("143","seconds",base.charge_seconds) * p("144","seconds_scale",1)

func snapshot() -> Dictionary:
	var result := fx.duplicate(true)
	result.aim_seconds = actor.air_focus_ability.air_time_used
	result.field = scene.saved_field()
	result.stamina = actor.actor_resources.stamina.current
	return result

func stage(candidate: Dictionary, kind: String, id: String) -> void:
	var gear: Dictionary = candidate.services
	var saved := snapshot()
	var equipped: Array = gear.equipped
	var level := int(gear.owned.get("B11",0)) if "B11" in equipped else 0
	var maximum := (base_hp + EquipmentCatalog.parameter("B11",level,"capacity")) * EquipmentCatalog.parameter("P18",int(gear.owned.get("P18",0)) if "P18" in equipped else 0,"capacity_scale",1)
	candidate.hp = minf(actor.actor_resources.health.current,maximum)
	var bonus := EquipmentCatalog.parameter("B26",int(gear.owned.get("B26",0)) if "B26" in equipped else 0,"capacity")
	candidate.combat_energy = minf(actor.combat_energy.current,actor.combat_energy.definition.capacity + bonus)
	if kind == "unequip":
		var spatial := {"B23":"rings","99":"winds","89":"decoy","84":"anchors"}
		if spatial.has(id): saved.field.erase(spatial[id])
		saved.shields = saved.shields.filter(func(origin): return origin != id)
		if id == "G05": saved.guard_hp = 0.0
		if id in ["P14","P15","G05","G19"]: saved.companions.erase(id)
		if id == "117": saved.target = {}; saved.armed = false
		if id in ["103","104","105"]:
			saved.enchanted = false
			for target: String in saved.time: saved.time[target].erase(id)
		if id == "B24": saved.dots.clear()
		if id == "119": saved.marks.erase("memory")
		if id in ["P13","G01"]:
			var prefix := "hook:" if id == "P13" else "echo:"
			for key: String in saved.marks.keys():
				if key.begins_with(prefix): saved.marks.erase(key)
		if id == "P26": saved.erase("protected")
	if kind == "rest":
		candidate.hp = maximum
		saved.hurt_count = 0
		saved.rescued = false
		if saved.guard_hp > 0: saved.guard_hp = p("G05","hp")
		if "B13" in equipped:
			while saved.shields.size() < int(p("B13","shields")): saved.shields.append("B13")
	gear.effects = saved

func after_transaction(kind: String, id: String) -> void:
	if kind == "unequip": scene.remove_source(id)
	fx = services.ledger().effects.duplicate(true)
	sync_resources(true)

func world_scale(base: float) -> float:
	var hp := actor.actor_resources.health
	return 0.0 if has("P06") and hp.current >= hp.capacity else p("N01","scale",base)

func world_is_frozen() -> bool: return freeze.frozen
func skill_cost(base: float) -> float: return base * p("P02","cost",1)
func selected_active() -> String: return services.ledger().selected
func weapon_cooldown_multiplier() -> float: return p("B05","interval",1)
func projectile_range_multiplier() -> float: return p("B22","range_scale",1)
func extra_pierce() -> Dictionary: return {"count":int(p("P08","count")),"damage_ratio":p("P08","damage_ratio",1)}
func monster_iframe(base: float) -> float: return base * p("B27","duration_scale",1)
func base_damage() -> float: return actor.motor.tuning.projectile_damage

func ready(id: String) -> bool: return float(fx.cooldowns.get(id,0)) <= 0
func cooldown(id: String) -> void: fx.cooldowns[id] = p(id,"cooldown")
func primary_packet_started(packet: int, direction: Vector2) -> void:
	fx.packet_serial = int(fx.get("packet_serial",0)) + 1
	packets[packet] = {"identity":fx.packet_serial,"epoch":fx.epoch,"air":not actor.motor.is_on_floor(),"recoil":false,
		"levels":services.ledger().equipped.reduce(func(levels: Dictionary,id: String): levels[id] = services.level(id); return levels,{}),
		"enchantment":fx.enchanted,"base":base_damage(),"low":p("P05","bonus") if actor.actor_resources.health.current <= actor.actor_resources.health.capacity * p("P05","threshold") else 0,
		"seen":{},"direction":direction}
	if packets.size() > 512: packets.erase(packets.keys()[0])

func recoil_started(packet: int) -> void:
	if packets.has(packet): packets[packet].recoil = true

func shot_parameter(shot: Dictionary, id: String, key: String, fallback: float = 0) -> float:
	return EquipmentCatalog.parameter(id,int(shot.get("levels",{}).get(id,0)),key,fallback)

func target_id(receiver: Damageable) -> String:
	for id: String in session.room.enemies:
		if session.room.enemies[id].damageable == receiver.damage_policy_owner(): return id
	return ""

func modify_direct_damage(amount: float, receiver: Damageable, skill: bool, packet: int) -> float:
	var shot: Dictionary = packets.get(packet,{})
	if skill: return amount * shot_parameter(shot,"P03","damage_scale",1)
	var marked: bool = fx.marks.has("hook:" + target_id(receiver))
	return amount * (1 + float(packets.get(packet,{}).get("low",0)) + (shot_parameter(shot,"P13","bonus") if marked else 0.0))

func on_hit(event: Dictionary) -> void:
	var receiver := event.receiver as Damageable
	if not is_instance_valid(receiver) or not receiver.grants_combat_energy: return
	var id := target_id(receiver)
	if id.is_empty(): return
	var packet: int = event.packet
	var shot: Dictionary = packets.get(packet,{})
	var skill: bool = event.skill
	if shot.is_empty(): return
	var seen: Dictionary = shot.get("seen",{})
	var airborne: bool = shot.get("air",false) and fx.in_air and shot.get("epoch") == fx.epoch
	if not skill and not seen.has("gain"):
		seen.gain = true
		var bonus := shot_parameter(shot,"B18","bonus")
		if airborne:
			var refund := minf(shot_parameter(shot,"B06","refund"),shot_parameter(shot,"B06","limit") - float(fx.refund))
			if refund > 0:
				actor.actor_resources.stamina.grant_continuous(refund,actor.actor_resources.stamina.epoch)
				fx.refund += refund
			fx.air_hits += 1
			if fx.air_hits == int(shot_parameter(shot,"75","packets")): bonus += shot_parameter(shot,"75","bonus")
		actor.combat_energy.committed_hit("%s/%s" % [actor.session_id,packet],event.target_id,false,bonus)
	elif not skill:
		actor.combat_energy.committed_hit("%s/%s" % [actor.session_id,packet],event.target_id)
	var base: float = shot.get("base",base_damage())
	if not skill and not seen.has("primary"):
		seen.primary = true
		if shot.levels.has("119"): fx.marks["memory"] = {"target":id,"remaining":shot_parameter(shot,"119","duration")}
		if shot.levels.has("P31") and shot.air and shot.recoil and ready("P31"):
			strike(receiver,base*shot_parameter(shot,"P31","damage"),"P31"); cooldown("P31")
		if shot.levels.has("P09") and ready("P09"):
			scene.area(event.point,shot_parameter(shot,"P09","radius"),base*shot_parameter(shot,"P09","damage"),"P09"); cooldown("P09")
		if shot.levels.has("B24") and ready("B24"):
			fx.dots[id] = {"due":shot_parameter(shot,"B24","interval"),"interval":shot_parameter(shot,"B24","interval"),"ticks":int(shot_parameter(shot,"B24","ticks")),"damage":base*shot_parameter(shot,"B24","damage")}
			cooldown("B24")
		if shot.levels.has("G01"):
			var key := "echo:"+id
			if fx.marks.has(key) and fx.marks[key].packet != shot.identity:
				strike(receiver,base*shot_parameter(shot,"G01","damage"),"G01"); fx.marks.erase(key); fx.cooldowns[key] = shot_parameter(shot,"G01","cooldown")
			elif ready(key) and shot.air: fx.marks[key] = {"packet":shot.identity,"remaining":shot_parameter(shot,"G01","duration")}
	if shot.levels.has("P29") and not seen.has("chain") and ready("P29"):
		seen.chain = true
		scene.chain(id,base,int(shot.levels.P29)); cooldown("P29")
	if event.get("bullet",false) and not skill and not seen.has("time:"+id):
		seen["time:"+id] = true
		enchant(id,receiver.time_profile,shot)

func enchant(id: String, kind: String, shot: Dictionary) -> void:
	if kind == "incompatible" or not shot.enchantment: return
	var effects: Dictionary = fx.time.get(id,{})
	for core in ["103","104","105"]:
		if not shot.levels.has(core): continue
		var stop: bool = core == "105"
		if stop and not ready("105:"+str(session.room.room_id)+"/"+id): return
		var duration := shot_parameter(shot,core,kind if stop else "duration") * shot_parameter(shot,"141","duration_scale",1)
		effects[core] = {"remaining":duration,"scale":0.0 if stop else shot_parameter(shot,core,kind)}
		if stop: fx.cooldowns["105:"+str(session.room.room_id)+"/"+id] = shot_parameter(shot,core,"cooldown")
	fx.time[id] = effects

func mechanism_hit(platform: WorldMovingPlatform, packet: int) -> void:
	if not packets.has(packet) or not packets[packet].enchantment: return
	var key := "time:" + platform.element_id
	if packets[packet].seen.has(key): return
	packets[packet].seen[key] = true
	enchant(platform.element_id,"mechanism",packets[packet])

func on_hook_hit(receiver: Damageable, packet: int) -> void:
	var id := target_id(receiver)
	if id.is_empty() or not receiver.grants_combat_energy: return
	if has("P13"): fx.marks["hook:"+id] = {"remaining":p("P13","duration")}
	if has("P29") and ready("P29"):
		scene.chain(id,base_damage(),services.level("P29")); cooldown("P29")

func strike(receiver: Damageable, amount: float, origin: String) -> void:
	if not is_instance_valid(receiver) or not receiver.active or amount <= 0: return
	serial += 1
	var key := "equipment/%s/%s" % [actor.motor.get_instance_id(),serial]
	proof[key] = [receiver.get_instance_id(),amount,origin]
	receiver.receive_damage({"event_id":key,"amount":amount,"item_origin":origin,"source_actor_id":actor.motor.get_instance_id(),
		"target_actor_id":receiver.actor_id,"target_epoch":receiver.damage_epoch,"source_faction":&"player","item_effect_damage":true})
	if proof.size() > 512: proof.erase(proof.keys()[0])

func authorizes_effect(context: Dictionary, receiver: Damageable) -> bool:
	return proof.get(str(context.event_id),[]) == [receiver.get_instance_id(),context.amount,str(context.item_origin)]

func advance(real_delta: float, delta: float) -> void:
	if not actor.active or not session.lifetime.active: return
	for key: String in fx.cooldowns.keys():
		fx.cooldowns[key] = maxf(0,fx.cooldowns[key] - (real_delta if key == "P26" else (0.0 if freeze.frozen else delta)))
		if fx.cooldowns[key] <= 0: fx.cooldowns.erase(key)
	fx.protected = maxf(0,float(fx.get("protected",0))-real_delta)
	var grounded := actor.motor.is_on_floor()
	grounded_frames = grounded_frames + 1 if grounded else 0
	if grounded_frames >= 2 and fx.in_air:
		fx.in_air = false; fx.refund = 0; fx.air_hits = 0
	if not grounded and not fx.in_air: fx.epoch += 1; fx.in_air = true
	scene.update_aim()
	if freeze.frozen:
		freeze.advance_contacts()
		return
	for key: String in fx.marks.keys():
		fx.marks[key].remaining -= delta
		if fx.marks[key].remaining <= 0: fx.marks.erase(key)
	for id: String in fx.time.keys():
		var scale := 1.0
		var slowed := false
		for core: String in fx.time[id].keys():
			var effect: Dictionary = fx.time[id][core]
			effect.remaining -= delta
			if effect.remaining <= 0: fx.time[id].erase(core); continue
			if effect.scale < 1: scale = minf(scale,effect.scale); slowed = true
			elif not slowed: scale = maxf(scale,effect.scale)
		scene.set_target_time(id,scale)
		if fx.time[id].is_empty(): fx.time.erase(id)
	for id: String in fx.dots.keys():
		var dot: Dictionary = fx.dots[id]
		dot.due -= delta
		while dot.due <= 1e-8 and dot.ticks > 0:
			if session.room.enemies.has(id): strike(session.room.enemies[id].damageable,dot.damage,"B24")
			dot.ticks -= 1; dot.due += dot.interval
		if dot.ticks == 0: fx.dots.erase(id)
	scene.advance(delta)

func activate_selected(_direction: Vector2) -> void:
	if not actor.active or not session.lifetime.active or actor.actor_resources.health.terminal: return
	var id := selected_active()
	if not has(id) or not ready(id): return
	match id:
		"103","104","105": fx.enchanted = not fx.enchanted
		"117":
			if fx.armed or not fx.target.is_empty(): fx.armed = false; fx.target = {}
			else: fx.armed = true
		"P26","G05":
			if id == "G05" and fx.guard_hp > 0: return
			serial += 1
			if not actor.combat_energy.consume("gear/%s/%s" % [id,serial],skill_cost(p(id,"cost"))): return
			cooldown(id)
			if id == "P26": fx.protected = p(id,"duration")
			else:
				fx.guard_hp = p(id,"hp")
				fx.guard_generation = int(fx.get("guard_generation",0)) + 1
				fx.guard_hits = []
				fx.companions.G05 = [{"next":p(id,"interval")}]

func _spent(_event: String, amount: float) -> void:
	stage_spending(fx,amount)

func stage_spending(saved: Dictionary, amount: float) -> void:
	if not has("P15"): return
	var drones: Array = saved.companions.get("P15",[])
	saved.drone_progress += amount
	while saved.drone_progress >= p("P15","cost") and drones.size() < int(p("P15","limit")):
		saved.drone_progress -= p("P15","cost")
		drones.append({"next":p("P15","interval"),"life":p("P15","duration"),"base":base_damage()})
	if drones.size() >= int(p("P15","limit")): saved.drone_progress = minf(saved.drone_progress,p("P15","cost")-1)
	saved.companions.P15 = drones

func defend_request(request: DamageRequest, hp: float) -> Dictionary:
	if request.kind == DamageRequest.Kind.ENVIRONMENT: return {}
	var amount := request.amount
	if fx.get("protected",0.0) > 0: return {"amount":0,"blocked":true}
	if has("P16") and ready("P16") and request.contact:
		cooldown("P16")
		return {"amount":0,"blocked":true,"barrier_absorbed":amount}
	var absorbed := 0.0
	while not fx.shields.is_empty() and amount > 0:
		fx.shields.pop_front()
		absorbed += minf(1,amount); amount = maxf(0,amount-1)
	var rescue := false
	if amount >= hp and has("G04") and not fx.rescued:
		if actor.combat_energy.consume("rescue:"+str(session.state.value.cycle),p("G04","cost")):
			fx.rescued = true; rescue = true; amount = maxf(0,hp-p("G04","hp"))
	return {"amount":amount,"blocked":amount<=0,"barrier_absorbed":absorbed,"rescued":rescue}

func on_damage(event: Dictionary) -> void:
	if event.kind == DamageRequest.Kind.ENVIRONMENT: return
	actor.combat_energy.grant("hurt:"+str(event.event_id),p("B14","gain"))
	if has("G02"):
		fx.hurt_count += 1
		if fx.hurt_count >= p("G02","hits"):
			fx.hurt_count = 0
			if fx.shields.size() < int(EquipmentCatalog.DATA.data.shield_limit): fx.shields.append("G02")

func clear() -> void:
	freeze.release()
	fx.guard_hp = 0.0
	fx.companions.clear()

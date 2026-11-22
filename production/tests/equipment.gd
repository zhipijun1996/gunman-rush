extends SceneTree

class Storage extends WorldSaveService:
	var payload := {}
	var revision := 0
	var writable := true

	func commit(value: Dictionary, next: int) -> bool:
		if not writable or next != revision + 1: return false
		payload = value.duplicate(true)
		revision = next
		return true

	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":payload.duplicate(true),"revision":revision}

var failures := 0
var checks := 0
var session: OrdinaryRoomSession
var store := Storage.new()
const AT := [160,366]

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ",label)

func station(definition: String, id: String, properties: Dictionary) -> Dictionary:
	return {"definition_id":definition,"definition_version":1,"id":id,"properties":properties}

func document() -> Dictionary:
	var doc := WorldRoomDocument.read("res://tests/assembly_room.json")
	doc.entities.patrol.properties.max_health = 20
	doc.entities.note = station("reward.resource","note",{"position":[310,366],"resource_kind":"note","amount":1})
	doc.entities.rest = station("recovery.station","rest",{"position":AT})
	doc.entities.smith = station("equipment.smith","smith",{"position":AT})
	for source: String in EquipmentCatalog.REWARDS.data:
		var id: String = EquipmentCatalog.REWARDS.data[source]
		doc.entities[id] = station("equipment.reward",id,{"position":AT,"source_id":source})
	return doc

func submit(kind: String, id: String = "") -> bool:
	return session.equipment_transaction(kind,id,session.state.revision)

func combat_checks() -> void:
	var gear := session.equipment
	var enemy: EnemyActor = session.room.enemies.patrol
	var hp := enemy.health.current
	check(submit("unequip","P15") and submit("equip","B24") and submit("equip","P09"),"area and periodic loadout")
	await physics_frame
	var point := enemy.motor.global_position
	gear.primary_packet_started(901,Vector2.RIGHT)
	var event := {"receiver":enemy.damageable,"packet":901,"skill":false,"point":point,"target_id":enemy.damageable.actor_id,"bullet":true}
	if int(event.target_id) == 0: event.target_id = enemy.damageable.get_instance_id()
	var resonance := session.controller.combat_energy.current
	gear.on_hit(event)
	gear.on_hit(event)
	session.policy.resolve_batch()
	check(is_equal_approx(enemy.health.current,hp-.60*gear.base_damage()),"one authenticated area hit per packet")
	check(is_equal_approx(session.controller.combat_energy.current,resonance+7),"one gain per damageable target and packet")
	var ticks := int(gear.fx.dots.patrol.ticks)
	gear.advance(3.0,3.0)
	session.policy.resolve_batch()
	check(ticks == 6 and not gear.fx.dots.has("patrol") and is_equal_approx(enemy.health.current,hp-1.5*gear.base_damage()),"all six fractional DOT ticks survive a shared frame")
	check(is_equal_approx(session.controller.combat_energy.current,resonance+7),"derived damage produces no currency")
	check(submit("unequip","B24") and submit("unequip","P09") and submit("equip","105") and submit("equip","141"),"time enchant loadout")
	gear.activate_selected(Vector2.RIGHT)
	gear.primary_packet_started(902,Vector2.RIGHT)
	event.packet = 902
	gear.on_hit(event)
	gear.advance(.01,.01)
	check(is_zero_approx(enemy.damageable.equipment_time_scale),"normal target stopped")
	gear.advance(2.0,2.0)
	check(is_equal_approx(enemy.damageable.equipment_time_scale,1.0) and not gear.ready("105:"+str(session.room.room_id)+"/patrol"),"target resumes while reapplication still locked")
	check(submit("unequip","105") and submit("unequip","141") and submit("equip","P26") and submit("equip","P02"),"protective active and discount")
	session.controller.combat_energy.grant("protection",100)
	gear.activate_selected(Vector2.RIGHT)
	check(is_equal_approx(session.controller.combat_energy.current,36),"P26 pays discounted 64")
	var hit := DamageRequest.new()
	hit.kind = DamageRequest.Kind.MONSTER
	hit.amount = 4
	check(gear.defend_request(hit,3).get("blocked",false),"enemy hit suppressed")
	hit.kind = DamageRequest.Kind.ENVIRONMENT
	check(gear.defend_request(hit,3).is_empty(),"forced terrain goes to scene policy")
	gear.advance(3.0,0.0)
	check(is_zero_approx(gear.fx.protected) and is_equal_approx(gear.fx.cooldowns.P26,27),"protection uses active real time")
	check(submit("unequip","P26") and submit("unequip","P02") and submit("equip","B01"),"pickup loadout")
	var pickup: WorldResourcePickup
	for node: Node in session.room.get_children():
		if node is WorldResourcePickup: pickup = node
	check(pickup != null,"direct pickup is a real room component")
	if pickup != null:
		pickup.global_position = session.player.global_position + Vector2(60,-12)
		pickup._physics_process(0.016)
		pickup._physics_process(0.016)
		check(session.state.value.inventory.get("notes",0) == 1 and not pickup.visible,"magnet claims a permanent note once")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var doc := document()
	var invalid := doc.duplicate(true)
	invalid.entities.B05.properties.source_id = "unknown"
	check(WorldRoomDocument.instantiate(invalid).has("error"),"unregistered world reward rejected")
	session = OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc,store)
	check(error.is_empty(),"equipment room opens "+error)
	if not error.is_empty(): session.free(); quit(1); return
	check(session.equipment_sites.size() == 61,"60 actual pickup hosts and one smith")
	var sources: Dictionary = EquipmentCatalog.REWARDS.data
	for source: String in sources:
		check(submit("claim",source),source)
		check(not submit("claim",source),"unique "+source)
	check(session.services.ledger().owned.size() == 60,"collection size")
	session.player.position += Vector2(180,0)
	check(not submit("equip","B11") and not submit("upgrade","B11"),"services require physical access")
	session.player.position = Vector2(AT[0],AT[1])
	var before := session.state.revision
	check(submit("equip","B11"),"equip with permanent ownership")
	session.equipment.fx.hurt_count = 2
	check(session.equipment_transaction("equip","B11",before) and session.equipment.fx.hurt_count == 2,"replay preserves live counters")
	check(not submit("upgrade","B11"),"insufficient funds")
	var funds := session.services.earned_candidate(session.state.candidate(),"treasury",3000)
	check(session.state.commit(funds,session.state.revision),"test income committed")
	store.writable = false
	check(not submit("upgrade","B11") and session.services.ledger().gold == 3000 and session.services.level("B11") == 1,"failed disk write rolls back price and level")
	store.writable = true
	var upgrades := 0
	var loads := [0,0,0,0,0,0]
	for id: String in EquipmentCatalog.DATA.data.items:
		var item := EquipmentCatalog.item(id)
		loads[int(item.load)] += 1
		if item.max_level == 3:
			upgrades += 1
			check(submit("upgrade",id) and submit("upgrade",id),"two valid NPC purchases "+id)
		check(not submit("upgrade",id),"no fourth level or fixed-item upgrade "+id)
	check(loads == [0,18,21,15,3,3] and upgrades == 14 and session.services.ledger().gold == 0,"all prices and loads")
	var health := session.controller.actor_resources.health
	var hp := health.current
	check(submit("equip","P18") and is_equal_approx(health.current,hp) and health.normal_healing_blocked,"capacity change preserves HP")
	check(submit("rest") and is_equal_approx(health.current,health.capacity),"confirmed rest restores new maximum")
	check(submit("unequip","P18") and is_equal_approx(health.current,health.capacity),"capacity clamps on removal")
	check(submit("unequip","B11") and submit("equip","103") and not submit("equip","104"),"enchantments mutually exclusive")
	check(submit("unequip","103") and submit("equip","P15") and submit("equip","G05"),"8 load exactly")
	check(not submit("equip","N01"),"ninth load rejected")
	session.controller.combat_energy.grant("summon",100)
	session.equipment.activate_selected(Vector2.RIGHT)
	var fx: Dictionary = session.equipment.fx
	check(fx.guard_hp == 6 and fx.companions.P15.size() == 1 and session.controller.combat_energy.current == 55,"summon and actual spending")
	session.equipment.activate_selected(Vector2.RIGHT)
	check(session.controller.combat_energy.current == 55,"duplicate summon free of charges")
	session.equipment.scene.guard_hit("first",2)
	session.equipment.scene.guard_hit("second",3)
	check(fx.guard_hp == 4,"guard uses independent iframe")
	check(session.checkpoint(),"save live summon")
	var next := OrdinaryRoomSession.new()
	root.add_child(next)
	var destination := doc.duplicate(true)
	destination.room_id = "second"
	store.writable = false
	check(next.open(destination,null,session) == "room_transition_save_failed" and session.lifetime.active,"failed travel preserves active room")
	store.writable = true
	check(await session.audio_service.shutdown(),"release first audio")
	check(next.open(destination,null,session).is_empty(),"committed travel")
	session = next
	check(session.equipment.fx.guard_hp == 4 and session.equipment.fx.companions.P15.size() == 1,"cross-room resources and summons")
	check(not submit("claim","equipment.G05"),"shared permanent world source")
	check(await session.audio_service.shutdown(),"release second audio")
	session.free()
	await process_frame
	session = OrdinaryRoomSession.new()
	root.add_child(session)
	check(session.open(destination,store).is_empty(),"ordinary reload")
	check(session.equipment.fx.guard_hp == 4 and session.controller.combat_energy.current == 55,"load does not rest or summon")
	check(submit("rest") and session.equipment.fx.guard_hp == 6,"rest heals surviving guard")
	check(submit("unequip","G05") and session.equipment.fx.guard_hp == 0 and not session.equipment.ready("G05"),"dismissal preserves cooldown")
	check(submit("equip","B13") and submit("rest") and session.equipment.fx.shields == ["B13","B13"],"true rest fills source shields")
	check(submit("unequip","B13") and session.equipment.fx.shields.is_empty(),"unequip removes its shields")
	await combat_checks()
	var disk := WorldSaveService.new()
	var file := "user://equipment_test_%s.json" % Time.get_ticks_usec()
	disk.configure(file,false,"equipment_tests")
	disk.content_version = session.state.content.data.content_version
	disk.payload_validator = session.state.valid
	check(disk.commit(session.state.candidate(),session.state.revision),"write real checksummed profile")
	var loaded := disk.load_profile()
	check(loaded.get("accepted",false) and loaded.get("payload",{}).get("inventory",{}).get("notes",0) == 1,"durable JSON round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	var migrated := WorldServices.normalize({"version":1,"owned":{"N01":{"level":3},"retired":{"level":1}},"equipped":["retired","N01"],"gold":45})
	check(migrated.owned == {"N01":3} and migrated.equipped == ["N01"] and migrated.gold == 45,"legacy identifiers migrate once")
	check(not WorldServices.valid_ledger(WorldServices.normalize({"version":1,"owned":[]})),"malformed legacy state rejected")
	check(await session.audio_service.shutdown(),"release restored audio")
	session.free()
	print("EQUIPMENT failures=",failures," checks=",checks)
	quit(1 if failures else 0)

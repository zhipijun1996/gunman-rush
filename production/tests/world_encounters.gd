extends SceneTree
var errors := 0
var catalog := WorldContentCatalog.new()

class Storage extends WorldSaveService:
	var writable := true
	var data := {}
	var sequence := 0
	func commit(next: Dictionary, revision: int) -> bool:
		if not writable: return false
		data = next.duplicate(true)
		sequence = revision
		return true
	func load_profile() -> Dictionary: return {"accepted":true,"revision":sequence,"payload":data.duplicate(true)}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	if not ok:
		printerr("FAIL encounter ",detail)
		errors += 1

func frames(count: int) -> void:
	for i in count: await physics_frame

func hit(session: OrdinaryRoomSession, member: String) -> void:
	var actor: EnemyActor = session.room.enemies[member]
	var request := DamageRequest.new()
	request.token = session.lifetime.token()
	request.source_id = &"test_impact"
	request.event_id = StringName(member)
	request.target_id = StringName(member)
	request.health_epoch = actor.health.epoch
	request.actor_epoch = session.lifetime.actor_epoch
	request.amount = actor.health.current
	check(session.policy.submit(request),"combat authority accepted the hit on "+member)
	await frames(6)

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"load locked catalog")
	var storage := Storage.new()
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var document := WorldRoomDocument.read("res://rooms/world/P07.json")
	var error := session.open(document,storage,null,catalog)
	check(error.is_empty(),error)
	if errors:
		session.free()
		quit(1)
		return
	await frames(6)
	var fight := session.encounters.front() as WorldRoomEncounter
	var gates_before := catalog.passage_access("P07","d007",session.state.value.flags)
	check(not gates_before.matches and not fight.confirm(),"entering cannot clear the fight")
	var first: String = fight.waves[0][0]
	var second: Array = fight.waves[1]
	check(session.room.enemies.has(first) and not session.room.enemies.has(second[0]),"only first wave deployed")
	await hit(session,first)
	for id: String in second:
		check(session.room.enemies.has(id),"second wave deployed after the first defeat")
		await hit(session,id)
	check(not fight.confirm(),"combat alone cannot confirm victory at a distance")
	session.player.reset_at(fight.position)
	await frames(6)
	var before: int = session.services.ledger().gold
	storage.writable = false
	session.controller.router.request_action(&"interact")
	await frames(3)
	check(not session.state.has("encounter_P07_clear") and session.services.ledger().gold == before,"failed write keeps gate and wallet unchanged")
	storage.writable = true
	session.controller.router.request_action(&"interact")
	await frames(3)
	check(catalog.passage_access("P07","d007",session.state.value.flags).matches and session.services.ledger().gold == before + int(fight.encounter.coin_reward),"one real interaction opens the mapped road and awards the locked victory purse")
	await session.audio_service.shutdown()
	session.free()
	await frames(3)
	session = OrdinaryRoomSession.new()
	root.add_child(session)
	check(session.open(document,storage,null,catalog).is_empty(),"reload won encounter")
	await frames(6)
	check(session.room.enemies.is_empty() and session.state.has("encounter_P07_clear"),"completed formation stays defeated on return")
	var gold: int = session.services.ledger().gold
	session.controller.router.request_action(&"interact")
	await frames(3)
	check(session.services.ledger().gold == gold,"return does not reissue the victory purse")
	await session.audio_service.shutdown()
	session.free()
	await frames(3)
	print("WORLD ENCOUNTERS failures=",errors)
	quit(1 if errors else 0)

extends SceneTree
## Enter two map arenas with an established late-game loadout, opt in, observe
## both cycles, and finish through the ordinary projectile and interaction paths.
var errors := 0
var checks := 0
var catalog := WorldContentCatalog.new()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		printerr("FAIL sky ",msg)

func frames(count: int) -> void:
	for i in count: await physics_frame

func exercise(id: String, member: String) -> void:
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var doc := WorldRoomDocument.read("res://rooms/world/"+id+".json")
	var error := session.open(doc,null,null,catalog)
	check(error.is_empty(),id+" production session "+error)
	if not error.is_empty():
		session.free()
		return
	await frames(6)
	var fight := session.encounters.front() as WorldRoomEncounter
	var profile := session.state.candidate()
	profile.flags.assign(["gun","W","H","D","Q"])
	check(session.state.commit(profile,session.state.revision),"load previously acquired combat actions")
	await frames(5)
	check(not session.room.enemies.has(member) and not fight.confirm(),id+" safe observation area")
	session.player.reset_at(fight.position+fight.start_offset)
	await frames(8)
	check(fight.confirm(),id+" request the trial while standing")
	await frames(4)
	var actor: EnemyActor = session.room.enemies.get(member)
	check(actor!=null,id+" live arena actor")
	if actor!=null:
		var ai := actor.attack_behavior as ArenaBossBehavior
		var location := Vector2(ai.home.x-140, ai.floor_y-18)
		session.player.reset_at(location)
		actor.set_physics_process(false)
		for i in 160:
			ai.advance(1./60.)
			if ai.state==&"telegraph": break
		check(ai.state==&"telegraph" and not actor.damageable.can_receive_effects(),id+" readable protected windup")
		var heads := ai.hit_rects(.04)
		check(heads.size()==(3 if id=="A11" else 1),id+" authored formation")
		check(ai.hit_rects(.60)!=heads,id+" moving strike")
		for i in 240:
			ai.advance(1./60.)
			if ai.state==&"recovery": break
		check(ai.state==&"recovery" and actor.damageable.can_receive_effects(),id+" exposed counterattack")
		var hp := actor.health.current
		var muzzle := actor.motor.global_position-Vector2(actor.definition.collision_size.x/2+51,0)
		session.player.reset_at(muzzle)
		var shot := session.controller.shoot_ability.try_fire(Vector2.RIGHT,true)
		await frames(14)
		check(shot and actor.health.current<hp,id+" player shot lands through open core")
		var hit := {"event_id":id+"-phase", "amount":hp*.51, "source_faction":&"player","target_actor_id":actor.damageable.actor_id,"target_epoch":actor.damageable.damage_epoch,"hit_direction":Vector2.RIGHT}
		check(actor.damageable.receive_damage(hit),id+" first phase threshold")
		session.policy.resolve_batch()
		session.player.reset_at(location)
		ai.advance(1./60.)
		check(ai.phases.phase==2,id+" second cycle")
		hit.event_id=id+"-finish"
		hit.amount=hp
		check(actor.damageable.receive_damage(hit),id+" last registered hit")
		session.policy.resolve_batch()
		await frames(8)
		check(actor.health.terminal and not session.state.has(fight.encounter.completion_flag),id+" victory awaits confirmation")
		session.player.reset_at(fight.position)
		await frames(6)
		var balance: int = session.services.ledger().gold
		session.controller.router.request_action(&"interact")
		await frames(3)
		check(session.state.has(fight.encounter.completion_flag) and session.services.ledger().gold==balance+int(fight.encounter.coin_reward),id+" one confirmed victory and locked purse")
	await session.audio_service.shutdown()
	session.free()
	await frames(4)

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"locked world")
	await exercise("A11","broken_wing")
	await exercise("V08","gatekeeper")
	print("SKY WORLD TRIALS failures=",errors," checks=",checks)
	quit(1 if errors else 0)

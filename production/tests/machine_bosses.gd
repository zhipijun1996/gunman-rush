extends SceneTree
## Three real room documents, the standard encounter, controller and projectile endpoint.
var failures := 0
var checks := 0
var catalog := WorldContentCatalog.new()

class Storage extends WorldSaveService:
	var data := {}
	var seq := 0
	func commit(next: Dictionary, revision: int) -> bool:
		data=next.duplicate(true)
		seq=revision
		return true
	func load_profile() -> Dictionary:
		return {"accepted":true,"revision":seq,"payload":data.duplicate(true)}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL machine: ",message)

func frames(n: int) -> void:
	for i in n: await physics_frame

func snapshot(tag: String) -> void:
	var path := OS.get_environment("MACHINE_BOSS_CAPTURE_DIR")
	if path.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path.path_join(tag+".png"))

func shot_context(actor: EnemyActor, id: String, amount: float) -> Dictionary:
	return {"event_id":id,"amount":amount,"source_faction":&"player","target_actor_id":actor.damageable.actor_id,"target_epoch":actor.damageable.damage_epoch,"hit_direction":Vector2.RIGHT}

func exercise(room: String, member: String, identity: String) -> void:
	var storage := Storage.new()
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var document := WorldRoomDocument.read("res://rooms/world/"+room+".json")
	var error := session.open(document,storage,null,catalog)
	check(error.is_empty(),room+" open "+error)
	if not error.is_empty():
		session.free()
		return
	if not OS.get_environment("MACHINE_BOSS_CAPTURE_DIR").is_empty():
		var camera := session.player.find_children("*","Camera2D",false,false).front() as Camera2D
		var bounds := FixedWorldProvider.rect(document.bounds)
		camera.limit_left=roundi(bounds.position.x)
		camera.limit_top=roundi(bounds.position.y)
		camera.limit_right=roundi(bounds.end.x)
		camera.limit_bottom=roundi(bounds.end.y)
		camera.zoom=Vector2.ONE*1.40
		camera.make_current()
		WorldBackdrop.mount(session,document,{})
	await frames(6)
	var fight: WorldRoomEncounter = session.encounters.front()
	var row := fight.encounter
	check(not session.room.enemies.has(member) and not fight.confirm(),room+" locked")
	var required: Array = row.get("requires",[]).duplicate()
	for ability: String in row.get("minimum_abilities",[]):
		if not ability in required: required.append(ability)
	for missing: String in required:
		var partial: Array = required.duplicate()
		partial.erase(missing)
		check(not catalog.condition_match(fight.eligibility,partial).matches,room+" requires "+missing)
	var candidate := session.state.candidate()
	candidate.flags.append_array(required)
	check(session.state.commit(candidate,session.state.revision),room+" qualified state")
	await frames(5)
	if fight.awaiting_challenge:
		check(not session.room.enemies.has(member),room+" quiet before explicit challenge")
		session.player.reset_at(fight.position+fight.start_offset)
		await frames(6)
		check(fight.confirm(),room+" opt-in challenge")
		await frames(5)
	var actor: EnemyActor=session.room.enemies.get(member)
	check(actor!=null,room+" actual exclusive boss spawn")
	if actor==null:
		session.free()
		return
	var b := actor.attack_behavior as ArenaBossBehavior
	check(b!=null and actor.definition.behavior_id==StringName(identity) and actor.damageable.time_profile=="boss",room+" authored behavior")
	check(EnemyPresentationBinding.view(actor.motor.get_node("Presentation")).body_key==StringName(identity),room+" unique visual binding")
	var floor_y := b.floor_y
	var full := actor.health.current
	var placed := Vector2(b.home.x-198,floor_y-18)
	session.player.reset_at(placed)
	await frames(8)
	# Stop automatic ticks during the probes. Physics space, actors, the
	# projectile and the authoritative damage queue continue to run.
	actor.set_physics_process(false)
	for i in 90:
		b.advance(1.0/60.0)
		if b.state==&"telegraph": break
	check(b.state==&"telegraph" and not fight.confirm(),room+" windup locks shot and victory")
	check(not actor.damageable.receive_damage(shot_context(actor,room+"-armor",2)),room+" armour blocks incoming damage")
	await snapshot(room+"-warning")
	var hp := session.controller.actor_resources.health.current
	for i in 120:
		b.advance(1.0/60.0)
		if b.state==&"attack": break
	check(b.state==&"attack" and session.controller.actor_resources.health.current==hp,room+" warning does no damage")
	# Place the physical player across the committed head. Body contact is not advanced here.
	var probe := b.hit_rects(0)[0].get_center()
	session.player.reset_at(probe)
	session.policy.clock+=2
	for i in 6: b.advance(1.0/60.0)
	session.policy.resolve_batch()
	check(session.controller.actor_resources.health.current<hp,room+" active head deals actual damage")
	var after := session.controller.actor_resources.health.current
	for i in 4: b.advance(1.0/60.0)
	session.policy.resolve_batch()
	check(session.controller.actor_resources.health.current==after,room+" one blow hits once")
	session.player.reset_at(placed)
	for i in 125:
		b.advance(1.0/60.0)
		if b.state==&"recovery": break
	check(b.state==&"recovery" and actor.damageable.can_receive_effects(),room+" exposed recovery")
	# Fire a travelling production bullet from just outside the hitbox.
	var fire_direction := Vector2(actor.brain.direction,0) if identity=="borer_three" else Vector2.RIGHT
	var from := actor.motor.global_position-fire_direction*(actor.definition.collision_size.x/2+56)
	session.player.reset_at(from)
	var fired := session.controller.shoot_ability.try_fire(fire_direction,true)
	await frames(14)
	check(fired and actor.health.current<full,room+" recovery admits real sidearm shot")
	var phase_hit := shot_context(actor,room+"-phase",full*0.5)
	phase_hit.hit_direction = fire_direction
	if identity=="borer_three":
		var frontal := phase_hit.duplicate()
		frontal.hit_direction = -fire_direction
		check(not actor.damageable.receive_damage(frontal),room+" frontal plate protects the axle while retracting")
	check(actor.damageable.receive_damage(phase_hit),room+" accepted half-health hit")
	session.policy.resolve_batch()
	session.player.reset_at(placed)
	b.advance(1.0/60.0)
	check(b.phases.phase==2,room+" actual half-health phase change")
	var moves: Array = []
	for expected: String in b.machine.second_cycle:
		for i in 360:
			b.advance(1.0/60.0)
			if b.state==&"telegraph": break
		check(b.state==&"telegraph" and b.move_id==StringName(expected),room+" second phase "+expected)
		moves.append(b.move_id)
		for i in 270:
			b.advance(1.0/60.0)
			if b.state==&"recovery": break
	check(moves.size()>=3,room+" combined patterns")
	if identity=="ember_molter":
		var shell: EmberSpentShell = b.get("shell")
		check(is_instance_valid(shell),room+" settled shell spawned")
		if is_instance_valid(shell):
			await frames(3)
			var shell_at:=shell.global_position
			var ray:=PhysicsRayQueryParameters2D.create(shell_at-Vector2(0,55),shell_at+Vector2(0,5),1)
			check(session.player.get_world_2d().direct_space_state.intersect_ray(ray).get("collider")==shell,room+" real stable shell support")
			session.player.reset_at(Vector2(b.home.x-195,b.floor_y-18))
			b.advance(0.15)
			check(shell.global_position==shell_at,room+" terrain shell stays on its marked side")
	if identity=="tide_pump_bell":
		check(actor.damageable.receive_damage(shot_context(actor,room+"-third",full*0.22)),room+" critical pressure threshold hit")
		session.policy.resolve_batch()
		b.advance(1.0/60.0)
		check(b.phases.phase==3,room+" third phase reached through damage")
		var lanes: Dictionary={}
		var warning_times: Dictionary={}
		for expected: String in b.machine.third_cycle:
			for i in 360:
				b.advance(1.0/60.0)
				if b.state==&"telegraph": break
			check(b.move_id==StringName(expected),room+" third-phase pump order "+expected)
			lanes[b.attack_origin.x]=true
			warning_times[b.warning_seconds()]=true
			for i in 250:
				b.advance(1.0/60.0)
				if b.state==&"recovery": break
		check(lanes.size()==3 and warning_times.size()==2,room+" three fixed pump positions and staggered timing")

	await snapshot(room+"-core")
	var finish_hit := shot_context(actor,room+"-finish",full)
	finish_hit.hit_direction = Vector2(actor.brain.direction,0)
	check(actor.damageable.receive_damage(finish_hit),room+" genuine final incoming hit")
	session.policy.resolve_batch()
	await frames(8)
	check(actor.health.terminal and not session.state.has(row.completion_flag),room+" defeat pending explicit victory")
	session.player.reset_at(fight.position)
	await frames(10)
	var coins: int = session.services.ledger().gold
	session.controller.router.request_action(&"interact")
	await frames(4)
	check(session.state.has(row.completion_flag) and session.services.ledger().gold==coins+int(row.coin_reward),room+" unlock and exact one-time purse")
	check(not fight.confirm(),room+" cannot reopen cleared reward")
	await session.audio_service.shutdown()
	session.free()
	await frames(2)

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"locked data")
	await exercise("G07","inspection_overseer","gear_overseer")
	await exercise("G19","traction_engine","traction_engine")
	await exercise("Z06","regulator","clock_regulator")
	await exercise("M06","stone_curtain_lord","stone_curtain_lord")
	await exercise("N23","borer_three","borer_three")
	await exercise("R23","tide_pump_bell","tide_pump_bell")
	await exercise("E21","ember_molter","ember_molter")
	print("MACHINE BOSSES failures=",failures," checks=",checks)
	quit(1 if failures else 0)

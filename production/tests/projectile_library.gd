extends SceneTree

var failures := 0
var checks := 0
var serial := 100

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL projectile ",label)
func ticks(frames: int) -> void:
	for i: int in frames: await physics_frame
func row(id: String,definition: String,p: Dictionary) -> Dictionary:
	return {"id":id,"definition_id":definition,"definition_version":1,"properties":p}
func document(entities: Array) -> Dictionary:
	var doc := WorldRoomDocument.read("res://tests/assembly_room.json")
	doc.entities.erase("bell")
	doc.entities.erase("gate")
	doc.entities.erase("patrol")
	for item: Dictionary in entities: doc.entities[item.id] = item
	return doc
func open(items: Array) -> OrdinaryRoomSession:
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(document(items))
	check(error.is_empty(),error)
	await ticks(3)
	return session
func close(session: OrdinaryRoomSession) -> void:
	if session.audio_service!=null: await session.audio_service.shutdown()
	session.free()
func player_round(session: OrdinaryRoomSession, point: Vector2, velocity: Vector2) -> PlayerProjectile:
	var projectile := PlayerProjectile.new()
	projectile.owner_controller = session.controller
	projectile.owner_body = session.player
	projectile.owner_id = session.player.get_instance_id()
	projectile.session_id = session.controller.session_id
	serial += 1
	projectile.shot_id = serial
	projectile.energy_receipt_id = serial
	projectile.speed = velocity.length()
	projectile.direction = velocity.normalized()
	projectile.lifetime = 10
	projectile.radius = 2
	session.add_child(projectile)
	projectile.global_position = point
	projectile.set_physics_process(false)
	return projectile

func geometry() -> void:
	var session := await open([
		row("fog","zone.projectile_drag",{"bounds":[140,160,20,80],"speed_scale":0.5}),
		row("dense","zone.projectile_drag",{"bounds":[150,160,20,80],"speed_scale":0.25}),
		row("grate","terrain.projectile_grate",{"bounds":[176,160,8,80]}),
		row("veil","zone.projectile_barrier",{"position":[240,200]}),
		row("wall","terrain.breakable",{"bounds":[290,150,32,100],"hits_required":2}),
	])
	if session.room==null: return
	var round := player_round(session,Vector2(100,200),Vector2(100,0))
	round.advance(1)
	check(not round.spent and is_equal_approx(round.position.x,160.),"minimum overlapping fog integrates time")
	round.advance(0.8)
	check(not round.spent and is_equal_approx(round.position.x,210.),"leave fog then pass physical grate")
	round.advance(1)
	check(round.spent,"visible finite barrier consumes round")
	var veil: ProjectileBarrier = session.room.element_runtime.nodes.veil
	veil.element_restore({"active":false})
	var wall: BreakableTerrain = session.room.element_runtime.nodes.wall
	var intact: int = wall.hp[0]
	var fresh := player_round(session,Vector2(210,200),Vector2(1200,0))
	fresh.advance(.12)
	check(fresh.spent and wall.hp[0]==intact-1,"inactive curtain permits real projectile damage")
	var packet := fresh.mechanism_packet()
	packet.hit_point = Vector2(290,200)
	check(not wall.mechanism_shot(packet),"packet dedup across same root")
	check(session.state.value.mechanisms.wall.data.hp[0]==1,"permanent breakable committed in real save ledger")
	var front := player_round(session,Vector2(360,200),Vector2(-1200,0))
	veil.element_restore({"active":true})
	front.advance(.2)
	check(front.spent and wall.hp[0]==0 and wall.pieces[0].collision_layer==0,"nearer target blocks before barrier")
	var inside := player_round(session,Vector2(240,200),Vector2.RIGHT*1200)
	inside.advance(.016)
	check(inside.spent,"born inside active field")
	await close(session)

func mirrors() -> void:
	var session := await open([
		row("mirror","surface.projectile_mirror",{"position":[280,220],"two_sided":true,"orientation_mode":"indexed"}),
		row("second","surface.projectile_mirror",{"position":[100,220],"normal_deg":0,"mirror_length":160}),
	])
	if session.room==null: return
	var round := player_round(session,Vector2(160,220),Vector2.RIGHT*1000)
	round.advance(.2)
	check(not round.spent and round.flight.reflections==1 and round.direction.x<0 and absf(round.position.x-196)<.1,"remaining frame follows reflected velocity")
	round.advance(.2)
	check(round.spent,"second mirror ends lifecycle")
	var mirror: ProjectileMirror = session.room.element_runtime.nodes.mirror
	var rotor := player_round(session,Vector2(210,132),Vector2.RIGHT*1000)
	rotor.advance(.1)
	check(rotor.spent and mirror.target==1,"indexed control accepts shot and consumes it")
	var another := player_round(session,Vector2(210,132),Vector2.RIGHT*1000)
	another.advance(.1)
	check(mirror.target==1,"busy control cannot enqueue a turn")
	await ticks(26)
	check(is_equal_approx(mirror.angle,PI/4),"mirror completes shortest turn")
	check(not mirror.element_can_receive("set_index",9),"out of range index refused")
	await close(session)

func hazards() -> void:
	var session := await open([
		row("cells","terrain.breakable",{"bounds":[350,160,96,96],"break_mode":"local_cells","cell_size":32,"dig_radius":12}),
		row("a","hazard.explosive_container",{"position":[290,220],"blast_radius":96,"fuse_s":.2}),
		row("b","hazard.explosive_container",{"position":[316,215],"fuse_s":.2}),
		row("stream","hazard.periodic_emitter",{"position":[150,120],"emit_mode":"stream","initial_active":false,"warning_time":.1}),
		row("grate","terrain.projectile_grate",{"bounds":[245,108,20,40]}),
		row("bolt","hazard.periodic_emitter",{"position":[110,250],"initial_active":false,"warning_time":.1,"burst_count":2,"shot_interval":.1}),
	])
	if session.room==null: return
	var nodes := session.room.element_runtime.nodes
	var round := player_round(session,Vector2(230,220),Vector2.RIGHT*1300)
	round.advance(.1)
	check(nodes.a.stage=="warning","physical shot ignites barrel")
	await ticks(35)
	check(nodes.a.stage=="spent" and nodes.b.stage=="spent","explosions chain through distinct fuses")
	check(0 in nodes.cells.hp and 1 in nodes.cells.hp,"explosion excavates local region, surviving cells retained")
	var stream: PeriodicEmitter = nodes.stream
	stream.element_restore(stream.element_propose("set_active",true))
	await ticks(18)
	check(stream.phase=="streaming" and absf(stream.stream_length-95)<2,"full stream width stopped by grate")
	stream.element_restore(stream.element_propose("set_active",false))
	check(not stream.active and stream.stream_length==0,"disable stream immediately")
	var bolt: PeriodicEmitter = nodes.bolt
	bolt.element_restore(bolt.element_propose("set_active",true))
	await ticks(22)
	check(bolt.serial==2 and bolt.phase=="cooldown","actual hostile burst, cooldown")
	await close(session)

func validation() -> void:
	for entry: Array in [
		["zone.projectile_drag",{"speed_scale":0}],["zone.projectile_drag",{"factions":["enemy","enemy"]}],
		["terrain.projectile_grate",{"projectile_categories":[]}],["zone.projectile_barrier",{"line_points":[[0,0],[0,0]]}],
		["surface.projectile_mirror",{"orientation_mode":"indexed","control_offset":[0,25]}],
		["terrain.breakable",{"break_mode":"local_cells","cell_size":25}],["terrain.breakable",{"accepted_attacks":["ice"]}],
		["hazard.periodic_emitter",{"emit_mode":"stream","aim_mode":"track_lock"}],["hazard.periodic_emitter",{"projectile_profile":"missing"}],
		["hazard.periodic_emitter",{"aim_mode":"manual_index","manual_angles_deg":[0,360]}],
		["hazard.explosive_container",{"fuse_s":0}]]:
		var result := WorldRoomDocument.instantiate(document([row("invalid",entry[0],entry[1])]))
		check(result.has("error"),"reject "+str(entry))
		if result.has("room"): result.room.free()

func enemy_round(emitter: PeriodicEmitter, at: Vector2, velocity: Vector2, profile_id := "clockwork_bolt") -> EmitterProjectile:
	var round := EmitterProjectile.new()
	serial += 1
	round.launch(emitter.host,"test/"+str(serial),ProjectileImpact.profile(profile_id),at,velocity)
	round.set_physics_process(false)
	return round

func hostile_and_pools() -> void:
	var session := await open([
		row("source","hazard.periodic_emitter",{"position":[80,100],"initial_active":false}),
		row("fog","zone.projectile_drag",{"bounds":[180,100,100,100],"speed_scale":0.25}),
		row("grate","terrain.projectile_grate",{"bounds":[268,100,4,100]}),
		row("veil","zone.projectile_barrier",{"position":[320,150],"factions":["enemy"],"initial_active":false}),
		row("ledge","terrain.breakable",{"bounds":[470,220,32,32],"state_scope":"attempt"}),
	])
	if session.room==null: return
	var nodes := session.room.element_runtime.nodes
	var source: PeriodicEmitter = nodes.source
	var enemy := enemy_round(source,Vector2(130,150),Vector2.RIGHT*1000)
	enemy._physics_process(.25)
	check(is_equal_approx(enemy.position.x,230) and enemy.remaining<3.0,"hostile flight fog changes travel, native lifetime advances")
	enemy._physics_process(.24)
	check(is_equal_approx(enemy.position.x,320),"hostile flight exits fog through grate")
	var friendly := player_round(session,enemy.position,Vector2.RIGHT*200)
	ProjectileFlight.register_at(friendly,session.controller,"player")
	nodes.veil.element_restore({"active":true})
	check(enemy.spent and not friendly.spent,"enable samples existing projectile instantly by faction")
	var ember := enemy_round(source,Vector2(320,150),Vector2.DOWN*120,"ember_shot")
	check(ember.spent,"hostile birth inside enabled curtain expires immediately")
	var ledge: StaticBody2D = nodes.ledge.pieces[0]
	var falling := enemy_round(source,Vector2(485,160),Vector2.DOWN*500,"ember_shot")
	falling._physics_process(.16)
	var pools := ledge.get_children().filter(func(n: Node)->bool:return n is EmberPool)
	check(falling.spent and pools.size()==1,"real emitter projectile creates one pool on top impact")
	if not pools.is_empty():
		var pool: EmberPool = pools[0]
		check(is_equal_approx(pool.start.distance_to(pool.end),32),"pool uses actual short face")
		var before := pool.to_global(pool.start)
		ledge.position.x += 17
		check(pool.to_global(pool.start).distance_to(before+Vector2.RIGHT*17)<.01,"pool follows moving carrier transform")
		nodes.ledge.element_restore({"hp":[0]})
		await ticks(3)
		check(not is_instance_valid(pool),"removed support extinguishes pool")
	nodes.ledge.element_restore({"hp":[1]})
	await ticks(2)
	var side := enemy_round(source,Vector2(420,235),Vector2.RIGHT*900,"ember_shot")
	side._physics_process(.12)
	check(side.spent and ledge.get_children().filter(func(n: Node)->bool:return n is EmberPool).is_empty(),"wall side does not produce pool")
	var beneath := enemy_round(source,Vector2(505,315),Vector2.UP*1000,"ember_shot")
	beneath._physics_process(.12)
	check(beneath.spent and ledge.get_children().filter(func(n: Node)->bool:return n is EmberPool).is_empty(),"underside does not produce pool")
	var alive := enemy_round(source,Vector2(440,100),Vector2.RIGHT*120)
	var left := enemy_round(source,Vector2(501,170),Vector2.DOWN*500,"ember_shot")
	left._physics_process(.13)
	nodes.source.element_restore(nodes.source.element_propose("set_active",false))
	check(not alive.spent and ledge.get_children().filter(func(n: Node)->bool:return n is EmberPool).size()==1,"disabling emitter preserves existing effects")
	session.room.element_runtime.reset_section("main")
	await ticks(3)
	check(not is_instance_valid(alive) and ledge.get_children().filter(func(n: Node)->bool:return n is EmberPool).is_empty(),"attempt reset clears matching source projectiles and pools")
	await close(session)

func tracking_and_turns() -> void:
	var session := await open([
		row("track","hazard.periodic_emitter",{"position":[100,360],"initial_active":false,"aim_mode":"track_lock","track_duration":.2,"warning_time":.2,"burst_count":2,"shot_interval":.1}),
		row("manual","hazard.periodic_emitter",{"position":[100,180],"initial_active":false,"aim_mode":"manual_index","manual_angles_deg":[0,270],"manual_turn_s":.3,"warning_time":.1}),
		row("wall","terrain.breakable",{"bounds":[240,290,30,94],"state_scope":"attempt"}),
		row("mirror","surface.projectile_mirror",{"position":[540,190],"orientation_mode":"indexed","normal_angles_deg":[350,10,190],"turn_s":.2}),
	])
	if session.room==null: return
	var nodes := session.room.element_runtime.nodes
	var gun: PeriodicEmitter = nodes.track
	gun.element_restore(gun.element_propose("set_active",true))
	session.player.reset_at(Vector2(170,360))
	await ticks(6)
	check(gun.phase=="tracking" and gun.phase_time>0,"visible live player starts continuous acquisition")
	session.player.reset_at(Vector2(310,360))
	await ticks(3)
	check(gun.phase=="idle" and is_zero_approx(gun.phase_time),"solid occlusion resets tracking")
	session.player.reset_at(Vector2(180,360))
	await ticks(15)
	var locked := gun.locked
	check(gun.phase=="warning","tracking completes before lock warning")
	session.player.reset_at(Vector2(310,360))
	await ticks(22)
	check(gun.serial==2 and gun.locked.is_equal_approx(locked),"occlusion after lock keeps direction throughout burst")
	var manual: PeriodicEmitter = nodes.manual
	var control := player_round(session,Vector2(30,180),Vector2.RIGHT*1000)
	control.advance(.12)
	check(manual.turning and manual.index==1 and not manual.active,"real shot rotates disabled nozzle")
	manual.element_restore(manual.element_propose("set_active",true))
	await ticks(9)
	var emitted := get_nodes_in_group("ordinary_flight_enemy").filter(func(n:Node)->bool:return n is EmitterProjectile and n.host.emitter==manual)
	check(manual.serial==1 and manual.turning and emitted.size()==1 and emitted[0].direction.y>0.8,"fire during clockwise turn uses actual nozzle direction")
	var dup := player_round(session,Vector2(30,180),Vector2.RIGHT*1000)
	dup.advance(.12)
	check(manual.index==1,"turning hit does not queue next notch")
	await ticks(15)
	var wrap := player_round(session,Vector2(30,180),Vector2.RIGHT*1000)
	wrap.advance(.12)
	await ticks(24)
	check(manual.index==0 and not manual.turning and Vector2.from_angle(manual.angle).is_equal_approx(Vector2.RIGHT),"manual ring wraps and completes clockwise")
	var mirror: ProjectileMirror = nodes.mirror
	mirror.element_restore(mirror.element_propose("set_index",1))
	await ticks(6)
	check(mirror.arc()>0 and mirror.arc()<PI/8,"mirror shortest arc across zero")
	var snapshot := mirror.element_state()
	await ticks(12)
	mirror.element_restore(snapshot)
	check(is_equal_approx(mirror.progress,snapshot.progress) and mirror.progress<1,"silent intermediate mirror state recovery")
	await ticks(15)
	mirror.element_restore(mirror.element_propose("set_index",2))
	check(is_equal_approx(mirror.arc(),PI),"180-degree tie is clockwise")
	# A stationary disk is clear at both endpoints of the 90-degree sweep.
	mirror.frame_start=0
	mirror.frame_span=PI/2
	mirror.frame_turn_start=0
	mirror.frame_turn_end=1
	var contact := mirror.contact(mirror.position+Vector2(-32,32),Vector2.ZERO,2,"player",0,1,1)
	check(not contact.is_empty() and contact.t>.4 and contact.t<.5 and not contact.reflect,"rotating finite mirror catches stationary disk at intermediate angle")
	if not contact.is_empty():
		var half := mirror.contact(mirror.position+Vector2(-32,32),Vector2.ZERO,2,"player",0,.5,1)
		check(not half.is_empty() and absf(contact.t-half.t*.5)<.00001 and contact.normal.is_equal_approx(half.normal),"contact normal and physical time agree under substeps")
	await close(session)

func physical_order(reverse: bool) -> Vector2:
	var session := await open([row("mirror","surface.projectile_mirror",{"position":[400,220],"orientation_mode":"indexed","normal_angles_deg":[0,60],"turn_s":.025,"two_sided":true})])
	if session.room==null: return Vector2.INF
	var mirror: ProjectileMirror = session.room.element_runtime.nodes.mirror
	# The late command is inserted first in one run. The face shot must see
	# the rotation that began at 10% of the tick in either insertion order.
	var emitters := [[Vector2(371,132),Vector2.RIGHT*1200],[Vector2(416,223),Vector2.LEFT*1200],[Vector2(386,132),Vector2.RIGHT*1200]]
	if reverse: emitters.reverse()
	var face: PlayerProjectile
	for setup: Array in emitters:
		var round := player_round(session,setup[0],setup[1])
		if round.direction.x<0: face = round
		ProjectileFlight.register_at(round,session.controller,"player")
		round.set_physics_process(true)
	await ticks(1)
	check(absf(mirror.frame_turn_start-.1)<.001,"earliest physical button wins under reversed insertion")
	check(face.flight.reflections==1 and face.direction.x>0 and face.direction.y>.1,"same-tick face collision uses actual moving normal")
	var dir := face.direction
	await close(session)
	return dir

class Store extends WorldSaveService:
	var writable := true
	var payload := {}
	var revision := 0
	func commit(value: Dictionary, rev: int) -> bool:
		if not writable: return false
		payload = value.duplicate(true)
		revision = rev
		return true
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":payload.duplicate(true),"revision":revision}

func persistence_and_rewards() -> void:
	var rows := [
		row("cells","terrain.breakable",{"bounds":[300,288,96,96],"break_mode":"local_cells","hits_required":2,"dig_radius":6}),
		row("target","enemy.patrol",{"id":"target","point":[505,364],"max_health":1}),
		row("barrel","hazard.explosive_container",{"position":[510,357],"fuse_s":.15,"blast_radius":110}),
		row("charged","terrain.breakable",{"bounds":[630,252,30,80],"accepted_attacks":["charged_shot"]}),
		row("bomb","terrain.breakable",{"bounds":[730,252,30,80],"accepted_attacks":["bomb"]}),
	]
	var doc := document(rows)
	var storage := Store.new()
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	check(session.open(doc,storage).is_empty(),"persistence scenario opens")
	if session.room==null: return
	await ticks(3)
	var nodes := session.room.element_runtime.nodes
	var initial: Array = nodes.cells.hp.duplicate()
	storage.writable = false
	var round := player_round(session,Vector2(200,307),Vector2.RIGHT*1000)
	round.advance(.15)
	check(nodes.cells.hp==initial and nodes.cells.can_commit(),"failed save preserves colliders and queues proposal")
	storage.writable=true
	await ticks(2)
	var damaged: Array = nodes.cells.hp.duplicate()
	check(damaged.count(1)==1 and damaged.count(2)==8,"retry commits exact contacted local cell")
	storage.writable = false
	var interrupted := player_round(session,Vector2(200,340),Vector2.RIGHT*1000)
	interrupted.advance(.15)
	check(nodes.cells.can_commit(),"interrupted permanent damage is pending")
	session.room.element_runtime.reset_section("main")
	storage.writable = true
	await ticks(3)
	check(not nodes.cells.can_commit() and nodes.cells.hp==damaged,"reset drops failed uncommitted damage and retains saved cells")
	var basic := player_round(session,Vector2(580,264),Vector2.RIGHT*1200)
	basic.advance(.08)
	check(nodes.charged.hp[0]==1,"uncharged hit cannot break charged-only surface")
	var ice := player_round(session,Vector2(580,264),Vector2.RIGHT*1200)
	ice.skill_attack=true
	ice.art_kind=&"ice"
	ice.advance(.08)
	check(nodes.charged.hp[0]==0,"charged attack breaks specialized surface")
	ProjectileImpact.blast_mechanisms(session,Vector2(742,270),30,{"attack_kind":"explosion","packet_id":"blast"})
	check(nodes.bomb.hp[0]==1,"generic blast cannot break bomb-only surface")
	ProjectileImpact.blast_mechanisms(session,Vector2(742,270),30,{"attack_kind":"bomb","packet_id":"grenade"})
	check(nodes.bomb.hp[0]==0,"formal bomb tag opens bomb-only terrain")
	var barrel: ExplosiveContainer = nodes.barrel
	barrel.mechanism_shot({"controller":session.controller})
	check(not barrel.mechanism_shot({"controller":session.controller}),"repeated ignition leaves one fuse")
	await ticks(16)
	check(barrel.stage=="spent" and session.state.value.enemies.has("target"),"barrel kill enters formal persistent enemy result")
	check(not session.services.ledger().drops.is_empty() or session.services.ledger().gold>0,"barrel kill pays an actual enemy reward")
	for i: int in 100:
		if session.room.loot.pickups.is_empty() or session.services.ledger().gold>0: break
		for pickup: Dictionary in session.room.loot.pickups:
			if not pickup.claimed: session.player.reset_at(pickup.position); break
		await ticks(1)
	check(session.services.ledger().gold==session.drop_rules.enemy_gold,"real drop collects exactly once")
	session.room.element_runtime.reset_section("main")
	check(barrel.stage=="intact" and nodes.cells.hp==damaged,"attempt restores barrel, keeps permanent excavation")
	await close(session)
	var restored := OrdinaryRoomSession.new()
	root.add_child(restored)
	check(restored.open(doc,storage).is_empty(),"same document reopens persistent storage")
	if restored.room==null: return
	await ticks(3)
	check(restored.room.element_runtime.nodes.cells.hp==damaged and restored.room.element_runtime.nodes.charged.hp[0]==0,"new room loads exact permanent grid and specialized terrain state")
	check(restored.room.element_runtime.nodes.barrel.stage=="intact" and restored.room.enemies.target.health.terminal,"barrel restores independently from persistent enemy")
	await close(restored)

func mirror_faces() -> void:
	var session := await open([
		row("mirror","surface.projectile_mirror",{"position":[400,240],"normal_deg":180}),
		row("wall","terrain.breakable",{"bounds":[400,174,20,130]}),
		row("grate","terrain.projectile_grate",{"bounds":[278,130,6,76]}),
		row("grate2","terrain.projectile_grate",{"bounds":[289,130,6,76]}),
		row("emitter","hazard.periodic_emitter",{"position":[120,160],"initial_active":false}),
	])
	if session.room==null: return
	var nodes := session.room.element_runtime.nodes
	var mirror: ProjectileMirror
	for node: Node in ProjectileField.fields_for(session):
		if node is ProjectileMirror: mirror=node
	var straight := player_round(session,Vector2(320,240),Vector2.RIGHT*4000)
	straight.advance(.04)
	check(not straight.spent and straight.direction.x<0 and nodes.wall.hp[0]==1,"coplanar body and mirror resolve one reflecting surface")
	var diagonal := player_round(session,Vector2(340,202),Vector2(1000,420))
	diagonal.advance(.09)
	check(not diagonal.spent and diagonal.direction.x<0 and diagonal.direction.y>0,"oblique incidence retains tangent")
	var back := mirror.contact(Vector2(450,246),Vector2(-90,0),2,"enemy",0,1,1)
	check(not back.is_empty() and not back.reflect,"single-sided mirror back blocks enemy")
	var endpoint := mirror.contact(Vector2(330,175),Vector2(100,0),2,"player",0,1,1)
	check(not endpoint.is_empty() and endpoint.reflect,"disk contacts finite mirror endpoint")
	check(mirror.contact(Vector2(330,172),Vector2(100,0),2,"player",0,1,1).is_empty(),"outside endpoint remains clear")
	var moved := enemy_round(nodes.emitter,Vector2(250,161),Vector2.RIGHT*800)
	moved._physics_process(.1)
	check(not moved.spent and is_equal_approx(moved.position.x,330),"enemy bullet crosses multiple adjacent real grates")
	var floor_query := PhysicsRayQueryParameters2D.create(Vector2(250,160),Vector2(330,160),1)
	check(not session.get_world_2d().direct_space_state.intersect_ray(floor_query).is_empty(),"grates retain ordinary solid collision")
	await close(session)

func plume_exposure() -> void:
	var session := await open([
		row("plume","hazard.periodic_emitter",{"position":[340,361],"emit_mode":"stream","initial_active":false,"stream_range":190,"stream_width":18,"stream_duration_s":3,"warning_time":.03}),
		row("shadow","terrain.breakable",{"bounds":[415,345,20,24],"state_scope":"attempt"}),
		row("victim","enemy.patrol",{"id":"victim","point":[470,361],"max_health":4}),
	])
	if session.room==null: return
	var nodes := session.room.element_runtime.nodes
	var target: EnemyActor = session.room.enemies.victim
	target.motor.set_physics_process(false)
	target.motor.global_position = Vector2(472,361)
	var initial := target.health.current
	var stream: PeriodicEmitter = nodes.plume
	stream.element_restore(stream.element_propose("set_active",true))
	await ticks(12)
	check(is_equal_approx(target.health.current,initial) and absf(stream.stream_length-75)<2,"opaque box shields real enemy from full stream")
	nodes.shadow.element_restore({"hp":[0]})
	await ticks(8)
	check(is_equal_approx(target.health.current,initial-1) and stream.stream_length>180,"remove shield exposes enemy in same live plume")
	await ticks(12)
	check(is_equal_approx(target.health.current,initial-1),"continuous exposure does not hit every frame")
	stream.element_restore(stream.element_propose("set_active",false))
	var old_due := stream.due.duplicate()
	await ticks(12)
	check(stream.stream_length==0 and stream.due==old_due,"disabled stream leaves no active exposure")
	await close(session)

func run() -> void:
	validation()
	await geometry()
	await mirrors()
	await hazards()
	await hostile_and_pools()
	await tracking_and_turns()
	var a := await physical_order(false)
	var b := await physical_order(true)
	check(a.is_equal_approx(b),"ordered events independent of scene insertion order")
	await persistence_and_rewards()
	await mirror_faces()
	await plume_exposure()
	check(checks>=98,"all suites completed")
	print("PROJECTILE LIBRARY failures=",failures," checks=",checks)
	quit(1 if failures else 0)

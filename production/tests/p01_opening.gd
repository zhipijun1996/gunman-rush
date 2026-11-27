extends SceneTree
## Exercise the native wake poses and actual touch/weapon/state paths on the authored room.
const P01 := "res://rooms/world/P01.json"
const TouchInput := preload("res://tests/plains_touch_driver.gd")
var failures := 0
var checks := 0
var shots := 0
var retired_playbacks: Array[WeakRef] = []
var catalog := WorldContentCatalog.new()

class Storage extends WorldSaveService:
	var payload := {}
	var revision := 0
	var writable := true
	func commit(data: Dictionary, rev: int) -> bool:
		if not writable: return false
		payload=data.duplicate(true)
		revision=rev
		return true
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":payload.duplicate(true),"revision":revision}

# Use the registered shipping documents and real passage controller, with an
# isolated fresh slot for every run.
class OpeningHost extends WorldGameHost:
	func startup_destination() -> Dictionary:
		storage = Storage.new()
		return {"ok":true,"room":"P01"}

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, detail: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL P01 opening ",detail)

func frames(count: int) -> void:
	for i in count: await physics_frame

func watch_shot(_direction: Vector2, _packet: int) -> void:
	shots+=1

func open_room(store: Storage) -> OrdinaryRoomSession:
	var session:=OrdinaryRoomSession.new()
	root.add_child(session)
	var error:=session.open(WorldRoomDocument.read(P01),store,null,catalog)
	check(error.is_empty(),"load authored P01 with its native actors: "+error)
	return session

func close_session(session: OrdinaryRoomSession) -> void:
	if session.audio_service!=null:
		check(await session.audio_service.shutdown(),"standalone room releases its audio")
	session.free()
	await frames(2)

# A previous room can be gone before the separate audio thread finishes its
# final mix. Keep the service's existing weak playback handles across handoffs.
func observe_room_audio(node: Node) -> void:
	if node is GameAudio or node is GameAmbience:
		retired_playbacks.append_array(node._playbacks)

func wait_for_room_audio() -> bool:
	var deadline:=Time.get_ticks_msec()+2000
	while retired_playbacks.any(func(track: WeakRef) -> bool: return track.get_ref()!=null):
		if Time.get_ticks_msec()>=deadline: return false
		await process_frame
	return true

func cross_latch(pilot: WorldGameHost, side: float, destination: String) -> bool:
	var source:=pilot.active
	source.controller.router.set_move_axis(side)
	for frame in 180:
		await physics_frame
		if pilot.active!=source and not pilot.crossing: break
	pilot.active.controller.router.set_move_axis(0)
	await frames(4)
	return pilot.active.room.room_id==destination and pilot.active.player.is_on_floor() and pilot.last_error.is_empty()

func visit_forest_latch(pilot: WorldGameHost) -> void:
	var meadow:=pilot.active
	meadow.controller.router.set_move_axis(-1)
	await frames(105)
	meadow.controller.router.set_move_axis(0)
	meadow.controller.router.request_action(&"interact")
	await frames(4)
	var gate:=meadow.room.get_node("ForestShortcutGate") as Node2D
	check(pilot.active==meadow and meadow.player.position.distance_to(gate.position+Vector2.UP*18)<45 and not meadow.state.has("forest_slope_return_open"),"following the downhill grass reaches the physical gate but its latch cannot be operated from P01")
	# Begin a separate return trip at the registered forest-side receiving area.
	pilot.enter_room("F08","")
	await frames(8)
	if pilot.active.room.room_id!="F08":
		check(false,"the v29 forest-side receiving area loads")
		return
	var forest:=pilot.active
	var lever:=FixedWorldProvider.point(pilot.active_doc.sites.d223.at)
	var heading:=signf(lever.x-forest.player.position.x)
	forest.controller.router.set_move_axis(heading)
	for frame in 90:
		await physics_frame
		if (lever.x-forest.player.position.x)*heading<=1: break
	forest.controller.router.set_move_axis(0)
	await frames(3)
	forest.controller.router.request_action(&"interact")
	await frames(5)
	check(forest.state.has("forest_slope_return_open"),"interacting on the registered forest side opens the latch")
	check(await cross_latch(pilot,1,"P01"),"enter P01 west through the open gate and regain control on supported grass")
	check(await cross_latch(pilot,-1,"F08"),"walk back through the open forest gate while retaining its receipt")
	if not await cross_latch(pilot,1,"P01"):
		check(false,"the forest remains linked to the meadow")
		return
	var home:=pilot.active
	var start_at:=home.room.start_point
	home.controller.router.set_move_axis(1)
	for frame in 65:
		await physics_frame
		if home.player.position.x>=132: break
	home.controller.router.request_action(&"jump")
	for frame in 85:
		await physics_frame
		if home.player.position.x>=start_at.x: break
	home.controller.router.set_move_axis(0)
	home.controller.router.request_action(&"jump_release")
	await frames(28)
	check(home.player.is_on_floor() and home.player.position.distance_to(start_at)<12,"a returning player reaches the original training field from the forest tread with one ordinary jump")

func route_and_respawn() -> void:
	var pilot:=OpeningHost.new()
	node_removed.connect(observe_room_audio)
	root.add_child(pilot)
	var source:=pilot.active
	await frames(110)
	source.controller.router.set_move_axis(1)
	for i in 460:
		await physics_frame
		if pilot.active.room.room_id=="P02" and not pilot.crossing: break
	check(pilot.active.room.room_id=="P02" and not pilot.active.controller.shoot_ability.enabled,"walk across d001 without claiming gun and remain unarmed")
	pilot.active.controller.router.set_move_axis(0)
	await frames(4)
	pilot.active.controller.router.set_move_axis(-1)
	for i in 250:
		await physics_frame
		if pilot.active.room.room_id=="P01" and not pilot.crossing: break
	pilot.active.controller.router.set_move_axis(0)
	check(pilot.active.room.room_id=="P01" and pilot.active.opening!=null and not pilot.active.opening.waking,"return to a standing unarmed actor and an available ground gun")
	source=pilot.active
	source.controller.router.set_move_axis(-1)
	for i in 320:
		await physics_frame
		if source.player.position.x<source.opening.position.x+8: break
	source.controller.router.set_move_axis(0)
	await frames(2)
	source.controller.router.request_action(&"interact")
	await frames(5)
	check(source.state.has("gun"),"claim ground gun after initially walking past it")
	var health:=source.controller.actor_resources.health
	var lethal:=DamageRequest.new()
	lethal.token=source.lifetime.token()
	lethal.source_id=&"regression_lethal"
	lethal.event_id=&"opening_death"
	lethal.target_id=&"player"
	lethal.health_epoch=health.epoch
	lethal.actor_epoch=source.lifetime.actor_epoch
	lethal.amount=health.current
	check(source.policy.submit(lethal),"accepted lethal damage through normal frame policy")
	for i in 240:
		await physics_frame
		if pilot.active!=source and not pilot.crossing: break
	check(pilot.active!=source and pilot.active.state.value.cycle==2 and pilot.active.state.has("gun") and pilot.active.controller.shoot_ability.enabled and pilot.active.opening==null,"real death returns to standing armed spawn without another pickup")
	await visit_forest_latch(pilot)
	check(await pilot.active.audio_service.shutdown(),"last room releases its audio")
	pilot.free()
	node_removed.disconnect(observe_room_audio)
	check(await wait_for_room_audio(),"previous P01 and P02 room playbacks have left the mixer")
	await frames(3)

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"load the locked world and bindings")
	var store:=Storage.new()
	var s:=open_room(store)
	if s.room==null:
		await close_session(s)
		quit(1)
		return
	var input:=TouchInput.new()
	input.attach(s)
	var wake:=s.opening
	var floor_point:=s.player.position
	check(wake!=null and wake.waking and not s.controller.active and not s.controller.shoot_ability.enabled and not s.state.has("gun"),"fresh player is prone, input locked, genuine shooting switched off")
	s.controller.shoot_ability.shot_fired.connect(watch_shot)
	input.fire(Vector2.DOWN)
	check(not s.controller.shoot_ability.try_fire(Vector2.DOWN,true),"unarmed direct shot rejected")
	var seen: Dictionary={}
	for i in 115:
		await physics_frame
		if wake.waking: seen[wake.body.authored_pose.frame]=true
	check(seen.size()>=5 and seen.has(0) and seen.has(7) and not wake.waking and s.controller.active,"original down, rising and final canonical idle poses run in sequence")
	check(shots==0 and s.player.position.distance_to(floor_point)<2 and store.payload.receipts.has(PlainsOpening.WAKE) and not store.payload.receipts.has(PlainsOpening.TAKE),"wake does not grant weapon or buffer a recoil")
	input.tap(s.touch_controls.interact_center)
	await frames(3)
	check(not s.state.has("gun"),"interact at spawn cannot collect distant item")
	await close_session(s)
	s=open_room(store)
	input.attach(s)
	await frames(4)
	check(s.opening!=null and not s.opening.waking and s.controller.active and not s.controller.shoot_ability.enabled and s.opening.prompt.text!="我在哪？","profile saved before weapon returns to standing actor and unclaimed gun")
	s.controller.shoot_ability.shot_fired.connect(watch_shot)
	input.fire(Vector2.RIGHT)
	await frames(3)
	check(shots==0,"shoot input after rising but before claim remains inert")
	input.move(1)
	for i in 45:
		await physics_frame
		if s.player.position.x>=s.opening.position.x-5: break
	input.move(0)
	await frames(3)
	check(s.opening.can_reach() and "互动" in s.opening.prompt.text and not s.sign_reader.hint.visible,"mobile approach exposes device-specific pickup near actual gun")
	store.writable=false
	var before:=store.revision
	input.tap(s.touch_controls.interact_center)
	await frames(3)
	check(not s.state.has("gun") and not s.controller.shoot_ability.enabled and store.revision==before,"failed pickup save leaves weapon in the grass")
	store.writable=true
	input.tap(s.touch_controls.interact_center)
	await frames(3)
	check(s.state.has("gun") and s.controller.shoot_ability.enabled and store.payload.receipts.has(PlainsOpening.TAKE) and store.revision==before+1,"real touch interaction atomically grants ownership and unlocks shooting")
	check(not s.opening.interact() and store.revision==before+1,"ground weapon cannot be claimed twice")
	input.fire(Vector2.RIGHT)
	await frames(3)
	check(shots==1,"right-thumb release emits a real projectile after pickup")
	before=store.revision
	await close_session(s)
	s=open_room(store)
	await frames(3)
	check(s.opening==null and s.controller.active and s.controller.shoot_ability.enabled and store.revision==before,"armed profile skips wake and ground item without writing another claim")
	await close_session(s)
	await route_and_respawn()
	print("P01 OPENING failures=",failures," checks=",checks)
	quit(1 if failures else 0)

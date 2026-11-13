extends SceneTree
var failures := 0
var assertions := 0
var app: FixedWorldApp
var shot := 10000
class RefusingSave extends WorldRoomReview.MemorySave:
	var refuse := true
	func commit(payload: Dictionary, revision: int) -> bool:
		if refuse: return false
		return super.commit(payload,revision)
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; printerr("ELEMENT CHECK FAILED: "+label)
func ticks(n: int) -> void:
	for i: int in n: await physics_frame
func hit(source: WorldElementSwitch) -> void:
	shot += 1
	source._register_shot(Vector2.RIGHT, shot)
	check(source._receive_projectile({"shot_id":shot,"session_id":app.controller.session_id,"event_id":"element-test:"+str(shot),"source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":source.receiver.actor_id,"target_epoch":source.health.epoch}),"accepted projectile eligibility")
	await ticks(4)
func run() -> void:
	var doc := WorldRoomDocument.read("res://config/world/rooms/P-R03.json")
	var assembly := WorldElementCatalog.instantiate_definition("assembly.bell_gate","test-assembly",Vector2(160,160))
	check(not assembly.has("error") and assembly.entities.size()==2,"data-only assembly instantiation")
	var copy := doc.duplicate(true); copy.entities.merge(assembly.entities)
	check(WorldElementCatalog.document_error(copy).is_empty(),"assembly has compatible stable references")
	copy.entities["test-assembly/switch"].properties.links[0].target = "missing"
	check(not WorldElementCatalog.document_error(copy).is_empty(),"missing target rejected before creation")
	check(not WorldElementCatalog.state_error({"is_open":true}).is_empty(),"old untyped saves rejected")
	check(not WorldElementCatalog.state_error({"type":"WorldElementGate","version":2,"data":{"active":true}}).is_empty(),"unknown state version rejected")
	app = preload("res://game/application/world/fixed_world.tscn").instantiate()
	root.add_child(app)
	check(await app.review.begin("P-R03","","base",true,[],["intro_gun","intro_move","intro_shoot","intro_complete"]),"real game loads new elements")
	var trigger := app.room.mechanisms["P-R03:first_bell"] as WorldElementSwitch
	var gate := app.room.element_runtime.nodes[str(trigger.links[0].target)] as WorldElementGate
	check(gate.body.collision_layer==1 and not trigger.is_open,"gate starts closed")
	var second_gate := WorldElementGate.new(); second_gate.element_id="test:second-gate"; second_gate.bounds=Rect2(8000,8000,32,128)
	app.room.add_child(second_gate); second_gate.element_bind({"controller":app.controller})
	app.room.element_runtime.nodes[second_gate.element_id]=second_gate
	app.room.element_runtime.kinds[second_gate.element_id]="WorldElementGate"
	trigger.links.append({"output":"active","target":second_gate.element_id,"input":"invalid_port"})
	await hit(trigger)
	check(not trigger.is_open and not gate.active and not second_gate.active,"one refusing receiver prevents the entire fanout")
	trigger.cancel_pending(); trigger.links[1].input="set_active"
	shot+=1; trigger._register_shot(Vector2.RIGHT,shot)
	trigger._receive_projectile({"shot_id":shot,"session_id":app.controller.session_id,"event_id":"cancelled-shot","source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":trigger.receiver.actor_id,"target_epoch":trigger.health.epoch})
	app.controller.router.clear("cancel queued element intent"); await ticks(3)
	check(not trigger.is_open and not gate.active,"cancel before acceptance emits no signal")
	var old_storage := app.state.storage
	var refusing := RefusingSave.new(); refusing.payload_validator = app.state.valid
	app.state.storage = refusing
	var before := app.state.value.duplicate(true)
	await hit(trigger)
	check(not trigger.is_open and not gate.active and app.state.value==before,"save failure publishes neither sender nor receiver")
	app.state.storage = old_storage
	# Exercise the real input router, shot qualification and moving projectile.
	app.player.reset_at(trigger.global_position-Vector2(90,-6)); await ticks(1)
	app.controller.router.request_action(&"shoot_release",(trigger.global_position-app.player.position-Vector2(0,-6)).normalized())
	await ticks(22)
	check(trigger.is_open and gate.active and second_gate.active and gate.body.collision_layer==0,"accepted signal changes target collision")
	check(app.state.value.mechanisms.has(gate.element_id) and app.state.value.mechanisms.has(second_gate.element_id),"source and target saved together")
	check(app.state.valid(app.state.value),"new typed state accepted by world store")
	var retained: Dictionary = app.state.value.mechanisms.duplicate(true)
	await app.load_room("P-R03",""); await ticks(30)
	check(app.room.element_runtime.nodes[gate.element_id if is_instance_valid(gate) else "P-R03:first_bell/gate"].active,"reload restores gate without replay")
	check(app.state.value.mechanisms["P-R03:first_bell"].data.open_count==retained["P-R03:first_bell"].data.open_count,"restoration emits no duplicate permanent event")
	check(await app.review.begin("P-R05","","base",true),"moving element room loads")
	trigger = app.room.mechanisms["P-R05:drive_shuttle"] as WorldElementSwitch
	var carrier := app.room.element_runtime.nodes[str(trigger.links[0].target)] as WorldMovingPlatform
	check(not carrier.motion_running,"controlled platform begins parked")
	await hit(trigger); await ticks(10)
	check(carrier.motion_running and carrier.motion_clock>0,"signal starts actual carrier")
	await hit(trigger)
	var parked := carrier.position; var clock := carrier.motion_clock
	await ticks(10)
	check(not carrier.motion_running and carrier.position.is_equal_approx(parked) and carrier.motion_clock==clock,"second signal pauses phase and position")
	for node: Node in app.room.element_runtime.nodes.values():
		if node is WorldElementGear and not node.drive_id.is_empty(): check(is_equal_approx(node.hazard.clock,carrier.motion_clock),"driven gear shares stable clock source")
	check(await app.review.begin("P-R12","","base",true),"timed elements load")
	trigger = app.room.mechanisms["P-R12:air_shutter"] as WorldElementSwitch
	gate = app.room.element_runtime.nodes[str(trigger.links[0].target)] as WorldElementGate
	await hit(trigger)
	check(gate.active,"timed signal opens gate")
	check(not app.state.value.mechanisms.has(gate.element_id),"attempt gate does not become permanent state")
	app.player.reset_at(Vector2(800,590))
	await ticks(120)
	check(not gate.active,"timed expiry closes clear gate")
	# Every authored room must instantiate and bind all targets with real services.
	for file: String in DirAccess.get_files_at("res://config/world/rooms"):
		if not file.ends_with(".json") or file.begins_with("V-"): continue
		var id := file.trim_suffix(".json")
		check(await app.review.begin(id,"","hd",true),"runtime room "+id)
		for element: String in app.room.element_runtime.snapshot():
			check(WorldElementCatalog.state_error(app.room.element_runtime.snapshot()[element]).is_empty(),"registered state "+element)
	await WorldAudioLifecycle.drain_world(app); app.queue_free(); await process_frame
	print("WORLD ELEMENTS: ",assertions," assertions, ",failures," failures")
	quit(1 if failures else 0)

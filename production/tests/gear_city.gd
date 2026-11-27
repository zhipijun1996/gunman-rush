extends SceneTree
## Observe the pump circuit, primary encounter and wall-grapple workshop return
## through the same ordinary room, encounter and passage components as the game.
class Journey extends WorldGameHost:
	func startup_destination() -> Dictionary:
		return {"ok":true,"room":"G22"}

var host: Journey
var checks:=0
var failures:=0
var outgoing: Array[WeakRef]=[]

func _initialize() -> void: run.call_deferred()

func check(ok: bool, detail:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL gear city ",detail," in ",host.active.room.room_id if host.active!=null else "startup")

func ticks(n:int) -> void:
	for i in n:await physics_frame

func place(point:Vector2) -> void:
	host.active.player.reset_at(point)
	await ticks(4)

func observe_audio(node:Node) -> void:
	if node is GameAudio or node is GameAmbience:outgoing.append_array(node._playbacks)

func run() -> void:
	node_removed.connect(observe_audio)
	host=Journey.new()
	root.add_child(host)
	if host.active==null:
		check(false,host.last_error)
		host.free()
		quit(1)
		return
	await ticks(6)
	var lift:WorldMovingPlatform=host.active.room.element_runtime.nodes.drained_maintenance_lift
	check(not lift.activation_enabled and not host.catalog.passage_access("G22","d403",[]).matches,"dormant lift and guarded boss hatch before pump")
	host.enter_room("G23","d036")
	var s:=host.active
	await place(FixedWorldProvider.point(host.active_doc.sites.factory_pump_restored.at))
	check(s.content_sites.claim("factory_pump_restored",s.state.revision) and s.state.value.receipts.has("wr_G23_pump"),"physical valve commits pump restoration and world reward together")
	host.enter_room("G22","d036")
	await ticks(4)
	lift=host.active.room.element_runtime.nodes.drained_maintenance_lift
	check(lift.activation_enabled and lift.visible and lift.collision_layer==1,"restored pump powers actual rideable freight bed on return")
	var service_gate:Dictionary=host.active_doc.exits.d403
	await place(FixedWorldProvider.point(service_gate.spawn))
	host.active.controller.router.request_action(&"jump")
	for i in 175:
		await physics_frame
		if host.active.room.room_id=="G07" and not host.crossing:break
	check(host.active.room.room_id=="G07" and host.last_error.is_empty(),"jump through G22 upper hatch and physically emerge from G07 service shaft")
	if host.active.room.room_id=="G07":
		await ticks(4)
		s=host.active
		var encounter:WorldRoomEncounter=s.encounters[0]
		check(not s.state.has("encounter_G07_clear") and not s.state.has("W") and s.room.enemies.has("inspection_overseer"),"real overhaul machine spawns while victory and wall-climb remain locked")
		var boss:EnemyActor=s.room.enemies.inspection_overseer
		# Send a legitimate player hit only at the machine's actual stopped phase.
		# Its detailed damage/phase patterns belong to the dedicated Boss suite.
		await place(boss.motor.position+Vector2(-198,20))
		var accepted:=false
		for i in 660:
			await physics_frame
			if not host.active==s:break
			if boss.damageable.can_receive_effects():
				accepted=boss.damageable.receive_damage({"event_id":"gear_overseer_open_core","amount":boss.health.current,"source_faction":&"player","target_actor_id":boss.damageable.actor_id,"target_epoch":boss.damageable.damage_epoch})
				if accepted:
					s.policy.resolve_batch()
					break
		await ticks(6)
		check(accepted and boss.health.terminal and not s.state.has("encounter_G07_clear"),"exposed boss core can be struck; kill awaits explicit victory")
		await place(encounter.position)
		var gold:int=s.services.ledger().gold
		check(encounter.confirm() and s.state.has("encounter_G07_clear") and s.services.ledger().gold==gold+int(encounter.encounter.coin_reward),"confirming victory settles exact encounter purse once")
		check(not encounter.confirm() and not s.state.has("W"),"victory alone does not pick up the next room's device")
		var east:=FixedWorldProvider.point(host.active_doc.exits.d026.spawn)
		await place(east)
		s.controller.router.set_move_axis(1)
		for i in 170:
			await physics_frame
			if host.active.room.room_id=="G08" and not host.crossing:break
		check(host.active.room.room_id=="G08" and host.last_error.is_empty(),"walk out of cleared hall into wall-climb room")
		if host.active.room.room_id=="G08":
			s=host.active
			s.controller.router.set_move_axis(0)
			await place(FixedWorldProvider.point(host.active_doc.sites.W.at))
			check(s.content_sites.claim("W",s.state.revision) and s.controller.traversal.wall_enabled and s.state.has("W"),"physically claim the wall device and enable actual traversal")
			await place(Vector2(573,558))
			s.controller.router.set_move_axis(1)
			s.controller.router.request_action(&"jump")
			var kicks:=0
			var climbed:=false
			for i in 430:
				await physics_frame
				if s.controller.traversal.wall_ready and s.controller.traversal.state==&"wall_attach":
					s.controller.router.request_action(&"jump")
					kicks+=1
				if s.player.position.x>616 and s.player.position.y<=215 and s.player.is_on_floor():
					climbed=true
					break
			s.controller.router.set_move_axis(0)
			check(climbed and kicks>0,"wall kicks lift the player onto the actual upper walkway")
			var high:=FixedWorldProvider.point(host.active_doc.sites.d033.at)
			await place(high)
			s.controller.router.request_action(&"interact")
			await ticks(5)
			check(s.state.has("city_outer_lift_open") and host.catalog.passage_access("G04","d033",s.state.value.flags).matches,"release upper lift from its real inside handle and retain the return edge")
	await host.active.audio_service.shutdown()
	host.free()
	var until:=Time.get_ticks_msec()+2000
	while outgoing.any(func(track:WeakRef)->bool:return track.get_ref()!=null) and Time.get_ticks_msec()<until:await process_frame
	print("GEAR CITY failures=",failures," checks=",checks)
	quit(1 if failures else 0)

extends "res://tests/world/focus_heal.gd"
## Formal application only. Declared entry/cache fixtures test integration and
## durable rewards, not full-route traversal or enemy difficulty.
const ROOMS := ["P-R04","P-R05","P-R07","P-R09","P-R17","P-R19","P-R28","P-R29","P-R30","P-R31","P-R01","P-R02","P-R06","P-R08","P-R26","P-R27","P-R32","P-R33","P-R35"]

func freeze_encounters() -> void:
	for enemy: EnemyActor in app.room.enemies.values():
		enemy.cancel_attacks();enemy.process_mode=Node.PROCESS_MODE_DISABLED
		enemy.motor.position=Vector2(-10000,-10000) # Isolate reward persistence from combat.

func support(point: Vector2, label: String) -> void:
	var query := PhysicsRayQueryParameters2D.create(point-Vector2(0,6),point+Vector2(0,6),1)
	var hit := app.player.get_world_2d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and (hit.normal as Vector2).y < -.8,label+" fixed ground "+str(point))

func run() -> void:
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://approved_drafts_test.json"
	root.add_child(app)
	check(not app.content.data.get("editor_preview",false),"uses formal catalog")
	check(not app.content.room("Z-R01").is_empty(),"authorized Z01 is in the formal catalog")
	var caches:=0
	for id: String in ROOMS:
		check(await app.review.begin(id,"","hwdq"),id+" formal review entry")
		freeze_encounters();await ticks(8)
		check(app.player.is_on_floor(),id+" default entry has actual support")
		var hp:float=app.controller.actor_resources.health.current
		await ticks(12)
		check(app.controller.actor_resources.health.current==hp,id+" entry is outside terrain damage")
		var screen:=app.player.get_global_transform_with_canvas().origin
		check(Rect2(Vector2(24,24),Vector2(1232,672)).has_point(screen),id+" player visible at entry")
		for door: Dictionary in app.room.contract.doors:
			var foot:=FixedWorldProvider.point(door.landing_contract.safe_standing_position_world_units)+Vector2(0,18)
			support(foot,id+" "+str(door.id))
		for mechanism:WorldElementSwitch in app.room.mechanisms.values():
			check(mechanism!=null,id+" registered bell bound")
			for link:Dictionary in mechanism.links:
				check(app.room.element_runtime.nodes.has(str(link.target)),id+" bell resolves actual registered receiver")
		for host:WorldRoomInteraction in app.room.interaction_hosts:
			if not host.name.begins_with("Cache_"):continue
			caches+=1
			support(host.position+Vector2(0,18),host.action_id)
			app.player.reset_at(host.position);app.lifetime.invalidate_actor();app.controller.session_id+=1;await ticks(5)
			check(app.player.is_on_floor() and host.available(app.player.position,app.room.section_at(app.player.position)),host.action_id+" reachable interaction fixture at "+str(app.player.position)+" section "+app.room.section_at(app.player.position))
			var gold_before:int=app.services.ledger().gold
			app._interact();await ticks(3)
			var total:int=int(app.services.ledger().gold)-gold_before
			for drop:Dictionary in app.services.ledger().drops.values():
				if str(drop.source)=="chest:"+host.action_id:total+=int(drop.amount)
			check(app.state.value.receipts.has(host.action_id) and total==int(host.action.coin_drop_amount),host.action_id+" exact committed payout")
			var revision:int=app.state.revision
			app._commit_action(host.action_id)
			check(app.state.revision==revision,host.action_id+" duplicate interaction does not pay twice")
			check(app.state.valid(app._snapshot()),host.action_id+" reloadable durable receipt and coin ledger")
	check(caches==15,"all fifteen concentrated caches covered")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
	print("APPROVED DRAFTS: ",checks," assertions, ",failures," failures");quit(failures)

extends SceneTree
## Check accepted contact damage, failed storage, unique claims and the playable return.
const Connection := preload("res://rooms/world/p02_connections/connection_room.gd")
var failures := 0
var checks := 0
var pilot: FieldTerracePilot

class Storage extends WorldSaveService:
	var writable := true
	var recovery_attempts := 0
	var successful_recoveries := 0
	func commit(payload: Dictionary, _revision: int) -> bool:
		if payload.room == "P01" and payload.cycle == 2:
			recovery_attempts += 1
			if writable: successful_recoveries += 1
		return writable

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL P02 death ",description)

func frames(count: int) -> void:
	for tick in count: await physics_frame

func enter_field() -> bool:
	pilot.active.controller.router.set_move_axis(1)
	for tick in 360:
		await physics_frame
		if pilot.active.room.room_id == "P02" and not pilot.crossing:
			pilot.active.controller.router.set_move_axis(0)
			return true
	return false

func contact(east: EnemyActor, fatal: bool) -> void:
	var session := pilot.active
	var health := session.controller.actor_resources.health
	var before := health.current
	session.player.reset_at(Vector2(east.motor.position.x,398))
	for tick in 1500:
		await physics_frame
		if not session.controller.active or (not fatal and health.current < before): return
		var distance := east.motor.position.x-session.player.position.x
		session.controller.router.set_move_axis(clampf(distance/18,-.85,.85))

func run() -> void:
	pilot = load("res://rooms/world/P02.tscn").instantiate()
	root.add_child(pilot)
	var storage := Storage.new()
	pilot.active.state.storage = storage
	check(await enter_field(),"real P01 crossing enters the field")
	# Collect the two actual P16 services. The passage suites exercise the journeys.
	pilot.enter_room("P16","d009")
	await frames(4)
	var site := pilot.connection as P02ConnectionRoom
	for id: String in [Connection.SHARD,Connection.PURSE]:
		pilot.active.player.reset_at(site.points[id])
		await frames(6)
		pilot.active.controller.router.request_action(&"interact")
		await frames(3)
		check(not site.objects[id].visible,"independent claim "+id)
	var gold: int = pilot.active.services.ledger().gold
	check(gold > 0,"credited P16 currency")
	pilot.enter_room("P02","d009")
	await frames(4)
	var source := pilot.active
	source.player.reset_at(FixedWorldProvider.point(pilot.active_doc.sites.discover_p02_low_slope.at))
	await frames(3)
	check(source.state.has("discover_p02_low_slope"),"actual proximity fact exists")
	var revision := source.state.revision
	var west: EnemyActor = source.room.enemies.grass_verge_grub
	var target := west.damageable
	storage.writable = false
	target.receive_damage({"event_id":"death_test_west","amount":west.health.current,"source_faction":&"player",
		"target_actor_id":target.actor_id,"target_epoch":target.damage_epoch})
	await frames(4)
	check(west.health.terminal and not source.pending_defeats.is_empty(),"earlier defeat awaits a working save")
	await contact(source.room.enemies.east_road_grub,true)
	check(source.controller.actor_resources.health.terminal and not source.controller.active and not source.lifetime.active,"repeated real patrol contact is fatal")
	for tick in 240:
		await physics_frame
		if storage.recovery_attempts > 0: break
	check(storage.recovery_attempts==1 and pilot.active==source and not source.controller.active,"write failure retains the dead source until retry")
	check(source.state.revision==revision and source.state.value.cycle==1,"failure does not publish a new cycle")
	storage.writable = true
	for tick in 240:
		await physics_frame
		if pilot.active.room.room_id=="P01" and not pilot.crossing: break
	var restored := pilot.active
	check(restored.room.room_id=="P01" and restored.controller.active and restored.lifetime.active,"initial registered rest returns control")
	var health := restored.controller.actor_resources.health
	var rest := FixedWorldProvider.point(restored.state.value.rest.point)
	check(restored.player.position.distance_to(rest)<2 and restored.player.is_on_floor(),"full body stands on the registered rest ground")
	check(is_equal_approx(health.current,health.capacity) and restored.controller.combat_energy.current==0,"new life restores full health and clears resonance")
	check(storage.successful_recoveries==1 and restored.state.value.cycle==2 and restored.state.revision==revision+1,"retry commits death exactly once")
	check(restored.state.has("discover_p02_low_slope") and restored.state.value.inventory.get("health_shard",0)==1 and restored.services.ledger().gold==gold and restored.state.value.receipts.has("income:"+Connection.PURSE),"map, unique fragment and paid currency survive")
	var income := "income:enemy:P02/grass_verge_grub:cycle:1"
	check(restored.state.value.receipts.has(income) and not restored.services.ledger().drops.is_empty(),"the pending old-life reward becomes collectible exactly once")
	check(await enter_field(),"the player can walk and traverse the entrance again")
	check(not pilot.active.room.enemies.grass_verge_grub.health.terminal,"normal enemy refreshes with the new cycle")
	await contact(pilot.active.room.enemies.east_road_grub,false)
	check(pilot.active.controller.actor_resources.health.current < health.capacity and pilot.active.controller.active,"real contact can damage the restored player")
	await pilot.active.audio_service.shutdown()
	pilot.free()
	await frames(2)
	print("P02 DEATH RECOVERY failures=",failures," checks=",checks)
	quit(1 if failures else 0)

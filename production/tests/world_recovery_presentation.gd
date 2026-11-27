extends SceneTree

var failures := 0
var checks := 0
var catalog := WorldContentCatalog.new()

class StationStore extends WorldSaveService:
	var writable := true
	var writes := 0
	func commit(_candidate: Dictionary, _revision: int) -> bool:
		writes += 1
		return writable

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ",label)

func ticks(count: int) -> void:
	for frame in count: await physics_frame

func check_service_sites() -> void:
	for id: String in ["P08","Y23","E03","E09"]:
		var session := OrdinaryRoomSession.new()
		root.add_child(session)
		var edge := "d173" if id=="E09" else ""
		var error := session.open(preload("service_chamber.gd").document(id),null,null,catalog,edge)
		check(error.is_empty(),id+" opens "+error)
		if not error.is_empty():
			session.free()
			continue
		await ticks(60)
		if id=="E03":
			var heat := session.room.element_runtime.nodes["hot_bed_694"] as WorldHazardArea
			var epoch := session.lifetime.actor_epoch
			var hp := session.controller.actor_resources.health.current
			session.player.reset_at(heat.to_global(heat.rect.get_center()))
			await ticks(5)
			check(session.controller.actor_resources.health.current == hp-1 and session.lifetime.actor_epoch==epoch,"heat exposure hurts in place without resetting mechanisms")
		elif id=="E09":
			var zone: Dictionary = session.room.environment_zones.filter(func(z): return z.mode=="phase_light")[0]
			var epoch := session.lifetime.actor_epoch
			var hp := session.controller.actor_resources.health.current
			session.player.reset_at(FixedWorldProvider.rect(zone.bounds).get_center())
			await ticks(5)
			check(session.controller.actor_resources.health.current==hp-1 and session.lifetime.actor_epoch==epoch+1 and session.player.position.distance_to(session.recovery.entry_point)<4,"phase curtain returns to the actual d173 receiving platform")
		else:
			session.player.reset_at(session.room.rest_point)
			await ticks(20)
			session._interact()
			check(session.equipment_menu.panel.visible and session.equipment_menu.mode=="rest" and session.player.is_on_floor(),id+" can interact with the rest station on real floor")
			session.equipment_menu.close()
			if id=="Y23": check(session.room.section_at(session.room.rest_point)=="Y23_prize","rest belongs to locked reward zone")
			if id=="P08": check(session.content_sites.positions.tp_P08.distance_to(session.room.rest_point)>WorldContentSites.REACH,"fast travel and rest have distinct interactions")
		await session.audio_service.shutdown()
		session.free()
		await ticks(3)

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"load current lock")
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var storage := StationStore.new()
	var error := session.open(preload("service_chamber.gd").document("G12"),storage,null,catalog)
	check(error.is_empty(),"open station fixture: "+error)
	if not error.is_empty():
		quit(1)
		return
	await ticks(18)
	check(session.recovery.entry_verified,"resolve real arrival with two feet supported")
	var landing := session.recovery.entry_point
	session.player.reset_at(session.room.rest_point)
	await ticks(12)
	var departure_epoch := session.lifetime.actor_epoch
	session.policy.environment_return_requested.emit()
	check(session.lifetime.actor_epoch == departure_epoch+1 and session.player.position.is_equal_approx(landing),"terrain return uses actual entry in an unmarked room")
	var light := session.player.get_node_or_null("CarryLight") as PlayerCarryLight
	check(light != null and light.enabled and light.energy > 0, "actual carry light")
	check(session.focus_vignette.ability == session.controller.air_focus_ability, "focus signal follows current actor")
	check(session.player.get_children().any(func(child): return child is PlayerAimGuide),"current weapon aim guide")
	var earlier := session.state.candidate()
	earlier["visited_states"] = {"P02":{"enemies":{"grass_verge_grub":{"terminal":true}},"mechanisms":{"example":{"active":false}}}}
	check(session.state.commit(earlier,session.state.revision),"prior room snapshot")
	for writable: bool in [false,true]:
		storage.writable = writable
		session.player.reset_at(session.room.rest_point+Vector2(12,0))
		await ticks(16)
		session.equipment_menu.open("rest")
		var revision := session.state.revision
		var writes := storage.writes
		session.equipment_menu.rest.pressed.emit()
		var seq := session.rest_sequence
		check(is_instance_valid(seq) and seq.active and paused and not session.equipment_menu.panel.visible, "station starts from real menu")
		await ticks(35)
		check(session.state.revision == revision and storage.writes == writes, "no early or duplicate rest commit")
		await ticks(230)
		check(storage.writes == writes+1 and session.controller.active,"single charge attempt and controls restored")
		if writable:
			check(session.state.revision == revision+1 and session.state.value.rest.room=="G12" and not paused,"durable rest and world resumed")
			check(session.state.value.visited_states.P02.enemies.is_empty() and session.state.value.visited_states.P02.mechanisms.has("example") and session.state.value.visited_states.G12.refresh_on_leave,"next cycle refreshes visited enemies and preserves mechanisms")
		else:
			check(session.state.revision == revision and paused and session.equipment_menu.panel.visible and session.equipment_menu.detail.text.contains("未保存"),"failed write retains original checkpoint and offers retry")
			check(session.state.value.visited_states.P02.enemies.has("grass_verge_grub"),"failed rest does not refresh other rooms")
			session.equipment_menu.close()
	check(await session.audio_service.shutdown(),"release presentation voices")
	session.free()
	await ticks(3)
	await check_service_sites()
	print("WORLD RECOVERY PRESENTATION failures=",failures," checks=",checks)
	quit(1 if failures else 0)

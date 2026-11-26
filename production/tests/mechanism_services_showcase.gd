extends "res://tests/regional_mechanism_art.gd"
## Continuous player route through a recovery point, reward, return gate and station.
func run() -> void:
	var region := "moon_crown_castle"
	var doc := WorldRoomDocument.read("res://tests/assembly_room.json")
	doc.root.properties.region_id = region
	# Exercise the independent terrain slot in CI; the filmed example uses
	# the castle tile set and background together.
	var headless := DisplayServer.get_name() == "headless"
	doc.root.properties.terrain_material = "echo_mines" if headless else region
	doc.entities.erase("bell")
	doc.entities.erase("gate")
	doc.entities.erase("patrol")
	for id: String in ["cache","shortcut"]:
		var actions: Array = doc.get_or_add("actions",[])
		actions.append({"id":id,"room_id":doc.room_id,"section_id":"main","grants":[id+"_done"]})
	put(doc,"interaction.sign","notice",Vector2(110,352))
	put(doc,"recovery.anchor","safe",Vector2(112,288))
	put(doc,"interaction.action","chest",Vector2(266,366),{"action_id":"cache","visual":"chest"})
	put(doc,"interaction.return_gate","latch",Vector2(402,366),{"action_id":"shortcut","visual":"pulley_switch","closed_panels":[[28,-74,32,92]],"return_steps":[[58,-2,46,10]]})
	put(doc,"recovery.station","charger",Vector2(565,366))
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var problem := session.open(doc)
	expect(problem.is_empty(),problem)
	if session.room:
		var latch: WorldReturnLatch
		for host: WorldRoomInteraction in session.room.interaction_hosts:
			if host is WorldReturnLatch: latch = host
		expect(latch != null and latch.closed_terrain.show_behind_parent,"stone inset behind regional retaining frame")
		expect(MechanismRegionArt.sheet(latch).resource_path.ends_with("/"+region+".png"),"latch frame uses room region")
		expect(session.room.terrain_material == doc.root.properties.terrain_material,"inset follows separate terrain slot")
		if not headless: backdrop(session,region)
		var camera := Camera2D.new()
		camera.position = Vector2(349,329)
		camera.zoom = Vector2.ONE*2
		session.add_child(camera)
		camera.make_current()
		for tick in 270:
			await physics_frame
			if tick == 20: session.controller.router.set_move_axis(1)
			for pair: Array in [["cache",248],["shortcut",383]]:
				if session.player.position.x >= pair[1] and not session.state.value.receipts.has(pair[0]):
					session.controller.interact_requested.emit()
			if session.player.position.x >= 550: session.controller.router.set_move_axis(0)
		expect(session.state.value.receipts.has("cache"),"chest opens")
		expect(session.state.value.receipts.has("shortcut"),"return gate opens")
		expect(not session.recovery.selected.is_empty(),"safe marker activates")
		expect(session.player.position.x >= 540,"player reaches charger")
		await session.audio_service.shutdown()
	session.free()
	print("MECHANISM SERVICES SHOWCASE failures=",failures)
	quit(0 if failures==0 else 1)

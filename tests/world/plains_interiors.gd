extends "res://tests/world/plains_intro.gd"
## Regression for the shared foreground/background paths that leaked outdoors in.
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://plains_interiors.json"
	root.add_child(app);app.start_new();await settle()
	for rid: String in ["P-R05","P-R08","P-R10","P-R11","P-R12","P-R16","P-R17","P-R26","P-R29","P-R30"]:
		app.load_room(rid,"");await settle()
		var art:=app.room.get_node("RegionalArt") as PlainsRoomArt
		check(art.indoor and art.sky==null and art.daylight==null,"enclosed room uses its internal light/wall field: "+rid)
		check(not app.room.has_node("UnderworldForeground"),"no automatic meadow foreground inside: "+rid)
		for node: Node in art.get_children():
			if node is Sprite2D and node.texture!=null:
				var path: String=node.texture.resource_path
				check(not "windmill_frame" in path and not "windchime_plains_mid" in path and not "windchime_plains_near" in path and not "sunken_well" in path,"no exterior silhouette in indoor assembly: "+rid)
		if rid=="P-R26":
			var gear:=app.room.get_node("shaft_gear") as WorldGearObstacle
			var before:=gear.wheel.position
			await ticks(30);check(gear.wheel.position!=before,"real gear moves along visible rail")
			paused=true;var clock:=gear.clock;await ticks(12)
			check(gear.clock==clock,"pausing freezes gear motion and contact cadence")
			paused=false
			# Declared failure fixture on the real inspection shelf; then only input.
			app.player.reset_at(Vector2(1040,686));await ticks(30)
			var health:=app.controller.actor_resources.health.current
			for _i: int in 500:
				await ticks(1)
				if absf(gear.wheel.position.x-1040)<4:break
			app.controller.router.set_jump_held(&"keyboard_mouse",true)
			await ticks(50);app.controller.router.clear("gear_contact");await ticks(90)
			check(app.controller.actor_resources.health.current==health-1,"gear contact applies one shared environment hit")
			check(app.player.is_on_floor() and app.player.position.distance_to(Vector2(1040,686))<4,"gear hit recovers to visited safe inspection shelf without repeated damage")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
	print("PLAINS INTERIORS: ",failures," failures");quit(failures)

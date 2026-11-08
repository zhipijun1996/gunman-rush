extends "res://tests/world/plains_intro.gd"
## Qualified reward-side fixtures: actual interaction, failure rollback and reload.
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_returns_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle()
	for rid: String in ["P-R05","P-R12","P-R13","P-R17","P-R19","P-R20","P-R30"]:
		app.load_room(rid,"");await settle()
		var latch:=app.room.get_node("RewardReturn") as WorldReturnLatch
		check(latch.state==app.state,"latch bound "+rid)
		app._commit_action(latch.action_id)
		check(not app.state.has(latch.action_id),"entry cannot remotely open "+rid)
		var inventory: Dictionary=app.state.value.inventory.duplicate(true)
		app.player.reset_at(latch.position);await ticks(3)
		app.controller.router.request_action(&"interact");await ticks(5)
		check(app.state.has(latch.action_id),"reward-side explicit opening "+rid)
		check(app.state.value.inventory==inventory,"return independent of pickup "+rid)
		for body: StaticBody2D in latch.opened_bodies:check(body.collision_layer==1,"real unfolded step "+rid)
		var return_paths: Dictionary={
			"P-R05":[Vector2(1872,878),Vector2(2000,878)],
			"P-R12":[Vector2(1230,558),Vector2(1136,654),Vector2(1230,750),Vector2(1230,878)],
			"P-R13":[Vector2(1216,622),Vector2(1200,718),Vector2(1280,750)],
			"P-R17":[Vector2(832,534),Vector2(816,630),Vector2(816,782),Vector2(640,750)],
			"P-R19":[Vector2(1760,398),Vector2(1760,1134)],
			"P-R20":[Vector2(2240,526),Vector2(2096,622),Vector2(2240,718),Vector2(2096,814),Vector2(2128,878)],
			"P-R30":[Vector2(1968,622),Vector2(1824,718),Vector2(1968,814),Vector2(1968,878)]}
		check(await path(return_paths[rid],rid),"real unfolded return reaches low route "+rid)
		app.load_room(rid,"");await settle();latch=app.room.get_node("RewardReturn") as WorldReturnLatch
		check(latch.state.has(latch.action_id),"revisit retains return "+rid)
		if latch.metal_hatch:
			check(latch.hatch_opening==1 and latch.closed_bodies[0].collision_layer==0,"revisit restores open shaft and settled hinge "+rid)
		for body: StaticBody2D in latch.opened_bodies:check(body.collision_layer==1,"restored collision "+rid)
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS RETURNS: ",failures," failures");quit(failures)

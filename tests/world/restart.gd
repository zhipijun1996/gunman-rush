extends "res://tests/world/plains_intro.gd"
## Separate process reads genuine intro and arena results, never fabricates their progress.
func run() -> void:
	for slot: String in ["plains_intro_replay","plains_full_loop_replay","plains_boss_replay","plains_bellstrider_fixture","plains_returns_fixture"]:
		app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://"+slot+".json";root.add_child(app)
		check(app.continue_world(),"disk restore "+slot);await settle()
		if slot=="plains_intro_replay":check(app.state.has("intro_complete") and app.state.value.rest.room=="P-R01" and app.state.value.cycle==2,"actual introduction and explicit rest persist")
		if slot=="plains_full_loop_replay":check(app.state.has("H") and app.state.has("clock_P") and app.state.has("shortcut_p01") and app.state.has("shortcut_p02") and app.state.has("shortcut_p03") and app.state.value.rest.room=="P-R01" and app.state.value.cycle==4,"continuous first region loop persists")
		if slot=="plains_boss_replay":check(app.state.has("H") and app.state.has("boss_P_WINDKEEPER_defeated") and app.controller.traversal.hook_enabled,"actual victory and claimed H persist")
		if slot=="plains_bellstrider_fixture":check(app.state.has("boss_P_BELLSTRIDER_defeated") and app.state.value.receipts.has("pickup_part_triple"),"actual optional Boss and claimed part persist")
		if slot=="plains_returns_fixture":check(app.state.has("reward_return_TG04_open") and not app.state.value.receipts.has("pickup_TG04"),"local return persists independently of unclaimed reward")
		check(app.player.is_on_floor(),"physical supported recovery "+slot)
		await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
	print("WORLD RESTART: ",failures," failures");quit(failures)

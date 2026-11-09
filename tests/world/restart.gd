extends "res://tests/world/plains_intro.gd"
## Separate process reads genuine current six-room intro result, never fabricates their progress.
func run() -> void:
	for slot: String in ["plains_intro_replay"]:
		app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://"+slot+".json";root.add_child(app)
		check(app.continue_world(),"disk restore "+slot);await settle()
		if slot=="plains_intro_replay":check(app.state.has("intro_complete") and app.state.value.rest.room=="P-R01" and app.state.value.cycle==2,"actual introduction and explicit rest persist")
		check(app.player.is_on_floor(),"physical supported recovery "+slot)
		await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
	print("WORLD RESTART: ",failures," failures");quit(failures)

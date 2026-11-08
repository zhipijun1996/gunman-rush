extends "res://tests/world/plains_first_loop.gd"
## Declared post-victory H fixture. The first loop independently earns this state.
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_clock_return.json"
 root.add_child(app)
 check(await app.review.begin("P-R14","APPROACH-P27-P14:P-R14","h"),"post-H forecourt entry")
 var candidate:=app.state.value.duplicate(true)
 candidate.flags.append_array(["boss_P_WINDKEEPER_defeated","shortcut_p02"])
 app.state.commit(candidate,app.state.revision);app._apply_capabilities()
 check(await clock_return(),"victory gallery through repair and station loop")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS CLOCK RETURN: ",failures," failures");quit(failures)

extends "res://tests/world/plains_first_loop.gd"
## Declared base-stage entry; shots, recoil, cage boarding and the upper handoff.
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_well.json"
 root.add_child(app)
 check(await app.review.begin("P-R08","L01:P-R08","base"),"base-stage well entry")
 check(await well_route(),"inspection bell/recoil, carrier continuation and actual upper door")
 check(app.room.room_id=="P-R06" and app.state.value.entry=="room-link-139:P-R06","actual paired well exit")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS WELL: ",failures," failures");quit(failures)

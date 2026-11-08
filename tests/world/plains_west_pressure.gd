extends "res://tests/world/plains_first_loop.gd"
## Actual incoming well entry; optional HP pocket, one-way return and orchard handoff.
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_west_pressure.json"
 root.add_child(app)
 check(await app.review.begin("P-R06","room-link-139:P-R06","base"),"junction entry from well")
 check(await western_approach(true),"junction, cliff, earned shoulder reward, return and planted field")
 check(app.room.room_id=="P-R25","actual orchard arrival")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS WEST PRESSURE: ",failures," failures");quit(failures)
